#!/usr/bin/env python3
"""Build issue #195's deterministic directional HD player dash-body atlas.

The 1024x1024 straight-alpha sheet has launch, compression, streak, and
recovery columns with north/west/south/east rows. The top-down actor remains
upright in screen space; facing drives body displacement, planted stride, cloak
drag, and restrained speed ticks. Movement and combat FX remain runtime-owned.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
CELL = 256
SCALE = 4
PHASES = ("launch", "compression", "streak", "recovery")
FACINGS = ("north", "west", "south", "east")
DIRECTIONS = {
    "north": (0.0, -1.0), "west": (-1.0, 0.0),
    "south": (0.0, 1.0), "east": (1.0, 0.0),
}
OUTLINE = (17, 29, 39, 235)
DARK = (20, 71, 82, 255)
MID = (35, 119, 128, 255)
LIGHT = (86, 166, 167, 255)
LEATHER = (92, 55, 34, 255)
SKIN = (214, 158, 119, 255)
HAIR = (61, 43, 38, 255)
CYAN = (76, 232, 255, 225)
MAGENTA = (241, 69, 207, 205)


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


def _offset(point: tuple[float, float], right: tuple[float, float], amount: float) -> tuple[float, float]:
    return _add(point, right, amount)


def _pose(phase: str) -> tuple[float, float, float, float]:
    # torso displacement, lead foot, arm pump, trail length
    return {
        "launch": (3.0, 19.0, 14.0, 16.0),
        "compression": (12.0, 42.0, 29.0, 38.0),
        "streak": (16.0, 49.0, -25.0, 46.0),
        "recovery": (7.0, 27.0, -11.0, 18.0),
    }[phase]


def _draw_cell(facing_name: str, phase: str) -> Image.Image:
    facing = DIRECTIONS[facing_name]
    right = (-facing[1], facing[0])
    torso_shift, lead_foot, arm_pump, trail = _pose(phase)
    actor = (128.0, 137.0)
    torso = _add(actor, facing, torso_shift)
    canvas = Image.new("RGBA", (CELL*SCALE, CELL*SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    _ellipse(draw, (128.0, 171.0), (41.0, 11.0), (8, 15, 20, 54))

    # Restrained directional ticks sit behind the actor and never form a second
    # dash trail; CombatFxSpawner remains the full movement-FX owner.
    if phase in ("compression", "streak"):
        rear = _add(actor, facing, -trail)
        for lateral, color in ((-25.0, MAGENTA), (22.0, CYAN)):
            start = _offset(rear, right, lateral)
            end = _offset(_add(actor, facing, -10.0), right, lateral * 0.72)
            _line(draw, [start, end], 3.0, color)

    # A diagonal sprint stance communicates travel while the torso remains an
    # upright top-down silhouette instead of rotating sideways.
    rear_foot = _offset(_add(actor, facing, -20.0), right, -24.0)
    front_foot = _offset(_add(actor, facing, lead_foot), right, 24.0)
    if phase == "streak":
        rear_foot, front_foot = front_foot, rear_foot
    hips = ((113.0, 158.0), (143.0, 158.0))
    for hip, foot in zip(hips, (rear_foot, front_foot)):
        knee = ((hip[0]+foot[0])*0.5, (hip[1]+foot[1])*0.5)
        _line(draw, [hip, knee, foot], 20.0, OUTLINE)
        _line(draw, [hip, knee, foot], 11.0, DARK)
        _ellipse(draw, foot, (11.0, 7.0), OUTLINE)
        _ellipse(draw, foot, (7.0, 4.0), LEATHER)

    cx, cy = torso
    cloak = [(cx-29, cy-38), (cx-38, cy+5), (cx-24, cy+44),
             (cx-7, cy+55), (cx+17, cy+51), (cx+38, cy+9), (cx+29, cy-38)]
    draw.polygon(_scaled(cloak), fill=OUTLINE)
    inner = [(cx-24, cy-32), (cx-31, cy+6), (cx-18, cy+37),
             (cx-3, cy+47), (cx+13, cy+43), (cx+31, cy+7), (cx+23, cy-32)]
    draw.polygon(_scaled(inner), fill=MID)
    draw.polygon(_scaled([(cx-4, cy-28), (cx+16, cy-23), (cx+20, cy+27), (cx+1, cy+40)]), fill=LIGHT)
    _line(draw, [(cx-27, cy+10), (cx+27, cy+10)], 4.0, LEATHER)

    # Cloak drag bends opposite travel, making direction visible without
    # rotating the whole body or adding a broad combat-style streak.
    tail_root = (cx-6.0, cy+39.0)
    tail_tip = _offset(_add(tail_root, facing, -trail*0.52), right, -10.0)
    _line(draw, [tail_root, tail_tip], 13.0, OUTLINE)
    _line(draw, [tail_root, tail_tip], 7.0, DARK)

    head = (cx, cy-54)
    _ellipse(draw, head, (21.0, 20.0), OUTLINE)
    _ellipse(draw, head, (17.0, 16.0), SKIN)
    _ellipse(draw, (head[0]-2.0, head[1]-9.0), (18.0, 9.0), HAIR)

    shoulders = ((cx-25.0, cy-20.0), (cx+25.0, cy-20.0))
    hand_a = _offset(_add((cx, cy-7.0), facing, arm_pump), right, -18.0)
    hand_b = _offset(_add((cx, cy-7.0), facing, -arm_pump*0.72), right, 18.0)
    for shoulder, hand in zip(shoulders, (hand_a, hand_b)):
        elbow = ((shoulder[0]+hand[0])*0.5, (shoulder[1]+hand[1])*0.5)
        _line(draw, [shoulder, elbow, hand], 17.0, OUTLINE)
        _line(draw, [shoulder, elbow, hand], 10.0, DARK)
        _ellipse(draw, hand, (6.5, 6.5), SKIN)

    return canvas.resize((CELL, CELL), Image.Resampling.LANCZOS)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (CELL*len(PHASES), CELL*len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for column, phase in enumerate(PHASES):
            sheet.alpha_composite(_draw_cell(facing, phase), (column*CELL, row*CELL))
    sheet.save(ROOT / "player_dash_body_atlas.png", format="PNG", optimize=False, compress_level=9)
    print("wrote deterministic HD player dash body atlas")


if __name__ == "__main__":
    main()
