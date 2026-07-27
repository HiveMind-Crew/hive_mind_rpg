class_name PlayerHdPresentation
extends Node2D
## HD player display layer for issues #150/#165/#168/#189/#193. It mirrors the existing
## PlayerVisual state driver instead of taking ownership of movement, combat,
## collision, or health. The body texture is a four-cell directional atlas
## curated from non-commercial Flux prototype output; see
## assets/sprites/LICENSES.md before distributing it beyond this project. The
## steel weapon child (issues #168/#184) is deterministic CC0 art; its hand-
## anchored wind-up/contact/recovery is display-only and the CombatFxSpawner
## slash stays the single slash FX owner. Issue #189 adds a deterministic body
## pose atlas so melee visibly moves the HD body and arms as well as the weapon.
## Issue #193 adds a separate body cast atlas so the same live relic state
## visibly channels and releases lightning without owning projectile FX. Issue #203
## adds deterministic locomotion and hurt-recoil poses driven only by that same
## PlayerVisual state owner.

const ATLAS_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_directional_atlas.png")
const MELEE_ATLAS_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_melee_body_atlas.png")
const RELIC_ATLAS_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_relic_body_atlas.png")
const DASH_ATLAS_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_dash_body_atlas.png")
const LOCOMOTION_RESPONSE_ATLAS_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_locomotion_response_atlas.png")
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const ATLAS_CELL_SIZE: Vector2 = Vector2(256.0, 256.0)
const MELEE_ATLAS_CELL_SIZE: Vector2 = Vector2(256.0, 256.0)
## Opaque art height inside every atlas cell (curation contract in
## tools/curate_player_directional_atlas.py); the rest is safe transparent border.
const ATLAS_CONTENT_HEIGHT_PX: float = 190.0
## Facing label → atlas column. The authored side cells are ordered west then
## east (the original east/west labels were reversed); neither is a runtime flip.
const DIRECTION_ATLAS_COLUMNS: Dictionary[StringName, int] = {
	&"north": 0,
	&"east": 3,
	&"south": 2,
	&"west": 1,
}
## The authored melee atlas rows are north, west, south, east. They are full
## cardinal poses, never runtime-flipped, so the body/arms agree with the live
## facing even while the held atlas uses a different cell ordering.
const MELEE_DIRECTION_ROWS: Dictionary[StringName, int] = {
	&"north": 0,
	&"west": 1,
	&"south": 2,
	&"east": 3,
}
const MELEE_WINDUP_COLUMN: int = 0
const MELEE_CONTACT_COLUMN: int = 1
const MELEE_RECOVERY_COLUMN: int = 2
## The relic atlas follows the same north/west/south/east row contract, but its
## charge/release/recovery phases mirror the existing three-frame relic clip.
const RELIC_DIRECTION_ROWS: Dictionary[StringName, int] = MELEE_DIRECTION_ROWS
const RELIC_CHARGE_COLUMN: int = 0
const RELIC_RELEASE_COLUMN: int = 1
const RELIC_RECOVERY_COLUMN: int = 2
const RELIC_WINDOW_SECONDS: float = 0.25
const RELIC_CHARGE_SECONDS: float = 1.0 / 12.0
const RELIC_RELEASE_SECONDS: float = 1.0 / 12.0
const RELIC_RECOVERY_SECONDS: float = 1.0 / 12.0
## PlayerMovementStateMachine owns the 0.14-second logical dash. These four
## equal display phases are strictly visual and never extend that state.
const DASH_DIRECTION_ROWS: Dictionary[StringName, int] = MELEE_DIRECTION_ROWS
const DASH_LAUNCH_COLUMN: int = 0
const DASH_STREAK_A_COLUMN: int = 1
const DASH_STREAK_B_COLUMN: int = 2
const DASH_RECOVERY_COLUMN: int = 3
const DASH_WINDOW_SECONDS: float = 0.14
const DASH_PHASE_SECONDS: float = DASH_WINDOW_SECONDS / 4.0
## Issue #203 loops four authored gait poses at presentation speed while the
## fifth column is the real PlayerVisual HURT state response. No movement clock,
## control lockout, health, or collision behavior is owned here.
const LOCOMOTION_DIRECTION_ROWS: Dictionary[StringName, int] = MELEE_DIRECTION_ROWS
const LOCOMOTION_GAIT_COLUMNS: int = 3
const LOCOMOTION_SETTLE_COLUMN: int = 3
const LOCOMOTION_HURT_COLUMN: int = 4
const LOCOMOTION_PHASE_SECONDS: float = 0.11
const LOCOMOTION_SETTLE_SECONDS: float = 0.11
## These presentation phases partition, but never own or extend, the existing
## PlayerMeleeAttack 0.12 second combat window.
const MELEE_WINDOW_SECONDS: float = 0.12
const MELEE_WINDUP_SECONDS: float = 0.04
const MELEE_CONTACT_SECONDS: float = 0.04
const MELEE_RECOVERY_SECONDS: float = 0.04
const DISPLAY_HEIGHT_PX: float = 42.0
const BODY_POSITION: Vector2 = Vector2(0.0, -10.0)
const CONTACT_SHADOW_SCALE: Vector2 = Vector2(0.55, 0.18)
const CONTACT_SHADOW_COLOR: Color = Color(0.02, 0.03, 0.04, 0.42)
const MOVE_BOB_HEIGHT_PX: float = 1.2
const MOVE_BOB_FREQUENCY: float = 11.0
const MOVE_SWAY_DEGREES: float = 2.5
const ACTION_SQUASH: Vector2 = Vector2(1.1, 0.9)
const DASH_STRETCH: Vector2 = Vector2(0.9, 1.12)
const HURT_TINT: Color = Color(1.0, 0.72, 0.72, 1.0)
const DEAD_TINT: Color = Color(0.35, 0.37, 0.4, 1.0)
const FACING_ACCENT_COLOR: Color = Color(0.28, 0.9, 1.0, 0.9)
const ACTION_FACING_ACCENT_COLOR: Color = Color(1.0, 0.35, 0.82, 0.96)
const FACING_ACCENT_POSITION: Vector2 = Vector2(0.0, -11.0)

