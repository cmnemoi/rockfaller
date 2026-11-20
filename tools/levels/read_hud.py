# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Reads the moves and the goal shown above the grid on a level start frame.

Digits are compared with glyphs cut from the playthrough and labelled once
(refs/digits/<area>/<digit>_<n>.png): the game's font atlases are empty in this archive.
Goal icons are told apart by their mean colour, compared with the game's sprites.

Usage: uv run read_hud.py START_FRAME.png
"""
import sys
from dataclasses import dataclass, field
from functools import cache
from itertools import pairwise
from pathlib import Path

import cv2
import numpy as np
from classify_cells import atlas_sprite

DIGITS = Path(__file__).parent / "refs/digits"
GLYPH_SIZE = (12, 18)


@dataclass(frozen=True)
class TextArea:
    """Where a number is printed, in 720p video pixels, and how its digits look."""

    name: str
    left: int
    top: int
    right: int
    bottom: int
    dark_digits: bool
    digit_heights: range


MOVES = TextArea("moves", left=600, top=50, right=662, bottom=76, dark_digits=True, digit_heights=range(12, 22))
SCORE_GOAL = TextArea("objective", left=362, top=60, right=520, bottom=100, dark_digits=False, digit_heights=range(20, 33))
# A count wider than its icon, like "100", starts left of the icon.
ICON_COUNTS = TextArea("count", left=350, top=88, right=520, bottom=108, dark_digits=False, digit_heights=range(8, 15))
# Inside the star thresholds strip that segment_video.py saves from the victory panel.
STAR_THRESHOLDS = TextArea("stars", left=0, top=12, right=370, bottom=52, dark_digits=False, digit_heights=range(10, 20))
STAR_COUNT = 3
# The medallion centres its number at x = 630 or 631 on every level; a digit hidden
# by a falling particle shifts what is left (a lone "3" at 625 for "30").
MOVES_CENTER_X = 630.5
MAX_MOVES_OFF_CENTER = 2
# Mean squared gap between a normalised glyph and its closest digit; icons stay above it.
MAX_GLYPH_GAP = 0.5
# Digits of one number are a few pixels apart; two numbers are at least 8 px apart.
MIN_GAP_BETWEEN_NUMBERS = 8
# Goal icons sit above their number, in a 26 px box.
ICON_TOP, ICON_BOTTOM, ICON_HALF_WIDTH = 62, 88, 13
# Narrower bright runs in the icon row are sparks, not icons.
MIN_ICON_WIDTH = 10
# Icon pixels are brighter than the dark HUD background.
MIN_ICON_BRIGHTNESS = 70
GOAL_ICONS = {
    "mudBack": "gelatin",
    "mercury": "mercury",
    "crystal": "crystal",
    "ground": "ground",
    "roc": "roc",
    "sand": "sand",
    "vegeta": "vegeta",
}


@dataclass(frozen=True)
class Goal:
    kind: str
    score: int | None = None
    cell_count: int | None = None
    rocks: dict[str, int] = field(default_factory=dict)


def read_moves(frame: np.ndarray) -> int | None:
    """None when the medallion is unreadable, for example behind a falling particle."""
    numbers = _read_numbers(frame, MOVES)
    if len(numbers) != 1:
        return None
    moves, center_x = numbers[0]
    return moves if abs(center_x - MOVES_CENTER_X) <= MAX_MOVES_OFF_CENTER else None


def read_goal(frame: np.ndarray) -> Goal | None:
    score_goal = _read_numbers(frame, SCORE_GOAL)
    if len(score_goal) == 1:
        return Goal(kind="scoring", score=score_goal[0][0])
    icons = [(_icon_at(frame, center_x), count) for count, center_x in _counts_under_icons(frame)]
    if not icons:
        return None
    if len(icons) == 1 and icons[0][0] in ("gelatin", "mercury"):
        return Goal(kind=icons[0][0], cell_count=icons[0][1])
    return Goal(kind="collect", rocks=dict(icons))


def read_star_thresholds(star_strip: np.ndarray) -> list[int] | None:
    """Scores for 1, 2 and 3 stars (LevelInfo.arStepScore); None unless three rising numbers show."""
    thresholds = [score for score, _ in _read_numbers(star_strip, STAR_THRESHOLDS)]
    rising = all(lower < higher for lower, higher in pairwise(thresholds))
    return thresholds if len(thresholds) == STAR_COUNT and rising else None


def _read_numbers(frame: np.ndarray, area: TextArea) -> list[tuple[int, float]]:
    """Returns each number printed in the area, with its horizontal centre."""
    numbers: list[tuple[str, float, float]] = []
    for left, right, digit in _digits(frame, area):
        if numbers and left - numbers[-1][2] < MIN_GAP_BETWEEN_NUMBERS:
            text, first_left, _ = numbers[-1]
            numbers[-1] = (text + digit, first_left, right)
        else:
            numbers.append((digit, left, right))
    return [(int(text), area.left + (first_left + last_right) / 2) for text, first_left, last_right in numbers]


def _counts_under_icons(frame: np.ndarray) -> list[tuple[int, float]]:
    """Two counts can touch ("100100"), so each digit goes to the icon above it, not to its neighbour."""
    icon_centers = _icon_centers(frame)
    counts = {center_x: "" for center_x in icon_centers}
    for left, right, digit in _digits(frame, ICON_COUNTS):
        digit_center_x = ICON_COUNTS.left + (left + right) / 2
        counts[min(icon_centers, key=lambda center_x: abs(center_x - digit_center_x))] += digit
    return [(int(count), center_x) for center_x, count in counts.items() if count]


def _icon_centers(frame: np.ndarray) -> list[float]:
    icon_row = frame[ICON_TOP:ICON_BOTTOM, ICON_COUNTS.left: ICON_COUNTS.right]
    bright_columns = (cv2.cvtColor(icon_row, cv2.COLOR_BGR2HSV)[:, :, 2] > MIN_ICON_BRIGHTNESS).any(axis=0)
    centers = []
    run_start = None
    for column, bright in enumerate([*bright_columns, False]):
        if bright and run_start is None:
            run_start = column
        elif not bright and run_start is not None:
            if column - run_start >= MIN_ICON_WIDTH:
                centers.append(ICON_COUNTS.left + (run_start + column - 1) / 2)
            run_start = None
    return centers


def _digits(frame: np.ndarray, area: TextArea) -> list[tuple[int, int, str]]:
    """Glyphs that are no digit, like goal icons, are left out."""
    grey = cv2.cvtColor(frame[area.top: area.bottom, area.left: area.right], cv2.COLOR_BGR2GRAY)
    if area.dark_digits:
        grey = 255 - grey
    _, ink = cv2.threshold(grey, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    blob_count, _, blob_stats, _ = cv2.connectedComponentsWithStats(ink)
    digits = []
    for blob in range(1, blob_count):
        left, top, width, height, _ = blob_stats[blob]
        if height not in area.digit_heights or width > height:
            continue
        glyph = cv2.resize(grey[top: top + height, left: left + width], GLYPH_SIZE, interpolation=cv2.INTER_AREA)
        digit = _closest_digit(glyph, area.name)
        if digit is not None:
            digits.append((left, left + width, digit))
    return sorted(digits)


def _closest_digit(glyph: np.ndarray, area_name: str) -> str | None:
    normalised = _normalise(glyph)
    gap, digit = min((np.mean((normalised - reference) ** 2), digit) for digit, reference in _references(area_name))
    return digit if gap <= MAX_GLYPH_GAP else None


@cache
def _references(area_name: str) -> list[tuple[str, np.ndarray]]:
    return [
        (path.name[0], _normalise(cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)))
        for path in sorted((DIGITS / area_name).glob("*.png"))
    ]


def _normalise(glyph: np.ndarray) -> np.ndarray:
    values = glyph.astype(float)
    return (values - values.mean()) / (values.std() + 1e-6)


def _icon_at(frame: np.ndarray, center_x: float) -> str:
    left = round(center_x) - ICON_HALF_WIDTH
    icon = frame[ICON_TOP:ICON_BOTTOM, left: left + 2 * ICON_HALF_WIDTH]
    brightness = cv2.cvtColor(icon, cv2.COLOR_BGR2HSV)[:, :, 2]
    icon_colour = _mean_lab(icon, (brightness > MIN_ICON_BRIGHTNESS).astype(float))
    sprite_name = min(GOAL_ICONS, key=lambda name: np.linalg.norm(icon_colour - _sprite_colour(name)))
    return GOAL_ICONS[sprite_name]


@cache
def _sprite_colour(name: str) -> np.ndarray:
    sprite = atlas_sprite(name)
    return _mean_lab(sprite[:, :, :3], sprite[:, :, 3] / 255)


def _mean_lab(pixels: np.ndarray, weights: np.ndarray) -> np.ndarray:
    lab = cv2.cvtColor(pixels.reshape(-1, 1, 3).astype(np.uint8), cv2.COLOR_BGR2LAB).reshape(-1, 3).astype(float)
    flat_weights = weights.reshape(-1)
    return (lab * flat_weights[:, None]).sum(axis=0) / flat_weights.sum()


if __name__ == "__main__":
    start = cv2.imread(sys.argv[1])
    print("moves:", read_moves(start))
    print("goal:", read_goal(start))
