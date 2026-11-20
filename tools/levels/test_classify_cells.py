# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Checks the cell recognition on start frames saved in fixtures/."""
from pathlib import Path

import cv2
from classify_cells import classify_grid, find_goal_cells

FIXTURES = Path(__file__).parent / "fixtures"
CLASSIC_ROCKS = {"crystal", "ground", "roc", "sand", "vegeta"}

LEVEL_1_CENTER = [
    ["roc", "ground", "roc", "roc", "crystal"],
    ["crystal", "ground", "crystal", "sand", "ground"],
    ["sand", "sand", "sand", "roc", "ground"],
    ["roc", "ground", "roc", "roc", "sand"],
    ["crystal", "roc", "sand", "ground", "sand"],
    ["sand", "ground", "roc", "crystal", "ground"],
]


def test_level_1_is_a_5_by_6_block_of_classic_rocks_surrounded_by_holes():
    level_1_start = cv2.imread(str(FIXTURES / "level_001_start.png"))

    grid = classify_grid(level_1_start)

    expected = [["hole"] * 9 for _ in range(10)]
    for row, rocks in enumerate(LEVEL_1_CENTER, start=2):
        expected[row][2:7] = rocks
    assert grid == expected, "\n".join(" ".join(f"{cell:8}" for cell in row) for row in grid)


def test_level_8_has_two_pairs_of_intact_blocks_between_classic_rocks():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_008_start.png")))

    blocks = {(row, column) for row in (4, 5) for column in (1, 2, 6, 7)}
    holes = {(row, column) for row in (0, 9) for column in range(9)}
    _assert_pieces(grid, {cell: "block3" for cell in blocks} | {cell: "hole" for cell in holes})


def test_level_16_has_a_3_by_4_ice_square_intact_in_its_middle():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_016_start.png")))

    ice = {(row, column): "freeze1" for row in range(3, 7) for column in range(3, 6)}
    ice[(4, 4)] = ice[(5, 4)] = "freeze2"
    _assert_pieces(grid, ice)


def test_level_88_has_a_column_of_time_bombs_counting_down_from_7_to_3():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_088_start.png")))

    bombs = {(0, 4): "bombCiv7", (2, 4): "bombCiv6", (4, 4): "bombCiv5", (6, 4): "bombCiv4", (8, 4): "bombCiv3"}
    assert {cell: grid[cell[0]][cell[1]] for cell in bombs} == bombs


def test_a_rock_hovered_by_the_cursor_is_not_mistaken_for_ice():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_005_start.png")))

    assert grid[8][6] == "hovered"
    assert not any(piece.startswith("freeze") for row in grid for piece in row)


def test_rocks_dragged_by_the_cursor_are_not_mistaken_for_bubbles_or_bombs():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_044_start.png")))

    dragged = [grid[8][7], grid[8][8], grid[9][8]]
    assert all(piece == "hovered" or piece in CLASSIC_ROCKS for piece in dragged), dragged


def test_real_ice_next_to_the_cursor_stays_ice():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_017_start.png")))

    assert all(grid[row][7].startswith("freeze") for row in range(4, 8)), [grid[row][7] for row in range(4, 8)]


def test_level_18_ends_with_a_row_of_intact_ice_not_bubbles():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_018_start.png")))

    assert grid[9][1:8] == ["freeze2"] * 7


def test_level_57_has_bubbles_along_its_sides():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_057_start.png")))

    bubbles = {(row, column) for row, pieces in enumerate(grid) for column, piece in enumerate(pieces) if piece == "bubble"}
    assert bubbles == {(0, 0), (2, 0), (4, 0), (6, 0), (6, 8), (8, 0)}


def test_a_grown_crystal_is_not_mistaken_for_a_bubble():
    grid = classify_grid(cv2.imread(str(FIXTURES / "level_022_start.png")))

    assert grid[9][4] == "crystal"


def test_gelatin_cells_are_found_by_their_golden_frame():
    goal_cells = find_goal_cells(cv2.imread(str(FIXTURES / "level_008_start.png")))

    rims = {(row, column) for row in (3, 6) for column in range(2, 7)}
    middle = {(row, column) for row in (4, 5) for column in (3, 4, 5)}
    assert goal_cells == {"gelatin": rims | middle, "mercury": set()}


def test_mercury_cells_are_found_by_their_silver_background():
    goal_cells = find_goal_cells(cv2.imread(str(FIXTURES / "level_127_start.png")))

    assert goal_cells == {"gelatin": set(), "mercury": {(1, column) for column in range(9)} | {(2, 0), (2, 8)}}


def _assert_pieces(grid: list[list[str]], special_pieces: dict[tuple[int, int], str]) -> None:
    """Every cell holds its special piece, or a classic rock elsewhere."""
    wrong_cells = [
        (row, column, piece)
        for row, pieces in enumerate(grid)
        for column, piece in enumerate(pieces)
        if piece != special_pieces.get((row, column), piece if piece in CLASSIC_ROCKS else "a classic rock")
    ]
    assert not wrong_cells, wrong_cells


if __name__ == "__main__":
    test_level_1_is_a_5_by_6_block_of_classic_rocks_surrounded_by_holes()
    test_level_8_has_two_pairs_of_intact_blocks_between_classic_rocks()
    test_level_16_has_a_3_by_4_ice_square_intact_in_its_middle()
    test_level_88_has_a_column_of_time_bombs_counting_down_from_7_to_3()
    test_a_rock_hovered_by_the_cursor_is_not_mistaken_for_ice()
    test_rocks_dragged_by_the_cursor_are_not_mistaken_for_bubbles_or_bombs()
    test_real_ice_next_to_the_cursor_stays_ice()
    test_level_18_ends_with_a_row_of_intact_ice_not_bubbles()
    test_level_57_has_bubbles_along_its_sides()
    test_a_grown_crystal_is_not_mistaken_for_a_bubble()
    test_gelatin_cells_are_found_by_their_golden_frame()
    test_mercury_cells_are_found_by_their_silver_background()
    print("PASS")
