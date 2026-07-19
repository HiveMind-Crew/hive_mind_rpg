#!/usr/bin/env python3
"""Curate an externally retained #165 four-view source into the runtime atlas.

The raw Flux generation is intentionally not versioned under `assets/`: Godot's
all-resources Web export would package it beside the runtime atlas. Provide it
from a local review/archive path when recuration is needed:

  python3 tools/curate_player_directional_atlas.py /absolute/path/to/source.png

The committed runtime atlas plus prompt/provenance JSON is the shipped source of
truth; this helper documents the deterministic cleanup/cropping recipe.
"""
import colorsys
import sys
from pathlib import Path
from PIL import Image, ImageOps

OUTPUT = Path("assets/sprites/player/hd/player_directional_atlas.png")
FRAME_SIZE = 256
MAX_CONTENT = 190


def remove_lime(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _alpha = pixels[x, y]
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
            # Key lime/yellow-green plate noise while retaining cyan-teal cloth.
            if saturation > 0.18 and value > 0.20 and 0.12 <= hue <= 0.31:
                pixels[x, y] = (red, green, blue, 0)
    return rgba


def crop_and_center(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError("A source cell lost all opaque pixels during chroma keying")
    art = image.crop(bounds)
    scale = min(MAX_CONTENT / art.width, MAX_CONTENT / art.height)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(art, ((FRAME_SIZE - art.width) // 2, (FRAME_SIZE - art.height) // 2))
    return frame


if len(sys.argv) != 2:
    raise SystemExit("usage: curate_player_directional_atlas.py /absolute/path/to/four_view_source.png")
source_path = Path(sys.argv[1])
source = Image.open(source_path)
if source.size != (1024, 1024):
    raise RuntimeError(f"Expected 1024x1024 source, received {source.size}")
boxes = [(0, 0, 512, 512), (512, 0, 1024, 512), (0, 512, 512, 1024), (512, 512, 1024, 1024)]
frames = [crop_and_center(remove_lime(source.crop(box))) for box in boxes]
frames[3] = ImageOps.mirror(frames[3])
atlas = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE), (0, 0, 0, 0))
for index, frame in enumerate(frames):
    atlas.alpha_composite(frame, (FRAME_SIZE * index, 0))
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
atlas.save(OUTPUT, optimize=True)
print(OUTPUT)
