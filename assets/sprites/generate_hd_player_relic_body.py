#!/usr/bin/env python3
"""Build the deterministic HD player-body relic-cast atlas for issue #193.

`player/hd/player_relic_body_atlas.png` is a 768x1024 straight-alpha sheet:
three 256x256 phases (charge, release, recovery) by north/west/south/east rows.
Each cell moves the torso and casting arm while the existing `PlayerWeaponHdPresentation`
continues to own the hand-anchored steel sword and `CombatFxSpawner` owns the cast,
lightning bolt, and impact. No gameplay state, projectile, or timing is authored here.

All art is deterministic closed-form Pillow geometry with no source image or randomness,
so the runtime asset is reproducible and CC0-safe project art.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
CELL_SIZE = 256
SCALE = 4
PHASES = ("charge", "release", "recovery")
FACINGS = ("north", "west", "south", "east")

OUTLINE = (17, 29, 39, 235)
CLOAK_DARK = (20, 71, 82, 255)
CLOAK_MID = (35, 119, 128, 255)
CLOAK_LIGHT = (86, 166, 167, 255)
LEATHER = (92, 55, 34, 255)
SKIN = (214, 158, 119, 255)
HAIR = (61, 43, 38, 255)
CYAN = (76, 232, 255, 255)
MAGENTA = (241, 69, 207, 255)
WHITE = (246, 255, 255, 255)


def _point(facing: tuple[float, float], local: tuple[float, float]) -> tuple[float, float]:
    forward_x, forward_y = facing
    right_x, right_y = -forward_y, forward_x
    return (
        CELL_SIZE * 0.5 + right_x * local[0] + forward_x * local[1],
        CELL_SIZE * 0.56 + right_y * local[0] + forward_y * local[1],
    )


def _scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(round(x * SCALE), round(y * SCALE)) for x, y in points]


def _ellipse(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: tuple[float, float], fill: tuple[int, ...]) -> None:
    draw.ellipse(
        (
            round((center[0] - radius[0]) * SCALE),
            round((center[1] - radius[1]) * SCALE),
            round((center[0] + radius[0]) * SCALE),
            round((center[1] + radius[1]) * SCALE),
        ),
        fill=fill,
    )


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], width: float, fill: tuple[int, ...]) -> None:
    draw.line(_scaled(points), fill=fill, width=round(width * SCALE), joint="curve")


def _pose(phase: str) -> tuple[float, float, float, float, float]:
    """Return torso lean, cast-hand forward, cast-hand spread, off-hand, glow radius."""
    if phase == "charge":
        return (-5.0, -13.0, 26.0, 14.0, 3.5)
    if phase == "release":
        return (7.0, 36.0, 7.0, 6.0, 5.0)
    return (3.0, 17.0, -14.0, 11.0, 2.5)


def _draw_cell(facing_name: str, phase: str) -> Image.Image:
    facing_map = {
        "north": (0.0, -1.0), "west": (-1.0, 0.0),
        "south": (0.0, 1.0), "east": (1.0, 0.0),
    }
    facing = facing_map[facing_name]
    canvas = Image.new("RGBA", (CELL_SIZE * SCALE, CELL_SIZE * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    torso_lean, cast_forward, cast_spread, offhand_forward, glow_radius = _pose(phase)

    # Stable shadow and cloak preserve the accepted HD wanderer silhouette.
    _ellipse(draw, _point(facing, (0.0, 33.0)), (39.0, 11.0), (8, 15, 20, 58))
    torso = [
        _point(facing, (-31.0, torso_lean - 12.0)), _point(facing, (-39.0, torso_lean + 28.0)),
        _point(facing, (-18.0, torso_lean + 51.0)), _point(facing, (13.0, torso_lean + 55.0)),
        _point(facing, (38.0, torso_lean + 25.0)), _point(facing, (29.0, torso_lean - 14.0)),
    ]
    draw.polygon(_scaled(torso), fill=OUTLINE)
    inner = [
        _point(facing, (-25.0, torso_lean - 7.0)), _point(facing, (-31.0, torso_lean + 24.0)),
        _point(facing, (-13.0, torso_lean + 45.0)), _point(facing, (10.0, torso_lean + 48.0)),
        _point(facing, (30.0, torso_lean + 22.0)), _point(facing, (23.0, torso_lean - 8.0)),
    ]
    draw.polygon(_scaled(inner), fill=CLOAK_MID)
    draw.polygon(_scaled([
        _point(facing, (-7.0, torso_lean - 5.0)), _point(facing, (13.0, torso_lean - 2.0)),
        _point(facing, (19.0, torso_lean + 30.0)), _point(facing, (1.0, torso_lean + 42.0)),
    ]), fill=CLOAK_LIGHT)
    _line(draw, [_point(facing, (-24.0, torso_lean + 28.0)), _point(facing, (24.0, torso_lean + 28.0))], 4.0, LEATHER)

    head = _point(facing, (0.0, torso_lean - 34.0))
    _ellipse(draw, head, (21.0, 20.0), OUTLINE)
    _ellipse(draw, head, (17.0, 16.0), SKIN)
    _ellipse(draw, _point(facing, (-2.0, torso_lean - 43.0)), (18.0, 9.0), HAIR)

    # The off-hand remains near the existing held sword. The cast hand is the
    # moving readability cue: pulled back to charge, thrust forward to release.
    cast_shoulder = _point(facing, (-24.0, torso_lean - 1.0))
    off_shoulder = _point(facing, (24.0, torso_lean - 1.0))
    cast_elbow = _point(facing, (-cast_spread, cast_forward * 0.52 + torso_lean))
    cast_hand = _point(facing, (-cast_spread * 0.24, cast_forward + torso_lean))
    off_elbow = _point(facing, (17.0, offhand_forward * 0.48 + torso_lean))
    off_hand = _point(facing, (8.0, offhand_forward + torso_lean + 9.0))
    for shoulder, elbow, hand in ((cast_shoulder, cast_elbow, cast_hand), (off_shoulder, off_elbow, off_hand)):
        _line(draw, [shoulder, elbow, hand], 17.0, OUTLINE)
        _line(draw, [shoulder, elbow, hand], 11.0, CLOAK_DARK)
        _ellipse(draw, hand, (7.0, 7.0), SKIN)

    # A small hand-centered relic charge supports the body's release pose but is
    # not a second projectile, cast flare, or impact effect.
    if phase != "recovery":
        _ellipse(draw, cast_hand, (glow_radius + 4.0, glow_radius + 4.0), (18, 143, 219, 40))
        _ellipse(draw, cast_hand, (glow_radius, glow_radius), CYAN)
        _ellipse(draw, cast_hand, (max(1.4, glow_radius * 0.42), max(1.4, glow_radius * 0.42)), WHITE)
        # Thin charged forks at the casting hand support the release silhouette
        # without forming a second orb or projectile body.
        for angle in (-0.52, 0.42):
            tip = _point(facing, (math.sin(angle) * (glow_radius + 7.0), cast_forward + torso_lean + math.cos(angle) * (glow_radius + 7.0)))
            _line(draw, [cast_hand, tip], 2.2, MAGENTA)
    else:
        _line(draw, [cast_hand, _point(facing, (-19.0, cast_forward + torso_lean - 8.0))], 3.0, (128, 210, 235, 115))

    return canvas.resize((CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)


def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (CELL_SIZE * len(PHASES), CELL_SIZE * len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for column, phase in enumerate(PHASES):
            sheet.alpha_composite(_draw_cell(facing, phase), (column * CELL_SIZE, row * CELL_SIZE))
    return sheet


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    build_sheet().save(ROOT / "player_relic_body_atlas.png")
    print("wrote deterministic HD player relic body atlas")


if __name__ == "__main__":
    main()
