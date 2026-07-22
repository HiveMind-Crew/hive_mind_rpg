#!/usr/bin/env python3
"""Build the deterministic stylized-HD combat FX sheet for issue #157.

Layout of assets/sprites/fx/combat_fx_hd.png (384x256, straight alpha), uniform
64x64 cells so the runtime reads each effect as a row of same-size frames:
  row y=0   : melee slash, 4 frames  - warm gold crescent sweeping a wedge
              around +x (rotated to the swing direction at runtime)
  row y=64  : hit spark,   4 frames  - white-hot radial contact burst
  row y=128 : dash trail,  3 frames  - cyan energy streak trailing toward -x
              (authored facing +x, rotated to the dash direction)
  row y=192 : death dissolve, 6 frames - ash motes lifting into a magenta
              corruption fringe

Every pixel is computed from closed-form math (no randomness, no external source
imagery), so reruns are byte-identical and the output is CC0-safe hand-authored
art. Colors follow the visual-bible combat language: warm gold wind-up/slash,
white-hot contact, cyan dash energy, and dark-neutral ash resolving to a
restrained magenta corruption fringe on defeat.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent / "fx"

CELL = 64
SHEET_SIZE = (384, 256)
SLASH_FRAMES = 4
SPARK_FRAMES = 4
DASH_FRAMES = 3
DISSOLVE_FRAMES = 6
SLASH_ROW_Y = 0
SPARK_ROW_Y = 64
DASH_ROW_Y = 128
DISSOLVE_ROW_Y = 192

WHITE_HOT = (1.0, 1.0, 1.0)
GOLD = (1.0, 0.80, 0.32)
AMBER = (1.0, 0.48, 0.16)
CYAN = (0.32, 0.90, 1.0)
CYAN_DEEP = (0.12, 0.52, 0.82)
MAGENTA = (0.95, 0.35, 0.82)
ASH = (0.34, 0.34, 0.40)


def _glow(distance: float, core_radius: float, outer_radius: float) -> float:
    if distance <= core_radius:
        return 1.0
    if distance >= outer_radius or outer_radius <= core_radius:
        return 0.0
    linear = 1.0 - (distance - core_radius) / (outer_radius - core_radius)
    return linear * linear


def _band(distance: float, radius: float, width: float) -> float:
    if width <= 0.0:
        return 0.0
    linear = 1.0 - abs(distance - radius) / width
    return linear * linear if linear > 0.0 else 0.0


def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _slash(x: float, y: float, frame: int) -> list:
    center = CELL / 2.0
    dx = x - center
    dy = y - center
    distance = math.hypot(dx, dy)
    progress = (frame + 0.5) / SLASH_FRAMES
    fade = 1.0 - progress
    # A crescent arc that expands outward and thins as the swing follows through.
    radius = 17.0 + 9.0 * progress
    ring = _band(distance, radius, 5.0 * (1.0 - 0.4 * progress))
    if ring <= 0.0 or distance < 1.0:
        return []
    theta = math.atan2(dy, dx)
    # Wedge opening toward +x; outside ~±65° the arc tapers off.
    wedge = max(0.0, 1.0 - (abs(theta) / 1.15) ** 2)
    if wedge <= 0.0:
        return []
    contributions = []
    body = ring * wedge * (0.55 + 0.45 * fade)
    contributions.append((body, _lerp(AMBER, GOLD, 0.5 + 0.5 * fade)))
    # A white-hot leading edge travels down the arc as the slash sweeps.
    hot_angle = -0.9 + 1.8 * progress
    alignment = max(0.0, 1.0 - abs(theta - hot_angle) / 0.5)
    hot = ring * alignment ** 2 * (0.6 + 0.4 * fade)
    if hot > 0.0:
        contributions.append((hot, _lerp(GOLD, WHITE_HOT, alignment)))
    return contributions


def _spark(x: float, y: float, frame: int) -> list:
    center = CELL / 2.0
    dx = x - center
    dy = y - center
    distance = math.hypot(dx, dy)
    progress = frame / SPARK_FRAMES
    fade = 1.0 - progress
    contributions = []
    # Collapsing white-hot contact core.
    core = _glow(distance, 2.0 + 5.0 * fade, 5.0 + 12.0 * fade) * fade ** 0.6
    if core > 0.0:
        contributions.append((core, _lerp(GOLD, WHITE_HOT, fade)))
    # Six expanding spikes so contact reads sharp without hiding the target.
    if distance > 1.0:
        theta = math.atan2(dy, dx)
        spike_length = 10.0 + 20.0 * progress
        for index in range(6):
            spoke = math.tau * index / 6.0
            alignment = math.cos(theta - spoke)
            if alignment <= 0.0:
                continue
            radial = 1.0 - abs(distance - 0.7 * spike_length) / (0.6 * spike_length)
            if radial <= 0.0:
                continue
            strength = alignment ** 24 * radial * fade * 0.9
            if strength > 0.0:
                contributions.append((strength, _lerp(WHITE_HOT, GOLD, progress)))
    return contributions


def _dash(x: float, y: float, frame: int) -> list:
    center_x = CELL / 2.0
    center_y = CELL / 2.0
    dy = y - center_y
    progress = frame / DASH_FRAMES
    fade = 1.0 - progress
    contributions = []
    # A tapering streak: brightest at the +x leading head, trailing toward -x.
    head_x = center_x + 4.0
    if x <= head_x:
        tail = (head_x - x) / (head_x - 4.0)
        if 0.0 <= tail <= 1.0:
            half_width = 8.5 * (1.0 - tail) ** 0.8 + 1.0
            lateral = 1.0 - abs(dy) / half_width
            if lateral > 0.0:
                strength = lateral ** 1.6 * (1.0 - 0.7 * tail) * (0.5 + 0.5 * fade)
                edge = 1.0 - lateral
                color = _lerp(CYAN, CYAN_DEEP, 0.5 * tail + 0.3 * edge)
                # Faint magenta only at the dissipating tail tip.
                color = _lerp(color, MAGENTA, max(0.0, tail - 0.7) * 0.6)
                contributions.append((strength, color))
    head = _glow(math.hypot(x - head_x, dy), 2.0, 7.0) * (0.4 + 0.6 * fade)
    if head > 0.0:
        contributions.append((head, _lerp(CYAN, WHITE_HOT, 0.5 * fade)))
    return contributions


def _dissolve(x: float, y: float, frame: int) -> list:
    progress = frame / (DISSOLVE_FRAMES - 1)
    contributions = []
    # Twelve deterministic motes lift and spread from the body center, cooling
    # from ash to a magenta corruption fringe as they scatter and fade.
    for index in range(12):
        angle = math.tau * (index * 0.61803398875)
        spread = 4.0 + 22.0 * progress
        mote_x = CELL / 2.0 + math.cos(angle) * spread * (0.4 + 0.6 * ((index % 5) / 4.0))
        mote_y = CELL / 2.0 + math.sin(angle) * spread * 0.7 - 14.0 * progress
        radius = 3.2 * (1.0 - 0.5 * progress)
        mote = _glow(math.hypot(x - mote_x, y - mote_y), 0.5, radius)
        if mote > 0.0:
            fade = (1.0 - progress) ** 0.7
            contributions.append((mote * fade, _lerp(ASH, MAGENTA, progress)))
    return contributions


def _write_cell(image: Image.Image, origin: tuple, contribution_fn) -> None:
    for py in range(CELL):
        for px in range(CELL):
            red = green = blue = alpha = 0.0
            for strength, color in contribution_fn(px + 0.5, py + 0.5):
                red += color[0] * strength
                green += color[1] * strength
                blue += color[2] * strength
                alpha += strength
            if alpha <= 0.0:
                continue
            clamped = min(1.0, alpha)
            image.putpixel(
                (origin[0] + px, origin[1] + py),
                (
                    round(min(1.0, red / alpha) * 255),
                    round(min(1.0, green / alpha) * 255),
                    round(min(1.0, blue / alpha) * 255),
                    round(clamped * 255),
                ),
            )


def combat_fx_hd_sheet() -> Image.Image:
    image = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    rows = [
        (SLASH_ROW_Y, SLASH_FRAMES, _slash),
        (SPARK_ROW_Y, SPARK_FRAMES, _spark),
        (DASH_ROW_Y, DASH_FRAMES, _dash),
        (DISSOLVE_ROW_Y, DISSOLVE_FRAMES, _dissolve),
    ]
    for row_y, frame_count, fn in rows:
        for frame in range(frame_count):
            _write_cell(image, (frame * CELL, row_y), lambda x, y, f=frame, g=fn: g(x, y, f))
    return image


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    combat_fx_hd_sheet().save(ROOT / "combat_fx_hd.png")
    print("wrote deterministic HD combat FX sheet")


if __name__ == "__main__":
    main()
