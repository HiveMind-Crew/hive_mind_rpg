# Sprite Asset Licenses

Per `AGENTS.md` §11, every binary sprite asset's source and license is logged
here.

| Asset | Source | License |
|---|---|---|
| `player/wanderer_{front,back,side}_{idle,move,attack}.png` | Custom nine-cell directional action atlas generated for this project with OpenAI image generation on 2026-07-12. It preserves the dark-cloaked wanderer, steel sword, and cyan/magenta relic across front, back, and side idle, movement, and attack poses. | Project-owned generated asset; no third-party source material intentionally used. |
| `player/wanderer_walk_{north,south,east,west}_{0,1,2,3}.png` | Four independently generated four-frame cardinal walk cycles for the same wanderer, created with OpenAI image generation on 2026-07-12. North hides the relic; south, east, and west keep it on the character's anatomical left side without runtime mirroring. | Project-owned generated asset; no third-party source material intentionally used. |

The generated directional atlas was chroma-keyed locally, then split into the
nine transparent runtime frames listed above.
