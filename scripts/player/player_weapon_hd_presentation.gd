class_name PlayerWeaponHdPresentation
extends Sprite2D
## Presentation-only steel weapon display for issue #168. PlayerHdPresentation
## owns and drives this sprite from the live PlayerVisual facing/action state;
## it never touches PlayerController, PlayerMeleeAttack, the melee hitbox, or
## any gameplay timing. The atlas is deterministic CC0 art authored pointing +x
## (assets/sprites/generate_hd_steel_weapon.py) so runtime rotation is truthful
## for every facing.

const WEAPON_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/steel_weapon_atlas.png")
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const CELL_SIZE: Vector2 = Vector2(256.0, 128.0)
const HELD_REGION: Rect2 = Rect2(Vector2.ZERO, CELL_SIZE)
const SWING_REGION: Rect2 = Rect2(Vector2(256.0, 0.0), CELL_SIZE)
## Grip-center pixel inside each cell; the sprite offset moves it onto the node
## origin so rotation pivots at the wielding hand.
const HILT_PIVOT_X_PX: float = 24.0
## Opaque sword length inside each cell (pommel edge to blade tip) and its
## on-screen contract. 24 px keeps the mid-swing tip inside the reach the
## existing 24x24 melee hitbox at 14 px offset already covers, so the weapon
## never overstates collision.
const CONTENT_LENGTH_PX: float = 228.0
const DISPLAY_LENGTH_PX: float = 24.0
## facing_label -> rotation of the authored +x sword for that facing.
const FACING_ANGLES: Dictionary[StringName, float] = {
	&"north": -PI * 0.5,
	&"east": 0.0,
	&"south": PI * 0.5,
	&"west": PI,
}
## facing_label -> hand anchor relative to the presentation root, chosen so the
## grip sits on the body silhouette at the 42 px display-height contract.
const HAND_ANCHORS: Dictionary[StringName, Vector2] = {
	&"north": Vector2(5.0, -10.0),
	&"east": Vector2(5.0, -7.0),
	&"south": Vector2(-5.0, -5.0),
	&"west": Vector2(-5.0, -7.0),
}
## Held (idle/move/dash/relic/hurt) rest tilt away from the facing axis, so the
## carried silhouette never matches the melee sweep.
const REST_ANGLE_DEGREES: float = 55.0
## Melee sweep passes from -arc/2 through the exact facing angle to +arc/2.
const SWING_ARC_DEGREES: float = 150.0
## West mirrors the rest tilt and sweep so both side facings read as the same
## down-forward stance and downward chop; the mid-swing angle still crosses the
## exact play_melee facing for every direction.
const FACING_TILT_SIGNS: Dictionary[StringName, float] = {
	&"north": 1.0,
	&"east": 1.0,
	&"south": 1.0,
	&"west": -1.0,
}
## Presentation-only sweep pacing that mirrors the melee clip length; gameplay
## swing timing stays owned by PlayerMeleeAttack and is never read or written.
const SWING_SWEEP_SECONDS: float = 0.12
## North-facing swings read behind the body; every other facing in front.
const BEHIND_BODY_FACING: StringName = &"north"
const WEAPON_Z_BEHIND: int = -1
const WEAPON_Z_FRONT: int = 0


func _init() -> void:
	name = "SteelWeapon"
	texture = WEAPON_TEXTURE
	texture_filter = HD_TEXTURE_FILTER
	region_enabled = true
	# Facing always comes from rotation, never flip_h. flip_v is used only for
	# mirrored (west) sweeps so the authored hot leading edge and trailing smear
	# stay on the kinematically truthful sides of the moving blade.
	flip_h = false
	flip_v = false
	offset = Vector2(CELL_SIZE.x * 0.5 - HILT_PIVOT_X_PX, 0.0)
	scale = Vector2.ONE * (DISPLAY_LENGTH_PX / CONTENT_LENGTH_PX)
	update_presentation(&"south", PlayerVisual.IDLE_ANIMATION, 0.0)


## Mirrors the already-decided PlayerVisual state onto the weapon display.
## state_elapsed is the presentation time since the current state began.
func update_presentation(
	facing: StringName, animation_state: StringName, state_elapsed: float
) -> void:
	visible = animation_state != PlayerVisual.DEATH_ANIMATION
	if not visible:
		return
	var facing_angle: float = FACING_ANGLES.get(facing, FACING_ANGLES[&"south"])
	var tilt_sign: float = FACING_TILT_SIGNS.get(facing, 1.0)
	position = HAND_ANCHORS.get(facing, HAND_ANCHORS[&"south"])
	z_index = WEAPON_Z_BEHIND if facing == BEHIND_BODY_FACING else WEAPON_Z_FRONT
	if animation_state == PlayerVisual.MELEE_ANIMATION:
		region_rect = SWING_REGION
		rotation = facing_angle + tilt_sign * _swing_sweep_offset(state_elapsed)
		flip_v = tilt_sign < 0.0
	else:
		region_rect = HELD_REGION
		rotation = facing_angle + tilt_sign * deg_to_rad(REST_ANGLE_DEGREES)
		flip_v = false


func _swing_sweep_offset(state_elapsed: float) -> float:
	var progress: float = clampf(state_elapsed / SWING_SWEEP_SECONDS, 0.0, 1.0)
	var half_arc: float = deg_to_rad(SWING_ARC_DEGREES) * 0.5
	return lerpf(-half_arc, half_arc, progress)
