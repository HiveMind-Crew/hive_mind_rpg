#!/usr/bin/env python3
"""Generate the deterministic HD Zone 1 encounter seal for issue #212.

The asset is a presentation-only corrupted-root boundary. Gameplay collision
remains authored by the six StaticBody2D seams in zone1_graybox.tscn.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

WIDTH = 192
HEIGHT = 384
OUT = Path(__file__).resolve().parent / "world" / "hd" / "encounter_seal.png"

BARK_DARK = (29, 24, 27, 235)
BARK_MID = (70, 52, 42, 250)
BARK_LIGHT = (128, 91, 58, 230)
THORN = (36, 29, 34, 245)
MAGENTA = (178, 43, 128, 220)
MAGENTA_HOT = (240, 88, 187, 245)
GOLD = (231, 176, 79, 245)
GOLD_CORE = (255, 222, 142, 255)


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], width: int, color: tuple[int, int, int, int]) -> None:
    draw.line(points, fill=color, width=width, joint="curve")


def _root_paths() -> tuple[list[tuple[int, int]], ...]:
    return (
        [(66, 24), (47, 52), (76, 91), (47, 127), (75, 179), (47, 230), (72, 282), (45, 312), (65, 330)],
        [(126, 24), (147, 56), (119, 98), (145, 137), (117, 189), (148, 238), (120, 292), (146, 322), (126, 330)],
        [(94, 22), (111, 56), (88, 106), (108, 168), (84, 227), (108, 288), (91, 318), (102, 330)],
    )


def build() -> Image.Image:
    shadow = Image.new("RGBA", (WIDTH, HEIGHT))
    shadow_draw = ImageDraw.Draw(shadow)
    for path in _root_paths():
        _line(shadow_draw, [(x + 5, y + 7) for x, y in path], 30, (8, 7, 10, 145))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))

    canvas = Image.new("RGBA", (WIDTH, HEIGHT))
    canvas.alpha_composite(shadow)
    draw = ImageDraw.Draw(canvas)
    paths = _root_paths()
    widths = (27, 25, 18)
    for path, width in zip(paths, widths):
        _line(draw, path, width + 8, THORN)
        _line(draw, path, width, BARK_DARK)
        _line(draw, [(x - 3, y) for x, y in path], max(4, width // 3), BARK_MID)
        _line(draw, [(x - 5, y - 3) for x, y in path], 3, BARK_LIGHT)

    # Jagged thorn silhouettes break the old rectangular read.
    for y in range(20, 370, 28):
        side = -1 if (y // 28) % 2 == 0 else 1
        x = 57 if side < 0 else 136
        draw.polygon([(x, y), (x + side * 35, y + 12), (x + side * 9, y + 19)], fill=THORN)
        draw.polygon([(x + 8 * side, y + 5), (x + side * 23, y + 12), (x + side * 8, y + 14)], fill=BARK_MID)

    glow = Image.new("RGBA", (WIDTH, HEIGHT))
    glow_draw = ImageDraw.Draw(glow)
    for y in (68, 180, 298):
        glow_draw.ellipse((76, y - 20, 116, y + 20), outline=(220, 34, 151, 185), width=7)
        glow_draw.line((82, y, 110, y), fill=(238, 66, 176, 220), width=4)
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
    draw = ImageDraw.Draw(canvas)
    for y in (68, 180, 298):
        # Broken corruption seam and a small lock glyph: readable but not a pickup.
        _line(draw, [(84, y - 13), (96, y - 3), (88, y + 7), (106, y + 16)], 4, MAGENTA)
        draw.ellipse((82, y - 16, 112, y + 16), outline=MAGENTA_HOT, width=3)
        draw.polygon([(97, y - 8), (105, y), (97, y + 8), (89, y)], fill=GOLD)
        draw.ellipse((94, y - 3, 100, y + 3), fill=GOLD_CORE)

    # Fine root fibers make the seal feel interwoven rather than mechanically striped.
    for index in range(7):
        y = 18 + index * 46
        _line(draw, [(60, y), (91, y + 18), (131, y + 4)], 3, BARK_LIGHT)
        _line(draw, [(130, y + 20), (96, y + 34), (58, y + 48)], 2, BARK_MID)
    return canvas


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build().save(OUT)
    print(f"wrote {OUT}")
