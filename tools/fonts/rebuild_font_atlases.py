# /// script
# dependencies = ["pillow", "numpy", "fonttools"]
# ///
"""Redraws the bitmap font atlases missing from the archive.

client/client/assetsWeb/benchNineFont.png and birminghamFont.png came empty:
the game drew every text set in those fonts (score goals, end screens, shop...)
invisible. Their TexturePacker XML survived, so each glyph is drawn back in its
box from a TrueType font, white on transparent: the game tints it.

Birmingham.ttf comes from client/client/assets/birmingham.zip (regular weight:
its glyph widths match the atlas boxes best, 2 px apart on average).
It has no accented letters: those get their letter without the accent. It has
no ! ¡ ´ ¿ either: BenchNine draws those.
The original glyphs had their own margins; these are close, not identical.

Usage: uv run tools/fonts/rebuild_font_atlases.py
"""
import re
import unicodedata
from functools import cache
from pathlib import Path

import numpy as np
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parents[2]
ATLASES = ROOT / "client/client/assetsWeb"
BENCH_NINE = ROOT / "assets/BenchNine-Regular.ttf"
BIRMINGHAM = ROOT / "assets/Birmingham.ttf"
ATLAS_SIZE = (1024, 1024)
FONTS = {"benchNineFont": BENCH_NINE, "birminghamFont": BIRMINGHAM}
SPACE = "Space"


def rebuild(atlas_name: str, font_file: Path) -> None:
    boxes = _glyph_boxes((ATLASES / f"{atlas_name}.xml").read_text())
    line_height = max(height for _, _, _, height in boxes.values())
    atlas = Image.new("RGBA", ATLAS_SIZE, (255, 255, 255, 0))
    pen = ImageDraw.Draw(atlas)
    for name, (left, top, width, _) in boxes.items():
        if name == SPACE:
            continue
        character, glyph_font_file = _drawable(_character(name), font_file)
        font = _font_fitting(glyph_font_file, _size_filling(glyph_font_file, line_height), character, width)
        ascent, _ = font.getmetrics()
        ink_left, _, ink_right, _ = font.getbbox(character, anchor="ls")
        x = left + (width - (ink_right - ink_left)) / 2 - ink_left
        pen.text((x, top + ascent), character, font=font, fill=(255, 255, 255, 255), anchor="ls")
    atlas.save(ATLASES / f"{atlas_name}.png")
    _check(atlas, boxes)


def _glyph_boxes(index: str) -> dict[str, tuple[int, int, int, int]]:
    pattern = r'name="([^"]+)" x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"'
    return {name: tuple(map(int, numbers)) for name, *numbers in re.findall(pattern, index)}


def _character(glyph_name: str) -> str:
    """TileFont.fromSlb names glyphs by their character, or char_<hex code>."""
    if glyph_name.startswith("char_"):
        return chr(int(glyph_name.removeprefix("char_"), 16))
    return glyph_name


def _drawable(character: str, font_file: Path) -> tuple[str, Path]:
    """The character in this font, else its letter without accent, else BenchNine's."""
    unaccented = unicodedata.normalize("NFD", character)[0]
    for candidate in (character, unaccented):
        if ord(candidate) in _characters_in(font_file):
            return candidate, font_file
    return character, BENCH_NINE


@cache
def _characters_in(font_file: Path) -> set[int]:
    return set(TTFont(font_file).getBestCmap())


@cache
def _size_filling(font_file: Path, line_height: int) -> int:
    """Largest size whose ascent plus descent fits the atlas line height."""
    size = line_height
    while sum(ImageFont.truetype(str(font_file), size).getmetrics()) > line_height:
        size -= 1
    return size


def _font_fitting(font_file: Path, size: int, character: str, width: int) -> ImageFont.FreeTypeFont:
    """Shrinks the font for the few glyphs wider than their box."""
    font = ImageFont.truetype(str(font_file), size)
    while size > 1 and font.getbbox(character)[2] - font.getbbox(character)[0] > width:
        size -= 1
        font = ImageFont.truetype(str(font_file), size)
    return font


def _check(atlas: Image.Image, boxes: dict[str, tuple[int, int, int, int]]) -> None:
    opacity = np.array(atlas)[:, :, 3]
    inside = np.zeros_like(opacity, dtype=bool)
    for name, (left, top, width, height) in boxes.items():
        inside[top: top + height, left: left + width] = True
        if name != SPACE:
            assert opacity[top: top + height, left: left + width].any(), f"glyph {name} has no ink"
    assert not opacity[~inside].any(), "ink outside the glyph boxes"


if __name__ == "__main__":
    for atlas_name, font_file in FONTS.items():
        rebuild(atlas_name, font_file)
        print(f"{atlas_name}.png rebuilt from {font_file.name}")
