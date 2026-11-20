# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Finds the gelatin (gold) cells of each won level over the whole attempt.

On the start frame, rocks dragged under the cursor, bubbles and ice can hide gold.
Gold only disappears during a game, so a cell seen gold at any time of the attempt
was gold at start. Golden flashes and screen shakes also make cells look gold for a
moment, so the script counts the frames on which each cell looks gold, and
build_levels.py keeps the cells seen most often.

Writes level-NNN-SSSSS.S-gold.json next to each start frame: [[row, column, frames], ...].

Usage: uv run collect_gold_cells.py
"""
import json
import subprocess
from collections import Counter
from collections.abc import Iterable
from pathlib import Path

import cv2
import numpy as np
from classify_cells import find_goal_cells
from read_hud import read_goal

ROOT = Path(__file__).parents[2]
LEVELS_CACHE = ROOT / ".cache/levels"
VIDEOS = ROOT / ".cache/videos"
FRAME_WIDTH, FRAME_HEIGHT = 1280, 718
SAMPLES_PER_SECOND = 2


def gold_sightings(frames: Iterable[np.ndarray]) -> Counter[tuple[int, int]]:
    """For each (row, column) cell, the number of frames on which it looks gold."""
    return Counter(cell for frame in frames for cell in find_goal_cells(frame)["gelatin"])


def _frames(video: Path, start_seconds: float, end_seconds: float):
    decoder = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-ss", str(start_seconds), "-to", str(end_seconds), "-i", str(video),
         "-vf", f"fps={SAMPLES_PER_SECOND},scale={FRAME_WIDTH}:{FRAME_HEIGHT}", "-f", "rawvideo", "-pix_fmt", "bgr24", "-"],
        stdout=subprocess.PIPE,
    )
    frame_size = FRAME_WIDTH * FRAME_HEIGHT * 3
    while len(raw := decoder.stdout.read(frame_size)) == frame_size:
        yield np.frombuffer(raw, np.uint8).reshape(FRAME_HEIGHT, FRAME_WIDTH, 3)
    decoder.wait()


if __name__ == "__main__":
    for attempts_file in sorted(LEVELS_CACHE.glob("*/attempts.json")):
        video = next(VIDEOS.glob(f"{attempts_file.parent.name}-*.mp4"))
        for attempt in json.loads(attempts_file.read_text()):
            name = f"level-{attempt['level']:03d}-{attempt['start_seconds']:07.1f}"
            goal = read_goal(cv2.imread(str(attempts_file.parent / f"{name}.png")))
            if not attempt["won"] or goal is None or goal.kind != "gelatin":
                continue
            sightings = gold_sightings(_frames(video, attempt["start_seconds"], attempt["panel_first_seconds"]))
            rows = [[row, column, frames] for (row, column), frames in sorted(sightings.items())]
            (attempts_file.parent / f"{name}-gold.json").write_text(json.dumps(rows))
            print(f"level {attempt['level']}: {len(sightings)} cells seen gold for {goal.cell_count} in the goal")
