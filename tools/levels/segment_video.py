# /// script
# dependencies = ["numpy", "opencv-python-headless"]
# ///
"""Splits a Rockfaller Journey playthrough video into level attempts.

An attempt starts when the grid comes back after a break (end screen, map,
loading), or at the start of the video. It is won when the victory banner
("¡ENHORABUENA!") shows. The start frame is the first stable grid frame:
the initial level layout.

Usage: uv run segment_video.py VIDEO FIRST_LEVEL OUTPUT_DIR
"""
import json
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path

import cv2
import numpy as np

FRAME_WIDTH, FRAME_HEIGHT = 1280, 718
FRAMES_PER_SECOND = 10
REFERENCES = Path(__file__).parent / "refs"
# Top-left corners where the references were cropped in the 720p videos.
SCORE_LABEL_POSITION = (820, 34)
WIN_BANNER_POSITION = (530, 58)
# Small video shifts between recordings are tolerated around those corners.
SEARCH_MARGIN = 8
MATCH_THRESHOLD = 0.8
# Play area: the 9x10 grid with its border, in video pixels.
PLAY_AREA = (slice(110, 620), slice(400, 870))
# Between two levels the video leaves the grid for about 5 s; shorter gaps are
# detection glitches inside the same level.
LEVEL_BREAK_FRAMES = 2 * FRAMES_PER_SECOND
# The loading screen ("CARGANDO") keeps the score label but blacks out the play
# area: its mean grey level is about 13, against 33 or more for a real grid.
MIN_GRID_BRIGHTNESS = 20
# Tutorials dim the grid and show a white speech bubble. The bubble is one
# near-white blob of about 36000 px; white rocks never exceed 3000 px.
SCREEN_COLUMNS = slice(350, 910)
NEAR_WHITE = 235
MIN_SPEECH_BUBBLE_AREA = 10_000
# The victory panel prints the three star thresholds in this strip. Shooting stars
# fly over it; the median of the middle half of the panel frames removes them.
STAR_THRESHOLDS_STRIP = (slice(280, 340), slice(450, 820))
# Mean absolute grey difference under which the grid has stopped moving.
STABLE_GRID_DIFFERENCE = 2.0


class Screen(Enum):
    GAME = "game"
    WIN = "win"
    OTHER = "other"


@dataclass
class Attempt:
    level: int
    start_seconds: float
    won: bool
    # Middle of the victory panel, which shows the star thresholds; the panel slides
    # in at its start and fades out at its end.
    end_seconds: float | None = None
    panel_first_seconds: float | None = field(default=None, repr=False)


def segment(video: Path, first_level: int, output_dir: Path | None = None) -> list[Attempt]:
    attempts: list[Attempt] = []
    level = first_level
    frames_away_from_grid = LEVEL_BREAK_FRAMES
    waits_for_start = False
    previous_frame = None
    star_strips: dict[int, list[np.ndarray]] = {}
    for frame_index, frame in enumerate(_grey_frames(video)):
        screen = _screen_of(frame)
        if screen is Screen.GAME:
            if frames_away_from_grid >= LEVEL_BREAK_FRAMES:
                waits_for_start = True
            frames_away_from_grid = 0
            if waits_for_start and _grid_is_stable(frame, previous_frame) and not _shows_tutorial(frame):
                waits_for_start = False
                attempt = Attempt(level=level, start_seconds=frame_index / FRAMES_PER_SECOND, won=False)
                attempts.append(attempt)
                if output_dir is not None:
                    _save_frame(video, attempt.start_seconds, output_dir / f"level-{attempt.level:03d}-{attempt.start_seconds:07.1f}.png")
        else:
            frames_away_from_grid += 1
            if screen is Screen.WIN and attempts:
                attempt, seconds = attempts[-1], frame_index / FRAMES_PER_SECOND
                if not attempt.won:
                    attempt.won = True
                    attempt.panel_first_seconds = seconds
                    level += 1
                attempt.end_seconds = round((attempt.panel_first_seconds + seconds) / 2, 1)
                star_strips.setdefault(len(attempts) - 1, []).append(frame[STAR_THRESHOLDS_STRIP].copy())
        previous_frame = frame
    if output_dir is not None:
        for index, attempt in enumerate(attempts):
            if attempt.end_seconds is not None:
                name = f"level-{attempt.level:03d}-{attempt.start_seconds:07.1f}"
                _save_frame(video, attempt.end_seconds, output_dir / f"{name}-end.png")
                cv2.imwrite(str(output_dir / f"{name}-stars.png"), _without_shooting_stars(star_strips[index]))
    return attempts


