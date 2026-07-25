#!/usr/bin/env python3
"""Build the deterministic stylized-HD relic-lightning FX sheet for issue #190.

Layout of `fx/relic_lightning_fx.png` (768x288, straight alpha):
- cast: 6 x 96x96 cells (row y=0), an angular muzzle fork authored toward +x;
- flight: 4 x 128x64 cells (row y=96), a lightning head exactly at the cell
  center with the branching trail behind -x;
- impact: 6 x 128x128 cells (row y=160), a compact electrical contact burst.

The runtime rotates the +x-authored cast/flight art to all eight relic aim
angles. The flight head stays centered on the collision position; this generator
only changes presentation. Pixels are closed-form Pillow geometry with no
randomness or external source imagery, making the output byte-reproducible and
CC0-safe project art.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent / "fx"
SHEET_SIZE = (768, 288)
CAST_CELL = 96
CAST_FRAMES = 6
FLIGHT_CELL = (128, 64)
FLIGHT_FRAMES = 4
FLIGHT_ROW_Y = 96
IMPACT_CELL = 128
IMPACT_FRAMES = 6
IMPACT_ROW_Y = 160
SCALE = 4

WHITE = (246, 255, 255, 255)
CYAN = (76, 232, 255, 255)
CYAN_DEEP = (23, 112, 193, 255)
MAGENTA = (241, 69, 207, 255)
MAGENTA_DEEP = (137, 32, 156, 210)


def _p(point: tuple[float, float]) -> tuple[int, int]:
    return (round(point[0] * SCALE), round(point[1] * SCALE))


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], width: float, color: tuple[int, ...]) -> None:
    draw.line([_p(point) for point in points], fill=color, width=max(1, round(width * SCALE)), joint="curve")


def _bolt_points(start: tuple[float, float], end: tuple[float, float], phase: float, zigzag: float, steps: int = 5) -> list[tuple[float, float]]:
    """Return a deterministic angular lightning polyline from start to end."""
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    length = math.hypot(dx, dy)
    if length <= 0.0:
        return [start, end]
    normal = (-dy / length, dx / length)
    points = [start]
    for index in range(1, steps):
        progress = index / steps
        # Alternating hard kinks; phase changes the authored animation without
        # using random numbers and preserves a clear overall +x direction.
        offset = math.sin(index * 4.3 + phase) * zigzag
        points.append((start[0] + dx * progress + normal[0] * offset, start[1] + dy * progress + normal[1] * offset))
    points.append(end)
    return points


def _add_glow(canvas: Image.Image, paths: list[list[tuple[float, float]]], radius: float, color: tuple[int, int, int, int]) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for path in paths:
        _line(draw, path, radius, color)
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius * SCALE * 0.8)))


def _draw_lightning(canvas: Image.Image, paths: list[list[tuple[float, float]]], core_width: float = 2.2) -> None:
    _add_glow(canvas, paths, 8.0, (20, 144, 255, 82))
    _add_glow(canvas, paths, 4.0, (30, 236, 255, 145))
    draw = ImageDraw.Draw(canvas)
    for path in paths:
        _line(draw, path, core_width + 2.6, CYAN_DEEP)
        _line(draw, path, core_width + 1.1, CYAN)
        _line(draw, path, core_width, WHITE)


def _cast_cell(frame: int) -> Image.Image:
    phase = frame / CAST_FRAMES
    canvas = Image.new("RGBA", (CAST_CELL * SCALE, CAST_CELL * SCALE), (0, 0, 0, 0))
    origin = (43.0, 48.0)
    head = (73.0 + phase * 9.0, 48.0)
    main = _bolt_points(origin, head, phase * math.tau, 5.0 - phase * 1.2, 4)
    branches = [main]
    branch_length = 13.0 + frame * 1.7
    branches.append(_bolt_points((58.0, 47.0), (57.0 + branch_length, 28.0), phase + 0.7, 2.7, 3))
    branches.append(_bolt_points((62.0, 50.0), (65.0 + branch_length * 0.78, 66.0), phase + 1.8, 2.2, 3))
    _draw_lightning(canvas, branches, 2.1)
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((round((origin[0] - 4.0) * SCALE), round((origin[1] - 4.0) * SCALE), round((origin[0] + 4.0) * SCALE), round((origin[1] + 4.0) * SCALE)), fill=WHITE)
    return canvas.resize((CAST_CELL, CAST_CELL), Image.Resampling.LANCZOS)


def _flight_cell(frame: int) -> Image.Image:
    phase = math.tau * frame / FLIGHT_FRAMES
    width, height = FLIGHT_CELL
    canvas = Image.new("RGBA", (width * SCALE, height * SCALE), (0, 0, 0, 0))
    # This is the collision-truthful center, not the visual leading tip.
    core = (width / 2.0, height / 2.0)
    head = (core[0] + 13.0, core[1] + math.sin(phase) * 1.5)
    tail_end = (17.0, core[1] + math.cos(phase) * 4.5)
    main = _bolt_points(tail_end, head, phase, 5.0, 7)
    branches = [main]
    branches.append(_bolt_points((42.0, core[1] - 1.0), (28.0, core[1] - 15.0), phase + 1.4, 3.0, 3))
    branches.append(_bolt_points((50.0, core[1] + 2.0), (36.0, core[1] + 14.0), phase + 2.7, 2.8, 3))
    branches.append(_bolt_points((70.0, core[1] - 1.0), (82.0, core[1] - 10.0), phase + 4.0, 2.0, 3))
    _draw_lightning(canvas, branches, 1.8)
    draw = ImageDraw.Draw(canvas)
    # A compact centered charge knot tells players where the collision is while
    # angular lines, not a circular outline, carry the silhouette.
    for radius, color in ((7.0, CYAN_DEEP), (4.6, CYAN), (2.4, WHITE)):
        draw.ellipse((round((core[0] - radius) * SCALE), round((core[1] - radius) * SCALE), round((core[0] + radius) * SCALE), round((core[1] + radius) * SCALE)), fill=color)
    return canvas.resize(FLIGHT_CELL, Image.Resampling.LANCZOS)


def _impact_cell(frame: int) -> Image.Image:
    progress = frame / IMPACT_FRAMES
    center = (64.0, 64.0)
    canvas = Image.new("RGBA", (IMPACT_CELL * SCALE, IMPACT_CELL * SCALE), (0, 0, 0, 0))
    branches: list[list[tuple[float, float]]] = []
    for index in range(9):
        angle = math.tau * index / 9.0 + progress * 0.42
        length = 23.0 + progress * 15.0 + (index % 3) * 2.0
        endpoint = (center[0] + math.cos(angle) * length, center[1] + math.sin(angle) * length)
        branches.append(_bolt_points(center, endpoint, progress * 5.0 + index * 0.73, 4.5 - progress * 1.7, 4))
    _draw_lightning(canvas, branches, 1.8)
    draw = ImageDraw.Draw(canvas)
    flash = max(2.0, 12.0 - progress * 9.0)
    draw.ellipse((round((center[0] - flash) * SCALE), round((center[1] - flash) * SCALE), round((center[0] + flash) * SCALE), round((center[1] + flash) * SCALE)), fill=WHITE)
    # Sparse magenta charged fragments distinguish impact from ordinary cyan hit sparks.
    for index in range(6):
        angle = math.tau * (index + 0.35) / 6.0 - progress * 0.3
        distance = 19.0 + progress * 27.0
        x = center[0] + math.cos(angle) * distance
        y = center[1] + math.sin(angle) * distance
        _line(draw, [(x, y), (x + math.cos(angle) * 5.0, y + math.sin(angle) * 5.0)], 2.2, MAGENTA)
    return canvas.resize((IMPACT_CELL, IMPACT_CELL), Image.Resampling.LANCZOS)


def relic_lightning_sheet() -> Image.Image:
    sheet = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    for frame in range(CAST_FRAMES):
        sheet.alpha_composite(_cast_cell(frame), (frame * CAST_CELL, 0))
    for frame in range(FLIGHT_FRAMES):
        sheet.alpha_composite(_flight_cell(frame), (frame * FLIGHT_CELL[0], FLIGHT_ROW_Y))
    for frame in range(IMPACT_FRAMES):
        sheet.alpha_composite(_impact_cell(frame), (frame * IMPACT_CELL, IMPACT_ROW_Y))
    return sheet


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    relic_lightning_sheet().save(ROOT / "relic_lightning_fx.png")
    print("wrote deterministic relic lightning FX sheet")


if __name__ == "__main__":
    main()
