#!/usr/bin/env python3
"""Build the deterministic stylized-HD relic orb FX sheet for issues #169/#185.

Layout of assets/sprites/fx/relic_orb_fx.png (768x288, straight alpha):
  row y=0   : cast flare,   6 frames of  96x96, authored radially with a
              forward (+x) bias so the runtime can rotate it to the aim angle
  row y=96  : flight orb,   4 frames of 128x64, orb core at the exact cell
              center (collision-truthful) with the trail streaming toward -x
  row y=160 : impact burst, 6 frames of 128x128, radial

Every pixel is computed from closed-form math (no randomness, no external
source imagery), so reruns are byte-identical and the output is CC0-safe
hand-authored art. The #185 readability pass keeps a white-hot core visible at
gameplay scale, makes the flight tail unmistakably directional, and holds the
impact inside its cell rather than expanding into a screen-filling ring.
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
    # A persistent compact core gives the cast a clear launch point even after
    # the expanding halo has begun to dissipate.
    flash = _glow(distance, 3.0 + 4.0 * fade, 10.0 + 7.0 * fade) * (0.45 + 0.55 * fade)
    if flash > 0.0:
        contributions.append((flash, _lerp_color(CYAN_CORE, WHITE_HOT, fade)))
    # Compact broken halo, held well inside the cell so it reads as a cast
    # flash instead of a large empty circle.
    ring_radius = 10.0 + 24.0 * progress
    ring = _band(distance, ring_radius, 2.5 + 2.0 * fade) * fade * 0.7
    if ring > 0.0:
        rim_shift = 0.45 if distance > ring_radius else 0.08
        contributions.append((ring, _lerp_color(CYAN_CORE, MAGENTA, rim_shift * progress)))
    # A tight forward fan keeps the aim legible before the projectile clears
    # the muzzle. This +x-authored silhouette rotates with the true aim.
    if distance > 1.0:
        theta = math.atan2(dy, dx)
        for petal_angle in (-0.30, 0.0, 0.30):
            alignment = math.cos(theta - petal_angle)
            if alignment <= 0.0:
                continue
            petal = (
                alignment ** 30
                * _glow(distance, 7.0, 24.0 + 10.0 * fade)
                * (0.25 + 0.75 * fade)
                * 0.9
            )
            if petal > 0.0:
                contributions.append((petal, _lerp_color(WHITE_HOT, CYAN_CORE, 0.35 + 0.45 * progress)))
    return contributions


def _flight_contributions(x: float, y: float, phase: float) -> list:
    core_x = FLIGHT_CELL[0] / 2.0
    core_y = FLIGHT_CELL[1] / 2.0
    distance = math.hypot(x - core_x, y - core_y)
    pulse = 0.94 + 0.06 * math.sin(phase)
    contributions = []
    # Keep the collision-center core near-white in every flight frame. The
    # broad cyan body is deliberately secondary to that gameplay anchor.
    core = _glow(distance, 4.0 * pulse, 8.0 * pulse)
    if core > 0.0:
        # Weight the white core above its translucent body so straight-alpha
        # compositing preserves an actually white center instead of averaging
        # it into cyan.
        contributions.append((core * 3.5, WHITE_HOT))
    body = _glow(distance, 7.0 * pulse, 14.0 * pulse) * 0.72
    if body > 0.0:
        contributions.append((body, CYAN_CORE))
    rim = _band(distance, 12.5 * pulse, 2.2) * 0.25
    if rim > 0.0:
        contributions.append((rim, MAGENTA))
    # Long, tapered +x-authored tail. It is made from a dense core streak plus
    # two broken wisps, avoiding the former tiny smear at gameplay scale while
    # leaving the leading half visually quiet. Runtime rotation keeps it behind
    # all eight true launch directions.
    if 14.0 <= x < core_x - 4.0:
        tail = (core_x - 4.0 - x) / (core_x - 18.0)
        half_width = 1.2 + 5.0 * (1.0 - tail) ** 0.7
        wave = math.sin(x / 7.0 + phase) * (0.7 + 1.4 * tail)
        lateral = 1.0 - abs(y - core_y - wave) / half_width
        if lateral > 0.0:
            strength = lateral ** 1.7 * (0.32 + 0.62 * (1.0 - tail))
            contributions.append((strength, _lerp_color(CYAN_DEEP, CYAN_CORE, 1.0 - tail)))
        # Magenta remains an intermittent thin fringe, never the tail body.
        wisp_offset = 3.0 + 2.0 * tail
        wisp = 1.0 - abs(abs(y - core_y) - wisp_offset) / 1.15
        gaps = 0.45 + 0.55 * max(0.0, math.sin(x * 0.34 - phase))
        if wisp > 0.0:
            contributions.append((wisp ** 2 * (1.0 - tail) * 0.26 * gaps, MAGENTA))
    return contributions


def _impact_contributions(x: float, y: float, progress: float) -> list:
    center = IMPACT_CELL / 2.0
    dx = x - center
    dy = y - center
    distance = math.hypot(dx, dy)
    fade = 1.0 - progress
    contributions = []
    # White-hot contact flash, followed by a compact cyan body. The maximum
    # radius remains inside the cell so impact never reads as a giant aura.
    flash = _glow(distance, 5.0 + 13.0 * fade, 12.0 + 17.0 * fade) * (0.18 + 0.82 * fade)
    if flash > 0.0:
        contributions.append((flash, _lerp_color(CYAN_CORE, WHITE_HOT, fade)))
    # A dense contained shock ring makes the hit read distinctly from cast.
    ring_radius = 12.0 + 31.0 * progress
    ring = _band(distance, ring_radius, 2.5 + 3.5 * fade) * fade ** 0.85
    if ring > 0.0:
        rim_shift = 0.35 if distance > ring_radius else 0.08
        contributions.append((ring, _lerp_color(CYAN_CORE, MAGENTA, rim_shift * progress)))
    # Eight short radial sparks remain inside the shock ring's silhouette.
    if distance > 1.0:
        theta = math.atan2(dy, dx)
        spoke_length = 14.0 + 34.0 * progress
        for spoke_index in range(8):
            spoke_angle = math.tau * (spoke_index + 0.5 + 0.12 * math.sin(progress * math.tau)) / 8.0
            alignment = math.cos(theta - spoke_angle)
            if alignment <= 0.0:
                continue
            radial = 1.0 - abs(distance - 0.78 * spoke_length) / (0.3 * spoke_length)
            if radial <= 0.0:
                continue
            spoke = alignment ** 34 * radial * fade * 0.55
            if spoke > 0.0:
                tip = min(1.0, distance / spoke_length)
                contributions.append((spoke, _lerp_color(CYAN_CORE, MAGENTA, tip * 0.22 * progress)))
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
