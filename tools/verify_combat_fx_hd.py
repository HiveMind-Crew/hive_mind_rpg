#!/usr/bin/env python3
"""Verify the deterministic decoded pixels of the HD combat FX generator.

PNG byte streams can legitimately differ across Pillow encoder versions. This
check verifies the rendering contract (RGBA pixels, dimensions, and mode)
rather than a container-specific file hash.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
from typing import cast

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "assets/sprites/generate_combat_fx_hd.py"
COMMITTED = ROOT / "assets/sprites/fx/combat_fx_hd.png"


def load_generator():
    spec = importlib.util.spec_from_file_location("generate_combat_fx_hd", GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {GENERATOR}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    generated: Image.Image = load_generator().combat_fx_hd_sheet()
    with Image.open(COMMITTED) as committed_file:
        committed = committed_file.convert("RGBA")

    if generated.mode != "RGBA" or committed.mode != "RGBA":
        raise SystemExit("error: combat FX images must decode as RGBA")
    if generated.size != committed.size:
        raise SystemExit(f"error: size mismatch: generated {generated.size}, committed {committed.size}")
    for y in range(generated.height):
        for x in range(generated.width):
            generated_pixel: tuple[int, int, int, int] = cast(
                tuple[int, int, int, int], generated.getpixel((x, y))
            )
            committed_pixel: tuple[int, int, int, int] = cast(
                tuple[int, int, int, int], committed.getpixel((x, y))
            )
            # RGB values below fully transparent alpha are not observable and Pillow
            # encoders may normalize them differently. Every visible RGBA pixel and
            # every alpha value must remain identical.
            if generated_pixel[3] != committed_pixel[3]:
                raise SystemExit("error: generated combat FX alpha differs from the committed sheet")
            if generated_pixel[3] > 0 and generated_pixel[:3] != committed_pixel[:3]:
                raise SystemExit("error: generated visible combat FX pixels differ from the committed sheet")

    print(f"combat FX visible pixels: OK ({generated.size[0]}x{generated.size[1]} RGBA; encoder bytes ignored)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
