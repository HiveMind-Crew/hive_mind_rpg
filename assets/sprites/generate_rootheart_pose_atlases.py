#!/usr/bin/env python3
"""Build deterministic Rootheart state-pose atlases for issue #205.

The two accepted Rootheart phase portraits remain canonical source art. This
presentation-only generator centers a reduced portrait inside transparent cells
and derives dormant, awakening, slam, burst, hit, and defeat poses without
changing boss mechanics, collision, or timing.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parent / "enemies" / "hd" / "boss"
PHASES = ("rootheart_phase_one", "rootheart_phase_two")
STATE_ROWS = (
    "dormant",
    "awakening",
    "windup",
    "contact",
    "recovery",
    "burst",
    "hit",
    "defeat",
)
ATLAS_COLUMNS = 3
CELL_SIZE = 256
CONTENT_SIZE = 176


def pose(source: Image.Image, state: str, frame: int) -> Image.Image:
    """Return one padded pose cell with transparent transform margins."""
    scale_x: float = 1.0
    scale_y: float = 1.0
    dx: int = 0
    dy: int = 0
    angle: float = 0.0
    saturation: float = 1.0
    if state == "dormant":
        dy = (2, 0, 2)[frame]
        saturation = (0.78, 0.84, 0.78)[frame]
    elif state == "awakening":
        scale_x, scale_y = ((0.92, 1.04), (0.98, 1.08), (1.0, 1.0))[frame]
        dy = (5, -3, 0)[frame]
        saturation = (1.1, 1.3, 1.2)[frame]
    elif state == "windup":
        # Rootheart coils visibly tall and narrow before the existing live slam.
        scale_x, scale_y = ((0.78, 1.18), (0.70, 1.26), (0.66, 1.30))[frame]
        dy = (-4, -9, -12)[frame]
        saturation = (1.04, 1.14, 1.24)[frame]
    elif state == "contact":
        # The committed frame is a broad, grounded root-slam silhouette.
        scale_x, scale_y = ((1.20, 0.84), (1.30, 0.74), (1.16, 0.88))[frame]
        dy = (9, 15, 10)[frame]
        saturation = (1.20, 1.32, 1.14)[frame]
    elif state == "recovery":
        # Follow-through leans away from contact instead of replaying wind-up.
        scale_x, scale_y = ((1.14, 0.86), (1.07, 0.94), (1.0, 1.0))[frame]
        dx = (12, 5, 0)[frame]
        dy = (11, 5, 0)[frame]
        angle = (10.0, 4.0, 0.0)[frame]
    elif state == "burst":
        scale_x, scale_y = ((1.02, 1.02), (1.20, 1.20), (1.08, 1.08))[frame]
        saturation = (1.32, 1.62, 1.28)[frame]
    elif state == "hit":
        scale_x, scale_y = ((0.94, 1.02), (0.86, 1.10), (0.96, 1.01))[frame]
        dx = (-10, -19, -7)[frame]
        dy = (3, 8, 2)[frame]
        angle = (-7.0, -12.0, -4.0)[frame]
        saturation = (1.30, 1.46, 1.12)[frame]
    elif state == "defeat":
        angle = (0.0, 28.0, 58.0)[frame]
        scale_y = (1.0, 0.84, 0.66)[frame]
        dx = (0, 8, 14)[frame]
        dy = (0, 12, 25)[frame]
        saturation = (0.92, 0.64, 0.38)[frame]
    resized = source.resize(
        (round(source.width * scale_x), round(source.height * scale_y)),
        Image.Resampling.LANCZOS,
    ).rotate(angle, Image.Resampling.BICUBIC, expand=True)
    cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE))
    cell.alpha_composite(
        resized,
        ((CELL_SIZE - resized.width) // 2 + dx, (CELL_SIZE - resized.height) // 2 + dy),
    )
    return ImageEnhance.Color(cell).enhance(saturation)


def build(phase: str) -> None:
    source = Image.open(ROOT / f"{phase}.png").convert("RGBA")
    source.thumbnail((CONTENT_SIZE, CONTENT_SIZE), Image.Resampling.LANCZOS)
    centered = Image.new("RGBA", (CELL_SIZE, CELL_SIZE))
    centered.alpha_composite(source, ((CELL_SIZE - source.width) // 2, (CELL_SIZE - source.height) // 2))
    atlas = Image.new("RGBA", (CELL_SIZE * ATLAS_COLUMNS, CELL_SIZE * len(STATE_ROWS)))
    for row, state in enumerate(STATE_ROWS):
        for frame in range(ATLAS_COLUMNS):
            atlas.alpha_composite(pose(centered, state, frame), (frame * CELL_SIZE, row * CELL_SIZE))
    atlas.save(ROOT / f"{phase}_poses.png")


if __name__ == "__main__":
    for phase in PHASES:
        build(phase)
    print("wrote deterministic Rootheart pose atlases")
