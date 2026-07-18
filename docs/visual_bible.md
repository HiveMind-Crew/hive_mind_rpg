# Visual Bible — v1 Vertical Slice (Stylized HD 2D)

> **Status:** Canonical for the v1 slice (issue #139). Expands `DESIGN.md` §10.
> It replaces the former 16-bit pixel-art target. `docs/asset_manifest_v1.md`
> owns migration groups and production status. Existing pixel assets remain
> playable legacy content until focused replacement passes land.

## 1. Direction in one paragraph

**Stylized HD 2D illustration.** Zone 1 is a corrupted forest of painterly,
hand-worn medieval materials — soil, bark, moss, worked stone, cloth — ruptured
by buried relic technology. The medieval language is low-saturation, organic,
and imperfect. Relic tech is precise, geometric, emissive, and visibly foreign.
The goal is a premium illustrated action RPG, not 3D realism and not enlarged or
smoothed pixel art. The top-down camera, 2D gameplay/collision, hand-built
rooms, and surreal science-fantasy tone remain unchanged.

## 2. Visual languages and palette

### 2.1 Medieval world

Earth, stone, foliage, and cloth occupy warm/cool muted ranges. Materials should
show deliberate brush texture, value variation, and age without noisy detail.
Keep playable floors calmer and lower-contrast than walls, props, and actors.
The current earth/stone/moss palette families remain useful starting anchors,
but exact ramps are established by the one-screen HD prototype rather than
copied mechanically from legacy pixel art.

### 2.2 Relic corruption

Relic technology reserves bright **cyan** and **magenta** emissives. Cyan reads
as power, relic machinery, pickups, and player energy; magenta reads as
corruption, hostile tech, and threat-side machinery. The colors must appear as
an intrusion into medieval materials, never as ambient forest decoration. Glow
is spatially contained: it lights nearby material and supports interaction or
threat readability rather than washing out the scene.

### 2.3 Actor and gameplay signals

- Player: teal-led silhouette with a restrained magenta facing/readability
  accent.
- Enemies: violet-led silhouettes, distinct from both player and world.
- Wind-up/telegraph: warm yellow; damage: red; restoration/checkpoint: green;
  energy: cyan; defeat: desaturated dark neutral.
- These semantic colors are gameplay communication and must not be repurposed
  as ordinary decoration.

## 3. Value hierarchy and readability

1. Background/void is darkest and quietest.
2. Walls and major props create readable framing silhouettes.
3. Walkable floor is mid-value and visually calm.
4. Actors, interactables, and navigation affordances have the strongest local
   separation from their immediate floor and wall backgrounds.
5. Combat telegraphs, relic glow, and short-lived FX are the brightest and most
   saturated elements.

At actual play size, the player, every enemy archetype, hostile attack,
checkpoint, pickup, secret cue, and zone gate must be identifiable without
relying on labels. Environment art may frame routes but may not conceal enemy
spawns, interact prompts, collision boundaries, or secret entrances.

## 4. Material, lighting, and depth

- **Medieval materials:** irregular hand-painted edges; warm/cool shifts across
  worn stone, bark, moss, soil, cloth, and metal. Detail follows form and
  lighting rather than evenly coating every surface.
- **Relic materials:** clean geometry, repeated manufacture marks, emissive
  cores, restrained distortion/channel splitting near corruption boundaries.
- **Lighting:** authored top-down/three-quarter lighting defines form, contact,
  and navigation. Soft shadows may ground actors and props, but may not hide
  gameplay space or imply collision where none exists.
- **Depth:** use overlap, value, ambient occlusion/contact shadow, and
  disciplined prop placement. Do not use visual depth to change top-down
  collision, targeting, camera, or movement rules.

## 5. Animation and combat presentation

Animation should be smooth enough to communicate anticipation, impact,
recovery, movement direction, and state changes clearly. It may use authored
frame animation, skeletal/rigged animation, or a validated hybrid; exact method
is intentionally deferred to the prototype. Attack contact, dash readability,
relic casting, hit reactions, death states, and enemy telegraphs remain
presentation-only unless a gameplay issue explicitly changes them.

Live mechanical signals always win over decorative art: facing, active shields,
wind-ups, hitboxes, invulnerability, and defeated pass-through states need
clear current-state feedback even if an illustrated body sheet is static.

## 6. Geometry, collision, and scene composition

Gameplay geometry is canonical. Art conforms to existing collision shapes,
navigation, spawns, interact areas, and encounter layout; an art pass never
silently changes them. Decorative overhangs must preserve honest ground contact
and leave actor silhouettes, interactables, and walkable routes readable.
Visual nodes remain separate from collision components and gameplay signals.

The former 16×16 tile grid and 32×32 actor frame conventions are **legacy
implementation details**, not art-direction targets. They remain valid for
current assets only while the migration is underway.

## 7. Rendering and implementation transition

The shipped project currently retains pixel snapping, nearest-filtered legacy
textures, a 2× world camera configuration, and 1280×720 output. The Zone 1
entrance-route prototype (issue #141) produced **measured prototype
decisions** — settings observed working in the integrated route and its
headless test suite. They are the starting point for conversion issues, but
they do **not** yet constitute the complete final HD technical contract:
no browser load-time or frame-time measurement has been taken, and full
window-size/DPR/performance budgeting is an explicit follow-up validation
item.

Measured prototype decisions:

- **Source dimensions:** a 1024×576 wide painted environment plate treated as
  a single background (uniformly scaled 5/6 to the 480 px zone height and
  region-cropped to end on a room boundary), plus chroma-key-extracted
  transparent actor illustrations at native source size — player 180×274,
  melee chaser 162×286, checkpoint shrine 249×330 — scaled per-node to the
  legacy actor footprint at play size.
- **Filtering:** per-node `TEXTURE_FILTER_LINEAR` on the new HD nodes only.
  The project-wide default filter, pixel snapping, and every legacy
  nearest-filtered node are unchanged.
- **Camera:** the existing 2× world camera is retained for this measured
  prototype; no zoom, bounds, or renderer changes.
- **Animation:** static single-pose prototype art, honestly documented as
  such. Live mechanical signals stay readable by mirroring the hidden legacy
  drivers (facing flips, CombatFeedback flashes, enemy state tints, shrine
  lit state) onto the HD sprites; no fake frame animation was added.
- **Composition:** the HD layer is a zone-local presentation helper
  (`Zone1HdPresentation`) that hides only the selected legacy display nodes
  and the covered-route scenery it paints over (display-only prop sprites and
  the exit-gate marker polygon); collision, spawns, Area2D contracts, combat,
  saves, and HUD behavior are untouched.
- **No painted affordances:** environment plates must depict environment
  only. The first encounter-room plate was rejected in independent review for
  baking a shrine at a location with no matching interactable (a false
  affordance); the integrated plate is the recomposed v2 with no shrine,
  gate, pickup, or characters. Anything interactable gets its own live node
  and visual.

Follow-up validation items, **not established by this prototype**: browser
load-time and frame-time measurement; window-size/DPR/performance budgeting;
mipmap, compression, and alpha import settings; atlas/rig approach; the
production animation workflow and runtime cost; and UI/world readability
across browser and window sizes. Do not introduce fractional visual scaling,
smoothing, renderer changes, or new asset settings in a conversion pass
before those remaining decisions land.

## 8. UI and typography

UI remains clean, high-contrast, and subordinate to active combat. It should
share the illustrated material language without becoming ornate or reducing
scan speed. HP, energy, skill availability, interaction prompts, and controller
hints must remain legible at 1280×720 output and ordinary browser/window sizes.
The former pixel font and 8 px minimum are legacy constraints pending the UI
conversion pass; accessibility and functional layout are not optional.

## 9. Production, provenance, and review

- Every binary asset records source, author/tool, license, and post-processing
  in `assets/sprites/LICENSES.md` or the applicable license log.
- Use only properly licensed hand-authored, CC0/compatible third-party, or
  policy-compliant generated source material. Do not claim provenance that is
  not documented.
- Review art at actual gameplay size and in a real combat route, not only a
  zoomed asset sheet.
- Each focused conversion pass preserves gameplay and includes structural tests
  and manual playtest evidence appropriate to its asset group.
