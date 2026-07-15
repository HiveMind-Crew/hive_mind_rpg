#!/usr/bin/env python3
"""Deterministically build the regular Zone 1 enemy sprite sheets for issue #114."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
enemy_dir = ROOT / "enemies"
FRAME = 32
LOGICAL_FRAME = 24
COLUMNS = 6
ROW_ORDER = [
    "idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side",
    "windup", "attack_melee", "hurt", "death",
]

TRANSPARENT = (0, 0, 0, 0)
DARK = (0x3A, 0x14, 0x45, 255)
MID = (0x94, 0x40, 0xAD, 255)
LIGHT = (0xD9, 0x8F, 0xF0, 255)
CYAN = (0x4D, 0xE5, 0xFF, 255)
MAGENTA = (0xF2, 0x59, 0xB8, 255)
WINDUP = (0xFF, 0xC7, 0x2E, 255)
ATTACK = (0xFF, 0x33, 0x40, 255)
DEATH = (0x38, 0x38, 0x42, 255)
SHADOW = (0x10, 0x0D, 0x16, 102)
SOIL = (0x4A, 0x36, 0x28, 255)


def animation_spec() -> dict[str, tuple[int, bool, float]]:
    return {
        "idle_down": (4, True, 6.0), "idle_up": (4, True, 6.0), "idle_side": (4, True, 6.0),
        "walk_down": (6, True, 10.0), "walk_up": (6, True, 10.0), "walk_side": (6, True, 10.0),
        "windup": (3, False, 8.0), "attack_melee": (3, False, 12.0),
        "hurt": (2, False, 12.0), "death": (5, False, 10.0),
    }


def shadow(draw: ImageDraw.ImageDraw, dy: int = 0) -> None:
    draw.ellipse((5, 19 + dy, 19, 22 + dy), fill=SHADOW)


def pixel_polygon(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: tuple[int, int, int, int]) -> None:
    draw.polygon(points, fill=color)


def harasser(draw: ImageDraw.ImageDraw, state: str, facing: str, phase: int) -> None:
    bob = -1 if state.startswith("walk") and phase in (1, 4) else 0
    if state == "death":
        if phase == 0:
            bob = 2
        elif phase == 1:
            pixel_polygon(draw, [(4, 17), (19, 14), (20, 18), (7, 20)], DARK)
            pixel_polygon(draw, [(7, 16), (17, 15), (18, 18), (8, 19)], DEATH)
            draw.rectangle((10, 16, 12, 17), fill=CYAN)
            shadow(draw)
            return
        else:
            pixel_polygon(draw, [(4, 18), (20, 18), (18, 21), (6, 21)], DEATH)
            draw.rectangle((10, 18, 13, 19), fill=CYAN if phase == 2 else DEATH)
            shadow(draw)
            return
    shadow(draw, bob)
    if state == "windup":
        glow = WINDUP if phase > 0 else MID
        draw.ellipse((5, 4 + bob, 18, 16 + bob), fill=glow)
        draw.rectangle((7, 11 + bob, 16, 18 + bob), fill=DARK)
        draw.rectangle((10, 12 + bob, 13, 15 + bob), fill=CYAN)
        if phase == 2:
            draw.rectangle((3, 7 + bob, 5, 13 + bob), fill=WINDUP)
            draw.rectangle((19, 7 + bob, 21, 13 + bob), fill=WINDUP)
        return
    if state == "attack_melee":
        draw.ellipse((5, 4 + bob, 18, 16 + bob), fill=MID)
        draw.rectangle((7, 11 + bob, 16, 18 + bob), fill=DARK)
        draw.rectangle((10, 12 + bob, 13, 15 + bob), fill=CYAN)
        if phase == 1:
            pixel_polygon(draw, [(14, 10), (22, 7), (22, 15), (14, 14)], ATTACK)
        return
    if state == "hurt":
        draw.ellipse((4, 5 + bob, 19, 16 + bob), fill=LIGHT)
        draw.rectangle((7, 12 + bob, 16, 18 + bob), fill=MID)
        draw.rectangle((10, 13 + bob, 13, 16 + bob), fill=CYAN)
        return
    cap = DARK if facing == "up" else MID
    draw.ellipse((5, 4 + bob, 18, 14 + bob), fill=DARK)
    draw.rectangle((7, 7 + bob, 16, 14 + bob), fill=cap)
    draw.rectangle((9, 12 + bob, 14, 18 + bob), fill=MID)
    draw.rectangle((10, 13 + bob, 13, 16 + bob), fill=CYAN)
    if facing != "up":
        draw.rectangle((8, 10 + bob, 9, 11 + bob), fill=LIGHT)
        draw.rectangle((14, 10 + bob, 15, 11 + bob), fill=LIGHT)
    if state.startswith("walk"):
        leg_x = 8 if phase % 2 == 0 else 13
        draw.rectangle((leg_x, 18 + bob, leg_x + 2, 20 + bob), fill=DARK)


def brute(draw: ImageDraw.ImageDraw, state: str, facing: str, phase: int) -> None:
    bob = -1 if state.startswith("walk") and phase in (1, 4) else 0
    if state == "death":
        if phase < 2:
            pixel_polygon(draw, [(5, 12), (18, 12), (21, 19), (3, 19)], DEATH)
        else:
            pixel_polygon(draw, [(3, 17), (21, 17), (19, 21), (5, 21)], DEATH)
        shadow(draw)
        return
    shadow(draw, bob)
    shield_color = WINDUP if state == "windup" and phase > 0 else DARK
    if state == "attack_melee" and phase == 1:
        shield_color = ATTACK
    pixel_polygon(draw, [(7, 3 + bob), (16, 3 + bob), (20, 8 + bob), (19, 18 + bob), (4, 18 + bob), (3, 8 + bob)], DARK)
    pixel_polygon(draw, [(8, 5 + bob), (15, 5 + bob), (17, 9 + bob), (16, 16 + bob), (6, 16 + bob), (6, 9 + bob)], MID)
    draw.rectangle((10, 7 + bob, 13, 9 + bob), fill=LIGHT)
    if facing != "up":
        draw.rectangle((9, 10 + bob, 10, 11 + bob), fill=LIGHT)
        draw.rectangle((13, 10 + bob, 14, 11 + bob), fill=LIGHT)
    pixel_polygon(draw, [(17, 6 + bob), (22, 8 + bob), (22, 17 + bob), (17, 19 + bob)], shield_color)
    draw.line((18, 8 + bob, 18, 17 + bob), fill=MAGENTA, width=1)
    if state == "attack_melee" and phase == 1:
        pixel_polygon(draw, [(2, 8 + bob), (6, 8 + bob), (3, 18 + bob), (0, 18 + bob)], ATTACK)
    if state == "hurt":
        draw.rectangle((8, 5 + bob, 15, 16 + bob), fill=LIGHT)
    if state.startswith("walk"):
        leg_x = 6 if phase % 2 == 0 else 14
        draw.rectangle((leg_x, 17 + bob, leg_x + 3, 20 + bob), fill=DARK)


def flanker(draw: ImageDraw.ImageDraw, state: str, facing: str, phase: int) -> None:
    bob = -1 if state.startswith("walk") and phase in (1, 4) else 0
    if state == "death":
        pixel_polygon(draw, [(3, 17), (20, 17), (17, 20), (6, 20)], DEATH)
        shadow(draw)
        return
    shadow(draw, bob)
    body = [(4, 11 + bob), (9, 6 + bob), (16, 7 + bob), (20, 11 + bob), (16, 15 + bob), (8, 15 + bob)]
    if state == "windup":
        body = [(3, 13 + bob), (8, 8 + bob), (16, 8 + bob), (21, 13 + bob), (16, 16 + bob), (8, 16 + bob)]
    pixel_polygon(draw, body, DARK)
    pixel_polygon(draw, [(7, 11 + bob), (10, 8 + bob), (16, 10 + bob), (17, 13 + bob), (10, 14 + bob)], MID)
    draw.rectangle((12, 10 + bob, 14, 11 + bob), fill=CYAN)
    spike = WINDUP if state == "windup" and phase > 0 else MAGENTA
    pixel_polygon(draw, [(9, 7 + bob), (10, 2 + bob), (12, 7 + bob)], spike)
    pixel_polygon(draw, [(14, 7 + bob), (16, 3 + bob), (16, 9 + bob)], spike)
    if state == "attack_melee" and phase == 1:
        pixel_polygon(draw, [(17, 9 + bob), (23, 7 + bob), (23, 15 + bob), (17, 14 + bob)], ATTACK)
    if state == "hurt":
        pixel_polygon(draw, [(5, 10 + bob), (10, 6 + bob), (18, 8 + bob), (19, 14 + bob), (9, 16 + bob)], LIGHT)
    if state.startswith("walk"):
        foot_x = 6 if phase % 2 == 0 else 15
        draw.rectangle((foot_x, 15 + bob, foot_x + 2, 18 + bob), fill=DARK)


class NativePixelDraw:
    ## Maps the original silhouette layout onto a 32px canvas, preserving hard
    ## pixels while giving each feature native-resolution edge detail.
    def __init__(self, image: Image.Image) -> None:
        self._draw = ImageDraw.Draw(image)

    def _point(self, point: tuple[int, int]) -> tuple[int, int]:
        return (round(point[0] * FRAME / LOGICAL_FRAME), round(point[1] * FRAME / LOGICAL_FRAME))

    def rectangle(self, box: tuple[int, int, int, int], **kwargs: object) -> None:
        left, top = self._point((box[0], box[1]))
        right, bottom = self._point((box[2] + 1, box[3] + 1))
        self._draw.rectangle((left, top, right - 1, bottom - 1), **kwargs)

    def ellipse(self, box: tuple[int, int, int, int], **kwargs: object) -> None:
        left, top = self._point((box[0], box[1]))
        right, bottom = self._point((box[2] + 1, box[3] + 1))
        self._draw.ellipse((left, top, right - 1, bottom - 1), **kwargs)

    def polygon(self, points: list[tuple[int, int]], **kwargs: object) -> None:
        self._draw.polygon([self._point(point) for point in points], **kwargs)

    def line(self, points: tuple[int, int, int, int], **kwargs: object) -> None:
        start = self._point((points[0], points[1]))
        end = self._point((points[2], points[3]))
        width: int = int(kwargs.pop("width", 1))
        self._draw.line((start, end), width=max(1, round(width * FRAME / LOGICAL_FRAME)), **kwargs)


def render(kind: str, state: str, facing: str, phase: int) -> Image.Image:
    image = Image.new("RGBA", (FRAME, FRAME), TRANSPARENT)
    draw = NativePixelDraw(image)
    if kind == "ranged_harasser":
        harasser(draw, state, facing, phase)
    elif kind == "shielded_brute":
        brute(draw, state, facing, phase)
    else:
        flanker(draw, state, facing, phase)
    return image


def write_frames(kind: str, specs: dict[str, tuple[int, bool, float]]) -> None:
    subresources: list[str] = []
    animations: list[str] = []
    for row, name in enumerate(ROW_ORDER):
        count, loop, speed = specs[name]
        frames: list[str] = []
        for column in range(count):
            identifier = f"AtlasTexture_{name}_{column}"
            subresources.append(
                f'[sub_resource type="AtlasTexture" id="{identifier}"]\n'
                'atlas = ExtResource("1_sheet")\n'
                f"region = Rect2({column * FRAME}, {row * FRAME}, {FRAME}, {FRAME})\n"
            )
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % identifier)
        animations.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
            % (", ".join(frames), "true" if loop else "false", name, speed)
        )
    (enemy_dir / f"{kind}_frames.tres").write_text(
        f'[gd_resource type="SpriteFrames" load_steps={len(subresources) + 2} format=3]\n\n'
        f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{kind}.png" id="1_sheet"]\n\n'
        + "\n".join(subresources) + "\n[resource]\nanimations = [" + ", ".join(animations) + "]\n",
        encoding="utf-8",
    )


def build(kind: str) -> None:
    specs = animation_spec()
    sheet = Image.new("RGBA", (COLUMNS * FRAME, len(ROW_ORDER) * FRAME), TRANSPARENT)
    for row, name in enumerate(ROW_ORDER):
        count, _, _ = specs[name]
        facing = name.rsplit("_", 1)[1] if name.startswith(("idle", "walk")) else "down"
        for column in range(count):
            sheet.alpha_composite(render(kind, name, facing, column), (column * FRAME, row * FRAME))
    sheet.save(enemy_dir / f"{kind}.png")
    write_frames(kind, specs)


if __name__ == "__main__":
    enemy_dir.mkdir(parents=True, exist_ok=True)
    for enemy_kind in ("ranged_harasser", "shielded_brute", "fast_flanker"):
        build(enemy_kind)
