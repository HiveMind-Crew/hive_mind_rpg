#!/usr/bin/env python3
"""Build issue #224's source-derived directional HD melee-body atlas.

The three display-only phases reuse the accepted illustrated hooded wanderer,
so combat never swaps the player for a procedural substitute. Small facing-led
body compression, translation, and twist create a readable upright wind-up,
committed reach, and cross-body recovery while the dedicated weapon layer owns
the complete blade.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
SOURCE = ROOT / "player_directional_atlas.png"
OUTPUT = ROOT / "player_melee_body_atlas.png"
CELL = 256
FACINGS = ("north", "west", "south", "east")
SOURCE_COLUMNS = {"north": 0, "west": 1, "south": 2, "east": 3}
DIRECTIONS = {"north": (0, -1), "west": (-1, 0), "south": (0, 1), "east": (1, 0)}
RIGHTS = {"north": (1, 0), "west": (0, -1), "south": (-1, 0), "east": (0, 1)}
PHASES = ("windup", "contact", "recovery")
# forward, lateral, vertical, rotation, x scale, y scale. The values are
# intentionally small: the player stays upright, keeps contact with the ground,
# and visibly commits into the target rather than becoming a sideways capsule.
PHASE_TRANSFORM = {
    "windup": (-6, -4, 2, -5.0, 0.94, 1.03),
    "contact": (24, 0, -2, 5.0, 1.08, 0.94),
    "recovery": (3, 9, 1, 10.0, 1.0, 1.0),
}
OUTLINE = (17, 29, 39, 190)
CLOTH_LIGHT = (97, 188, 190, 125)
WARM_CONTACT = (255, 214, 137, 190)


def _source_cell(facing: str) -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    x = SOURCE_COLUMNS[facing] * CELL
    return source.crop((x, 0, x + CELL, CELL))


def _scaled_body(source: Image.Image, sx: float, sy: float, angle: float) -> Image.Image:
    # Resize and center the canonical body before a restrained twist. The source
    # remains the only character paint; no generic/vector replacement is drawn.
    width, height = round(CELL * sx), round(CELL * sy)
    resized = source.resize((width, height), Image.Resampling.LANCZOS)
    centered = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    centered.alpha_composite(resized, ((CELL - width) // 2, (CELL - height) // 2))
    return centered.rotate(angle, resample=Image.Resampling.BICUBIC, center=(CELL / 2, CELL / 2))


def _draw_phase_cues(frame: Image.Image, facing: str, phase: str, hand: tuple[int, int]) -> None:
    draw = ImageDraw.Draw(frame)
    direction = DIRECTIONS[facing]
    right = RIGHTS[facing]
    # The compact hand/guard cue makes the body read as an active two-hand grip
    # at the exact point where the separate steel weapon attaches.
    guard_a = (hand[0] + right[0] * 11, hand[1] + right[1] * 11)
    guard_b = (hand[0] - right[0] * 11, hand[1] - right[1] * 11)
    draw.line([guard_a, guard_b], fill=OUTLINE, width=5)
    draw.line([guard_a, guard_b], fill=(210, 221, 225, 230), width=2)
    if phase == "windup":
        trail_end = (hand[0] - direction[0] * 18, hand[1] - direction[1] * 18)
        draw.line([hand, trail_end], fill=CLOTH_LIGHT, width=4)
    elif phase == "contact":
        lead = (hand[0] + direction[0] * 24, hand[1] + direction[1] * 24)
        draw.line([hand, lead], fill=WARM_CONTACT, width=4)
    else:
        follow = (hand[0] + right[0] * 19, hand[1] + right[1] * 19)
        draw.line([hand, follow], fill=CLOTH_LIGHT, width=4)


def _hand_anchor(facing: str, phase: str) -> tuple[int, int]:
    # Source-pixel grip landmarks consumed by PlayerHdPresentation metadata.
    # They share the source's 256px cell coordinates and stay near the canonical
    # upper-body hand region while moving by phase with the committed action.
    base = {"north": (151, 110), "west": (104, 126), "south": (108, 129), "east": (150, 126)}[facing]
    forward, lateral, vertical, _, _, _ = PHASE_TRANSFORM[phase]
    direction = DIRECTIONS[facing]
    right = RIGHTS[facing]
    return (
        round(base[0] + direction[0] * forward + right[0] * lateral),
        round(base[1] + direction[1] * forward + right[1] * lateral + vertical),
    )


def _draw_cell(facing: str, phase: str) -> Image.Image:
    forward, lateral, vertical, angle, sx, sy = PHASE_TRANSFORM[phase]
    direction = DIRECTIONS[facing]
    right = RIGHTS[facing]
    body = _scaled_body(_source_cell(facing), sx, sy, angle)
    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    dx = direction[0] * forward + right[0] * lateral
    dy = direction[1] * forward + right[1] * lateral + vertical
    frame.alpha_composite(body, (dx, dy))
    _draw_phase_cues(frame, facing, phase, _hand_anchor(facing, phase))
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
    print(f"wrote source-derived HD player melee atlas: {OUTPUT}")


if __name__ == "__main__":
    main()
