# Sprite Asset Licenses

Per `AGENTS.md` §11, every binary sprite asset's source and license is logged
here. Test-only art remains documented separately in `assets/sprites/testing/README.md`.

| Asset | Source / author | License | Notes |
|---|---|---|---|
| `player/wanderer_{front,back,side}_{idle,move,attack}.png` | Custom nine-cell directional action atlas generated for this project with OpenAI image generation on 2026-07-12. It preserves the dark-cloaked wanderer, steel sword, and cyan/magenta relic across front, back, and side idle, movement, and attack poses. | Project-owned generated asset; no third-party source material intentionally used. | The generated directional atlas was chroma-keyed locally, then split into the nine transparent runtime frames. |
| `player/wanderer_walk_{north,south,east,west}_{0,1,2,3}.png` | Four independently generated four-frame cardinal walk cycles for the same wanderer, created with OpenAI image generation on 2026-07-12. North hides the relic; south, east, and west keep it on the character's anatomical left side without runtime mirroring. | Project-owned generated asset; no third-party source material intentionally used. | Runtime walk-cycle frames. |
| `enemies/melee_chaser.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_authored_pixel_art.py`. | CC0-1.0 | 24×24 original violet relic-hound frames. No third-party pixels or generated-image model output. |
| `enemies/melee_chaser_frames.tres` | Hand-authored for hive_mind_rpg by the project team; generated deterministically by `assets/sprites/generate_authored_pixel_art.py`. | CC0-1.0 | Godot `SpriteFrames` regions for the authored sheet. |
| `world/zone1_forest_tiles.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_authored_pixel_art.py`. | CC0-1.0 | 16×16 corrupted-forest atlas using the canonical visual-bible palette. No third-party pixels or generated-image model output. |
