# Asset Manifest — v1 Vertical Slice (Stylized HD 2D Migration)

> **Status:** Canonical migration manifest for the v1 slice (issue #139).
> Pairs with [`visual_bible.md`](visual_bible.md), which owns the visual
> language and readability rules. Existing pixel assets are playable legacy
> content; they are not the target contract for new production art.

## 1. Migration rules

- The project is moving from 16-bit pixel art to **stylized HD 2D
  illustration**. Do not create new production assets to the former 16×16 tile,
  32×32 actor-frame, nearest-filter, or integer-pixel presentation contract.
- Existing production scenes and textures remain functional until a focused
  conversion PR replaces them. No migration issue may combine a visual refresh
  with changes to collision, navigation, spawns, encounter rules, combat,
  save/load, or scene-flow behavior.
- The one-screen HD prototype is the required dependency for all replacement
  passes. It establishes exact asset dimensions, texture/import settings,
  camera/zoom presentation, animation approach, performance budget, and Web
  export budget. Conversion issues use those decisions rather than inventing
  their own values.
- One asset group per issue/PR. Asset rows are planning contracts, not claims
  that a file already exists.

## 2. Required prototype

### 2.1 One-screen HD visual prototype

| Deliverable | Required proof |
|---|---|
| Representative Zone 1 encounter screen | Walkable forest environment, player, one enemy, a checkpoint or pickup, relic corruption, and HUD in the intended HD 2D language. |
| Gameplay preservation | Existing scene flow, collision, interaction, enemy behavior, combat, save state, and controls remain unchanged. |
| Readability | Actual-size player/enemy/interactable/telegraph reads against floor and wall; no visual props obscure routes or collision intent. |
| Technical contract | Document source dimensions, art composition method, filtering/import settings, camera/zoom, animation workflow, draw/performance cost, and Web export size/load evidence. |
| Provenance | Every prototype source asset has a documented author/tool/license path. |

The prototype does **not** authorize a bulk replacement. Its outcome updates
this manifest and opens the conversion issues below.

### 2.2 Measured prototype decisions (issue #141)

The Zone 1 entrance → encounter-room-A route now runs the HD presentation
prototype via the zone-local `Zone1HdPresentation` helper. The rows below are
**measured prototype decisions** (observed working in the integrated route
and its test suite) that conversion issues may start from; they are not the
complete final HD technical contract — see the follow-up list after the
table:

| Decision | Measured value |
|---|---|
| Environment source | 1024×576 wide painted plate (`assets/sprites/hd_prototype/encounter_room_background.png`, the recomposed v2 environment-only plate with **no baked affordances** — no shrine/gate/pickup/characters; the first plate was rejected in review for a false shrine affordance), uniformly scaled 5/6 to the 480 px zone height and region-cropped so its seam lands on the room B doorway. Legacy display props and the exit-gate marker polygon under the plate are hidden; interact Areas, prompts, and collision are untouched. |
| Actor sources | Chroma-key-extracted transparent PNGs at native size: player 180×274, melee chaser 162×286, checkpoint shrine 249×330; scaled per-node to the legacy play-size footprint (34/30/44 px tall). |
| Filtering | Per-node `TEXTURE_FILTER_LINEAR` on HD nodes only; project default filter, snapping, and legacy nearest nodes unchanged. |
| Camera | Existing 2× camera retained. |
| Art state | Static single-pose prototype illustrations; mechanical state (facing, hit/invuln/death feedback, enemy state, shrine lit) mirrored from the hidden legacy display drivers — no fake animation. |
| Provenance | LemonadeAI / `Flux-2-Klein-9B-GGUF`, `flux-non-commercial-license` — **prototype-only, non-commercial, not CC0**; rows in `assets/sprites/LICENSES.md`. Production conversion art requires a compatible license. |

Measured Web bundle size with the prototype assets included (release
no-threads export via `tools/build_web.sh`, passing `tools/smoke_check_web.sh`):
`index.wasm` 39,509,339 bytes (≈37.7 MiB), `index.pck` 6,227,072 bytes
(≈5.9 MiB). This is size evidence only — no browser load-time or frame-time
was measured.

The remaining prototype follow-ups are now governed by the production contract
in [`visual_bible.md` §7.1](visual_bible.md#71-production-hd-technical-art-contract-issue-149).
It fixes the canonical canvas/safe-frame behavior, per-node filtering,
texture-import defaults, animation/state ownership, Web-bundle guardrails, and
a repeatable Chromium-emulation evidence method. Headless/emulated timing is
not a substitute for physical-device performance measurement: focused art PRs
that materially increase PCK size or draw cost still require an authenticated
phone smoke test before merge.

## 3. Planned conversion groups

### 3.1 Player presentation

| Group | Scope | Non-goals |
|---|---|---|
| Player HD presentation | Implemented in issue #150; body source upgraded in issue #165: a 1024×256 four-cell directional atlas (`assets/sprites/player/hd/player_directional_atlas.png`, 256×256 cells with a 190 px content box, north/east/south/west at columns 0–3, west authored as a baked mirror of the side pose — never a runtime flip) selected by `PlayerHdPresentation` from the live `PlayerVisual.facing_label`, shown at a 42 px display-height contract with presentation-only bob/lean gait, plus the retained directional cyan facing accent (magenta during dash/melee/relic) as a supporting cue and contact shadow. | Movement, dash/melee/relic timing, hitboxes/hurtboxes, stats, saves, or player collision. |
| Hub environment presentation | Implemented in issue #151: 1024×576 environment-only illustrated settlement plate, region-cropped/scaled by `HubHdPresentation` over the existing collision TileMapLayer. | Hub bounds/tile collision, spawn, checkpoint, skill-tree station, gate sensor/transition, camera, saves, or input behavior. |

### 3.2 Enemies and boss

| Group | Scope | Non-goals |
|---|---|---|
| Regular enemy roster | **Production conversion in issue #154:** four distinct transparent illustrated bodies under `assets/sprites/enemies/hd/`; scene-local adapters mirror live facing, telegraph, hit, death, and shield state while legacy SpriteFrames remain hidden mechanical drivers. | AI, attacks, damage, ranges, collision, rewards, or encounter composition. |
| Zone boss | Illustrated boss body, phase/readability cues, arena-facing presentation, and boss-specific FX. | Boss logic, phase thresholds, rewards, arena collision, or progression. |

### 3.3 Zone 1 environment and interactables

| Group | Scope | Non-goals |
|---|---|---|
| Corrupted-forest environment | Floors, walls, foliage, ruins, relic corruption, route framing, and set dressing. | Tile/collision layout, camera bounds, secret route geometry, enemy placement, or room logic. |
| Interactables | **Production conversion in issue #153:** six distinct transparent illustrated assets under `assets/sprites/world/hd/interactables/`; each display is parented to its live checkpoint, gate sensor, pickup, station, hidden-room trigger, or boss-door body. Dormant/lit, nearby, collected, screen-open, revealed, and sealed/open presentation follows the existing mechanical signals and state. | Area2D contracts, reward values, save behavior, transition logic, secret geometry, or boss-door collision. |

Issue #153 uses explicit display-height/offset contracts at the shipped 2×
camera: checkpoint 44 px, travel gate 54 px, pickup 24 px, station 52 px,
secret-reveal pulse 48 px, and boss door 88 px. The neutral gate and station
reserve cyan, the checkpoint changes from a dim neutral state to restoration
green/white, pickups and reveal feedback use cyan, and the sealed boss door
uses threat-side magenta. Legacy polygons remain hidden in the tree where
their owning scene previously used them; collision shapes and sensors are
unchanged. All six PNG imports are lossless, unmipmapped, unpremultiplied-alpha
textures with alpha-border correction, and every live Sprite2D filters
linearly per node.

Issue #152 has begun the production environment extension with
`assets/sprites/world/hd/zone1_rooms_b_c.png`, a 1024×576 environment-only
plate covering the named room-B → room-C route at the contract 5/6 scale. It
adds no baked actors, interactables, gates, shrines, pickups, or hazards; live
scene nodes and secret-reveal covers remain above the presentation layer. The
boss corridor, boss approach, and arena remain on the legacy environment layer
until the next focused plate lands, so this row does not yet mark the full
Zone 1 environment group complete.

### 3.4 UI and combat FX

| Group | Scope | Non-goals |
|---|---|---|
| UI skin and typography | **Production conversion in issue #156:** shared dark iron/stone material theme, semantic HP/energy and skill-state colors, eight illustrated HD emblems, larger typography, focus treatment, and readable desktop/mobile-landscape HUD, prompts, pause, skill tree, and touch controls. | UI layout behavior, skill costs, input flow, pause behavior, mobile input ownership, or save state. |
| Combat and relic FX | Attacks, impacts, dash/relic feedback, projectiles, enemy telegraphs, and death presentation. **Starter relic orb converted in issue #169:** deterministic CC0 stylized-HD sheet (`assets/sprites/fx/relic_orb_fx.png` from `assets/sprites/generate_relic_orb_fx.py`) drives a cast-origin flare, a collision-truthful flight orb/trail rotated to the exact launch angle, and an impact burst — all spawned from the existing `EnergyBolt`/`PlayerController` signals with per-node linear filtering; the legacy `fx/energy_bolt.png` sheet is retired. Melee/dash/dissolve feedback and enemy telegraphs remain legacy pending their own pass. | Damage, hitboxes/hurtboxes, hitstop, timing, AI, or time-scale ownership. |

Issue #154 desktop Web evidence used the production `1280×720` canvas and the
real Zone 1 route. All four bodies remained distinct at the shipped 2× camera;
the ranged mask/relic, brute shield, flanker limbs, and chaser quadruped profile
read without changing their collision footprints. The release/no-threads Web
export kept `index.wasm` at 39,509,339 bytes and produced a 6,712,544-byte PCK,
a +475,136-byte delta from the issue #149 baseline — below the 2 MiB review
threshold. Browser console inspection reported no warnings or errors.

Issue #153 browser evidence covered the live Hub and the real Zone 1 scene at
the production `1280×720` canvas. The checkpoint, travel gate, skill station,
pickup, and route-facing state cues remained distinct against both the Hub
graybox and the accepted forest background at the shipped 2× camera; the
browser console reported no warnings or errors. The release/no-threads export
kept `index.wasm` at 39,509,339 bytes and produced an 8,095,056-byte PCK after
merging the issue #152 environment extension, a +364,220-byte delta from that
7,730,836-byte `main` baseline and below the 2 MiB physical-device-review
threshold.

Issue #156 browser evidence covered the live HUD and pause overlay at
`1280×720`, the standalone skill tree at the same canvas, and forced touch
controls in the production Android-landscape `915×412` viewport. Resource
labels, focus outlines, semantic colors, and all eight emblems remained within
their panels and controls; the browser console reported no warnings or errors.
The release/no-threads export kept `index.wasm` at 39,509,339 bytes and produced
a 7,028,548-byte PCK, a +316,004-byte delta from issue #154 and below the 2 MiB
physical-device-review threshold.

Issue #165 replaced the static HD player body with the four-cell directional
atlas described in §3.1. Godot 4.7 headless import, the focused player/Zone 1
presentation tests, and the full GUT suite (481 tests) all passed, and the
release/no-threads Web export passed `tools/smoke_check_web.sh`. The export
kept `index.wasm` at 39,509,339 bytes and produced a 9,021,368-byte PCK, a
+92,208-byte delta from the rebuilt 8,929,160-byte `main` baseline at the same
engine version — below the 2 MiB physical-device-review threshold. Only the
runtime atlas ships; the raw generation source sheets were not committed
(JSON prompt metadata is retained at `assets/reference/hd_player_animation/`),
so the all-resources export packages no unused reference PNGs.

## 4. Legacy inventory

The following are retained during migration and may be replaced only by their
focused group issue after prototype decisions land:

| Legacy group | Current location | Transition status |
|---|---|---|
| Player pixel sheet and SpriteFrames | `assets/sprites/player/`, `scenes/player/` | Functional legacy presentation. |
| Enemy pixel sheets and frames | `assets/sprites/enemies/`, `scenes/enemies/` | Retained as hidden state/animation drivers behind the production HD regular-enemy bodies (issue #154). |
| Zone 1 forest/properties | `assets/sprites/world/`, `scenes/world/` | Functional legacy presentation. |
| Combat/projectile sheets | `assets/sprites/fx/`, combat/player scenes | Melee/dash/dissolve feedback remains functional legacy presentation; the relic-bolt rows were replaced by the issue #169 HD sheet and `fx/energy_bolt.png` was removed. |
| Pixel-era reference sheet and test textures | `scenes/reference/`, `assets/sprites/testing/` | Retained until HD readability/reference coverage replaces their role. |
| Pixel UI defaults | UI scenes and `assets/fonts/` | Functional legacy presentation. |

## 5. Provenance and license requirements

Every binary asset PR records, in `assets/sprites/LICENSES.md` or the relevant
license log:

- **Hand-authored:** author, created-for-repository statement, and license
  granted (CC0 preferred).
- **Third-party:** pack/source name, exact URL, compatible license, and required
  attribution. No paid asset without team sign-off.
- **Generated:** tool, date, prompt summary, post-processing, and confirmation
  that the tool terms allow the intended use.

No arbitrary generated or external asset lands ahead of the prototype contract
or its manifest group. Each conversion PR includes its source files, Godot
metadata sidecars where applicable, structural validation, and actual-size
playtest evidence.
