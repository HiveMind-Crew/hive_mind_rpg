#!/usr/bin/env python3
"""Deterministically build the Zone 1 corrupted-forest prop atlas for issue #116."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

OUT_PATH = Path(__file__).resolve().parent / "world" / "zone1_props.png"
ATLAS_SIZE = (128, 96)
TRANSPARENT = (0, 0, 0, 0)
CANOPY = (0x10, 0x0D, 0x16, 255)
SOIL_DARK = (0x2E, 0x21, 0x1B, 255)
SOIL_MID = (0x4A, 0x36, 0x28, 255)
SOIL_LIGHT = (0x8F, 0x6D, 0x46, 255)
MOSS_DARK = (0x1E, 0x2B, 0x1D, 255)
MOSS_MID = (0x33, 0x47, 0x2A, 255)
MOSS_LIGHT = (0x7A, 0x93, 0x4F, 255)
STONE_DARK = (0x2B, 0x2B, 0x33, 255)
STONE_MID = (0x45, 0x45, 0x4F, 255)
STONE_LIGHT = (0x63, 0x63, 0x6E, 255)
CYAN = (0x4D, 0xE5, 0xFF, 255)
MAGENTA = (0xF2, 0x59, 0xB8, 255)


def rect(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], color: tuple[int, int, int, int], offset: tuple[int, int]) -> None:
    draw.rectangle(tuple(value + (offset[0] if index % 2 == 0 else offset[1]) for index, value in enumerate(xy)), fill=color)


def tree(draw: ImageDraw.ImageDraw, offset: tuple[int, int], mirror: bool) -> None:
    ox, oy = offset
    if mirror:
        canopy = [(4, 8), (14, 1), (27, 6), (31, 17), (24, 27), (9, 25), (1, 17)]
    else:
        canopy = [(1, 8), (13, 1), (27, 6), (31, 17), (23, 27), (8, 25), (0, 17)]
    draw.polygon([(ox + x, oy + y) for x, y in canopy], fill=CANOPY)
    draw.polygon([(ox + 4, oy + 9), (ox + 13, oy + 3), (ox + 25, oy + 8), (ox + 27, oy + 17), (ox + 21, oy + 23), (ox + 7, oy + 21)], fill=MOSS_DARK)
    rect(draw, (9, 10, 23, 20), MOSS_MID, offset)
    rect(draw, (13, 6, 19, 13), MOSS_LIGHT, offset)
    rect(draw, (13, 21, 19, 45), SOIL_DARK, offset)
    rect(draw, (15, 21, 18, 44), SOIL_MID, offset)
    rect(draw, (9, 42, 22, 47), SOIL_DARK, offset)
    rect(draw, (5, 45, 15, 47), MOSS_DARK, offset)
    rect(draw, (20, 44, 28, 47), MOSS_DARK, offset)


def relic_machine(draw: ImageDraw.ImageDraw, offset: tuple[int, int]) -> None:
    rect(draw, (3, 7, 28, 30), STONE_DARK, offset)
    rect(draw, (6, 9, 25, 28), STONE_MID, offset)
    rect(draw, (9, 11, 22, 25), CANOPY, offset)
    rect(draw, (14, 5, 18, 29), MAGENTA, offset)
    rect(draw, (15, 7, 17, 27), CYAN, offset)
    rect(draw, (1, 28, 30, 31), STONE_DARK, offset)
    rect(draw, (6, 31, 25, 33), MOSS_DARK, offset)


def root_ruin(draw: ImageDraw.ImageDraw, offset: tuple[int, int]) -> None:
    rect(draw, (2, 16, 29, 28), SOIL_DARK, offset)
    rect(draw, (5, 18, 27, 26), SOIL_MID, offset)
    rect(draw, (9, 4, 16, 24), STONE_DARK, offset)
    rect(draw, (11, 5, 17, 22), STONE_MID, offset)
    rect(draw, (12, 7, 16, 10), STONE_LIGHT, offset)
    rect(draw, (2, 26, 30, 31), MOSS_DARK, offset)
    rect(draw, (4, 28, 20, 31), MOSS_MID, offset)


def stump(draw: ImageDraw.ImageDraw, offset: tuple[int, int]) -> None:
    rect(draw, (2, 5, 13, 14), SOIL_DARK, offset)
    rect(draw, (4, 4, 12, 8), SOIL_LIGHT, offset)
    rect(draw, (5, 9, 11, 14), SOIL_MID, offset)
    rect(draw, (0, 13, 15, 15), MOSS_DARK, offset)


def stone(draw: ImageDraw.ImageDraw, offset: tuple[int, int]) -> None:
    rect(draw, (3, 6, 13, 13), STONE_DARK, offset)
    rect(draw, (5, 5, 11, 11), STONE_MID, offset)
    rect(draw, (6, 5, 9, 6), STONE_LIGHT, offset)
    rect(draw, (1, 13, 14, 15), MOSS_DARK, offset)


def main() -> None:
    image = Image.new("RGBA", ATLAS_SIZE, TRANSPARENT)
    draw = ImageDraw.Draw(image)
    tree(draw, (0, 0), False)
    tree(draw, (32, 0), True)
    root_ruin(draw, (64, 0))
    relic_machine(draw, (96, 0))
    stump(draw, (0, 48))
    stone(draw, (16, 48))
    stump(draw, (32, 48))
    stone(draw, (48, 48))
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT_PATH)
    print(f"wrote {OUT_PATH.relative_to(Path.cwd())} {image.size}")


if __name__ == "__main__":
    main()
