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
| Player HD presentation | Implemented in issue #150; body source upgraded in issue #165: a 1024×256 four-cell directional atlas (`assets/sprites/player/hd/player_directional_atlas.png`, 256×256 cells with a 190 px content box: north/west/south/east at columns 0–3; the authored side cells are never runtime-flipped) selected by `PlayerHdPresentation` from the live `PlayerVisual.facing_label`, shown at a 42 px display-height contract with presentation-only bob/lean gait, plus the retained directional cyan facing accent (magenta during dash/melee/relic) as a supporting cue and contact shadow. Issue #189 adds, and issue #197 corrects after live feedback, a deterministic CC0 768×1024 body melee atlas (`assets/sprites/player/hd/player_melee_body_atlas.png` from `assets/sprites/generate_hd_player_melee_body.py`): 256×256 planted wind-up/committed full-body lunge/cross-body follow-through-recovery columns × north/west/south/east rows visibly separate the legs, displace the torso, and extend the wielding arms for each equal 0.04-second segment of the existing 0.12-second melee window, returning to the held directional body exactly at that gameplay boundary. Issue #195 adds a deterministic CC0 1024×1024 dash-body atlas (`assets/sprites/player/hd/player_dash_body_atlas.png` from `assets/sprites/generate_hd_player_dash_body.py`): launch/compression/streak/recovery columns × north/west/south/east rows keep the top-down actor upright while planted legs, torso displacement, arm pump, cloak drag, and restrained rear ticks mirror four equal phases of the unchanged 0.14-second logical dash. `CombatFxSpawner` remains the sole full dash-trail owner. Issue #193 adds a deterministic CC0 768×1024 relic body atlas (`assets/sprites/player/hd/player_relic_body_atlas.png` from `assets/sprites/generate_hd_player_relic_body.py`): charge/release/recovery columns × north/west/south/east rows animate the torso and casting arm over the same existing three-frame 0.25-second `PlayerVisual` relic clip, returning to the held directional body at that clip boundary. Its small cyan/magenta hand forks are a body cue only; `CombatFxSpawner` remains the sole cast/bolt/impact owner. Issue #168 added the presentation-owned steel weapon, consolidated as the sole weapon display in issue #175 and evolved in issue #184: a deterministic CC0 1024×128 four-cell atlas (`assets/sprites/player/hd/steel_weapon_atlas.png` from `assets/sprites/generate_hd_steel_weapon.py`) shown by `PlayerWeaponHdPresentation` at a 24 px length contract with the grip pivot on the hand anchor. Idle/move/dash/relic carry the held cell at a 55° down-forward rest tilt off the live facing (mirrored on west so both side stances match); melee uses equal 0.04-second wind-up, contact, and recovery cells across the existing 0.12-second melee state. The hand anchor stays fixed while the facing-truthful sweep starts at -75°, crosses the exact `play_melee` facing during contact, and finishes at +75° (west and its phase art mirror the same way), drawn behind the body only when facing north and hidden on death. The `CombatFxSpawner` slash stays the single complementary slash FX owner. | Movement, dash/melee/relic timing, hitboxes/hurtboxes, stats, saves, or player collision. |
Issue #203 adds `assets/sprites/player/hd/player_locomotion_response_atlas.png`, a deterministic CC0 1280×1024 sheet generated by `assets/sprites/generate_hd_player_locomotion_response.py`: three alternating gait cells, one stop/settle cell, and one braced hurt-recoil cell across north/west/south/east rows. `PlayerHdPresentation` selects it only while the live `PlayerVisual` reports move or hurt; movement, health, invulnerability, respawn, collision, and input ownership remain unchanged.

| Hub environment presentation | Implemented in issue #151: 1024×576 environment-only illustrated settlement plate, region-cropped/scaled by `HubHdPresentation` over the existing collision TileMapLayer. | Hub bounds/tile collision, spawn, checkpoint, skill-tree station, gate sensor/transition, camera, saves, or input behavior. |

### 3.2 Enemies and boss

