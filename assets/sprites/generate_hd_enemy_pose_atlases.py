#!/usr/bin/env python3
"""Build deterministic runtime pose atlases for issue #204.

Each source portrait gets a 6×4 transparent atlas: idle, chase, wind-up,
attack, stagger, and death state rows with four distinct readable frames.
The source portraits remain the canonical art; this generator produces only
presentation frames, never collision or combat geometry.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parent / "enemies" / "hd"
KINDS = ("melee_chaser", "fast_flanker", "ranged_harasser", "shielded_brute")
STATE_ROWS = ("idle", "chase", "windup", "attack", "stagger", "death")
CELL_HEIGHT = 128
CONTENT_HEIGHT = 80
CELL_HORIZONTAL_PADDING = 40


def pose(source: Image.Image, state: str, frame: int) -> Image.Image:
    width, height = source.size
    image = source.copy()
    scale_x, scale_y, dx, dy, angle = 1.0, 1.0, 0, 0, 0.0
    if state == "idle":
        dy = (-2, 0, 2, 0)[frame]
    elif state == "chase":
        dy = (-8, 0, 6, 0)[frame]
        angle = (-3.0, 3.0, -3.0, 3.0)[frame]
    elif state == "windup":
        scale_x, scale_y = (0.86, 1.13)
        dx = (-5, -12, -19, -24)[frame]
    elif state == "attack":
        scale_x = (1.03, 1.11, 1.06, 1.0)[frame]
        scale_y = (1.0, 0.89, 0.94, 1.0)[frame]
        dx = (5, 14, 24, 12)[frame]
        angle = (0.0, 4.0, -2.0, 0.0)[frame]
    elif state == "stagger":
        dx = (-5, -15, -8, 0)[frame]
        angle = (-7.0, -14.0, -6.0, 0.0)[frame]
    elif state == "death":
        angle = (15.0, 40.0, 70.0, 90.0)[frame]
        scale_y = (1.0, 0.95, 0.84, 0.76)[frame]
    resized = image.resize((round(width * scale_x), round(height * scale_y)), Image.Resampling.LANCZOS)
    resized = resized.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", source.size)
    canvas.alpha_composite(resized, ((width - resized.width) // 2 + dx, (height - resized.height) // 2 + dy))
    if state in ("windup", "attack", "stagger"):
        color = (1.08 if state == "windup" else 1.16) if frame >= 2 else 1.0
        canvas = ImageEnhance.Color(canvas).enhance(color)
    return canvas


def build(kind: str) -> None:
    source = Image.open(ROOT / f"{kind}.png").convert("RGBA")
    content_width: int = round(source.width * CONTENT_HEIGHT / source.height)
    source = source.resize((content_width, CONTENT_HEIGHT), Image.Resampling.LANCZOS)
    width: int = content_width + CELL_HORIZONTAL_PADDING * 2
    height: int = CELL_HEIGHT
    padded_source = Image.new("RGBA", (width, height))
    padded_source.alpha_composite(
        source,
        ((width - content_width) // 2, (height - CONTENT_HEIGHT) // 2),
    )
    atlas = Image.new("RGBA", (width * 4, height * len(STATE_ROWS)))
    for row, state in enumerate(STATE_ROWS):
        for frame in range(4):
            atlas.alpha_composite(pose(padded_source, state, frame), (frame * width, row * height))
    atlas.save(ROOT / f"{kind}_poses.png")


if __name__ == "__main__":
    for kind in KINDS:
        build(kind)
    print("wrote deterministic HD enemy pose atlases")