@export var visual_path: NodePath

var _legacy_visual: PlayerVisual
var _display_sprite: Sprite2D
var _contact_shadow: Polygon2D
var _facing_accent: Polygon2D
var _weapon: PlayerWeaponHdPresentation
var _animation_state: StringName = PlayerVisual.IDLE_ANIMATION
var _elapsed: float = 0.0
# Presentation time since the current logical state began; drives the weapon
# swing sweep without reading any gameplay timer.
var _state_elapsed: float = 0.0
## Move entry begins at authored gait column zero; when the logical driver
## returns to idle, a short presentation-only settle holds before the base idle.
var _locomotion_elapsed: float = 0.0
var _locomotion_settle_elapsed: float = -1.0


func _ready() -> void:
	_ensure_display_nodes()
	_legacy_visual = get_node_or_null(visual_path) as PlayerVisual
	if _legacy_visual == null:
		push_error("PlayerHdPresentation requires a PlayerVisual driver.")
		set_process(false)
		return
	_legacy_visual.animation_state_changed.connect(_on_animation_state_changed)
	_animation_state = _legacy_visual.animation_name
	_legacy_visual.visible = false


func _process(delta: float) -> void:
	_elapsed += delta
	_state_elapsed += delta
	if _animation_state == PlayerVisual.MOVE_ANIMATION:
		_locomotion_elapsed += delta
	elif _locomotion_settle_elapsed >= 0.0:
		_locomotion_settle_elapsed += delta
	if _legacy_visual == null:
		return
	_update_atlas_region()
	_display_sprite.self_modulate = _state_modulate() * _legacy_visual.self_modulate
	_apply_state_pose()
	_update_facing_accent()
	_update_weapon()