| Group | Scope | Non-goals |
|---|---|---|
| Regular enemy roster | **Production conversion in issue #154:** four distinct transparent illustrated bodies under `assets/sprites/enemies/hd/`; scene-local adapters mirror live facing, telegraph, hit, death, and shield state while legacy SpriteFrames remain hidden mechanical drivers. **Issue #204 adds per-archetype deterministic 6-row × 4-column pose atlases** (`*_poses.png` in the same folder); `EnemyHdPresentation` selects the atlas row from live `EnemyBase.State` (idle/chase/windup/attack/stagger/death) and the column from `_state_elapsed` (looping for idle/chase/recovery; terminal-at-3 for non-looping states). The prior per-state transform bridge is removed when an atlas is assigned; the generator bakes those silhouette reads directly into each frame. The atlas art is a prototype art transform pipeline — deterministic closed-form derivatives of the issue #154 source portraits; a future pass will replace them with dedicated authored directional rows. | AI, attacks, damage, ranges, collision, rewards, or encounter composition. |
| Zone boss | **Production conversion in issue #155:** matched dormant/awakened illustrated Rootheart bodies, grounded contact treatment, live slam tell, eight-direction radial cue, and defeat presentation. | Boss AI, phase thresholds, attack timing, projectiles, hitboxes/hurtboxes, rewards, arena collision, boss-door behavior, camera, or progression. |

Issue #204 pose-atlas layout and generator contract: each atlas is produced by
`assets/sprites/generate_hd_enemy_pose_atlases.py` from the accepted issue #154
single-portrait source for that archetype. The generator applies deterministic
PIL transforms (translate, rotate, scale, color-enhance) to each source frame
after uniformly downsampling it to an 80 px visible content height, then
centering that content in a 128 px cell with 40 px initial horizontal padding.
It composites the result into a sheet of `padded_cell_width × 4` columns by
`128 × 6` rows, giving one compact cell per state×frame. Rows 0–5 map to
idle/chase/windup/attack/stagger/death. Columns 0–3 are frames 0–3, with each
frame expressing progressive anticipation, peak, follow-through, and return.
`EnemyHdPresentation` uses `Sprite2D.region_enabled = true` and computes the
`Rect2` from the atlas dimensions at runtime; no hardcoded archetype name or cell
size lives in the script. The atlas art carries the same OpenAI-generation
provenance as its source portraits and is a prototype transform pipeline — not
bespoke directional illustration. `EnemyHdPresentation` scales the padded atlas
from its documented 80 px visible content height so the existing display-height
contract is preserved. Directional limitation: the atlas frames are
single-facing derivatives and are never runtime-mirrored; the live facing accent
remains the truthful directional cue until dedicated authored cardinal pose rows
replace them.

Issue #155 keeps the Rootheart's existing `BossBase`/`EnemyBase` signals as
the sole state authority. A scene-local `RootheartHdPresentation` hides only
the legacy body/tell polygons, swaps the matched 96 px-tall dormant and
awakened bodies at the existing half-health threshold, mirrors wind-up/attack/
defeat colors, and removes its contact shadow on defeat. The authored slam
ring is 78 px across to match the live 40 px attack range; the 68 px radial
sigil pulses only when the existing eight-bolt phase wake or post-slam burst
fires. All four PNGs use lossless, unmipmapped, unpremultiplied-alpha imports
with alpha-border correction and per-node linear filtering. The boss's 16 px
collision radius, attack offsets, timing, burst spawning, rewards, and arena
geometry are unchanged.

Issue #155 Web evidence used the real boss arena at the production `1280×720`
canvas. The dormant body, awakened cyan/magenta core, amber slam wind-up ring,
and existing eight-direction burst all remained distinct at the shipped 2×
camera without changing their live hit areas; browser console inspection
reported no warnings or errors. Downsampling the four overspecified generation
plates to 256×256 retained actual-size detail while keeping `index.wasm` at
39,509,339 bytes and producing a 9,200,556-byte PCK, a +271,396-byte delta from
the 8,929,160-byte `main` baseline and below both Web-bundle guardrails.

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

Issue #152 began the production extension with the Room B→C plate. **Issue #179 completes the remaining boss corridor, approach, and arena** with `assets/sprites/world/hd/zone1_boss_route.png`: an environment-only 1024×576 LemonadeAI / Flux-2-Klein-9B plate, uniformly scaled 5/6 and region-cropped so its reviewed left/center source area exactly covers the 464×480 tile-backed boss route. The boss, production boss door, collision, sensors, camera, and reward remain separate live nodes; the legacy boss-approach prop is hidden only as doubled presentation.

### 3.4 UI and combat FX