def _without_shooting_stars(strips: list[np.ndarray]) -> np.ndarray:
    quarter = len(strips) // 4
    return np.median(np.stack(strips[quarter: len(strips) - quarter]), axis=0).astype(np.uint8)


def _grey_frames(video: Path):
    decoder = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-i", str(video), "-vf", f"fps={FRAMES_PER_SECOND}",
         "-f", "rawvideo", "-pix_fmt", "gray", "-"],
        stdout=subprocess.PIPE,
    )
    frame_size = FRAME_WIDTH * FRAME_HEIGHT
    while len(raw := decoder.stdout.read(frame_size)) == frame_size:
        yield np.frombuffer(raw, np.uint8).reshape(FRAME_HEIGHT, FRAME_WIDTH)
    decoder.wait()


def _screen_of(frame) -> Screen:
    if _shows(frame, "win_banner", WIN_BANNER_POSITION):
        return Screen.WIN
    if _shows(frame, "score_label", SCORE_LABEL_POSITION) and _play_area_is_lit(frame):
        return Screen.GAME
    return Screen.OTHER


def _shows(frame, reference_name: str, position: tuple[int, int]) -> bool:
    reference = _reference(reference_name)
    left, top = position
    height, width = reference.shape
    window = frame[
        max(top - SEARCH_MARGIN, 0): top + height + SEARCH_MARGIN,
        max(left - SEARCH_MARGIN, 0): left + width + SEARCH_MARGIN,
    ]
    similarity = cv2.matchTemplate(window, reference, cv2.TM_CCOEFF_NORMED).max()
    return similarity >= MATCH_THRESHOLD


def _play_area_is_lit(frame) -> bool:
    return frame[PLAY_AREA].mean() >= MIN_GRID_BRIGHTNESS


_references: dict[str, np.ndarray] = {}


def _reference(name: str) -> np.ndarray:
    if name not in _references:
        _references[name] = cv2.imread(str(REFERENCES / f"{name}.png"), cv2.IMREAD_GRAYSCALE)
    return _references[name]


def _grid_is_stable(frame, previous_frame) -> bool:
    if previous_frame is None:
        return False
    difference = cv2.absdiff(frame[PLAY_AREA], previous_frame[PLAY_AREA]).mean()
    return difference < STABLE_GRID_DIFFERENCE


def _shows_tutorial(frame) -> bool:
    near_white = (frame[:, SCREEN_COLUMNS] > NEAR_WHITE).astype(np.uint8)
    _, _, blob_stats, _ = cv2.connectedComponentsWithStats(near_white)
    blob_areas = blob_stats[1:, cv2.CC_STAT_AREA]
    return blob_areas.size > 0 and blob_areas.max() >= MIN_SPEECH_BUBBLE_AREA


def _save_frame(video: Path, seconds: float, image: Path) -> None:
    image.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", str(seconds), "-i", str(video), "-frames:v", "1", str(image)],
        check=True,
    )


if __name__ == "__main__":
    video, first_level, output_dir = Path(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
    output_dir.mkdir(parents=True, exist_ok=True)
    attempts = segment(video, first_level, output_dir)
    (output_dir / "attempts.json").write_text(json.dumps([asdict(attempt) for attempt in attempts], indent=2))
    print(f"{len(attempts)} attempts, {sum(attempt.won for attempt in attempts)} won")
