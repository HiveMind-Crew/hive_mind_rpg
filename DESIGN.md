# hive_mind_rpg — Game Design Document

> **Status:** Draft v0.3 — core decisions locked through 2026-07-11.
> **Engine:** Godot 4.7 stable (2D) · **Language:** GDScript
> **Repo:** https://github.com/MeanGreen256/hive_mind_rpg
> Note: "hive_mind" is the **team/repo name**, not a game mechanic. Working title for the game itself: `[TBD]`.

---

## 1. High Concept

**One-liner:** A top-down real-time action RPG set in a surreal medieval world haunted by sci-fi magic — build your fighter through a branching skill tree that spans honest steel and reality-bending relic tech.

**Core fantasy:** You are a lone combatant who grows from scrappy survivor into a build of your own design — every unlocked ability visibly changes how you fight.

| Field | Value |
|---|---|
| Genre | Top-down real-time action RPG (Zelda-like combat, build-driven) |
| Perspective | Top-down |
| Art style | Stylized HD 2D illustration — painterly medieval materials, clean high-contrast silhouettes, soft authored lighting, cyan/magenta relic-tech emissives (pivoted from 16-bit pixel art, issue #139) |
| Tone | Weird / surreal — a medieval world where sci-fi "magic" makes things subtly wrong |
| Reference points | Hyper Light Drifter (tech-as-magic mood), 2D Zelda (combat feel), CrossCode (build depth in top-down 2D) |
| Target session length | 20–40 min play sessions |
| v1 scope | Tiny vertical slice: hub + 1 zone + 1 boss |

---

## 2. Pillars (in priority order)

Every feature must serve at least one pillar. When pillars conflict, higher wins.

1. **Combat depth & builds** — real-time combat with meaningful player choice. The skill tree is the game's spine; two players should end the game fighting *differently*.
2. **Exploration & secrets** — zones reward poking at the edges: hidden rooms, optional relics, skill points off the beaten path.
3. **Weird vibes & atmosphere** — the surreal science-fantasy setting is delivered through environment, enemy design, and audio — not exposition.
4. **Story & characters** — minimal and environmental. Story exists to justify the weirdness, never to interrupt the combat loop.

---

## 3. Core Gameplay Loop

### Moment-to-moment (seconds)
Move → read enemy → dodge/position → attack (melee or tech-magic) → manage resources (HP / energy) → loot the aftermath.

### Session loop (minutes)
Leave hub → push into a zone → fight through encounters, find secrets & skill points → reach checkpoint or die back to one → return to hub → spend points on the skill tree → feel stronger → push further.

### Meta loop (hours)
Unlock skill tree branches → develop a distinct build → clear zone boss → open next themed zone → deeper tree tiers + stranger tech-magic → final boss.

**The loop's engine:** skill points are the primary reward currency. Combat drops them, exploration hides them, bosses gate the tree's deeper tiers.

---

## 4. Player Character & Progression

- **Who:** A silent (or near-silent) wanderer in a medieval realm where crashed/buried sci-fi relics are treated as sorcery. `[Backstory TBD — keep thin]`
- **Core stats:** HP, Energy (passively regenerates and fuels tech-magic abilities), Attack, Speed. Keep the stat sheet small — depth lives in abilities, not numbers.
- **Progression model:** Skill tree with three branches (working names):
  - **Steel** — melee: combos, parry, charged strikes, mobility attacks
  - **Relic** — tech-magic: projectiles, area bursts, weird utility (short teleport, time-stutter, gravity pulse)
  - **Body** — shared/passive: HP, energy, dodge upgrades, resource efficiency
- **Hybrid by design:** No classes. Players mix branches freely; respec available at the hub (cheap or free — encourage experimentation).
- **Skill points come from:** combat milestones, exploration secrets, boss kills.

## 5. Combat & Encounters

- **Style:** Real-time action with free-angle top-down movement. Relic abilities aim in a fixed 8 directions. Dodge roll/dash has i-frames from the start.
- **Energy:** Regenerates passively. Exact capacity, regeneration rate, and ability costs are tuning values rather than separate progression rules.
- **Baseline kit (pre-tree):** basic melee swing, dash, one starter relic ability — the tree expands from this.
- **Combat readability:** Accepted hits use short, attack-family-colored flashes; invulnerability pulses visibly; defeated actors retain a clear death tint. These replaceable presentation effects use real-time visual clocks and never control global time scale. Defeated enemies are pass-through: remains keep their death presentation but never block a route or trap the player.
- **Enemy design philosophy:** Few enemy types, each with a readable tell and a distinct counter. Encounters are hand-placed combinations, not random mobs. Surreal designs (wrong geometry, glitching knights, machine-fauna) serve pillar 3.
- **Difficulty & death:** Moderate. Death respawns you at the last checkpoint (shrine/beacon). No XP/currency loss; enemies in the area reset. Checkpoints are placed generously enough that retries stay fun.
- **Bosses:** Each zone ends in a boss that tests that zone's lesson and pays out a large skill-point reward + unlocks a new tree tier.

---

## 6. World & Narrative

- **Setting:** A medieval world built on (or after) something science-fictional. Peasants, castles, and forests — but ancient machinery hums under the soil, "wizards" are relic-handlers, and the deeper you go the less the world obeys medieval logic.
- **Story premise:** `[TBD — one paragraph max. Suggested seed: something buried is waking up, and the zones are its symptoms.]`
- **World structure:** Hub + themed zones.
  - **Hub:** safe settlement — skill tree/respec, checkpoint, a few flavor NPCs, gates to zones.
  - **Zones:** hand-built themed areas (v1: one zone), each with its own enemy set, secrets, checkpoint(s), and boss.
  - **Zone 1:** corrupted forest — an overgrown woodland warped by buried relic machinery, where familiar paths are disrupted by glitching geometry and unnatural growth.
- **Dialogue:** Minimal. Short NPC barks and item descriptions carry lore (pillar 4 is lowest priority). No branching dialogue system in v1.

---

## 7. Systems

| System | Priority | Notes |
|---|---|---|
| Movement & collision | P0 | 8-dir/free-angle, dash with i-frames |
| Real-time combat | P0 | Melee + ranged relic abilities, hitboxes/hurtboxes, enemy AI |
| Skill tree | P0 | 3 branches; data-driven (each node a `.tres` Resource) |
| Checkpoint & respawn | P0 | Shrine/beacon checkpoints; enemy reset on death |
| Save/load | P0 | Persist tree, position/checkpoint, collected secrets |
| Enemy encounters | P0 | Hand-placed spawns per zone |
| Boss framework | P0 | Phase-based boss scenes |
| HUD & menus | P0 | HP/energy bars, skill tree UI, pause |
| Secrets/collectibles | P1 | Hidden rooms, skill-point pickups |
| Audio | P1 | Surreal ambient + combat SFX |
| NPC barks | P2 | Simple interaction, no dialogue trees in v1 |

---

## 8. Scope — v1 Vertical Slice

**Goal:** Prove the core loop — *fight → earn points → build → fight better* — is fun.

### Must-have (P0)
- Hub area with skill tree station, respec, and zone gate
- **1 themed zone** with ~3 hand-placed encounter rooms, 1–2 checkpoints, and at least 2 secrets
- **1 boss** with 2 phases
- **3–4 enemy types** with distinct tells/counters
- Skill tree with **~12–15 nodes** across the three branches (enough for 2 clearly different builds)
- Player kit: melee, dash, 1 starter relic ability + tree-unlocked abilities
- Checkpoint respawn + save/load
- Functional HUD (HP, energy, skill tree screen)

### Nice-to-have (P1)
- 2–3 flavor NPCs in the hub
- Ambient audio pass + basic SFX
- Controller support polish (Godot gives most of this free)

### Explicit non-goals for v1
- Multiplayer — never for this project unless re-scoped
- Procedural generation — zones are hand-built
- Dialogue trees / quest log — barks only
- Inventory & equipment system — builds come from the tree, not gear (revisit post-slice)
- Multiple zones, towns, or overworld map
- Cutscenes, voice acting, localization

---

## 9. Technical Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Engine | Godot 4.7 stable | Free, open-source, strong 2D tooling, AI-friendly GDScript; the supported project version |
| Language | GDScript, statically typed | Fast iteration; conventions in AGENTS.md |
| Base resolution | 1280×720, fractional-scaled with aspect `keep`; world camera currently zoomed 2× | **HD 2D presentation contract (issue #139):** all art readability is authored and judged against the 1280×720 output. Fractional scaling fills or letterbox-centers any window (issue #125). The 2× world camera zoom is the shipped configuration for the legacy pixel assets; no new camera zoom, source texture size, or filtering configuration is declared until the one-screen HD prototype provides evidence |
| Pixel snapping | Enabled (2D pixel snap) — legacy, retained during migration | The shipped pixel assets need snapping to avoid shimmer; the setting stays unchanged until the HD prototype demonstrates the replacement presentation |
| Tilemaps | Godot TileMapLayer | Native, well-documented |
| Content data | Custom Resources (`.tres`) | Type-safe in-editor editing for skills/enemies; diffs OK in git |
| Combat architecture | Hitbox/Hurtbox component scenes + state-machine actors | Composable across player/enemies (see AGENTS.md §5) |
| Energy regeneration | Passive | Keeps relic abilities available without requiring melee attacks to recharge them |
| Relic aiming | Fixed 8-direction | Predictable aiming that fits the top-down combat presentation; unchanged by the art pivot |
| Skill tree data | One Resource per node (id, branch, cost, prereqs, effect) | Agents can add nodes without touching UI code |
| Skill effect availability | A node is purchasable only when its effect has a registered live consumer | Players never spend scarce points on inert effects; future authored nodes remain unavailable until implemented |
| Save format | JSON via `FileAccess` in `user://` | Simple, debuggable |

---

## 10. Art & Audio Direction

- **Art:** Stylized HD 2D illustration (issue #139). Painterly, hand-worn medieval materials in a low-saturation earthy palette, broken by bright cyan/magenta relic-tech emissives; clean high-contrast silhouettes, soft authored top-down lighting, smooth animation. Not 3D realism and not upscaled pixel art. Canonical direction: `docs/visual_bible.md` + `docs/asset_manifest_v1.md`; in-engine palette proof: `scenes/reference/visual_reference_sheet.tscn` (pixel-era readability strip is legacy); reference imagery collects in `assets/reference/`.
- **Pipeline:** The shipped 16-bit pixel assets are the playable legacy layer during migration. A one-screen HD prototype locks the concrete technical art contracts (sizes, filtering, camera, animation approach, budget) before per-group conversion passes replace legacy assets. Every asset's source/license logged per AGENTS.md §11.
- **Audio:** Ambient drones + medieval instrumentation with synthetic artifacts; combat SFX punchy and readable. Placeholder-first.

---

## 11. Open Questions

| # | Question | Blocking? | Owner |
|---|---|---|---|
| 1 | Game's actual title (repo stays hive_mind_rpg) | No | Team |
| 2 | Story seed — what is the buried thing? | No (v1 barks only) | Team |

---

## Changelog

| Date | Version | Change | Author |
|---|---|---|---|
| 2026-07-10 | 0.1 | Initial scaffold | Claude + MeanGreen256 |
| 2026-07-10 | 0.2 | Filled from design interview: pillars, loops, combat, tree, world, v1 slice, tech decisions | Claude + MeanGreen256 |
| 2026-07-11 | 0.3 | Locked passive Energy regeneration and fixed 8-direction relic aiming | Codex + MeanGreen256 |
| 2026-07-11 | 0.4 | Locked Zone 1 theme as a corrupted forest | Codex + MeanGreen256 |
| 2026-07-13 | 0.5 | Linked canonical v1 visual bible, asset manifest, and reference sheet (issue #82) | Claude + pj200105 |
| 2026-07-13 | 0.6 | Required live runtime consumers for purchasable skill effects (issue #77) | Codex + MeanGreen256 |
| 2026-07-17 | 0.7 | Pivoted art direction to stylized HD 2D illustration; pixel-art contracts reclassified as legacy implementation pending the one-screen prototype (issue #139) | Claude + pj200105 |
