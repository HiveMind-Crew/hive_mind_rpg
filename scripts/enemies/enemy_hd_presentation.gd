class_name EnemyHdPresentation
extends Node2D
## Static HD body adapter for the regular enemy roster. EnemyBase and each
## archetype remain the sole owners of movement, facing, combat state, shield
## direction, collision, and death. The hidden legacy AnimatedSprite2D stays
## alive as the authored animation/state driver while this adapter mirrors its
## live feedback onto the illustrated body.

const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const FACING_COLOR: Color = Color(0.95, 0.18, 0.85, 0.82)
const FACING_DISTANCE_RATIO: float = 0.34
const FACING_HALF_WIDTH_PX: float = 2.0
const FACING_LENGTH_PX: float = 5.0
const CHASE_BOB_HEIGHT_PX: float = 1.2
const CHASE_BOB_FREQUENCY: float = 10.0
const WINDUP_PULLBACK_PX: float = 2.5
const ATTACK_LUNGE_PX: float = 4.5
const STAGGER_RECOIL_PX: float = 3.0
const DEAD_FLATTEN: Vector2 = Vector2(1.12, 0.78)

@export var body_texture: Texture2D
@export_range(1.0, 128.0, 1.0) var display_height_px: float = 32.0
@export var body_offset: Vector2 = Vector2.ZERO
@export var legacy_visual_path: NodePath = NodePath("../BodyVisual")

var _enemy: EnemyBase
var _legacy_visual: AnimatedSprite2D
var _body_sprite: Sprite2D
var _facing_accent: Polygon2D
var _elapsed: float = 0.0
var _state_elapsed: float = 0.0


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	_legacy_visual = get_node_or_null(legacy_visual_path) as AnimatedSprite2D
	if _enemy == null or _legacy_visual == null or body_texture == null:
		push_error("EnemyHdPresentation requires an EnemyBase parent, legacy visual, and texture.")
		set_process(false)
		return

	_legacy_visual.visible = false
	_body_sprite = Sprite2D.new()
	_body_sprite.name = "Body"
	_body_sprite.texture = body_texture
	_body_sprite.texture_filter = HD_TEXTURE_FILTER
	_body_sprite.position = body_offset
	var visual_scale: float = display_height_px / float(body_texture.get_height())
	_body_sprite.scale = Vector2(visual_scale, visual_scale)
	add_child(_body_sprite)

	_facing_accent = Polygon2D.new()
	_facing_accent.name = "FacingAccent"
	_facing_accent.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(-FACING_LENGTH_PX, -FACING_HALF_WIDTH_PX),
		Vector2(-FACING_LENGTH_PX, FACING_HALF_WIDTH_PX),
	])
	_facing_accent.color = FACING_COLOR
	_facing_accent.show_behind_parent = true
	add_child(_facing_accent)
	_enemy.state_changed.connect(_on_enemy_state_changed)
	_apply_live_presentation()


func _process(delta: float) -> void:
	_elapsed += delta
	_state_elapsed += delta
	_apply_live_presentation()


func _on_enemy_state_changed(_previous_state: EnemyBase.State, _current_state: EnemyBase.State) -> void:
	_state_elapsed = 0.0


static func state_tint_for(state: EnemyBase.State) -> Color:
	match state:
		EnemyBase.State.WIND_UP:
			return EnemyBase.WIND_UP_COLOR
		EnemyBase.State.ATTACK:
			return EnemyBase.ATTACK_COLOR
		EnemyBase.State.STAGGER:
			return EnemyBase.STAGGER_COLOR
		EnemyBase.State.DEAD:
			return EnemyBase.DEAD_COLOR
		_:
			return Color.WHITE


func get_body_sprite() -> Sprite2D:
	return _body_sprite


func get_facing_accent() -> Polygon2D:
	return _facing_accent


func get_facing_direction() -> Vector2:
	var brute: ShieldedBrute = _enemy as ShieldedBrute
	if brute != null:
		return brute.get_facing()
	return _enemy._get_visual_facing_direction()


func _apply_live_presentation() -> void:
	if _body_sprite == null or _facing_accent == null:
		return
	var facing: Vector2 = get_facing_direction()
	_body_sprite.flip_h = facing.x < 0.0
	_body_sprite.self_modulate = _legacy_visual.self_modulate
	_body_sprite.modulate = state_tint_for(_enemy.state)
	_apply_state_pose(facing)
	_facing_accent.position = facing * display_height_px * FACING_DISTANCE_RATIO
	_facing_accent.rotation = facing.angle()
	_facing_accent.color = state_tint_for(_enemy.state) * FACING_COLOR
	_facing_accent.visible = _enemy.state != EnemyBase.State.DEAD


func _apply_state_pose(facing: Vector2) -> void:
	var base_scale: float = display_height_px / float(body_texture.get_height())
	_body_sprite.position = body_offset
	_body_sprite.scale = Vector2.ONE * base_scale
	_body_sprite.rotation = 0.0
	match _enemy.state:
		EnemyBase.State.CHASE:
			_body_sprite.position.y += sin(_elapsed * CHASE_BOB_FREQUENCY) * CHASE_BOB_HEIGHT_PX
			_body_sprite.rotation = sin(_elapsed * CHASE_BOB_FREQUENCY * 0.5) * deg_to_rad(2.0)
		EnemyBase.State.WIND_UP:
			_body_sprite.position -= facing * WINDUP_PULLBACK_PX
			_body_sprite.scale *= Vector2(0.92, 1.08)
		EnemyBase.State.ATTACK:
			_body_sprite.position += facing * ATTACK_LUNGE_PX
			_body_sprite.scale *= Vector2(1.08, 0.94)
		EnemyBase.State.STAGGER:
			_body_sprite.position -= facing * STAGGER_RECOIL_PX
			_body_sprite.rotation = deg_to_rad(8.0 if facing.x >= 0.0 else -8.0)
		EnemyBase.State.DEAD:
			_body_sprite.scale *= DEAD_FLATTEN
			_body_sprite.rotation = deg_to_rad(90.0 if facing.x >= 0.0 else -90.0)
