class_name EnemyHdPresentation
extends Node2D
## Static HD body adapter for the regular enemy roster. EnemyBase and each
## archetype remain the sole owners of movement, facing, combat state, shield
## direction, collision, and death. The hidden legacy AnimatedSprite2D stays
## alive as the authored animation/state driver while this adapter mirrors its
## live feedback onto the illustrated body.
##
## When `pose_atlas` is assigned in the scene, the body Sprite2D uses region
## selection to advance through the 6-row × 4-column deterministic atlas (rows:
## idle/chase/windup/attack/stagger/death; columns: frames 0-3 driven by
## `_state_elapsed`). The prior per-state transform bridge (pullback, lunge,
## recoil, death-flatten) is removed when the atlas owns the visual pose; the
## atlas generator bakes those silhouette reads directly into each frame.
##
## Directional handling: the pose atlas is authored as a single right-facing
## side portrait. Horizontal (left/right dominant) combat intent mirrors the
## body toward the target with the same convention the legacy regular-enemy
## side animations use (see EnemyBase._set_body_visual), so a left-targeting
## wind-up/attack lunge commits toward its target instead of away from it.
## Remaining limitation: the upright side art is never re-projected for
## vertical (up/down dominant) intent — flipping horizontally would say nothing
## there — so the body stays unflipped for up/down and the live facing accent
## remains the truthful cue for the vertical and diagonal cardinal component
## until dedicated cardinal pose rows are authored.

const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const FACING_COLOR: Color = Color(0.95, 0.18, 0.85, 0.82)
const FACING_DISTANCE_RATIO: float = 0.34
const FACING_HALF_WIDTH_PX: float = 2.0
const FACING_LENGTH_PX: float = 5.0
## Legacy transform-bridge constants — used only when no pose_atlas is assigned.
const CHASE_BOB_HEIGHT_PX: float = 1.2
const CHASE_BOB_FREQUENCY: float = 10.0
const WINDUP_PULLBACK_PX: float = 2.5
const ATTACK_LUNGE_PX: float = 4.5
const STAGGER_RECOIL_PX: float = 3.0
const DEAD_FLATTEN: Vector2 = Vector2(1.12, 0.78)
## Atlas layout: 6 state rows × 4 frame columns (issue #204 generator contract).
const ATLAS_ROWS: int = 6
const ATLAS_COLUMNS: int = 4
const ATLAS_ROW_IDLE: int = 0
const ATLAS_ROW_CHASE: int = 1
const ATLAS_ROW_WINDUP: int = 2
const ATLAS_ROW_ATTACK: int = 3
const ATLAS_ROW_STAGGER: int = 4
const ATLAS_ROW_DEATH: int = 5
## Per-frame display duration. Looping states (idle, chase, recovery) cycle
## through all four frames; non-looping states hold at frame 3. These visual
## phases never extend or own any gameplay state machine timing.
const POSE_FRAME_SECONDS: float = 0.10

@export var body_texture: Texture2D
@export var pose_atlas: Texture2D
## The generator centers an 80 px-tall portrait in each 128 px pose cell so
## telegraph transforms keep transparent safety margins. Scale the atlas from
## this visible content height, not the padded region height.
@export_range(1.0, 128.0, 1.0) var pose_content_height_px: float = 80.0
@export_range(1.0, 128.0, 1.0) var display_height_px: float = 32.0
@export var body_offset: Vector2 = Vector2.ZERO
@export var legacy_visual_path: NodePath = NodePath("../BodyVisual")

var _enemy: EnemyBase
var _legacy_visual: AnimatedSprite2D
var _body_sprite: Sprite2D
var _facing_accent: Polygon2D
var _elapsed: float = 0.0
var _state_elapsed: float = 0.0
var _cell_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	_legacy_visual = get_node_or_null(legacy_visual_path) as AnimatedSprite2D
	if _enemy == null or _legacy_visual == null:
		push_error("EnemyHdPresentation requires an EnemyBase parent and legacy visual.")
		set_process(false)
		return
	if pose_atlas == null and body_texture == null:
		push_error("EnemyHdPresentation requires either pose_atlas or body_texture.")
		set_process(false)
		return

	_legacy_visual.visible = false
	_body_sprite = Sprite2D.new()
	_body_sprite.name = "Body"
	_body_sprite.texture_filter = HD_TEXTURE_FILTER
	_body_sprite.position = body_offset

	if pose_atlas != null:
		_cell_size = Vector2(
			float(pose_atlas.get_width()) / float(ATLAS_COLUMNS),
			float(pose_atlas.get_height()) / float(ATLAS_ROWS),
		)
		_body_sprite.texture = pose_atlas
		_body_sprite.region_enabled = true
		_body_sprite.region_rect = _atlas_region_for(ATLAS_ROW_IDLE, 0)
		_body_sprite.scale = Vector2.ONE * (display_height_px / pose_content_height_px)
	else:
		_body_sprite.texture = body_texture
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


