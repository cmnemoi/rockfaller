# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Checks the assembly of LevelInfo records from start frames saved in fixtures/."""
from pathlib import Path

import cv2
from build_levels import apply_overrides, level_info

FIXTURES = Path(__file__).parent / "fixtures"


def _level(level: int, stars: str | None = None) -> dict:
    start = cv2.imread(str(FIXTURES / f"level_{level:03d}_start.png"))
    star_strip = cv2.imread(str(FIXTURES / stars)) if stars else None
    return level_info(level, start, star_strip, biome="TBClassic")


def _manual_rocks(info: dict) -> dict[tuple[int, int], list]:
    return {(rock["y"], rock["x"]): rock["tr"] for rock in info["arManualRocks"]}


def test_holes_get_the_variant_whose_rough_sides_face_playable_cells():
    rocks = _manual_rocks(_level(1, stars="level_001_stars.png"))

    assert rocks[(0, 0)] == ["TRHole", 0]
    assert rocks[(1, 2)] == ["TRHole", 12]
    assert rocks[(2, 1)] == ["TRHole", 14]
    assert (2, 2) not in rocks


def test_level_8_is_a_gelatin_level_with_breakable_blocks():
    info = _level(8)

    assert info["numMoves"] == 20
    assert info["type"][0] == "TGGelatin"
    assert len(info["type"][1]) == 16
    blocks = [cell for cell, rock in _manual_rocks(info).items() if rock == ["TRBlockBreakable", 3]]
    assert len(blocks) == 8
    assert info["review"] == ["star thresholds unreadable"]


def test_classic_rocks_feed_the_deck_instead_of_the_manual_rocks():
    info = _level(1, stars="level_001_stars.png")

    deck = {entry["t"][1]: entry["v"] for entry in info["arDeck"]}
    # 5, 8, 9 and 8 rocks scaled to the 500 the game requires (Common.LENGTH_TOTAL_DECK).
    assert deck == {"crystal": 84, "ground": 133, "roc": 150, "sand": 133}
    assert info["arStepScore"] == [1000, 2000, 3000]


def test_level_88_time_bombs_are_manual_rocks():
    rocks = _manual_rocks(_level(88))

    assert rocks[(0, 4)] == ["TRBombCiv", 7]
    assert rocks[(8, 4)] == ["TRBombCiv", 3]


def test_overrides_replace_fields_and_clear_the_matching_review_reasons():
    info = {"level": 1, "numMoves": None, "type": None, "review": ["moves unreadable", "goal unreadable"]}

    fixed = apply_overrides(info, {"numMoves": 6, "type": ["TGScoring", 5000], "why": "tutorial"})

    assert fixed["numMoves"] == 6
    assert fixed["type"] == ["TGScoring", 5000]
    assert fixed["review"] == []


if __name__ == "__main__":
    test_holes_get_the_variant_whose_rough_sides_face_playable_cells()
    test_level_8_is_a_gelatin_level_with_breakable_blocks()
    test_classic_rocks_feed_the_deck_instead_of_the_manual_rocks()
    test_level_88_time_bombs_are_manual_rocks()
    test_overrides_replace_fields_and_clear_the_matching_review_reasons()
    print("PASS")
