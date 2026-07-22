#!/usr/bin/env python3
"""Build the deterministic stylized-HD enemy wind-up telegraph for issue #157.

Output assets/sprites/enemies/hd/enemy_windup_tell.png (96x96, straight alpha):
a single warm hazard aura shown behind a regular enemy only during its WIND_UP
state (EnemyBase drives visibility; this sprite never changes gameplay). The
center is transparent so the actor stays readable; a warm gold ring with four
converging hazard ticks reads as "incoming attack", and a restrained magenta
outer fringe carries the threat-side relic-corruption language from the visual
bible without hiding the enemy or implying a hitbox.

Every pixel is computed from closed-form math (no randomness, no external source
imagery), so reruns are byte-identical and the output is CC0-safe hand-authored
art.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent / "enemies" / "hd"

SIZE = 96
CENTER = SIZE / 2.0

WHITE_HOT = (1.0, 1.0, 1.0)
GOLD = (1.0, 0.80, 0.30)
AMBER = (1.0, 0.52, 0.18)
MAGENTA = (0.95, 0.35, 0.82)


def _band(distance: float, radius: float, width: float) -> float:
    if width <= 0.0:
        return 0.0
    linear = 1.0 - abs(distance - radius) / width
    return linear * linear if linear > 0.0 else 0.0


def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _tell(x: float, y: float) -> list:
    dx = x - CENTER
    dy = y - CENTER
    distance = math.hypot(dx, dy)
    contributions = []
    # Warm hazard ring; the transparent interior keeps the actor legible.
    ring = _band(distance, 30.0, 8.0)
    if ring > 0.0:
        contributions.append((ring * 0.85, _lerp(AMBER, GOLD, 0.5)))
    # Restrained magenta corruption fringe just outside the warm ring.
    fringe = _band(distance, 40.0, 6.0)
    if fringe > 0.0:
        contributions.append((fringe * 0.5, MAGENTA))
    # Four converging hazard ticks that point inward toward the actor.
    if distance > 1.0:
        theta = math.atan2(dy, dx)
        for index in range(4):
            spoke = math.tau * (index + 0.5) / 4.0
            alignment = math.cos(theta - spoke)
            if alignment <= 0.0:
                continue
            radial = _band(distance, 22.0, 10.0)
            tick = alignment ** 40 * radial
            if tick > 0.0:
                contributions.append((tick, _lerp(GOLD, WHITE_HOT, 0.4)))
    return contributions


def windup_tell() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for py in range(SIZE):
        for px in range(SIZE):
            red = green = blue = alpha = 0.0
            for strength, color in _tell(px + 0.5, py + 0.5):
                red += color[0] * strength
                green += color[1] * strength
                blue += color[2] * strength
                alpha += strength
            if alpha <= 0.0:
                continue
            image.putpixel(
                (px, py),
                (
                    round(min(1.0, red / alpha) * 255),
                    round(min(1.0, green / alpha) * 255),
                    round(min(1.0, blue / alpha) * 255),
                    round(min(1.0, alpha) * 255),
                ),
            )
    return image


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    windup_tell().save(ROOT / "enemy_windup_tell.png")
    print("wrote deterministic HD enemy wind-up tell")


if __name__ == "__main__":
    main()