static func state_to_atlas_row(state: EnemyBase.State) -> int:
	match state:
		EnemyBase.State.IDLE:
			return ATLAS_ROW_IDLE
		EnemyBase.State.CHASE:
			return ATLAS_ROW_CHASE
		EnemyBase.State.WIND_UP:
			return ATLAS_ROW_WINDUP
		EnemyBase.State.ATTACK:
			return ATLAS_ROW_ATTACK
		EnemyBase.State.RECOVERY:
			return ATLAS_ROW_IDLE  # safe idle visual; RECOVERY is gameplay-only, no dedicated row
		EnemyBase.State.STAGGER:
			return ATLAS_ROW_STAGGER
		EnemyBase.State.DEAD:
			return ATLAS_ROW_DEATH
		_:
			return ATLAS_ROW_IDLE


static func state_loops_frames(state: EnemyBase.State) -> bool:
	match state:
		EnemyBase.State.IDLE, EnemyBase.State.CHASE, EnemyBase.State.RECOVERY:
			return true
		_:
			return false


func get_body_sprite() -> Sprite2D:
	return _body_sprite


func get_facing_accent() -> Polygon2D:
	return _facing_accent


func get_facing_direction() -> Vector2:
	var brute: ShieldedBrute = _enemy as ShieldedBrute
	if brute != null:
		return brute.get_facing()
	return _enemy._get_visual_facing_direction()


func _body_faces_left(facing: Vector2) -> bool:
	# Mirror the side-authored body only when horizontal intent dominates, matching
	# the legacy regular-enemy `_side` rule in EnemyBase._set_body_visual. Up/down
	# dominant intent returns false so the upright art is never flipped into a
	# meaningless mirror and no stale left flip carries across a vertical turn.
	return absf(facing.x) > absf(facing.y) and facing.x < 0.0


func _atlas_region_for(row: int, col: int) -> Rect2:
	return Rect2(
		Vector2(_cell_size.x * float(col), _cell_size.y * float(row)),
		_cell_size,
	)


func _atlas_column() -> int:
	if state_loops_frames(_enemy.state):
		return int(_state_elapsed / POSE_FRAME_SECONDS) % ATLAS_COLUMNS
	return mini(int(_state_elapsed / POSE_FRAME_SECONDS), ATLAS_COLUMNS - 1)


func _apply_live_presentation() -> void:
	if _body_sprite == null or _facing_accent == null:
		return
	var facing: Vector2 = get_facing_direction()
	# Horizontal combat intent mirrors the side-authored body toward the target
	# (legacy regular-enemy `_side` convention); vertical intent never flips, so
	# an up/down transition cannot retain a stale left mirror. The accent still
	# carries the full cardinal facing for the un-mirrorable vertical component.
	_body_sprite.flip_h = _body_faces_left(facing)
	_body_sprite.self_modulate = _legacy_visual.self_modulate
	_body_sprite.modulate = state_tint_for(_enemy.state)
	if pose_atlas != null:
		_apply_atlas_frame()
	else:
		_apply_state_pose(facing)
	_facing_accent.position = facing * display_height_px * FACING_DISTANCE_RATIO
	_facing_accent.rotation = facing.angle()
	_facing_accent.color = state_tint_for(_enemy.state) * FACING_COLOR
	_facing_accent.visible = _enemy.state != EnemyBase.State.DEAD


func _apply_atlas_frame() -> void:
	var row: int = state_to_atlas_row(_enemy.state)
	var col: int = _atlas_column()
	_body_sprite.region_rect = _atlas_region_for(row, col)
	_body_sprite.scale = Vector2.ONE * (display_height_px / pose_content_height_px)
	_body_sprite.position = body_offset
	_body_sprite.rotation = 0.0


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
