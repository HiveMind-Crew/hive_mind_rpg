#!/usr/bin/env python3
"""Build deterministic 16-bit combat-feedback sprite sheets for issue #120."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "fx"
CLEAR = (0, 0, 0, 0)
CYAN = (77, 229, 255, 255)
MAGENTA = (242, 89, 184, 255)
GOLD = (255, 199, 46, 255)
WHITE = (255, 255, 255, 255)
ASH = (56, 56, 66, 255)


def combat_sheet() -> Image.Image:
    image = Image.new("RGBA", (264, 64), CLEAR)
    draw = ImageDraw.Draw(image)
    # melee slash: four 32×32 cells, x=0..127
    for frame in range(4):
        x = frame * 32
        draw.arc((x + 4, 4, x + 28, 28), 210 - frame * 12, 330 + frame * 8, fill=GOLD, width=2)
        draw.arc((x + 8, 8, x + 24, 24), 215 - frame * 12, 315 + frame * 8, fill=WHITE, width=1)
    # hit spark: four 16×16 cells, x=128..191
    for frame in range(4):
        x = 128 + frame * 16
        radius = 2 + frame
        draw.line((x + 8 - radius, 8, x + 8 + radius, 8), fill=WHITE, width=1)
        draw.line((x + 8, 8 - radius, x + 8, 8 + radius), fill=GOLD, width=1)
    # dash trail: three 24×24 cells, x=192..263
    for frame in range(3):
        x = 192 + frame * 24
        for trail in range(3 - frame):
            draw.rectangle((x + 3 + trail * 5, 10, x + 6 + trail * 5, 13), fill=CYAN if trail == 0 else MAGENTA)
    # death dissolve: six 24×24 cells on the lower row
    for frame in range(6):
        x = frame * 24
        for bit in range(8 - frame):
            px = x + 3 + (bit * 7) % 18
            py = 36 + (bit * 5) % 18
            draw.rectangle((px, py, px + 2, py + 2), fill=ASH if frame < 4 else MAGENTA)
    return image


def main() -> None:
    # The former bolt_sheet() output (fx/energy_bolt.png) was retired by the
    # issue #169 HD relic pass; generate_relic_orb_fx.py owns those visuals now.
    ROOT.mkdir(parents=True, exist_ok=True)
    combat_sheet().save(ROOT / "combat_fx.png")
    print("wrote deterministic combat FX PNGs")


if __name__ == "__main__":
    main()
