#!/usr/bin/env python3
"""Build issue #203's deterministic HD player locomotion/response atlas.

The 1280x1024 straight-alpha sheet has walk-A, passing, walk-B, settle, and
hurt-recoil columns across north/west/south/east rows. It is display-only:
PlayerVisual still owns logical move/hurt/death state and collision never moves.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
CELL = 256
SCALE = 4
PHASES = ("walk_a", "passing", "walk_b", "settle", "hurt")
FACINGS = ("north", "west", "south", "east")
DIRECTIONS = {"north": (0.0, -1.0), "west": (-1.0, 0.0), "south": (0.0, 1.0), "east": (1.0, 0.0)}
OUTLINE = (17, 29, 39, 235)
DARK = (20, 71, 82, 255)
MID = (35, 119, 128, 255)
LIGHT = (86, 166, 167, 255)
LEATHER = (92, 55, 34, 255)
SKIN = (214, 158, 119, 255)
HAIR = (61, 43, 38, 255)
HURT_ACCENT = (255, 119, 102, 220)


def _scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(round(x * SCALE), round(y * SCALE)) for x, y in points]


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], width: float, fill: tuple[int, ...]) -> None:
    draw.line(_scaled(points), fill=fill, width=round(width * SCALE), joint="curve")


def _ellipse(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: tuple[float, float], fill: tuple[int, ...]) -> None:
    x, y = center
    rx, ry = radius
    draw.ellipse((round((x-rx)*SCALE), round((y-ry)*SCALE), round((x+rx)*SCALE), round((y+ry)*SCALE)), fill=fill)


def _add(point: tuple[float, float], vector: tuple[float, float], amount: float) -> tuple[float, float]:
    return point[0] + vector[0] * amount, point[1] + vector[1] * amount


def _offset(point: tuple[float, float], right: tuple[float, float], amount: float) -> tuple[float, float]:
    return _add(point, right, amount)


def _motion(phase: str) -> tuple[float, float, float, float]:
    # torso shift, lead stride, arm swing, body bob
    return {
        "walk_a": (3.0, 27.0, 24.0, -5.0),
        "passing": (7.0, 8.0, 4.0, 2.0),
        "walk_b": (3.0, -27.0, -24.0, -5.0),
        "settle": (0.0, -8.0, -4.0, 1.0),
        "hurt": (-16.0, 12.0, -14.0, 8.0),
    }[phase]


def _draw_cell(facing_name: str, phase: str) -> Image.Image:
    facing = DIRECTIONS[facing_name]
    right = (-facing[1], facing[0])
    torso_shift, stride, arm_swing, bob = _motion(phase)
    actor = (128.0, 137.0 + bob)
    torso_center = _add(actor, facing, torso_shift)
    canvas = Image.new("RGBA", (CELL * SCALE, CELL * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    _ellipse(draw, (128.0, 174.0), (39.0, 10.0), (8, 15, 20, 55))

    # Feet and legs establish a readable weight transfer without rotating the
    # top-down human sideways. Hurt braces against the incoming facing.
    rear_foot = _offset(_add(actor, facing, -stride), right, -23.0)
    lead_foot = _offset(_add(actor, facing, stride), right, 23.0)
    hips = ((113.0, 160.0 + bob), (143.0, 160.0 + bob))
    for hip, foot in zip(hips, (rear_foot, lead_foot)):
        knee = ((hip[0] + foot[0]) * 0.5, (hip[1] + foot[1]) * 0.5)
        _line(draw, [hip, knee, foot], 20.0, OUTLINE)
        _line(draw, [hip, knee, foot], 11.0, DARK)
        _ellipse(draw, foot, (11.0, 7.0), OUTLINE)
        _ellipse(draw, foot, (7.0, 4.0), LEATHER)

    cx, cy = torso_center
    cloak = [(cx-29, cy-38), (cx-38, cy+5), (cx-24, cy+44), (cx-7, cy+55), (cx+17, cy+51), (cx+38, cy+9), (cx+29, cy-38)]
    draw.polygon(_scaled(cloak), fill=OUTLINE)
    inner = [(cx-24, cy-32), (cx-31, cy+6), (cx-18, cy+37), (cx-3, cy+47), (cx+13, cy+43), (cx+31, cy+7), (cx+23, cy-32)]
    draw.polygon(_scaled(inner), fill=MID)
    draw.polygon(_scaled([(cx-4, cy-28), (cx+16, cy-23), (cx+20, cy+27), (cx+1, cy+40)]), fill=LIGHT)
    _line(draw, [(cx-27, cy+10), (cx+27, cy+10)], 4.0, LEATHER)
    head = (cx, cy-54)
    _ellipse(draw, head, (21.0, 20.0), OUTLINE)
    _ellipse(draw, head, (17.0, 16.0), SKIN)
    _ellipse(draw, (head[0]-2.0, head[1]-9.0), (18.0, 9.0), HAIR)

    shoulders = ((cx-25.0, cy-20.0), (cx+25.0, cy-20.0))
    hands = (
        _offset(_add((cx, cy-7.0), facing, arm_swing), right, -19.0),
        _offset(_add((cx, cy-7.0), facing, -arm_swing * 0.75), right, 19.0),
    )
    for shoulder, hand in zip(shoulders, hands):
        elbow = ((shoulder[0] + hand[0]) * 0.5, (shoulder[1] + hand[1]) * 0.5)
        _line(draw, [shoulder, elbow, hand], 17.0, OUTLINE)
        _line(draw, [shoulder, elbow, hand], 10.0, DARK)
        _ellipse(draw, hand, (6.5, 6.5), SKIN)
    if phase == "hurt":
        # A short red diagonal crack is a response cue, not a combat hit FX.
        _line(draw, [(cx-31.0, cy-12.0), (cx+25.0, cy+20.0)], 3.0, HURT_ACCENT)
    return canvas.resize((CELL, CELL), Image.Resampling.LANCZOS)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (CELL * len(PHASES), CELL * len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for column, phase in enumerate(PHASES):
            sheet.alpha_composite(_draw_cell(facing, phase), (column * CELL, row * CELL))
    sheet.save(ROOT / "player_locomotion_response_atlas.png", format="PNG", optimize=False, compress_level=9)
    print("wrote deterministic HD player locomotion/response atlas")


if __name__ == "__main__":
    main()
