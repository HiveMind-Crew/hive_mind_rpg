# Asset Manifest — v1 Vertical Slice

> **Status:** Canonical for the v1 slice (issue #82). Pairs with
> [`visual_bible.md`](visual_bible.md), which owns palette, grid, pivot,
> import, and animation rules. Sprite/tileset tasks implement rows from this
> table; they do not invent new dimensions, paths, or naming.

## 1. Conventions

- Paths are the **target** location under `assets/`; a row's asset does not
  exist yet unless marked retained in §4.
- "Frame size" is the per-frame canvas (bible §6). "Frames" lists animation ×
  frame count using the bible §8 names.
- **Source / license** is `TBD` until the asset lands. The implementing PR
  must fill it in `assets/sprites/LICENSES.md` (create on first binary,
  following the `assets/audio/LICENSES.md` pattern) — see §3.
- One follow-up issue per row-group (player, enemies, world, FX, UI); do not
  bundle all art into one PR.

## 2. Production assets (to be created)

### 2.1 Actors

| Asset | Target path | Frame size | Frames | Role | Source / license |
|---|---|---|---|---|---|
| Player sheet | `assets/sprites/player/player.png` (+ `player_frames.tres`) | 24×24 | idle 4, walk 6, dash 4, attack_melee 4 (contact f3), attack_relic 3, hurt 2, death 6 — idle/walk/dash/attacks × 3 facings | Replaces `Polygon2D` body in `player.tscn`; teal identity ramp, magenta accent | TBD |
| Melee chaser sheet | `assets/sprites/enemies/melee_chaser.png` (+ `melee_chaser_frames.tres`) | 24×24 | idle 4, walk 6, windup 3, attack_melee 3 (contact f2), hurt 2, death 5 — idle/walk × 3 facings | Replaces `BodyVisual`/`TellVisual` in `melee_chaser.tscn`; violet ramp, windup keyed `#FFC72E` | TBD |

Additional v1 enemy types (DESIGN.md §8 calls for 3–4) and the Zone 1 boss get
manifest rows in their own design issues before art starts; they inherit the
24×24 (regular) / 48×48 (boss) canvases and violet identity ramp.

### 2.2 World & interactables

| Asset | Target path | Frame size | Frames | Role | Source / license |
|---|---|---|---|---|---|
| Zone 1 forest tileset | `assets/sprites/world/zone1_forest_tiles.png` | 16×16 tiles, atlas ≤ 160×160 | static; corruption shimmer tiles 2 × 4-frame loops | Floor (moss/soil/root, ≥ 6 variants), walls (≥ 8), edges/transitions (≥ 12), corruption vein overlays (≥ 4). Replaces `graybox_tiles.png` in Zone 1 | TBD |
| Zone 1 props | `assets/sprites/world/zone1_props.png` | trees 32×48, relic machinery 32×32, stones/stumps 16×16 | machinery glow 4-frame loop; rest static | Set dressing for encounter rooms and secrets; machinery is the only cyan-emissive world element | TBD |
| Checkpoint shrine | `assets/sprites/world/checkpoint_shrine.png` | 24×32 (upward overhang over 24×24 shape) | idle_dormant 4 loop, activate 6, idle_lit 4 loop | Replaces `Visual` in `checkpoint.tscn`; stone ramp dormant, `#80F2B8` lit | TBD |
| Skill-point pickup | `assets/sprites/world/skill_point_pickup.png` | 16×16 | hover 6 loop, collect 5 | Replaces `Visual` in `skill_point_pickup.tscn`; relic-cyan emissive | TBD |
| Boss door | `assets/sprites/world/boss_door.png` | 32×96 (over 16×80 collision) | sealed 4 loop, open 8 | Replaces boss door `Polygon2D` in `zone1_graybox.tscn`; corruption-magenta seal | TBD |

### 2.3 Combat FX

| Asset | Target path | Frame size | Frames | Role | Source / license |
|---|---|---|---|---|---|
| Energy bolt | `assets/sprites/fx/energy_bolt.png` | flight 8×8, impact 16×16 | flight 4 loop, impact 5 | Replaces `Visual` in `energy_bolt.tscn`; relic cyan `#4DE5FF` core | TBD |
| Combat FX sheet | `assets/sprites/fx/combat_fx.png` | slash 32×32, spark 16×16, dash trail 24×24, dissolve 24×24 | melee slash 4, hit spark 4, dash trail 3, death dissolve 6 | Shared player/enemy impact FX; tinted per attack family (bible §2.4) | TBD |

### 2.4 UI

| Asset | Target path | Frame size | Frames | Role | Source / license |
|---|---|---|---|---|---|
| HUD skin | `assets/sprites/ui/hud_skin.png` | panel 24×24 nine-slice (4 px border), bar back/fill 8×8 nine-slice, HP/energy icons 8×8 | static | Themes `player_hud.tscn` panel and bars; `#171721` panel, `#FFB8B8`/`#8CE5FF` fills | TBD |
| Skill-tree node frames | `assets/sprites/ui/skill_node_frames.png` | 20×20 × 3 states | static (locked / available / unlocked) | Themes `skill_node_button.tscn`; state colors from `skill_node_button.gd` | TBD |
| Skill icons | `assets/sprites/ui/skill_icons.png` | 16×16 × 15 | static | One icon per v1 skill node (12–15 nodes, DESIGN.md §8) | TBD |
| Pixel UI font | `assets/fonts/<name>.ttf` or `.png` bitmap | 8 px line height | — | Replaces default font at HUD sizes; must be CC0/OFL | TBD |

## 3. Provenance & license requirements

Per AGENTS.md §11, every binary asset PR must record, in
`assets/sprites/LICENSES.md`:

- **Hand-made:** author + "created for this repo", license granted (CC0
  preferred).
- **Third-party pack:** pack name, exact URL, license (CC0/CC-BY/OFL only;
  CC-BY attribution text included). No paid assets without team sign-off.
- **AI-generated:** tool + date, prompt summary, post-processing done, and
  confirmation the tool's terms permit CC0-equivalent use. Arbitrary
  generated art may not land ahead of its manifest row.

## 4. Retained graybox / test assets (not production)

| Asset | Path | Status |
|---|---|---|
| Graybox tile atlas | `assets/sprites/testing/graybox_tiles.png` | Retained for graybox scenes/tests until the Zone 1 tileset row lands; then testing-only. |
| Pixel-scale test SVG | `assets/sprites/testing/pixel_scale_test.svg` | Retained, test-only; never referenced by production scenes. |
| Placeholder audio | `assets/audio/*.wav` | Out of scope here; tracked by the audio pipeline (issue #25, `assets/audio/LICENSES.md`). |
| `Polygon2D` / default-Control visuals | in `scenes/**` (not files) | Graybox placeholders; each is replaced only by its manifest row's follow-up issue. |

## 5. Reference assets

| Asset | Path | Status |
|---|---|---|
| Visual reference sheet (scene) | `scenes/reference/visual_reference_sheet.tscn` | Exists; F6-runnable palette + 640×360 readability proof. Godot-native primitives only, no textures. |
| Mood/reference sheets | `assets/reference/` | Optional future collection point (DESIGN.md §10); every dropped image needs a source/license line in `assets/reference/README.md`. |