func get_display_sprite() -> Sprite2D:
	_ensure_display_nodes()
	return _display_sprite


func get_weapon_sprite() -> PlayerWeaponHdPresentation:
	_ensure_display_nodes()
	return _weapon


func _ensure_display_nodes() -> void:
	if _display_sprite != null:
		return
	_display_sprite = _create_display_sprite()
	_contact_shadow = _create_contact_shadow()
	_facing_accent = _create_facing_accent()
	_weapon = PlayerWeaponHdPresentation.new()
	add_child(_contact_shadow)
	add_child(_display_sprite)
	add_child(_weapon)
	add_child(_facing_accent)


func _create_display_sprite() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "HdBody"
	sprite.texture = ATLAS_TEXTURE
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.region_enabled = true
	sprite.region_rect = _atlas_region_for(&"south")
	# The atlas carries authored art for all four cardinals, so the sprite never
	# runtime-mirrors; facing feedback comes from region selection.
	sprite.flip_h = false
	sprite.scale = Vector2.ONE * _base_scale()
	sprite.position = BODY_POSITION
	return sprite


func _create_contact_shadow() -> Polygon2D:
	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = "ContactShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-12.0, 0.0), Vector2(-6.0, -3.0), Vector2(6.0, -3.0), Vector2(12.0, 0.0),
		Vector2(6.0, 3.0), Vector2(-6.0, 3.0),
	])
	shadow.scale = CONTACT_SHADOW_SCALE
	shadow.position = Vector2(0.0, 11.0)
	shadow.color = CONTACT_SHADOW_COLOR
	return shadow


func _create_facing_accent() -> Polygon2D:
	var accent: Polygon2D = Polygon2D.new()
	accent.name = "FacingAccent"
	accent.polygon = PackedVector2Array([
		Vector2(-3.0, 3.0), Vector2(0.0, -4.0), Vector2(3.0, 3.0),
	])
	accent.position = FACING_ACCENT_POSITION
	accent.color = FACING_ACCENT_COLOR
	return accent


func _on_animation_state_changed(next_state: StringName) -> void:
	var previous_state: StringName = _animation_state
	_animation_state = next_state
	_state_elapsed = 0.0
	if next_state == PlayerVisual.MOVE_ANIMATION:
		_locomotion_elapsed = 0.0
		_locomotion_settle_elapsed = -1.0
	elif previous_state == PlayerVisual.MOVE_ANIMATION and next_state == PlayerVisual.IDLE_ANIMATION:
		_locomotion_settle_elapsed = 0.0
	else:
		_locomotion_settle_elapsed = -1.0


func _base_scale() -> float:
	return DISPLAY_HEIGHT_PX / ATLAS_CONTENT_HEIGHT_PX


func _atlas_region_for(facing: StringName) -> Rect2:
	var column: int = DIRECTION_ATLAS_COLUMNS.get(facing, DIRECTION_ATLAS_COLUMNS[&"south"])
	return Rect2(Vector2(ATLAS_CELL_SIZE.x * float(column), 0.0), ATLAS_CELL_SIZE)


func _melee_atlas_region_for(facing: StringName, phase_column: int) -> Rect2:
	var row: int = MELEE_DIRECTION_ROWS.get(facing, MELEE_DIRECTION_ROWS[&"south"])
	return Rect2(
		Vector2(
			MELEE_ATLAS_CELL_SIZE.x * float(phase_column),
			MELEE_ATLAS_CELL_SIZE.y * float(row),
		),
		MELEE_ATLAS_CELL_SIZE,
	)


func _relic_atlas_region_for(facing: StringName, phase_column: int) -> Rect2:
	var row: int = RELIC_DIRECTION_ROWS.get(facing, RELIC_DIRECTION_ROWS[&"south"])
	return Rect2(
		Vector2(
			MELEE_ATLAS_CELL_SIZE.x * float(phase_column),
			MELEE_ATLAS_CELL_SIZE.y * float(row),
		),
		MELEE_ATLAS_CELL_SIZE,
	)


