#!/usr/bin/env python3
"""Build the deterministic HD player-body melee atlas for issue #189.

Layout of `player/hd/player_melee_body_atlas.png` (768x1024, straight alpha):
three 256x256 action-phase columns (wind-up, contact, recovery) by four facing
rows (north, west, south, east). Every cell is an independently rendered,
cardinal-facing wanderer body with a readable torso lean and arm pose. The
separate `PlayerWeaponHdPresentation` retains ownership of the steel blade's
hand-pivoted sweep; these cells deliberately animate the body and wielding arms
that support it, rather than creating a second weapon display or combat effect.

Every pixel is closed-form Pillow geometry with no source imagery or randomness,
so the runtime atlas is reproducible and CC0-safe hand-authored art.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "player" / "hd"
CELL_SIZE = 256
PHASES = ("windup", "contact", "recovery")
FACINGS = ("north", "west", "south", "east")
SCALE = 4

# Grounded HD wanderer palette: teal cloth, leather, cool steel and a very
# restrained warm key light. Cyan/magenta remain reserved for relic systems.
OUTLINE = (17, 29, 39, 235)
CLOAK_DARK = (20, 71, 82, 255)
CLOAK_MID = (35, 119, 128, 255)
CLOAK_LIGHT = (86, 166, 167, 255)
LEATHER = (92, 55, 34, 255)
SKIN = (214, 158, 119, 255)
HAIR = (61, 43, 38, 255)
STEEL_HIGHLIGHT = (230, 238, 240, 255)


def _point(facing: tuple[float, float], local: tuple[float, float]) -> tuple[float, float]:
    """Rotate local (right, forward) coordinates into a cardinal-facing cell."""
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


def _pose(phase: str) -> tuple[float, float, float, float]:
    """Return torso-forward lean, arm forward, arm spread, and hand extension."""
    if phase == "windup":
        return (-8.0, -18.0, 22.0, 10.0)
    if phase == "contact":
        return (8.0, 27.0, 8.0, 26.0)
    return (4.0, 16.0, -13.0, 18.0)


def _draw_cell(facing_name: str, phase: str) -> Image.Image:
    facing_map = {
        "north": (0.0, -1.0), "west": (-1.0, 0.0),
        "south": (0.0, 1.0), "east": (1.0, 0.0),
    }
    facing = facing_map[facing_name]
    canvas = Image.new("RGBA", (CELL_SIZE * SCALE, CELL_SIZE * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    torso_lean, arm_forward, arm_spread, hand_extension = _pose(phase)

    # A compact contact shadow keeps all three poses grounded at the same pivot.
    shadow_center = _point(facing, (0.0, 31.0))
    _ellipse(draw, shadow_center, (40.0, 12.0), (8, 15, 20, 58))

    # Cloak outline then its deliberately asymmetric hem and lit panel.
    torso = [
        _point(facing, (-31.0, torso_lean - 12.0)),
        _point(facing, (-39.0, torso_lean + 28.0)),
        _point(facing, (-18.0, torso_lean + 51.0)),
        _point(facing, (13.0, torso_lean + 55.0)),
        _point(facing, (38.0, torso_lean + 25.0)),
        _point(facing, (29.0, torso_lean - 14.0)),
    ]
    draw.polygon(_scaled(torso), fill=OUTLINE)
    inner_torso = [
        _point(facing, (-25.0, torso_lean - 7.0)),
        _point(facing, (-31.0, torso_lean + 24.0)),
        _point(facing, (-13.0, torso_lean + 45.0)),
        _point(facing, (10.0, torso_lean + 48.0)),
        _point(facing, (30.0, torso_lean + 22.0)),
        _point(facing, (23.0, torso_lean - 8.0)),
    ]
    draw.polygon(_scaled(inner_torso), fill=CLOAK_MID)
    panel = [
        _point(facing, (-7.0, torso_lean - 5.0)),
        _point(facing, (13.0, torso_lean - 2.0)),
        _point(facing, (19.0, torso_lean + 30.0)),
        _point(facing, (1.0, torso_lean + 42.0)),
    ]
    draw.polygon(_scaled(panel), fill=CLOAK_LIGHT)
    _line(draw, [_point(facing, (-24.0, torso_lean + 28.0)), _point(facing, (24.0, torso_lean + 28.0))], 4.0, LEATHER)

    # Head stays connected to the torso while the body shifts into the strike.
    head_center = _point(facing, (0.0, torso_lean - 34.0))
    _ellipse(draw, head_center, (21.0, 20.0), OUTLINE)
    _ellipse(draw, head_center, (17.0, 16.0), SKIN)
    hair_center = _point(facing, (-2.0, torso_lean - 43.0))
    _ellipse(draw, hair_center, (18.0, 9.0), HAIR)

    # Both arms visibly change angle per phase. Contact has an extended forward
    # silhouette (and therefore more opaque pixels) rather than a relabeled cell.
    shoulder_left = _point(facing, (-24.0, torso_lean - 1.0))
    shoulder_right = _point(facing, (24.0, torso_lean - 1.0))
    elbow_left = _point(facing, (-arm_spread, arm_forward * 0.50 + torso_lean))
    elbow_right = _point(facing, (arm_spread, arm_forward * 0.50 + torso_lean))
    hand_left = _point(facing, (-arm_spread * 0.45, arm_forward + hand_extension + torso_lean))
    hand_right = _point(facing, (arm_spread * 0.45, arm_forward + hand_extension + torso_lean))
    for shoulder, elbow, hand in ((shoulder_left, elbow_left, hand_left), (shoulder_right, elbow_right, hand_right)):
        _line(draw, [shoulder, elbow, hand], 17.0, OUTLINE)
        _line(draw, [shoulder, elbow, hand], 11.0, CLOAK_DARK)
        _ellipse(draw, hand, (7.0, 7.0), SKIN)

    # A small steel crossguard/hilt is embedded at the hands. The authoritative
    # full blade remains the existing hand-pivoted weapon presentation.
    grip_center = _point(facing, (0.0, arm_forward + hand_extension + torso_lean + 3.0))
    guard_a = _point(facing, (-18.0, arm_forward + hand_extension + torso_lean + 3.0))
    guard_b = _point(facing, (18.0, arm_forward + hand_extension + torso_lean + 3.0))
    _line(draw, [guard_a, guard_b], 7.0, OUTLINE)
    _line(draw, [guard_a, guard_b], 3.5, STEEL_HIGHLIGHT)
    _line(draw, [_point(facing, (0.0, arm_forward + hand_extension + torso_lean - 7.0)), grip_center], 6.0, LEATHER)

    # Contact includes a short warm edge glint at the arms, while the retained
    # weapon atlas and CombatFxSpawner supply the blade/impact readability.
    if phase == "contact":
        # A compact but solid hand/guard glint makes the fully extended contact
        # silhouette materially larger than wind-up at gameplay scale.
        _ellipse(draw, _point(facing, (0.0, arm_forward + hand_extension + torso_lean + 13.0)), (22.0, 12.0), (255, 214, 137, 170))
    elif phase == "recovery":
        _line(draw, [hand_left, _point(facing, (-18.0, arm_forward + torso_lean + 3.0))], 3.0, (169, 195, 202, 100))

    return canvas.resize((CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)


def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (CELL_SIZE * len(PHASES), CELL_SIZE * len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for column, phase in enumerate(PHASES):
            sheet.alpha_composite(_draw_cell(facing, phase), (column * CELL_SIZE, row * CELL_SIZE))
    return sheet


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    build_sheet().save(ROOT / "player_melee_body_atlas.png")
    print("wrote deterministic HD player melee body atlas")


if __name__ == "__main__":
    main()
