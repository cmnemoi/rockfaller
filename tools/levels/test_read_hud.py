# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Checks the reading of the moves and the goal on start frames saved in fixtures/."""
from pathlib import Path

import cv2
from read_hud import Goal, read_goal, read_moves, read_star_thresholds

FIXTURES = Path(__file__).parent / "fixtures"


def _start(level: int):
    return cv2.imread(str(FIXTURES / f"level_{level:03d}_start.png"))


def test_moves_are_read_in_the_top_medallion():
    moves = {level: read_moves(_start(level)) for level in (5, 8, 16, 17, 44, 88)}

    assert moves == {5: 15, 8: 20, 16: 20, 17: 20, 44: 25, 88: 15}


def test_moves_hidden_by_a_falling_particle_are_unreadable_rather_than_wrong():
    assert read_moves(_start(31)) is None


def test_score_goals():
    assert read_goal(_start(16)) == Goal(kind="scoring", score=20000)
    assert read_goal(_start(17)) == Goal(kind="scoring", score=22000)


def test_gelatin_goals_count_the_cells_to_clean():
    assert read_goal(_start(8)) == Goal(kind="gelatin", cell_count=16)
    assert read_goal(_start(44)) == Goal(kind="gelatin", cell_count=4)


def test_collect_goals_list_each_rock_and_its_quantity():
    assert read_goal(_start(5)) == Goal(kind="collect", rocks={"crystal": 20})
    assert read_goal(_start(88)) == Goal(kind="collect", rocks={"crystal": 20, "ground": 20, "roc": 20, "sand": 20})


def test_star_thresholds_are_read_on_the_victory_panel():
    thresholds = {
        level: read_star_thresholds(cv2.imread(str(FIXTURES / f"level_{level:03d}_stars.png")))
        for level in (1, 9, 18)
    }

    assert thresholds == {1: [1000, 2000, 3000], 9: [7000, 15000, 30000], 18: [30000, 60000, 90000]}


if __name__ == "__main__":
    test_moves_are_read_in_the_top_medallion()
    test_moves_hidden_by_a_falling_particle_are_unreadable_rather_than_wrong()
    test_score_goals()
    test_gelatin_goals_count_the_cells_to_clean()
    test_collect_goals_list_each_rock_and_its_quantity()
    test_star_thresholds_are_read_on_the_victory_panel()
    print("PASS")
