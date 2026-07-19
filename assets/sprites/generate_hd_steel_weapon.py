#!/usr/bin/env python3
"""Build the deterministic stylized-HD steel weapon atlas for issue #168.

Layout of assets/sprites/player/hd/steel_weapon_atlas.png (512x128, straight
alpha), two 256x128 cells of one arming sword authored pointing +x with the
grip center (the runtime rotation pivot) at x=24, y=64:
  cell x=0   : held pose — clean steel blade, fuller, iron crossguard,
               leather-wrapped grip, steel pommel
  cell x=256 : swing pose — same silhouette with a white-hot leading edge on
               the +y side and a translucent motion smear trailing on the -y
               side (rotation increases clockwise at runtime, so +y leads)

Every pixel is computed from closed-form math (no randomness, no external
source imagery), so reruns are byte-identical and the output is CC0-safe
hand-authored art. The steel keeps the visual-bible medieval material
language: low-saturation cool metal with a restrained warm top light — no
relic cyan/magenta, which stay reserved for relic tech.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent / "player" / "hd"

SHEET_SIZE = (512, 128)
CELL_SIZE = (256, 128)
AXIS_Y = 64.0

POMMEL_CENTER_X = 10.0
POMMEL_RADIUS = 5.5
GRIP_START_X = 14.0
GRIP_END_X = 34.0
GRIP_HALF_WIDTH = 4.2
GUARD_CENTER_X = 37.0
GUARD_HALF_LENGTH = 15.0
GUARD_HALF_WIDTH = 3.2
BLADE_START_X = 40.0
BLADE_SHOULDER_HALF_WIDTH = 7.0
BLADE_TAPER_END_X = 196.0
BLADE_TAPER_HALF_WIDTH = 4.2
BLADE_TIP_X = 232.0
FULLER_START_X = 46.0
FULLER_END_X = 180.0
FULLER_HALF_WIDTH = 1.6

STEEL_TOP = (0.78, 0.81, 0.87)
STEEL_BOTTOM = (0.44, 0.48, 0.56)
STEEL_EDGE = (0.93, 0.96, 1.00)
WARM_LIGHT = (0.05, 0.02, -0.03)
IRON_GUARD = (0.27, 0.26, 0.29)
LEATHER = (0.34, 0.23, 0.15)
POMMEL_STEEL = (0.40, 0.42, 0.48)
HOT_EDGE = (1.0, 0.99, 0.95)
SMEAR_STEEL = (0.85, 0.89, 0.95)


def _clamp01(value: float) -> float:
    return min(1.0, max(0.0, value))


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _lerp_color(a: tuple, b: tuple, t: float) -> tuple:
    t = _clamp01(t)
    return tuple(_lerp(a[i], b[i], t) for i in range(3))


def _coverage(signed_distance: float) -> float:
    """Analytic one-pixel anti-aliasing from a signed distance (inside > 0)."""
    return _clamp01(signed_distance + 0.5)


def _blade_half_width(x: float) -> float:
    if x < BLADE_START_X or x > BLADE_TIP_X:
        return 0.0
    if x <= BLADE_TAPER_END_X:
        progress = (x - BLADE_START_X) / (BLADE_TAPER_END_X - BLADE_START_X)
        return _lerp(BLADE_SHOULDER_HALF_WIDTH, BLADE_TAPER_HALF_WIDTH, progress)
    progress = (x - BLADE_TAPER_END_X) / (BLADE_TIP_X - BLADE_TAPER_END_X)
    return BLADE_TAPER_HALF_WIDTH * max(0.0, 1.0 - progress) ** 0.85


def _blade_pixel(x: float, dy: float, swing: bool) -> tuple:
    half_width = _blade_half_width(x)
    alpha = _coverage(half_width - abs(dy))
    if alpha <= 0.0 or half_width <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    shade = _clamp01((dy + half_width) / (2.0 * half_width))
    color = _lerp_color(STEEL_TOP, STEEL_BOTTOM, shade)
    warm = (1.0 - shade) ** 2
    color = tuple(_clamp01(color[i] + WARM_LIGHT[i] * warm) for i in range(3))
    if FULLER_START_X <= x <= FULLER_END_X and abs(dy) < FULLER_HALF_WIDTH:
        color = tuple(channel * 0.82 for channel in color)
    edge_proximity = half_width - abs(dy)
    if edge_proximity < 1.4:
        color = _lerp_color(color, STEEL_EDGE, 0.6 * (1.0 - edge_proximity / 1.4))
    if swing:
        color = tuple(_clamp01(channel * 1.08) for channel in color)
        if dy > 0.0 and edge_proximity < 1.8 and x >= 70.0:
            heat = _clamp01((x - 70.0) / (BLADE_TIP_X - 74.0))
            color = _lerp_color(color, HOT_EDGE, 0.85 * heat * (1.0 - edge_proximity / 1.8))
    return (color[0], color[1], color[2], alpha)


def _guard_pixel(x: float, dy: float) -> tuple:
    distance_x = abs(x - GUARD_CENTER_X) - GUARD_HALF_WIDTH
    distance_y = abs(dy) - GUARD_HALF_LENGTH
    outside = math.hypot(max(distance_x, 0.0), max(distance_y, 0.0))
    inside = min(max(distance_x, distance_y), 0.0)
    alpha = _coverage(-(outside + inside) - 0.0)
    if alpha <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    lit = _clamp01(0.5 - dy / (2.0 * GUARD_HALF_LENGTH))
    color = tuple(_clamp01(IRON_GUARD[i] + 0.12 * lit) for i in range(3))
    return (color[0], color[1], color[2], alpha)


def _grip_pixel(x: float, dy: float) -> tuple:
    if x < GRIP_START_X or x > GRIP_END_X:
        return (0.0, 0.0, 0.0, 0.0)
    alpha = _coverage(GRIP_HALF_WIDTH - abs(dy))
    if alpha <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    wrap = 1.0 + 0.14 * math.cos(math.tau * (x - GRIP_START_X) / 5.5)
    shade = 1.0 - 0.25 * _clamp01((dy + GRIP_HALF_WIDTH) / (2.0 * GRIP_HALF_WIDTH))
    color = tuple(_clamp01(channel * wrap * shade) for channel in LEATHER)
    return (color[0], color[1], color[2], alpha)


def _pommel_pixel(x: float, dy: float) -> tuple:
    distance = math.hypot(x - POMMEL_CENTER_X, dy)
    alpha = _coverage(POMMEL_RADIUS - distance)
    if alpha <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    lit = _clamp01(0.5 - dy / (2.0 * POMMEL_RADIUS))
    color = tuple(_clamp01(POMMEL_STEEL[i] + 0.15 * lit) for i in range(3))
    return (color[0], color[1], color[2], alpha)


def _smear_pixel(x: float, dy: float) -> tuple:
    """Trailing motion smear above the blade (-y side) for the swing cell."""
    half_width = _blade_half_width(x)
    if half_width <= 0.0 or dy >= 0.0 or x < 64.0 or x > 226.0:
        return (0.0, 0.0, 0.0, 0.0)
    trail_distance = -dy - half_width
    if trail_distance <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    envelope = math.sin(math.pi * (x - 64.0) / 162.0)
    if envelope <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    streak = 0.55 + 0.45 * math.cos(math.tau * (x - 64.0) / 34.0)
    alpha = 0.42 * math.exp(-trail_distance / 12.0) * envelope * _clamp01(streak)
    if alpha <= 0.004:
        return (0.0, 0.0, 0.0, 0.0)
    return (SMEAR_STEEL[0], SMEAR_STEEL[1], SMEAR_STEEL[2], alpha)


def _composite(base: tuple, over: tuple) -> tuple:
    if over[3] <= 0.0:
        return base
    alpha = over[3] + base[3] * (1.0 - over[3])
    if alpha <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    color = tuple(
        (over[i] * over[3] + base[i] * base[3] * (1.0 - over[3])) / alpha for i in range(3)
    )
    return (color[0], color[1], color[2], alpha)


def _sword_pixel(x: float, y: float, swing: bool) -> tuple:
    dy = y - AXIS_Y
    pixel = (0.0, 0.0, 0.0, 0.0)
    if swing:
        pixel = _composite(pixel, _smear_pixel(x, dy))
    pixel = _composite(pixel, _blade_pixel(x, dy, swing))
    pixel = _composite(pixel, _guard_pixel(x, dy))
    pixel = _composite(pixel, _grip_pixel(x, dy))
    pixel = _composite(pixel, _pommel_pixel(x, dy))
    return pixel


def build_sheet() -> Image.Image:
    image = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
    pixels = image.load()
    for cell_index, swing in enumerate((False, True)):
        origin_x = cell_index * CELL_SIZE[0]
        for y in range(CELL_SIZE[1]):
            for x in range(CELL_SIZE[0]):
                red, green, blue, alpha = _sword_pixel(x + 0.5, y + 0.5, swing)
                if alpha <= 0.0:
                    continue
                pixels[origin_x + x, y] = (
                    round(red * 255.0),
                    round(green * 255.0),
                    round(blue * 255.0),
                    round(alpha * 255.0),
                )
    return image


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    build_sheet().save(ROOT / "steel_weapon_atlas.png")
    print("wrote deterministic HD steel weapon atlas")


if __name__ == "__main__":
    main()
