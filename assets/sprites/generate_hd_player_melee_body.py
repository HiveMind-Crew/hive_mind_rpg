#!/usr/bin/env python3
"""Build issue #197's deterministic directional HD melee-body atlas.

The 768x1024 straight-alpha sheet contains planted wind-up, committed contact
lunge, and recovery columns across north/west/south/east rows. The body remains
upright in screen space like the canonical top-down wanderer; facing drives the
stance, torso displacement, and arm reach rather than rotating the actor into a
horizontal capsule. PlayerWeaponHdPresentation remains the sole full blade.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
CELL = 256
SCALE = 4
PHASES = ("windup", "contact", "recovery")
FACINGS = ("north", "west", "south", "east")
DIRECTIONS = {
    "north": (0.0, -1.0), "west": (-1.0, 0.0),
    "south": (0.0, 1.0), "east": (1.0, 0.0),
}
OUTLINE = (17, 29, 39, 235)
CLOAK_DARK = (20, 71, 82, 255)
CLOAK_MID = (35, 119, 128, 255)
CLOAK_LIGHT = (86, 166, 167, 255)
LEATHER = (92, 55, 34, 255)
SKIN = (214, 158, 119, 255)
HAIR = (61, 43, 38, 255)
STEEL = (230, 238, 240, 255)
WARM = (255, 214, 137, 185)


def _scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(round(x * SCALE), round(y * SCALE)) for x, y in points]


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], width: float, fill: tuple[int, ...]) -> None:
    draw.line(_scaled(points), fill=fill, width=round(width * SCALE), joint="curve")


def _ellipse(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: tuple[float, float], fill: tuple[int, ...]) -> None:
    x, y = center
    rx, ry = radius
    draw.ellipse((round((x-rx)*SCALE), round((y-ry)*SCALE), round((x+rx)*SCALE), round((y+ry)*SCALE)), fill=fill)


def _add(point: tuple[float, float], vector: tuple[float, float], amount: float) -> tuple[float, float]:
    return (point[0] + vector[0] * amount, point[1] + vector[1] * amount)


def _offset(point: tuple[float, float], right: tuple[float, float], lateral: float) -> tuple[float, float]:
    return _add(point, right, lateral)


def _pose(phase: str) -> tuple[float, float, float]:
    if phase == "windup":
        return (-7.0, -25.0, 22.0)
    if phase == "contact":
        return (13.0, 67.0, 5.0)
    return (5.0, 35.0, -14.0)


def _draw_cell(facing_name: str, phase: str) -> Image.Image:
    facing = DIRECTIONS[facing_name]
    right = (-facing[1], facing[0])
    torso_shift, hand_reach, hand_spread = _pose(phase)
    actor = (128.0, 137.0)
    torso_center = _add(actor, facing, torso_shift)
    canvas = Image.new("RGBA", (CELL * SCALE, CELL * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    # Ground pivot never moves even though the torso commits forward.
    _ellipse(draw, (128.0, 171.0), (41.0, 12.0), (8, 15, 20, 58))

    # Feet form a diagonal planted stance in screen space. Facing changes which
    # foot leads, but never rotates the whole human body sideways.
    if phase == "windup":
        rear_amount, lead_amount = -15.0, 17.0
    elif phase == "contact":
        rear_amount, lead_amount = -21.0, 45.0
    else:
        rear_amount, lead_amount = -8.0, 28.0
    feet = (
        _offset(_add(actor, facing, rear_amount), right, -24.0),
        _offset(_add(actor, facing, lead_amount), right, 24.0),
    )
    hips = ((113.0, 159.0), (143.0, 159.0))
    for hip, foot in zip(hips, feet):
        knee = ((hip[0] + foot[0]) * 0.5, (hip[1] + foot[1]) * 0.5)
        _line(draw, [hip, knee, foot], 21.0, OUTLINE)
        _line(draw, [hip, knee, foot], 12.0, LEATHER)
        _ellipse(draw, foot, (12.0, 8.0), OUTLINE)
        _ellipse(draw, foot, (8.0, 5.0), LEATHER)

    # Upright screen-space cloak; only its center translates into the strike.
    cx, cy = torso_center
    torso = [(cx-29, cy-38), (cx-38, cy+4), (cx-25, cy+43),
             (cx-7, cy+55), (cx+17, cy+51), (cx+38, cy+9), (cx+29, cy-38)]
    draw.polygon(_scaled(torso), fill=OUTLINE)
    inner = [(cx-24, cy-32), (cx-31, cy+5), (cx-19, cy+37),
             (cx-4, cy+47), (cx+13, cy+43), (cx+31, cy+7), (cx+23, cy-32)]
    draw.polygon(_scaled(inner), fill=CLOAK_MID)
    panel = [(cx-4, cy-28), (cx+16, cy-23), (cx+20, cy+27), (cx+1, cy+40)]
    draw.polygon(_scaled(panel), fill=CLOAK_LIGHT)
    _line(draw, [(cx-27, cy+10), (cx+27, cy+10)], 4.0, LEATHER)

    head = (cx, cy-54)
    _ellipse(draw, head, (21.0, 20.0), OUTLINE)
    _ellipse(draw, head, (17.0, 16.0), SKIN)
    _ellipse(draw, (head[0]-2.0, head[1]-9.0), (18.0, 9.0), HAIR)

    # Both arms converge on a hand anchor displaced along the live facing.
    shoulders = ((cx-25.0, cy-20.0), (cx+25.0, cy-20.0))
    hand_center = _add((cx, cy-9.0), facing, hand_reach)
    # Recovery follows through across the body instead of translating the
    # anticipation silhouette toward the target. This preserves a visibly
    # distinct top-down shape after camera scaling and directional alignment.
    if phase == "recovery":
        hand_center = _offset(hand_center, right, 55.0)
    hands = (_offset(hand_center, right, -hand_spread * 0.5), _offset(hand_center, right, hand_spread * 0.5))
    for shoulder, hand in zip(shoulders, hands):
        elbow = ((shoulder[0] + hand[0]) * 0.52, (shoulder[1] + hand[1]) * 0.52)
        elbow = _offset(elbow, right, -8.0 if shoulder[0] < cx else 8.0)
        _line(draw, [shoulder, elbow, hand], 18.0, OUTLINE)
        _line(draw, [shoulder, elbow, hand], 11.0, CLOAK_DARK)
        _ellipse(draw, hand, (7.0, 7.0), SKIN)

    # Small hilt only; the full steel weapon remains in its dedicated layer.
    guard_a = _offset(hand_center, right, -18.0)
    guard_b = _offset(hand_center, right, 18.0)
    _line(draw, [guard_a, guard_b], 7.0, OUTLINE)
    _line(draw, [guard_a, guard_b], 3.5, STEEL)
    _line(draw, [_add(hand_center, facing, -10.0), _add(hand_center, facing, 4.0)], 6.0, LEATHER)
    if phase == "contact":
        _line(draw, [_offset(_add(hand_center, facing, 8.0), right, -15.0),
                     _offset(_add(hand_center, facing, 18.0), right, -8.0)], 3.5, WARM)
        _line(draw, [_offset(_add(hand_center, facing, 6.0), right, 12.0),
                     _offset(_add(hand_center, facing, 16.0), right, 18.0)], 3.0, WARM)

    return canvas.resize((CELL, CELL), Image.Resampling.LANCZOS)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (CELL * len(PHASES), CELL * len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for column, phase in enumerate(PHASES):
            sheet.alpha_composite(_draw_cell(facing, phase), (column * CELL, row * CELL))
    sheet.save(ROOT / "player_melee_body_atlas.png", format="PNG", optimize=False, compress_level=9)
    print("wrote deterministic HD player melee body atlas")


if __name__ == "__main__":
    main()