func _dash_atlas_region_for(facing: StringName, phase_column: int) -> Rect2:
	var row: int = DASH_DIRECTION_ROWS.get(facing, DASH_DIRECTION_ROWS[&"south"])
	return Rect2(
		Vector2(
			MELEE_ATLAS_CELL_SIZE.x * float(phase_column),
			MELEE_ATLAS_CELL_SIZE.y * float(row),
		),
		MELEE_ATLAS_CELL_SIZE,
	)


func _locomotion_response_atlas_region_for(facing: StringName, phase_column: int) -> Rect2:
	var row: int = LOCOMOTION_DIRECTION_ROWS.get(facing, LOCOMOTION_DIRECTION_ROWS[&"south"])
	return Rect2(
		Vector2(
			MELEE_ATLAS_CELL_SIZE.x * float(phase_column),
			MELEE_ATLAS_CELL_SIZE.y * float(row),
		),
		MELEE_ATLAS_CELL_SIZE,
	)


func _update_atlas_region() -> void:
	if _is_active_melee_body():
		_display_sprite.texture = MELEE_ATLAS_TEXTURE
		_display_sprite.region_rect = _melee_atlas_region_for(
			_legacy_visual.facing_label, _melee_phase_column(_state_elapsed)
		)
		return
	if _is_active_relic_body():
		_display_sprite.texture = RELIC_ATLAS_TEXTURE
		_display_sprite.region_rect = _relic_atlas_region_for(
			_legacy_visual.facing_label, _relic_phase_column(_state_elapsed)
		)
		return
	if _is_active_dash_body():
		_display_sprite.texture = DASH_ATLAS_TEXTURE
		_display_sprite.region_rect = _dash_atlas_region_for(
			_legacy_visual.facing_label, _dash_phase_column(_state_elapsed)
		)
		return
	if _animation_state == PlayerVisual.MOVE_ANIMATION:
		_display_sprite.texture = LOCOMOTION_RESPONSE_ATLAS_TEXTURE
		_display_sprite.region_rect = _locomotion_response_atlas_region_for(
			_legacy_visual.facing_label, _locomotion_phase_column()
		)
		return
	if _is_active_locomotion_settle():
		_display_sprite.texture = LOCOMOTION_RESPONSE_ATLAS_TEXTURE
		_display_sprite.region_rect = _locomotion_response_atlas_region_for(
			_legacy_visual.facing_label, LOCOMOTION_SETTLE_COLUMN
		)
		return
	if _animation_state == PlayerVisual.HURT_ANIMATION:
		_display_sprite.texture = LOCOMOTION_RESPONSE_ATLAS_TEXTURE
		_display_sprite.region_rect = _locomotion_response_atlas_region_for(
			_legacy_visual.facing_label, LOCOMOTION_HURT_COLUMN
		)
		return
	_display_sprite.texture = ATLAS_TEXTURE
	_display_sprite.region_rect = _atlas_region_for(_legacy_visual.facing_label)


func _locomotion_phase_column() -> int:
	return int(floor(_locomotion_elapsed / LOCOMOTION_PHASE_SECONDS)) % LOCOMOTION_GAIT_COLUMNS


func _is_active_locomotion_settle() -> bool:
	return (
		_animation_state == PlayerVisual.IDLE_ANIMATION
		and _locomotion_settle_elapsed >= 0.0
		and _locomotion_settle_elapsed < LOCOMOTION_SETTLE_SECONDS
	)


func _is_active_melee_body() -> bool:
	return (
		_animation_state == PlayerVisual.MELEE_ANIMATION
		and _state_elapsed < MELEE_WINDOW_SECONDS
	)


func _melee_phase_column(state_elapsed: float) -> int:
	if state_elapsed < MELEE_WINDUP_SECONDS:
		return MELEE_WINDUP_COLUMN
	if state_elapsed < MELEE_WINDUP_SECONDS + MELEE_CONTACT_SECONDS:
		return MELEE_CONTACT_COLUMN
	return MELEE_RECOVERY_COLUMN


