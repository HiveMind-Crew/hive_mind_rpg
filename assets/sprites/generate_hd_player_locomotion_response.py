#!/usr/bin/env python3
"""Build the source-derived HD player locomotion/response atlas for issue #224.

Every runtime frame is deliberately derived from the accepted illustrated
``player_directional_atlas.png`` rather than redrawing a second character. This
keeps the hooded teal wanderer's silhouette, costume, palette, and material
language continuous from idle into movement. The logical PlayerVisual remains
the state owner; this sheet changes display art only.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
SOURCE = ROOT / "player_directional_atlas.png"
OUTPUT = ROOT / "player_locomotion_response_atlas.png"
CELL = 256
FACINGS = ("north", "west", "south", "east")
SOURCE_COLUMNS = {"north": 0, "west": 1, "south": 2, "east": 3}
DIRECTIONS = {"north": (0, -1), "west": (-1, 0), "south": (0, 1), "east": (1, 0)}
PHASES = ("walk_a", "passing", "walk_b", "settle", "hurt")
# Per phase: local forward translation, bob, body lean degrees, and an optional
# restrained facing-side cloth echo. Values stay modest so animation communicates
# gait/weight without turning the upright top-down body into a rotating capsule.
PHASE_MOTION = {
    # Values are source-pixel offsets. At the 42px shipped display contract the
    # split lower-cloak motion below resolves to a visible 2–4px planted gait,
    # instead of the sub-pixel translate/rotate that #224 replaced.
    "walk_a": (-3, -4, -2.0, 0),
    "passing": (0, 3, 0.0, 0),
    "walk_b": (3, -4, 2.0, 0),
    "settle": (0, 2, -0.8, 0),
    "hurt": (-12, 7, -4.0, 0),
}
LOWER_CLOAK_START_Y = 156
GAIT_LOWER_STEP_PX = 14
CLOTH_ECHO = (65, 159, 163, 105)
HURT_ACCENT = (255, 119, 102, 205)


def _source_cell(facing: str) -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    x = SOURCE_COLUMNS[facing] * CELL
    return source.crop((x, 0, x + CELL, CELL))


def _place_transformed(source: Image.Image, dx: int, dy: int, angle: float) -> Image.Image:
    # A transparent rotation of the actual approved source preserves authored
    # rendering detail. Translation is composited separately so no wraparound
    # pixels enter a neighboring atlas cell.
    transformed = source.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        center=(CELL / 2, CELL / 2),
        fillcolor=(0, 0, 0, 0),
    )
    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    frame.alpha_composite(transformed, (dx, dy))
    return frame


def _draw_hurt_slash(frame: Image.Image) -> None:
    draw = ImageDraw.Draw(frame)
    draw.line([(100, 118), (153, 145)], fill=HURT_ACCENT, width=3)


def _draw_cell(facing: str, phase: str) -> Image.Image:
    forward, bob, angle, _ = PHASE_MOTION[phase]
    direction = DIRECTIONS[facing]
    right = (-direction[1], direction[0])
    source = _source_cell(facing)
    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    if phase in ("walk_a", "walk_b"):
        # Preserve the illustrated hood/torso exactly while moving only the
        # planted cloak/boots. At game scale this reads as a visible step and
        # weight transfer, not an unrelated second character or a full-sheet
        # sub-pixel slide.
        upper = source.copy()
        lower = source.copy()
        # Feather the cloak split so the visible gait changes the planted lower
        # silhouette without ever exposing a hard horizontal crop seam.
        upper_mask = Image.new("L", (CELL, CELL), 0)
        lower_mask = Image.new("L", (CELL, CELL), 0)
        upper_draw = ImageDraw.Draw(upper_mask)
        lower_draw = ImageDraw.Draw(lower_mask)
        for y in range(CELL):
            blend = max(0.0, min(1.0, (y - LOWER_CLOAK_START_Y + 18) / 36.0))
            upper_alpha = round((1.0 - blend) * 255.0)
            lower_alpha = 255 - upper_alpha
            upper_draw.line([(0, y), (CELL, y)], fill=upper_alpha)
            lower_draw.line([(0, y), (CELL, y)], fill=lower_alpha)
        upper.putalpha(ImageChops.multiply(upper.getchannel("A"), upper_mask))
        lower.putalpha(ImageChops.multiply(lower.getchannel("A"), lower_mask))
        step_sign = -1 if phase == "walk_a" else 1
        lower_shift_x = right[0] * GAIT_LOWER_STEP_PX * step_sign + direction[0] * forward
        lower_shift_y = right[1] * GAIT_LOWER_STEP_PX * step_sign + direction[1] * forward + bob
        frame.alpha_composite(lower, (lower_shift_x, lower_shift_y))
        frame.alpha_composite(_place_transformed(upper, 0, bob, angle))
    else:
        frame.alpha_composite(_place_transformed(source, direction[0] * forward, direction[1] * forward + bob, angle))
    if phase == "hurt":
        _draw_hurt_slash(frame)
    return frame


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    if not SOURCE.is_file():
        raise FileNotFoundError(f"missing canonical player source: {SOURCE}")
    sheet = Image.new("RGBA", (CELL * len(PHASES), CELL * len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for column, phase in enumerate(PHASES):
            sheet.alpha_composite(_draw_cell(facing, phase), (column * CELL, row * CELL))
    sheet.save(OUTPUT, format="PNG", optimize=False, compress_level=9)
    print(f"wrote source-derived HD player locomotion atlas: {OUTPUT}")


if __name__ == "__main__":
    main()
