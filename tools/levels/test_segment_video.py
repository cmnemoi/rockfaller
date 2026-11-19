# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Checks the segmentation on the first two playlist videos (levels 1 to 18).

Needs the first two videos in .cache/videos/, downloaded by tools/levels/download_videos.sh.
"""
from pathlib import Path

import cv2
from segment_video import Screen, _screen_of, segment

VIDEOS = Path(__file__).parents[2] / ".cache/videos"
FIRST_VIDEO = VIDEOS / "01-YNq2kLSkfLY.mp4"
SECOND_VIDEO = VIDEOS / "02-TJ10BsNj4-I.mp4"
FIXTURES = Path(__file__).parent / "fixtures"


def test_first_video_contains_levels_1_to_9():
    attempts = segment(FIRST_VIDEO, first_level=1)

    won_levels = [attempt.level for attempt in attempts if attempt.won]
    assert won_levels == list(range(1, 10)), won_levels


def test_second_video_without_level_popups_contains_levels_10_to_18():
    attempts = segment(SECOND_VIDEO, first_level=10)

    won_levels = [attempt.level for attempt in attempts if attempt.won]
    assert won_levels == list(range(10, 19)), won_levels


def test_level_1_starts_on_its_initial_grid():
    attempts = segment(FIRST_VIDEO, first_level=1)

    level_1 = attempts[0]
    assert level_1.level == 1
    assert 24.5 <= level_1.start_seconds <= 27, level_1.start_seconds


def test_level_1_ends_on_its_settled_victory_panel():
    attempts = segment(FIRST_VIDEO, first_level=1)

    assert 58 <= attempts[0].end_seconds <= 66, attempts[0].end_seconds


def test_level_8_starts_after_its_tutorial():
    attempts = segment(FIRST_VIDEO, first_level=1)

    level_8 = next(attempt for attempt in attempts if attempt.level == 8)
    assert 406.5 <= level_8.start_seconds <= 409, level_8.start_seconds


def test_loading_screen_is_not_a_grid_even_with_the_score_label():
    loading_screen = cv2.imread(str(FIXTURES / "loading_screen.png"), cv2.IMREAD_GRAYSCALE)

    assert _screen_of(loading_screen) is Screen.OTHER


def test_initial_grid_is_a_game_screen():
    level_1_start = cv2.imread(str(FIXTURES / "level_001_start.png"), cv2.IMREAD_GRAYSCALE)

    assert _screen_of(level_1_start) is Screen.GAME


if __name__ == "__main__":
    test_loading_screen_is_not_a_grid_even_with_the_score_label()
    test_initial_grid_is_a_game_screen()
    test_first_video_contains_levels_1_to_9()
    test_level_1_starts_on_its_initial_grid()
    test_level_1_ends_on_its_settled_victory_panel()
    test_level_8_starts_after_its_tutorial()
    test_second_video_without_level_popups_contains_levels_10_to_18()
    print("PASS")
