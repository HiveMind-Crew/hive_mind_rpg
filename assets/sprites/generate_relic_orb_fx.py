#!/usr/bin/env python3
"""Build the deterministic stylized-HD relic orb FX sheet for issue #169.

Layout of assets/sprites/fx/relic_orb_fx.png (768x288, straight alpha):
  row y=0   : cast flare,   6 frames of  96x96, authored radially with a
              forward (+x) bias so the runtime can rotate it to the aim angle
  row y=96  : flight orb,   4 frames of 128x64, orb core at the exact cell
              center (collision-truthful) with the trail streaming toward -x
  row y=160 : impact burst, 6 frames of 128x128, radial

Every pixel is computed from closed-form math (no randomness, no external
source imagery), so reruns are byte-identical and the output is CC0-safe
hand-authored art. Emissives follow the visual-bible relic language: white-hot
core, cyan energy body, restrained magenta corruption fringe.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent / "fx"

SHEET_SIZE = (768, 288)
CAST_CELL = 96
CAST_FRAMES = 6
FLIGHT_CELL = (128, 64)
FLIGHT_FRAMES = 4
FLIGHT_ROW_Y = 96
IMPACT_CELL = 128
IMPACT_FRAMES = 6
IMPACT_ROW_Y = 160

WHITE_HOT = (1.0, 1.0, 1.0)
CYAN_CORE = (0.30, 0.92, 1.0)
CYAN_DEEP = (0.12, 0.58, 0.88)
MAGENTA = (0.95, 0.35, 0.82)


def _glow(distance: float, core_radius: float, outer_radius: float) -> float:
    """1.0 inside the core, smooth quadratic falloff to 0 at the outer edge."""
    if distance <= core_radius:
        return 1.0
    if distance >= outer_radius or outer_radius <= core_radius:
        return 0.0
    linear = 1.0 - (distance - core_radius) / (outer_radius - core_radius)
    return linear * linear


def _band(distance: float, radius: float, width: float) -> float:
    """Smooth ring profile centered on radius with the given half-width."""
    if width <= 0.0:
        return 0.0
    linear = 1.0 - abs(distance - radius) / width
    if linear <= 0.0:
        return 0.0
    return linear * linear


def _lerp_color(a: tuple, b: tuple, t: float) -> tuple:
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _cast_contributions(x: float, y: float, progress: float) -> list:
    center = CAST_CELL / 2.0
    dx = x - center
    dy = y - center
    distance = math.hypot(dx, dy)
    fade = 1.0 - progress
    contributions = []
    # Collapsing white-hot origin flash.
    flash = _glow(distance, 2.0 + 9.0 * fade, 6.0 + 17.0 * fade) * fade ** 1.2
    if flash > 0.0:
        contributions.append((flash, _lerp_color(CYAN_CORE, WHITE_HOT, fade)))
    # Expanding energy ring: cyan inside, magenta corruption on the leading edge.
    ring_radius = 6.0 + 34.0 * progress
    ring = _band(distance, ring_radius, 3.0 + 5.0 * fade) * fade * 0.95
    if ring > 0.0:
        rim_shift = 0.75 if distance > ring_radius else 0.15
        contributions.append((ring, _lerp_color(CYAN_CORE, MAGENTA, rim_shift * progress + 0.1)))
    # Three forward petals biased toward +x so aim rotation stays readable.
    if distance > 1.0:
        theta = math.atan2(dy, dx)
        for petal_angle in (-0.45, 0.0, 0.45):
            alignment = math.cos(theta - petal_angle)
            if alignment <= 0.0:
                continue
            petal = (
                alignment ** 22
                * _glow(distance, ring_radius * 0.4, ring_radius + 12.0)
                * fade
                * 0.8
            )
            if petal > 0.0:
                contributions.append((petal, _lerp_color(WHITE_HOT, CYAN_CORE, progress)))
    return contributions


def _flight_contributions(x: float, y: float, phase: float) -> list:
    core_x = FLIGHT_CELL[0] / 2.0
    core_y = FLIGHT_CELL[1] / 2.0
    distance = math.hypot(x - core_x, y - core_y)
    pulse = 0.9 + 0.1 * math.sin(phase)
    contributions = []
    core = _glow(distance, 3.0 * pulse, 7.0 * pulse)
    if core > 0.0:
        contributions.append((core, WHITE_HOT))
    body = _glow(distance, 6.0 * pulse, 15.0 * pulse) * 0.9
    if body > 0.0:
        contributions.append((body, CYAN_CORE))
    rim = _band(distance, 13.0 * pulse, 3.0) * 0.35
    if rim > 0.0:
        contributions.append((rim, MAGENTA))
    # Tapering trail behind the orb (toward -x); the runtime rotates the whole
    # sprite so the trail always streams opposite the true flight direction.
    if x < core_x:
        tail = (core_x - x) / (core_x - 6.0)
        if tail <= 1.0:
            half_width = 8.0 * (1.0 - tail) ** 1.2 + 1.0
            wave = 2.0 * math.sin(x / 9.0 + phase) * tail
            lateral = 1.0 - abs(y - core_y - wave) / half_width
            if lateral > 0.0:
                ripple = 0.8 + 0.2 * math.sin(x / 5.0 - phase)
                strength = lateral ** 1.8 * (1.0 - tail) ** 1.5 * 0.85 * ripple
                edge = 1.0 - lateral
                color = _lerp_color(CYAN_CORE, MAGENTA, 0.7 * tail + 0.3 * edge)
                color = _lerp_color(color, CYAN_DEEP, tail * 0.4)
                contributions.append((strength, color))
    return contributions


def _impact_contributions(x: float, y: float, progress: float) -> list:
    center = IMPACT_CELL / 2.0
    dx = x - center
    dy = y - center
    distance = math.hypot(dx, dy)
    fade = 1.0 - progress
    contributions = []
    # Collapsing detonation flash.
    flash = _glow(distance, 14.0 * fade, 6.0 + 28.0 * fade) * fade ** 1.1
    if flash > 0.0:
        contributions.append((flash, _lerp_color(CYAN_CORE, WHITE_HOT, fade)))
    # Expanding shockwave ring, magenta on the outer edge.
    ring_radius = 8.0 + 52.0 * progress
    ring = _band(distance, ring_radius, 4.0 + 8.0 * fade) * fade ** 0.8
    if ring > 0.0:
        rim_shift = 0.8 if distance > ring_radius else 0.2
        contributions.append((ring, _lerp_color(CYAN_CORE, MAGENTA, rim_shift * progress)))
    # Eight radial spark spokes with corruption-tinted tips.
    if distance > 1.0:
        theta = math.atan2(dy, dx)
        spoke_length = 20.0 + 60.0 * progress
        for spoke_index in range(8):
            spoke_angle = math.tau * (spoke_index + 0.5) / 8.0
            alignment = math.cos(theta - spoke_angle)
            if alignment <= 0.0:
                continue
            radial = 1.0 - abs(distance - 0.8 * spoke_length) / (0.5 * spoke_length)
            if radial <= 0.0:
                continue
            spoke = alignment ** 30 * radial * fade * 0.9
            if spoke > 0.0:
                # Cyan-dominant sparks; magenta stays a late outer-tip fringe so
                # the player burst never reads as threat-side corruption.
                tip = min(1.0, distance / spoke_length)
                contributions.append(
                    (spoke, _lerp_color(CYAN_CORE, MAGENTA, tip * (0.25 + 0.5 * progress)))
                )
    return contributions


def _write_cell(image: Image.Image, origin: tuple, size: tuple, contribution_fn) -> None:
    for py in range(size[1]):
        for px in range(size[0]):
            red = green = blue = alpha = 0.0
            for strength, color in contribution_fn(px + 0.5, py + 0.5):
                red += color[0] * strength
                green += color[1] * strength
                blue += color[2] * strength
                alpha += strength
            if alpha <= 0.0:
                continue
            clamped_alpha = min(1.0, alpha)
            # Accumulated additively in premultiplied space; store straight alpha.
            image.putpixel(
                (origin[0] + px, origin[1] + py),
                (
                    round(min(1.0, red / alpha) * 255),
                    round(min(1.0, green / alpha) * 255),
                    round(min(1.0, blue / alpha) * 255),
                    round(clamped_alpha * 255),
                ),
            )


def relic_orb_sheet() -> Image.Image:
    image = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    # Progress stops short of 1.0 so the last authored frame still carries a
    # faint dissipation instead of an empty cell; the one-shot then frees.
    for frame in range(CAST_FRAMES):
        progress = frame / CAST_FRAMES
        _write_cell(
            image,
            (frame * CAST_CELL, 0),
            (CAST_CELL, CAST_CELL),
            lambda x, y, p=progress: _cast_contributions(x, y, p),
        )
    for frame in range(FLIGHT_FRAMES):
        phase = math.tau * frame / FLIGHT_FRAMES
        _write_cell(
            image,
            (frame * FLIGHT_CELL[0], FLIGHT_ROW_Y),
            FLIGHT_CELL,
            lambda x, y, p=phase: _flight_contributions(x, y, p),
        )
    for frame in range(IMPACT_FRAMES):
        progress = frame / IMPACT_FRAMES
        _write_cell(
            image,
            (frame * IMPACT_CELL, IMPACT_ROW_Y),
            (IMPACT_CELL, IMPACT_CELL),
            lambda x, y, p=progress: _impact_contributions(x, y, p),
        )
    return image


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    relic_orb_sheet().save(ROOT / "relic_orb_fx.png")
    print("wrote deterministic relic orb FX sheet")


if __name__ == "__main__":
    main()
