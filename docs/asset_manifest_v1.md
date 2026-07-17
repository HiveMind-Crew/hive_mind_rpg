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

## 3. Planned conversion groups

### 3.1 Player presentation

| Group | Scope | Non-goals |
|---|---|---|
| Player HD presentation | Illustrated player body, directional movement/action states, readable facing cue, contact shadow, and presentation integration. | Movement, dash/melee/relic timing, hitboxes/hurtboxes, stats, saves, or player collision. |

### 3.2 Enemies and boss

| Group | Scope | Non-goals |
|---|---|---|
| Regular enemy roster | Distinct illustrated identities, directional/telegraph/death presentation, and readability validation for each v1 enemy. | AI, attacks, damage, ranges, collision, rewards, or encounter composition. |
| Zone boss | Illustrated boss body, phase/readability cues, arena-facing presentation, and boss-specific FX. | Boss logic, phase thresholds, rewards, arena collision, or progression. |

### 3.3 Zone 1 environment and interactables

| Group | Scope | Non-goals |
|---|---|---|
| Corrupted-forest environment | Floors, walls, foliage, ruins, relic corruption, route framing, and set dressing. | Tile/collision layout, camera bounds, secret route geometry, enemy placement, or room logic. |
| Interactables | Checkpoints, gates, pickups, boss door, secret reveals, and associated affordance feedback. | Area2D contracts, reward values, save behavior, or transition logic. |

### 3.4 UI and combat FX

| Group | Scope | Non-goals |
|---|---|---|
| UI skin and typography | HUD, skill tree, prompts, panels, icons, and accessibility/readability treatment. | UI layout behavior, skill costs, input flow, pause behavior, or save state. |
| Combat and relic FX | Attacks, impacts, dash/relic feedback, projectiles, enemy telegraphs, and death presentation. | Damage, hitboxes/hurtboxes, hitstop, timing, AI, or time-scale ownership. |

## 4. Legacy inventory

The following are retained during migration and may be replaced only by their
focused group issue after prototype decisions land:

| Legacy group | Current location | Transition status |
|---|---|---|
| Player pixel sheet and SpriteFrames | `assets/sprites/player/`, `scenes/player/` | Functional legacy presentation. |
| Enemy pixel sheets and frames | `assets/sprites/enemies/`, `scenes/enemies/` | Functional legacy presentation. |
| Zone 1 forest/properties | `assets/sprites/world/`, `scenes/world/` | Functional legacy presentation. |
| Combat/projectile sheets | `assets/sprites/fx/`, combat/player scenes | Functional legacy presentation. |
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
