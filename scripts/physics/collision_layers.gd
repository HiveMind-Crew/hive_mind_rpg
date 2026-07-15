class_name CollisionLayers
extends RefCounted

## Physical-body layers are separate from Area2D combat layers. Actors only
## query authored world geometry, so enemies can overlap the player without
## becoming a movement blocker while hitboxes and hurtboxes keep their own
## combat contract.
const WORLD: int = 1 << 0
const PLAYER_BODY: int = 1 << 1
const ENEMY_BODY: int = 1 << 2
const COMBAT_HITBOX: int = 1 << 1
const COMBAT_HURTBOX: int = 1 << 2
