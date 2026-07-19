class_name PlayerHdPresentation
extends Node2D
## HD player display layer for issues #150/#165. It mirrors the existing
## PlayerVisual state driver instead of taking ownership of movement, combat,
## collision, or health. The body texture is a four-cell directional atlas
## curated from non-commercial Flux prototype output; see
## assets/sprites/LICENSES.md before distributing it beyond this project.

const ATLAS_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_directional_atlas.png")
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const ATLAS_CELL_SIZE: Vector2 = Vector2(256.0, 256.0)
## Opaque art height inside every atlas cell (curation contract in
## tools/curate_player_directional_atlas.py); the rest is safe transparent border.
const ATLAS_CONTENT_HEIGHT_PX: float = 190.0
## Facing label → atlas column. West is authored art (mirrored side pose baked
## into the atlas), not a runtime flip, so all four reads stay distinct.
const DIRECTION_ATLAS_COLUMNS: Dictionary[StringName, int] = {
	&"north": 0,
	&"east": 1,
	&"south": 2,
	&"west": 3,
}
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
var _animation_state: StringName = PlayerVisual.IDLE_ANIMATION
var _elapsed: float = 0.0


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
	if _legacy_visual == null:
		return
	_update_atlas_region()
	_display_sprite.self_modulate = _state_modulate() * _legacy_visual.self_modulate
	_apply_state_pose()
	_update_facing_accent()


func get_display_sprite() -> Sprite2D:
	_ensure_display_nodes()
	return _display_sprite


func _ensure_display_nodes() -> void:
	if _display_sprite != null:
		return
	_display_sprite = _create_display_sprite()
	_contact_shadow = _create_contact_shadow()
	_facing_accent = _create_facing_accent()
	add_child(_contact_shadow)
	add_child(_display_sprite)
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
	_animation_state = next_state


func _base_scale() -> float:
	return DISPLAY_HEIGHT_PX / ATLAS_CONTENT_HEIGHT_PX


func _atlas_region_for(facing: StringName) -> Rect2:
	var column: int = DIRECTION_ATLAS_COLUMNS.get(facing, DIRECTION_ATLAS_COLUMNS[&"south"])
	return Rect2(Vector2(ATLAS_CELL_SIZE.x * float(column), 0.0), ATLAS_CELL_SIZE)


func _update_atlas_region() -> void:
	_display_sprite.region_rect = _atlas_region_for(_legacy_visual.facing_label)


func _apply_state_pose() -> void:
	_display_sprite.scale = Vector2.ONE * _base_scale()
	_display_sprite.position = BODY_POSITION
	_display_sprite.rotation = 0.0
	match _animation_state:
		PlayerVisual.MOVE_ANIMATION:
			# Presentation-only gait: vertical bob plus a half-frequency lean so
			# locomotion reads alive without touching movement timing.
			_display_sprite.position.y += sin(_elapsed * MOVE_BOB_FREQUENCY) * MOVE_BOB_HEIGHT_PX
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