| Group | Scope | Non-goals |
|---|---|---|
| UI skin and typography | **Production conversion in issue #156:** shared dark iron/stone material theme, semantic HP/energy and skill-state colors, eight illustrated HD emblems, larger typography, focus treatment, and readable desktop/mobile-landscape HUD, prompts, pause, skill tree, and touch controls. | UI layout behavior, skill costs, input flow, pause behavior, mobile input ownership, or save state. |
| Combat and relic FX | Attacks, impacts, dash/relic feedback, projectiles, enemy telegraphs, and death presentation. **Starter relic orb converted in issue #169, refined for gameplay-scale readability in issue #185, then corrected in issue #196 after live feedback still read the knot/impact as an orb:** deterministic CC0 stylized-HD lightning sheet (`assets/sprites/fx/relic_lightning_fx.png` from `assets/sprites/generate_relic_lightning_fx.py`) drives an angular cast fork with crossed spark origin, a collision-truthful thin jagged shaft with an elongated +x-authored tip and no filled knot, and a forward-weighted electrical slash/fork impact with cyan/magenta fragments, all rotated to the exact eight-direction launch angle and spawned from the existing `EnergyBolt`/`PlayerController` signals with per-node linear filtering; the retired `fx/relic_orb_fx.png` sheet is not shipped. Melee readability upgraded in issue #168 by the HD steel weapon sweep (§3.1). **Combat feedback FX and enemy telegraphs converted in issue #157:** the melee slash, hit spark, dash trail, and death dissolve read from a deterministic CC0 stylized-HD sheet (`assets/sprites/fx/combat_fx_hd.png` from `assets/sprites/generate_combat_fx_hd.py`) with per-node linear filtering, spawned from the same `CombatFeedback`/`PlayerController` signals; the legacy `fx/combat_fx.png` sheet is retired. Regular-enemy wind-up telegraphs (fast flanker, ranged harasser, shielded brute) use the HD `assets/sprites/enemies/hd/enemy_windup_tell.png` warm hazard aura, shown behind the actor by the existing `EnemyBase` WIND_UP visibility. | Damage, hitboxes/hurtboxes, hitstop, timing, AI, or time-scale ownership. |

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

Issue #168 added the presentation-owned HD steel weapon described in §3.1.
Issue #184 evolves it into an explicit, hand-anchored wind-up → contact →
recovery presentation over the unchanged 0.12-second melee state: the
four-cell CC0 atlas selects phase-specific anticipation, impact, and
follow-through art while the same hand anchor and facing-truthful rotation are
maintained for all four facings. This remains display-only; PlayerMeleeAttack,
hitboxes, damage, hitstop, collision, and action timing are untouched.

The issue #168 deterministic generator produced byte-identical output across reruns
(MD5 `b6d5401ddcc13d3023223eb0f42bd324`), Godot 4.7 headless import left the
worktree clean, the focused weapon-presentation tests (9 tests) and the full
GUT suite (497 tests) passed, and the release/no-threads Web export passed
`tools/smoke_check_web.sh`. The export kept `index.wasm` at 39,509,339 bytes
and produced a 4,348,172-byte PCK, a +10,364-byte delta from the
4,337,808-byte pre-change baseline rebuilt with the identical method at the
same commit and engine version — far below the 2 MiB physical-device-review
threshold. (Baseline and result were measured as a same-machine pair; earlier
issues' absolute PCK numbers came from other environments and are not directly
comparable.)

## 4. Legacy inventory

The following are retained during migration and may be replaced only by their
focused group issue after prototype decisions land:

| Legacy group | Current location | Transition status |
|---|---|---|
| Player pixel sheet and SpriteFrames | `assets/sprites/player/`, `scenes/player/` | Functional legacy presentation. |
| Enemy pixel sheets and frames | `assets/sprites/enemies/`, `scenes/enemies/` | Retained as hidden state/animation drivers behind the production HD regular-enemy bodies (issue #154). |
| Zone 1 forest/properties | `assets/sprites/world/`, `scenes/world/` | Functional legacy presentation. |
| Combat/projectile sheets | `assets/sprites/fx/`, combat/player/enemy scenes | Melee slash, hit spark, dash trail, and death dissolve converted to the HD `fx/combat_fx_hd.png` sheet in issue #157 (`fx/combat_fx.png` removed); relic-bolt rows replaced by the issue #169 HD sheet (`fx/energy_bolt.png` removed); regular-enemy wind-up tells converted to `enemies/hd/enemy_windup_tell.png`. |
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
