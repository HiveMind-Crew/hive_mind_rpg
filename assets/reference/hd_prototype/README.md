# HD Zone 1 prototype references — issue #141

These are **direction references only**, generated with LemonadeAI before any
production asset extraction or in-game integration. They do not yet establish a
production license, texture-import contract, asset dimensions, or final game
composition. The sidecar JSON files preserve each exact model, prompt, output
dimensions, and elapsed time.

| File | Purpose | Review outcome |
|---|---|---|
| `zone1_corrupted_forest_keyframe.png` | Initial cinematic mood keyframe | Strong material, lighting, relic-color, player/enemy, and shrine direction; too three-quarter/cinematic to serve as a direct top-down playfield template. |
| `zone1_topdown_playfield_keyframe.png` | Strict top-down gameplay direction keyframe | Preferred reference. It better communicates a central walkable clearing, player/enemy separation, shrine affordance, and contained relic cyan/magenta. It still needs deliberate game-ready extraction rather than use as a single background image. |

## Source plates (`source_plates/`)

Modular plates generated for the issue #141 prototype gate with the same
generator (LemonadeAI running `Flux-2-Klein-9B-GGUF`; exact prompts, model,
dimensions, and timing in each sidecar JSON):

| File | Purpose |
|---|---|
| `encounter_room_background.png` | **REJECTED — not used.** First 1024×576 encounter-room plate; independent review rejected it because it baked a shrine at a location with no matching interactable, creating a false affordance. Retained only as the review record of what was replaced; it must not be copied to `assets/sprites/`. |
| `encounter_room_background_v2.png` | 1024×576 recomposed environment-only plate (used by the prototype). Intentionally contains **no** shrine, altar, gate, pickup, characters, or other gameplay affordances; every interactable keeps its own live node + visual in the scene. |
| `player_wanderer_plate.png` / `extracted/player_wanderer.png` | Player illustration on chroma key / extracted to 180×274 transparent PNG (used by the prototype). |
| `relic_hound_plate.png` / `extracted/relic_hound.png` | Melee-chaser illustration on chroma key / extracted to 162×286 transparent PNG (used by the prototype). |
| `checkpoint_shrine_plate.png` / `extracted/checkpoint_shrine.png` | Checkpoint shrine on chroma key / extracted to 249×330 transparent PNG (used by the prototype). |
| `source_plate_contact_sheet.png`, `extracted/extracted_contact_sheet.png` | Review contact sheets only. |

## License determination (issue #141)

All images in this directory were generated with LemonadeAI running
`Flux-2-Klein-9B-GGUF` and are covered by the **`flux-non-commercial-license`
(non-commercial use only)**. The project owner confirmed this repository is a
non-commercial project, which is the only reason copies of the selected plates
were promoted to `assets/sprites/hd_prototype/` for the prototype. These
images are **not** CC0 and **not** commercial-safe; they must be replaced by
compatibly licensed art before any commercial or CC0-claimed distribution.
Per-file provenance rows live in `assets/sprites/LICENSES.md`.

## Required adaptation before production use

- Recompose environment art to the existing Zone 1 collision/navigation layout;
  generated perspective and painted boundaries must never define geometry.
- Create separate player, enemy, shrine, relic-machine, floor, wall, foliage,
  and FX assets with transparent backgrounds and a documented animation method.
- Preserve the existing collision shapes, combat telegraphs, interaction areas,
  spawn positions, camera bounds, and HUD behavior.
- Validate actual-size readability in the shipped camera and browser export.
- Confirm the selected generator/model terms allow the intended repository
  license before any image is committed as production art; then record the
  required source/tool/date/prompt-summary/post-processing information in
  `assets/sprites/LICENSES.md`.
