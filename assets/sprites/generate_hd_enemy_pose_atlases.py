#!/usr/bin/env python3
"""Build deterministic runtime pose atlases for issue #204.

Each source portrait gets a 5×4 transparent atlas: idle, chase, wind-up,
attack, stagger, and death state rows with four distinct readable frames.
The source portraits remain the canonical art; this generator produces only
presentation frames, never collision or combat geometry.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent / "enemies" / "hd"
KINDS = ("melee_chaser", "fast_flanker", "ranged_harasser", "shielded_brute")
STATE_ROWS = ("idle", "chase", "windup", "attack", "stagger", "death")


def pose(source: Image.Image, state: str, frame: int) -> Image.Image:
    width, height = source.size
    image = source.copy()
    scale_x, scale_y, dx, dy, angle = 1.0, 1.0, 0, 0, 0.0
    if state == "idle":
        dy = (-1, 0, 1, 0)[frame]
    elif state == "chase":
        dy = (-3, 0, 2, 0)[frame]
        angle = (-1.5, 1.5, -1.5, 1.5)[frame]
    elif state == "windup":
        scale_x, scale_y = (0.94, 1.06)
        dx = (-2, -4, -6, -7)[frame]
    elif state == "attack":
        scale_x = (1.02, 1.06, 1.03, 1.0)[frame]
        scale_y = (1.0, 0.94, 0.96, 1.0)[frame]
        dx = (2, 6, 10, 5)[frame]
        angle = (0.0, 2.0, -1.0, 0.0)[frame]
    elif state == "stagger":
        dx = (-2, -6, -3, 0)[frame]
        angle = (-4.0, -8.0, -3.0, 0.0)[frame]
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
    width, height = source.size
    atlas = Image.new("RGBA", (width * 4, height * len(STATE_ROWS)))
    for row, state in enumerate(STATE_ROWS):
        for frame in range(4):
            atlas.alpha_composite(pose(source, state, frame), (frame * width, row * height))
    atlas.save(ROOT / f"{kind}_poses.png")


if __name__ == "__main__":
    for kind in KINDS:
        build(kind)
    print("wrote deterministic HD enemy pose atlases")
