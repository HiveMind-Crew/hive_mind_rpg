# Visual Bible — v1 Vertical Slice (Corrupted Forest)

> **Status:** Canonical for the v1 slice (issue #82). Expands DESIGN.md §10.
> Every sprite/tileset/UI-skin task cites this document plus
> [`asset_manifest_v1.md`](asset_manifest_v1.md) instead of redefining scale,
> palette, or import rules.
> In-engine proof: run `scenes/reference/visual_reference_sheet.tscn` (F6) to
> see the palette and a native 640×360 readability strip. The scene's swatch
> constants mirror §2 and must be updated in the same PR as any palette change.

## 1. Direction in one paragraph

16-bit top-down pixel art. Zone 1 is a **corrupted forest**: earthy medieval
forms — soil, bark, moss, worked stone, parchment — broken by buried relic
tech that bleeds **cyan and magenta** into the world. The medieval layer is
low-saturation and hand-worn; the tech layer is high-saturation, emissive, and
geometric (straight seams, dithered glow, glitch offsets). The two languages
never blend: corruption reads as an intrusion, not a tint.

## 2. Palette

All colors are 8-bit hex. Actor/FX anchors are already shipped in gameplay
scenes and scripts (sources noted); world ramps are new and canonical here.

### 2.1 World ramps (earthy, low saturation)

| Ramp | Values (dark → light) | Use |
|---|---|---|
| Canopy / void | `#100D16` `#1C1826` `#2A2438` | Backgrounds, pit/void, deepest shadow. Coolest and darkest values on screen. |
| Soil / bark | `#2E211B` `#4A3628` `#6B4E33` `#8F6D46` | Ground, roots, trunks, wooden props. |
| Moss / foliage | `#1E2B1D` `#33472A` `#4F6B38` `#7A934F` | Walkable forest floor, leaves, undergrowth. |
| Stone | `#2B2B33` `#45454F` `#63636E` | Ruins, shrine masonry, walls. `#666B80` is the checkpoint-dormant anchor (`checkpoint.gd`). |
| Parchment | `#B8A98C` `#D9CBA8` `#F2E9CE` | Cloth, bone, bright medieval highlights, UI body text. |

### 2.2 Corruption accents (relic tech — reserved)

| Ramp | Values | Use |
|---|---|---|
| Relic cyan | `#0F4A52` `#1FA0A8` `#4DE5FF` `#C8F8FF` | Relic machinery glow, energy bolt (`#4DE5FF`, `energy_bolt.tscn`), skill-point pickups, energy UI. |
| Corruption magenta | `#5C1E52` `#9E2966` `#F259B8` `#FFC8EC` | Corruption veins/growths, boss door (`#9E2966`, `zone1_graybox.tscn`), threat-side tech. |

**Reservation rule:** cyan/magenta at these saturations appear **only** on
relic tech, corruption, and the interactive/threat elements listed above —
never in ambient foliage, soil, or stone. The sole actor exception is the
player's magenta facing marker (`#F259B8`): it communicates facing at a glance
and never appears as an ambient/world material. This keeps interactables,
danger, and player orientation readable at a glance.

### 2.3 Actor identity

| Group | Values | Anchors |
|---|---|---|
| Player (teal) | `#0E5F58` `#1FD1C2` `#A8FFF2`, accent `#F259B8` | Body `#1FD1C2` and facing marker `#F259B8` from `player.tscn`. |
| Enemies (violet) | `#3A1445` `#9440AD` `#D98FF0` | Idle body `#9440AD` from `enemy_base.gd`. |

Player = teal family; enemies = violet family; world = earth ramps. No world
material may sit in the teal or violet hue bands at actor saturation.

### 2.4 Signal colors (combat/UI states — semantic, do not repurpose)

| Meaning | Hex | Anchor |
|---|---|---|
| Wind-up / telegraph | `#FFC72E` | `enemy_base.gd` WIND_UP_COLOR |
| Attack / damage | `#FF3340` | `enemy_base.gd` ATTACK_COLOR |
| Restore / checkpoint lit | `#80F2B8` | `checkpoint.gd` lit_color |
| Energy / relic UI | `#8CE5FF` | `player_hud.tscn` energy label |
| Health UI | `#FFB8B8` | `player_hud.tscn` health label |
| Death / defeated | `#383842` | `enemy_base.gd` DEAD_COLOR |
| UI panel base | `#171721` | `skill_tree_screen.tscn` backdrop |

## 3. Value hierarchy (dark → light)

1. **Background / void** — darkest, least saturated (canopy ramp).
2. **Walls & large props** — dark silhouettes with a single light-ramp rim on
   the top edge; must separate from floor by ≥ 2 value steps.
3. **Walkable floor** — mid value, lowest local contrast on screen (moss/soil
   mids); floor detail stays within adjacent ramp steps so actors pop.
4. **Actors & interactables** — highest local contrast; each actor's mid value
   must differ from the floor mid by ≥ 3 value steps.
5. **FX, telegraphs, corruption glow** — brightest and most saturated,
   short-lived or spatially small.

Light reads as coming from above (top-down): top faces light, south faces
shadow.

## 4. Outline, shadow, and material language

- **Actors and interactables:** 1 px selective outline in the darkest value of
  the actor's own ramp (never pure black). Outline may drop out on the lit top
  edge.
- **World tiles and props:** no outlines; separation comes from value steps
  and the wall-top rim light.
- **Contact shadows:** optional 1–2 px tall ellipse under actors at ~40 %
  opacity of `#100D16`. No long cast shadows in v1.
- **Medieval materials:** rounded, irregular, hand-worn silhouettes; hue
  shifts toward warm in light, cool in shadow; dithering allowed only at
  16-bit-era coarseness (2×1 / 2×2 checker).
- **Relic-tech materials:** straight edges, exact repeats, emissive cores
  (lightest ramp value at the center, no outline); glitch treatment = 1–2 px
  horizontal row offsets and cyan/magenta channel-split ghosting, used
  sparingly and only near relic tech.

## 5. Native-resolution readability rules (640×360)

- Base resolution is 640×360, integer-scaled (`project.godot`); **1 texel =
  1 screen pixel**. Author and judge all art at 640×360, not zoomed.
- Sprites render at `scale = 1` only. No non-integer scaling, no rotation of
  pixel sprites (FX nodes may rotate in 90° steps; free rotation is allowed
  only for untextured/primitive FX).
- Minimum feature size 2 px; minimum text size = the 8 px UI font already used
  by the HUD.
- Every actor must read in **pure silhouette** against both the floor mid
  value and the wall dark value — verify in the reference sheet's readability
  strip before merging new actor art.
- Keep `snap_2d_transforms_to_pixel` / `snap_2d_vertices_to_pixel` on
  (already set project-wide).

## 6. Sprite grid, scale, pivots, collision alignment

- **Tile grid:** 16×16 px tiles (matches the existing graybox TileSet). Zone
  geometry, doors, and room sizes stay on this grid.
- **Frame canvases:** regular player and enemy actors use **32×32 px** frames; large elites use 48×48 px and bosses use 64×64 px or larger. This keeps the 16-bit pixel-art language while allowing enough silhouette, gear, and corruption detail for a modern action-RPG presentation. Per-asset sizes are fixed in the manifest. Canvas dimensions are even numbers so centered sprites land on the pixel grid.
- **Pivot convention:** all `Sprite2D` / `AnimatedSprite2D` use
  `centered = true`, `offset = (0, 0)`, and the **frame center aligns with the
  collision-shape center**. Where a collision shape is locally offset (the
  player capsule sits at `(0, 2)`), the sprite node takes the same local
  position. Existing collision shapes are canonical; art conforms to
  collision, never the reverse.
- **Overhang:** visuals may exceed their collision shape by ≤ 3 px per side,
  and by more only **upward** (e.g., checkpoint shrine, boss door arch) so
  ground contact stays honest.
- **Facing:** side-facing frames face **right**; left is `flip_h`. Up/down are
  authored frames.

## 7. Godot import settings (pixel art)

Every production texture uses these import parameters (the graybox atlas
already demonstrates them — see `graybox_tiles.png.import`):

| Parameter | Value |
|---|---|
| `compress/mode` | `0` (Lossless) |
| `mipmaps/generate` | `false` |
| `process/fix_alpha_border` | `true` |
| `process/premult_alpha` | `false` |
| `detect_3d/compress_to` | keep default; never convert |

Texture filtering must be **Nearest**. Until a dedicated ticket flips the
project default (`rendering/textures/canvas_textures/default_texture_filter`),
set `texture_filter = 1` (Nearest) on the node that displays the texture, as
`zone1_graybox.tscn` does for its `TileMapLayer`.

Source files: PNG only for production sprites (SVG remains test-only). No
paid or unlicensed assets (AGENTS.md §11); provenance rules are in the
manifest §3.

## 8. Animation naming and loop conventions

`SpriteFrames` animation names are `snake_case`:
`<action>[_<facing>]` with facings `down`, `up`, `side`.

| Animation | Loop | FPS | Notes |
|---|---|---|---|
| `idle_*` | loop | 6 | Subtle 2–4 frame breathing/bob. |
| `walk_*` | loop | 10 | |
| `dash_*` | one-shot | 12 | Player only in v1. |
| `attack_melee_*` | one-shot | 12 | Contact frame flagged in the frame count column of the manifest. |
| `attack_relic_*` | one-shot | 12 | |
| `windup` | one-shot | 8 | Enemy telegraph; tinted toward `#FFC72E`. |
| `hurt` | one-shot | 12 | |
| `death` | one-shot | 10 | Holds last frame; ends within death tint `#383842`. |

Non-actor loops (checkpoint lit, relic glow, corruption shimmer) are 4-frame
loops at 6 fps unless the manifest says otherwise. Frame counts per asset are
fixed in the manifest.

## 9. Production vs graybox

Programmatic placeholder visuals (`Polygon2D` bodies, flat tiles, default
Control theming) are **graybox** and remain untouched until a focused
follow-up issue replaces each one citing this bible. The manifest (§4 there)
lists exactly which assets are production targets and which existing files
are retained test assets.
