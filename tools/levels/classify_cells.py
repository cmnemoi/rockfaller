# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Recognises the piece in each cell of the 9x10 grid on a level start frame.

Each cell is compared with the game's own sprites (client/client/assetsWeb/assets1),
scaled to the video. A sprite matches when its shape correlates best and its
colours are close; a cell that matches no sprite is a hole.

Usage: uv run classify_cells.py START_FRAME.png
"""
import re
import sys
from dataclasses import dataclass
from functools import cache
from pathlib import Path

import cv2
import numpy as np

ATLAS = Path(__file__).parents[2] / "client/client/assetsWeb/assets1"
GRID_COLUMNS, GRID_ROWS = 9, 10
# Centre of the top-left cell and distance between cell centres, in 720p video pixels.
FIRST_CELL_CENTER = (436, 147)
CELL_PITCH = 48.8
# A cell is 124 px wide in the game, so sprites shrink by the same ratio as the grid.
SPRITE_SCALE = CELL_PITCH / 124
# Time bomb sprites are stored smaller in the atlas: the game draws them 1.5 times
# larger than rocks (measured: correlation 0.95 at 1.5, 0.69 at 1.375).
ATLAS_SIZE_RATIOS = {"bombeCiv/": 1.5}
# The cursor's white hand is a pure white blob of about 110 px, 14 px wide and
# 19 px high; rock highlights are flatter and wider.
CURSOR_WHITE = 245
CURSOR_AREA = range(90, 141)
CURSOR_WIDTH = range(12, 17)
CURSOR_HEIGHT = range(17, 23)
# A hovered rock grows and fades, and can then look like ice, a bubble or a bomb.
# Within about 2 cells of the cursor, those look-alikes must match closely to be kept.
# Measured on the 53 such cells of the playthrough (real piece / hovered rock):
# ice colour gap <= 32 / >= 36, bubble correlation >= 0.43 / <= 0.35,
# bonus bomb correlation >= 0.56 / <= 0.40.
HOVER_RADIUS = 110
CLOSE_MATCHES_NEAR_CURSOR = {
    "freeze": lambda match: match.colour_gap <= 34,
    "bubble": lambda match: match.correlation >= 0.4,
    "bomb": lambda match: match.correlation >= 0.5,
}
HOVERED = "hovered"
# Recordings shift by a few pixels; each sprite is searched around the cell centre.
SEARCH_MARGIN = 5
# Mean colour gap under the sprite mask: about 30 for a matching rock, 78 or more on a hole.
MAX_COLOUR_GAP = 55
HOLE = "hole"
# Cracks are pixels darker than 70 % of the median grey, in the 30 px middle of an
# ice cell. They cover about 0.12 of it when cracked, 0 when intact.
ICE_MIDDLE_HALF_SIDE = 15
CRACK_DARKNESS = 0.7
MIN_CRACKED_ICE_DARK_SHARE = 0.05
# Hovered rocks are drawn with their "Over" sprite; they are the same rock.
SPRITES = {
    "crystal": ["crystal", "crystalOver"],
    "ground": ["ground", "groundOver"],
    "roc": ["roc", "rocOver"],
    "sand": ["sand", "sandOver"],
    "vegeta": ["vegeta", "vegetaOver"],
    # The other pieces the level editor can place (client/levelEditor/src/mod/ModAssets.hx).
    # The number is the TypeRock parameter, which Common.GET_HSID_FROM_TYPEROCK turns into the sprite name.
    "bubble": ["bubble"],
    "block3": ["blocBreak00"],
    "block2": ["blocBreak01"],
    "block1": ["blocBreak02"],
    # Ice is told apart by its cracks (see _ice_state): the filmed cracks differ from iceFront1.
    "freeze": ["iceFront0", "iceFront1"],
    "bombMini": ["bombMini/0000"],
    "bombHoriz": ["bombHoriz/0000"],
    "bombVert": ["bombVert/0000"],
    "bombPlus": ["bombPlus/0000"],
    "bombCross": ["bombCross/0000"],
    "bombColor": ["bombColor/0000"],
} | {f"bombCiv{turns}": [f"bombeCiv/000{turns}"] for turns in range(10)}


# Gelatin (TGGelatin) and mercury (TGMercury) mark cells under their rock; their
# colour shows in the cell corners, 19 px from the centre, which rocks rarely cover.
# Median corner colours (OpenCV HSV): gelatin 24/199/235, while other cells keep a
# saturation of 150 or less; mercury 107-118 / 24-44 / 177-190.
# Gelatin under ice or under a hovered rock does not show: lot 5 flags levels whose
# gelatin cell count differs from the goal.
CORNER_INSET = 19
CORNER_HALF_SIDE = 3
GOAL_MARK_COLOURS = {
    "gelatin": {"hue": range(15, 36), "saturation": range(170, 256), "value": range(200, 256)},
    "mercury": {"hue": range(100, 126), "saturation": range(61), "value": range(160, 211)},
}


@dataclass
class Match:
    piece: str
    correlation: float
    colour_gap: float


def classify_grid(frame: np.ndarray) -> list[list[str]]:
    cursor = _cursor_position(frame)
    grid = []
    for row in range(GRID_ROWS):
        pieces = []
        for column in range(GRID_COLUMNS):
            match = _best_match(frame, column, row)
            if cursor is not None and _is_near(cursor, column, row) and _may_be_a_hovered_rock(match):
                pieces.append(HOVERED)
            elif match.piece == "freeze":
                pieces.append(_ice_state(frame, *_cell_center(column, row)))
            else:
                pieces.append(match.piece)
        grid.append(pieces)
    return grid


def find_goal_cells(frame: np.ndarray) -> dict[str, set[tuple[int, int]]]:
    """Returns the (row, column) cells marked with gelatin or mercury."""
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    cells = [(row, column) for row in range(GRID_ROWS) for column in range(GRID_COLUMNS)]
    return {
        mark: {cell for cell in cells if _is_in(_corner_colour(hsv, *cell), colour)}
        for mark, colour in GOAL_MARK_COLOURS.items()
    }


def _is_in(colour: tuple[int, int, int], ranges: dict[str, range]) -> bool:
    hue, saturation, value = colour
    return hue in ranges["hue"] and saturation in ranges["saturation"] and value in ranges["value"]


def _corner_colour(hsv: np.ndarray, row: int, column: int) -> tuple[int, int, int]:
    """Median HSV colour of the four cell corners."""
    center_x, center_y = (round(coordinate) for coordinate in _cell_center(column, row))
    corners = [
        hsv[y - CORNER_HALF_SIDE: y + CORNER_HALF_SIDE, x - CORNER_HALF_SIDE: x + CORNER_HALF_SIDE].reshape(-1, 3)
        for x in (center_x - CORNER_INSET, center_x + CORNER_INSET)
        for y in (center_y - CORNER_INSET, center_y + CORNER_INSET)
    ]
    hue, saturation, value = np.median(np.vstack(corners), axis=0)
    return int(hue), int(saturation), int(value)


def _cell_center(column: int, row: int) -> tuple[float, float]:
    return FIRST_CELL_CENTER[0] + column * CELL_PITCH, FIRST_CELL_CENTER[1] + row * CELL_PITCH


def _cursor_position(frame: np.ndarray) -> tuple[float, float] | None:
    pure_white = (cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY) >= CURSOR_WHITE).astype(np.uint8)
    blob_count, _, blob_stats, blob_centers = cv2.connectedComponentsWithStats(pure_white)
    for blob in range(1, blob_count):
        area = blob_stats[blob, cv2.CC_STAT_AREA]
        width, height = blob_stats[blob, cv2.CC_STAT_WIDTH], blob_stats[blob, cv2.CC_STAT_HEIGHT]
        if area in CURSOR_AREA and width in CURSOR_WIDTH and height in CURSOR_HEIGHT:
            return tuple(blob_centers[blob])
    return None


def _is_near(cursor: tuple[float, float], column: int, row: int) -> bool:
    center_x, center_y = _cell_center(column, row)
    return np.hypot(center_x - cursor[0], center_y - cursor[1]) <= HOVER_RADIUS


def _may_be_a_hovered_rock(match: Match) -> bool:
    """Time bombs keep a distinct octagon and digit, so they are never confused."""
    if match.piece.startswith("bombCiv"):
        return False
    look_alike = next((prefix for prefix in CLOSE_MATCHES_NEAR_CURSOR if match.piece.startswith(prefix)), None)
    return look_alike is not None and not CLOSE_MATCHES_NEAR_CURSOR[look_alike](match)


def _best_match(frame: np.ndarray, column: int, row: int) -> Match:
    center_x, center_y = _cell_center(column, row)
    best = Match(piece=HOLE, correlation=-1.0, colour_gap=float("inf"))
    for piece, sprite_names in SPRITES.items():
        for sprite_name in sprite_names:
            correlation, colour_gap = _compare(frame, center_x, center_y, atlas_sprite(sprite_name))
            if colour_gap <= MAX_COLOUR_GAP and correlation > best.correlation:
                best = Match(piece=piece, correlation=correlation, colour_gap=colour_gap)
    return best


def _ice_state(frame: np.ndarray, center_x: float, center_y: float) -> str:
    """TRFreeze(2) is intact ice, TRFreeze(1) is cracked ice."""
    x, y = round(center_x), round(center_y)
    middle = frame[y - ICE_MIDDLE_HALF_SIDE: y + ICE_MIDDLE_HALF_SIDE, x - ICE_MIDDLE_HALF_SIDE: x + ICE_MIDDLE_HALF_SIDE]
    grey_middle = cv2.cvtColor(middle, cv2.COLOR_BGR2GRAY)
    crack_share = (grey_middle < np.median(grey_middle) * CRACK_DARKNESS).mean()
    return "freeze1" if crack_share >= MIN_CRACKED_ICE_DARK_SHARE else "freeze2"


def _compare(frame: np.ndarray, center_x: float, center_y: float, sprite: np.ndarray) -> tuple[float, float]:
    height, width = sprite.shape[:2]
    left = round(center_x - width / 2 - SEARCH_MARGIN)
    top = round(center_y - height / 2 - SEARCH_MARGIN)
    window = frame[top: top + height + 2 * SEARCH_MARGIN, left: left + width + 2 * SEARCH_MARGIN]
    colours, opacity = sprite[:, :, :3], sprite[:, :, 3]
    correlations = cv2.matchTemplate(window, colours, cv2.TM_CCOEFF_NORMED, mask=opacity)
    # A flat window makes the normalised correlation divide by zero.
    correlations[~np.isfinite(correlations)] = 0
    _, correlation, _, (match_x, match_y) = cv2.minMaxLoc(correlations)
    patch = window[match_y: match_y + height, match_x: match_x + width].astype(float)
    weights = opacity[:, :, None] / 255
    colour_gap = (np.abs(patch - colours) * weights).sum() / (weights.sum() * 3)
    return correlation, colour_gap


@cache
def atlas_sprite(name: str) -> np.ndarray:
    """Returns the sprite in its full frame (BGRA), scaled to the video grid."""
    atlas = cv2.imread(f"{ATLAS}.png", cv2.IMREAD_UNCHANGED)
    entry = re.search(
        rf'name="{re.escape(name)}" x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"'
        rf'(?: frameX="(-?\d+)" frameY="(-?\d+)" frameWidth="(\d+)" frameHeight="(\d+)")?',
        _atlas_index(),
    )
    x, y, width, height = map(int, entry.groups()[:4])
    if entry.group(5) is None:
        offset_x, offset_y, frame_width, frame_height = 0, 0, width, height
    else:
        offset_x, offset_y, frame_width, frame_height = map(int, entry.groups()[4:])
    full_frame = np.zeros((frame_height, frame_width, 4), np.uint8)
    full_frame[-offset_y: -offset_y + height, -offset_x: -offset_x + width] = atlas[y: y + height, x: x + width]
    scale = SPRITE_SCALE * next((ratio for prefix, ratio in ATLAS_SIZE_RATIOS.items() if name.startswith(prefix)), 1)
    return cv2.resize(full_frame, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)


@cache
def _atlas_index() -> str:
    return Path(f"{ATLAS}.xml").read_text()


if __name__ == "__main__":
    for row in classify_grid(cv2.imread(sys.argv[1])):
        print(" ".join(f"{piece:8}" for piece in row))