func _is_active_relic_body() -> bool:
	return (
		_animation_state == PlayerVisual.RELIC_ANIMATION
		and _state_elapsed < RELIC_WINDOW_SECONDS
	)


func _relic_phase_column(state_elapsed: float) -> int:
	if state_elapsed < RELIC_CHARGE_SECONDS:
		return RELIC_CHARGE_COLUMN
	if state_elapsed < RELIC_CHARGE_SECONDS + RELIC_RELEASE_SECONDS:
		return RELIC_RELEASE_COLUMN
	return RELIC_RECOVERY_COLUMN


func _is_active_dash_body() -> bool:
	return _animation_state == PlayerVisual.DASH_ANIMATION and _state_elapsed < DASH_WINDOW_SECONDS


func _dash_phase_column(state_elapsed: float) -> int:
	if state_elapsed < DASH_PHASE_SECONDS:
		return DASH_LAUNCH_COLUMN
	if state_elapsed < DASH_PHASE_SECONDS * 2.0:
		return DASH_STREAK_A_COLUMN
	if state_elapsed < DASH_PHASE_SECONDS * 3.0:
		return DASH_STREAK_B_COLUMN
	return DASH_RECOVERY_COLUMN


func _apply_state_pose() -> void:
	_display_sprite.scale = Vector2.ONE * _base_scale()
	_display_sprite.position = BODY_POSITION
	_display_sprite.rotation = 0.0
	match _animation_state:
		PlayerVisual.MOVE_ANIMATION:
			# Presentation-only gait: vertical bob plus a half-frequency lean so
			# locomotion reads alive without touching movement timing.
			_display_sprite.position.y += _move_bob_offset_y()
			_display_sprite.rotation = (
				sin(_elapsed * MOVE_BOB_FREQUENCY * 0.5) * deg_to_rad(MOVE_SWAY_DEGREES)
			)
		PlayerVisual.DASH_ANIMATION:
			_display_sprite.scale *= DASH_STRETCH
		PlayerVisual.MELEE_ANIMATION, PlayerVisual.RELIC_ANIMATION:
			_display_sprite.scale *= ACTION_SQUASH
		PlayerVisual.DEATH_ANIMATION:
			_display_sprite.rotation = deg_to_rad(
				-90.0 if _legacy_visual.facing_label == &"west" else 90.0
			)


func _update_weapon() -> void:
	_weapon.self_modulate = _state_modulate() * _legacy_visual.self_modulate
	_weapon.update_presentation(_legacy_visual.facing_label, _animation_state, _state_elapsed)
	if _animation_state == PlayerVisual.MOVE_ANIMATION:
		# Keep the carried weapon attached to the bobbing body silhouette.
		_weapon.position.y += _move_bob_offset_y()


func _move_bob_offset_y() -> float:
	return sin(_elapsed * MOVE_BOB_FREQUENCY) * MOVE_BOB_HEIGHT_PX


func _update_facing_accent() -> void:
	_facing_accent.visible = _animation_state != PlayerVisual.DEATH_ANIMATION
	if not _facing_accent.visible:
		return
	match _legacy_visual.facing_label:
		&"north":
			_facing_accent.rotation = 0.0
		&"east":
			_facing_accent.rotation = PI * 0.5
		&"west":
			_facing_accent.rotation = -PI * 0.5
		_:
			_facing_accent.rotation = PI
	_facing_accent.color = (
		ACTION_FACING_ACCENT_COLOR
		if _animation_state in [PlayerVisual.DASH_ANIMATION, PlayerVisual.MELEE_ANIMATION, PlayerVisual.RELIC_ANIMATION]
		else FACING_ACCENT_COLOR
	)


func _state_modulate() -> Color:
	match _animation_state:
		PlayerVisual.HURT_ANIMATION:
			return HURT_TINT
		PlayerVisual.DEATH_ANIMATION:
			return DEAD_TINT
		_:
			return Color.WHITE
