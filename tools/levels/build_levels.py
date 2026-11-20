# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Builds one LevelInfo record per level from the segmented playthrough.

Reads .cache/levels/*/attempts.json and the frames saved next to it by
segment_video.py, and writes data/levels.json.

Enums are written as ["Constructor", arguments...], for example ["TRHole", 12],
so the Haxe side can rebuild them with Type.createEnum.
Each record carries a "review" list: the reasons to check it by hand.
Not extracted: arGrip, and the arGP mechanics other than water (they do not show
on the start frame).

Usage: uv run build_levels.py
"""
import json
import re
from collections import Counter
from functools import cache
from pathlib import Path

import cv2
import numpy as np
from classify_cells import (
    GRID_COLUMNS,
    GRID_ROWS,
    HOLE,
    HOVERED,
    classify_grid,
    find_goal_cells,
)
from read_hud import read_goal, read_moves, read_star_thresholds

ROOT = Path(__file__).parents[2]
LEVELS_CACHE = ROOT / ".cache/levels"
OUTPUT = ROOT / "data/levels.json"
# Hand corrections, by level number, each with a "why"; see apply_overrides.
OVERRIDES = Path(__file__).parent / "overrides.json"
ASSETS = ROOT / "client/client/assetsWeb"
LEVEL_VERSION = 1
# Common.VALIDATE_LEVEL rejects a level whose deck weights do not add up to this.
DECK_TOTAL = 500

CLASSIC_ROCKS = ("crystal", "ground", "roc", "sand", "vegeta")
BONUS_BOMBS = {
    "bombMini": "TBBombMini",
    "bombHoriz": "TBBombHor",
    "bombVert": "TBBombVert",
    "bombPlus": "TBBombPlus",
    "bombCross": "TBBombCross",
    "bombColor": "TBColor",
}
# Hole sprites hole0..hole15 differ by their rough sides, which face playable cells.
# Measured on the sprites' edge opacity: 0.6 when solid, 0.3 or less when rough.
HOLE_VARIANTS = {
    frozenset(): 0,
    frozenset({"top", "right", "bottom", "left"}): 1,
    frozenset({"top", "right", "left"}): 2,
    frozenset({"right", "bottom", "left"}): 3,
    frozenset({"top", "bottom", "left"}): 4,
    frozenset({"top", "right", "bottom"}): 5,
    frozenset({"top", "right"}): 6,
    frozenset({"top", "left"}): 7,
    frozenset({"right", "bottom"}): 8,
    frozenset({"bottom", "left"}): 9,
    frozenset({"right", "left"}): 10,
    frozenset({"top", "bottom"}): 11,
    frozenset({"bottom"}): 12,
    frozenset({"top"}): 13,
    frozenset({"right"}): 14,
    frozenset({"left"}): 15,
}
NEIGHBOURS = {"top": (-1, 0), "right": (0, 1), "bottom": (1, 0), "left": (0, -1)}
# Biomes are told apart by the wall left of the grid, compared with each biome's
# wall sprite by mean colour. Biomes span whole worlds of consecutive levels, so a
# level takes the most common biome among itself and its 3 neighbours on each side.
LEFT_WALL = (slice(150, 560), slice(358, 384))
BIOME_WALLS = {
    "TBClassic": ("universCIM", "wall_classic0"),
    "TBFreeze": ("universCIM", "wall_ice0"),
    "TBMagma": ("universCIM", "wall_magma0"),
    "TBWater": ("universWCC", "wall_water0"),
    "TBCiv": ("universWCC", "wall_civ0"),
    "TBCentEarth": ("universWCC", "wall_core0"),
    "TBNightmare": ("universNL", "wall_nightmare0"),
    "TBLimbo": ("universNL", "wall_tree0"),
}
BIOME_NEIGHBOURHOOD = 3


def level_info(level: int, start: np.ndarray, star_strip: np.ndarray | None, biome: str) -> dict:
    grid = classify_grid(start)
    manual_rocks = _manual_rocks(grid)
    moves = read_moves(start)
    goal = read_goal(start)
    goal_cells = find_goal_cells(start)
    if goal is not None and goal.kind == "gelatin":
        goal_cells["gelatin"] = _gelatin_cells(goal_cells["gelatin"], grid, goal.cell_count)
    star_thresholds = read_star_thresholds(star_strip) if star_strip is not None else None
    review = []
    if moves is None:
        review.append("moves unreadable")
    if goal is None:
        review.append("goal unreadable")
    elif goal.kind == "gelatin" and len(goal_cells["gelatin"]) != goal.cell_count:
        review.append(f"{len(goal_cells['gelatin'])} gelatin cells found for {goal.cell_count} in the goal")
    if star_thresholds is None:
        review.append("star thresholds unreadable")
    return {
        "level": level,
        "version": LEVEL_VERSION,
        "numMoves": moves,
        "arStepScore": star_thresholds,
        "type": _goal_type(goal, goal_cells),
        "arGrip": [],
        "arManualRocks": manual_rocks,
        "arGP": _game_mechanics(manual_rocks),
        "arDeck": _deck(grid),
        "biome": [biome],
        "review": review,
    }


def _gelatin_cells(visible: set[tuple[int, int]], grid: list[list[str]], goal_count: int) -> set[tuple[int, int]]:
    """Ice hides the gold under it. When the iced cells make up exactly the gold
    missing from the goal, the gold is under them."""
    iced = {(row, column) for row, pieces in enumerate(grid) for column, piece in enumerate(pieces) if piece.startswith("freeze")}
    with_iced = visible | iced
    return with_iced if len(with_iced) == goal_count else visible


def apply_overrides(info: dict, override: dict) -> dict:
    """Replaces the overridden fields and drops the review reasons they settle."""
    fields = {name: value for name, value in override.items() if name != "why"}
    review = [reason for reason in info["review"] if _field_under_review(reason) not in fields]
    return info | fields | {"review": review}


def _field_under_review(reason: str) -> str:
    if reason == "moves unreadable":
        return "numMoves"
    if reason == "star thresholds unreadable":
        return "arStepScore"
    return "type"


def _goal_type(goal, goal_cells: dict[str, set[tuple[int, int]]]) -> list | None:
    if goal is None:
        return None
    if goal.kind == "scoring":
        return ["TGScoring", goal.score]
    if goal.kind == "collect":
        return ["TGCollect", [{"tr": ["TRClassic", rock], "num": count} for rock, count in goal.rocks.items()]]
    cells = [{"cX": column, "cY": row} for row, column in sorted(goal_cells[goal.kind])]
    if goal.kind == "gelatin":
        return ["TGGelatin", cells]
    # The HUD shows the cells left to cover (ModuleGoal: num - arMerc.length), while
    # the goal counts every cell to cover, including those covered at start.
    cells_to_cover = goal.cell_count + len(cells)
    return ["TGMercury", cells_to_cover, cells]


def _manual_rocks(grid: list[list[str]]) -> list[dict]:
    """Special pieces only: classic rocks and hovered cells are drawn from the deck, as in the game."""
    rocks = []
    for row, pieces in enumerate(grid):
        for column, piece in enumerate(pieces):
            if piece in CLASSIC_ROCKS or piece == HOVERED:
                continue
            type_rock = _hole(grid, row, column) if piece == HOLE else _type_rock(piece)
            rocks.append({"tr": type_rock, "x": column, "y": row})
    return rocks


def _game_mechanics(manual_rocks: list[dict]) -> list[list]:
    """The game draws bubbles only in water levels, where they spread each turn."""
    if any(rock["tr"] == ["TRBubble"] for rock in manual_rocks):
        return [["TGWater"]]
    return []


def _hole(grid: list[list[str]], row: int, column: int) -> list:
    rough_sides = frozenset(
        side
        for side, (row_step, column_step) in NEIGHBOURS.items()
        if _is_playable(grid, row + row_step, column + column_step)
    )
    return ["TRHole", HOLE_VARIANTS[rough_sides]]


def _is_playable(grid: list[list[str]], row: int, column: int) -> bool:
    """Cells beyond the grid edge count as holes."""
    return 0 <= row < GRID_ROWS and 0 <= column < GRID_COLUMNS and grid[row][column] != HOLE


def _type_rock(piece: str) -> list:
    if piece in BONUS_BOMBS:
        return ["TRBonus", [BONUS_BOMBS[piece]]]
    if piece == "bubble":
        return ["TRBubble"]
    for prefix, constructor in (("block", "TRBlockBreakable"), ("freeze", "TRFreeze"), ("bombCiv", "TRBombCiv")):
        if piece.startswith(prefix):
            return [constructor, int(piece.removeprefix(prefix))]
    raise ValueError(f"no TypeRock for {piece}")


def _deck(grid: list[list[str]]) -> list[dict]:
    """Rock frequencies on the start grid stand in for the hidden deck weights.

    They are scaled to DECK_TOTAL: rounded down, then the missing units go to the
    largest remainders (first rock first on ties), so the total is exact.
    """
    counts = Counter(piece for pieces in grid for piece in pieces if piece in CLASSIC_ROCKS)
    rocks = [rock for rock in CLASSIC_ROCKS if counts[rock]]
    total = counts.total()
    weights = {rock: counts[rock] * DECK_TOTAL // total for rock in rocks}
    by_remainder = sorted(rocks, key=lambda rock: counts[rock] * DECK_TOTAL % total, reverse=True)
    for rock in by_remainder[: DECK_TOTAL - sum(weights.values())]:
        weights[rock] += 1
    return [{"t": ["TRClassic", rock], "v": weights[rock]} for rock in rocks]


def biome_of(start: np.ndarray) -> str:
    wall_colour = cv2.cvtColor(start[LEFT_WALL], cv2.COLOR_BGR2LAB).reshape(-1, 3).mean(axis=0)
    return min(BIOME_WALLS, key=lambda biome: np.linalg.norm(wall_colour - _wall_colour(biome)))


@cache
def _wall_colour(biome: str) -> np.ndarray:
    atlas_name, sprite_name = BIOME_WALLS[biome]
    atlas = cv2.imread(str(ASSETS / f"{atlas_name}.png"), cv2.IMREAD_UNCHANGED)
    index = (ASSETS / f"{atlas_name}.xml").read_text()
    entry = re.search(rf'name="{sprite_name}" x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"', index)
    x, y, width, height = map(int, entry.groups())
    sprite = atlas[y: y + height, x: x + width]
    opaque = sprite[:, :, 3] > 128
    return cv2.cvtColor(sprite[:, :, :3], cv2.COLOR_BGR2LAB)[opaque].mean(axis=0)


def smooth_biomes(biomes: list[str]) -> list[str]:
    smoothed = []
    for index in range(len(biomes)):
        neighbourhood = biomes[max(index - BIOME_NEIGHBOURHOOD, 0): index + BIOME_NEIGHBOURHOOD + 1]
        smoothed.append(Counter(neighbourhood).most_common(1)[0][0])
    return smoothed


def _won_attempts() -> list[tuple[int, Path, Path]]:
    """(level, start frame, star strip) for the won attempt of each level."""
    won = []
    for attempts_file in sorted(LEVELS_CACHE.glob("*/attempts.json")):
        for attempt in json.loads(attempts_file.read_text()):
            if attempt["won"]:
                name = f"level-{attempt['level']:03d}-{attempt['start_seconds']:07.1f}"
                won.append((attempt["level"], attempts_file.parent / f"{name}.png", attempts_file.parent / f"{name}-stars.png"))
    return sorted(won)


if __name__ == "__main__":
    attempts = _won_attempts()
    starts = [cv2.imread(str(start)) for _, start, _ in attempts]
    biomes = smooth_biomes([biome_of(start) for start in starts])
    overrides = json.loads(OVERRIDES.read_text())
    levels = [
        apply_overrides(level_info(level, start, cv2.imread(str(star_strip)), biome), overrides.get(str(level), {}))
        for (level, _, star_strip), start, biome in zip(attempts, starts, biomes, strict=True)
    ]
    OUTPUT.write_text(json.dumps(levels, indent=1))
    to_review = [level for level in levels if level["review"]]
    print(f"{len(levels)} levels written to {OUTPUT.relative_to(ROOT)}, {len(to_review)} to review")
