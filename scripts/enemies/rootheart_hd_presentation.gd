class_name RootheartHdPresentation
extends Node2D
## Presentation-only adapter for the Rootheart Colossus (issues #155/#205).
## BossBase and RootheartColossus remain the sole owners of phase, combat
## state, attack timing, burst spawning, collision, rewards, and defeat. This
## node mirrors those live signals onto the illustrated body and threat cues.

const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const BODY_DISPLAY_HEIGHT_PX: float = 96.0
const BODY_OFFSET: Vector2 = Vector2(0.0, -16.0)
## Rootheart pose sheets are three 256px cells across by eight state rows.
## Their 176px opaque portrait box, rather than their transparent cell border,
## defines the existing 96px on-screen body contract.
const POSE_CELL_SIZE: Vector2 = Vector2(256.0, 256.0)
const POSE_CONTENT_HEIGHT_PX: float = 176.0
const POSE_FRAME_COUNT: int = 3
const POSE_FRAME_DURATION_SECONDS: float = 0.12
const POSE_BURST_DURATION_SECONDS: float = 0.36
## Rootheart has poise, so a real accepted hit must not require STAGGER.
const HIT_POSE_DURATION_SECONDS: float = 0.14
enum PoseRow {
	DORMANT,
	AWAKENING,
	WINDUP,
	CONTACT,
	RECOVERY,
	BURST,
	HIT,
	DEFEAT,
}
const SLAM_TELL_DIAMETER_PX: float = 78.0
const RADIAL_CUE_DIAMETER_PX: float = 68.0
const RADIAL_PULSE_DURATION_SECONDS: float = 0.36
const CONTACT_SHADOW_COLOR: Color = Color(0.04, 0.035, 0.055, 0.48)
const CONTACT_SHADOW_RADIUS: Vector2 = Vector2(25.0, 10.0)
const CONTACT_SHADOW_POINT_COUNT: int = 20

@export var phase_one_texture: Texture2D
@export var phase_two_texture: Texture2D
@export var slam_tell_texture: Texture2D
@export var radial_burst_texture: Texture2D
@export var legacy_body_path: NodePath = NodePath("../BodyVisual")
@export var legacy_tell_path: NodePath = NodePath("../TellVisual")

var _boss: RootheartColossus
var _legacy_body: CanvasItem
var _legacy_tell: CanvasItem
var _contact_shadow: Polygon2D
var _phase_one_body: Sprite2D
var _phase_two_body: Sprite2D
var _slam_tell: Sprite2D
var _radial_cue: Sprite2D
var _radial_tween: Tween
var _pose_state_elapsed: float = 0.0
var _burst_pose_elapsed: float = 0.0
var _hit_pose_elapsed: float = 0.0
var _last_known_health: int = 0


func _ready() -> void:
	_boss = get_parent() as RootheartColossus
	_legacy_body = get_node_or_null(legacy_body_path) as CanvasItem
	_legacy_tell = get_node_or_null(legacy_tell_path) as CanvasItem
	if (
		_boss == null or _legacy_body == null or _legacy_tell == null
		or phase_one_texture == null or phase_two_texture == null
		or slam_tell_texture == null or radial_burst_texture == null
	):
		push_error("RootheartHdPresentation requires its boss, legacy visuals, and four textures.")
		set_process(false)
		return

	_legacy_body.visible = false
	_legacy_tell.visible = false
	_contact_shadow = _build_contact_shadow()
	add_child(_contact_shadow)
	_phase_one_body = _build_sprite(
		"PhaseOneBody", phase_one_texture, BODY_DISPLAY_HEIGHT_PX, BODY_OFFSET
	)
	_phase_two_body = _build_sprite(
		"PhaseTwoBody", phase_two_texture, BODY_DISPLAY_HEIGHT_PX, BODY_OFFSET
	)
	_slam_tell = _build_effect_sprite(
		"SlamTell", slam_tell_texture, SLAM_TELL_DIAMETER_PX, Vector2.ZERO
	)
	_slam_tell.show_behind_parent = true
	_radial_cue = _build_effect_sprite(
		"RadialBurstCue", radial_burst_texture, RADIAL_CUE_DIAMETER_PX, Vector2.ZERO
	)
	_radial_cue.show_behind_parent = true
	_radial_cue.visible = false

	_boss.phase_changed.connect(_on_phase_changed)
	_boss.state_changed.connect(_on_state_changed)
	# HealthComponent is a later sibling in the packed scene, so defer the
	# feedback hookup until every child and the parent @onready fields exist.
	call_deferred("_connect_health_feedback")
	_apply_live_state()


func _connect_health_feedback() -> void:
	if _boss == null or _boss.health == null:
		push_error("RootheartHdPresentation requires the boss HealthComponent.")
		return
	_last_known_health = _boss.health.current_health
	_boss.health.health_changed.connect(_on_health_changed)


func _process(_delta: float) -> void:
	# Reset-to-checkpoint restores phase after EnemyBase emits its state change,
	# so sample the authoritative boss state each frame instead of caching it.
	_pose_state_elapsed += _delta
	_burst_pose_elapsed = maxf(_burst_pose_elapsed - _delta, 0.0)
	_hit_pose_elapsed = maxf(_hit_pose_elapsed - _delta, 0.0)
	_apply_live_state()


func _on_health_changed(current_health: int, _maximum_health: int) -> void:
	# Health changes are the real accepted-hit boundary for a poised boss. This
	# is visual-only: BossBase still owns damage, phase changes, and poise.
	if current_health < _last_known_health and current_health > 0:
		_hit_pose_elapsed = HIT_POSE_DURATION_SECONDS
	_last_known_health = current_health
	_apply_live_state()


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


func get_phase_one_body() -> Sprite2D:
	return _phase_one_body


func get_phase_two_body() -> Sprite2D:
	return _phase_two_body


func get_slam_tell() -> Sprite2D:
	return _slam_tell


func get_radial_cue() -> Sprite2D:
	return _radial_cue


func get_contact_shadow() -> Polygon2D:
	return _contact_shadow


static func pose_row_for(state: EnemyBase.State, burst_active: bool) -> PoseRow:
	# Defeat always wins over a cue that began earlier in the same gameplay frame.
	if state == EnemyBase.State.DEAD:
		return PoseRow.DEFEAT
	if burst_active:
		return PoseRow.BURST
	match state:
		EnemyBase.State.IDLE:
			return PoseRow.DORMANT
		EnemyBase.State.CHASE:
			return PoseRow.AWAKENING
		EnemyBase.State.WIND_UP:
			return PoseRow.WINDUP
		EnemyBase.State.ATTACK:
			return PoseRow.CONTACT
		EnemyBase.State.RECOVERY:
			return PoseRow.RECOVERY
		EnemyBase.State.STAGGER:
			return PoseRow.HIT
		EnemyBase.State.DEAD:
			return PoseRow.DEFEAT
		_:
			return PoseRow.DORMANT


static func pose_region_for(row: PoseRow, frame: int) -> Rect2:
	var clamped_frame: int = clampi(frame, 0, POSE_FRAME_COUNT - 1)
	return Rect2(
		Vector2(POSE_CELL_SIZE.x * float(clamped_frame), POSE_CELL_SIZE.y * float(row)),
		POSE_CELL_SIZE,
	)


func _build_sprite(
	sprite_name: StringName,
	texture: Texture2D,
	target_height_px: float,
	offset: Vector2,
) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.region_enabled = true
	sprite.region_rect = pose_region_for(PoseRow.DORMANT, 0)
	sprite.position = offset
	var visual_scale: float = target_height_px / POSE_CONTENT_HEIGHT_PX
	sprite.scale = Vector2(visual_scale, visual_scale)
	add_child(sprite)
	return sprite


func _build_effect_sprite(
	sprite_name: StringName,
	texture: Texture2D,
	target_height_px: float,
	offset: Vector2,
) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.position = offset
	var visual_scale: float = target_height_px / float(texture.get_height())
	sprite.scale = Vector2(visual_scale, visual_scale)
	add_child(sprite)
	return sprite


func _build_contact_shadow() -> Polygon2D:
	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = "ContactShadow"
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in CONTACT_SHADOW_POINT_COUNT:
		var angle: float = TAU * float(index) / float(CONTACT_SHADOW_POINT_COUNT)
		points.append(Vector2(cos(angle), sin(angle)) * CONTACT_SHADOW_RADIUS)
	shadow.polygon = points
	shadow.color = CONTACT_SHADOW_COLOR
	shadow.position = Vector2(0.0, 13.0)
	shadow.show_behind_parent = true
	return shadow


func _apply_live_state() -> void:
	if _phase_one_body == null or _phase_two_body == null or _slam_tell == null:
		return
	var phase_two_active: bool = _boss.get_phase() >= 1
	_phase_one_body.visible = not phase_two_active
	_phase_two_body.visible = phase_two_active
	# The phase/burst channel must keep precedence when its health loss is also
	# an accepted hit; otherwise the hit recoil masks the phase-transition cue.
	var hit_pose_active: bool = (
		_hit_pose_elapsed > 0.0
		and _burst_pose_elapsed <= 0.0
		and _boss.state != EnemyBase.State.DEAD
	)
	var state_tint: Color = EnemyBase.STAGGER_COLOR if hit_pose_active else state_tint_for(_boss.state)
	_phase_one_body.modulate = state_tint
	_phase_two_body.modulate = state_tint
	_phase_one_body.self_modulate = _legacy_body.self_modulate
	_phase_two_body.self_modulate = _legacy_body.self_modulate
	var pose_row: PoseRow = pose_row_for(_boss.state, _burst_pose_elapsed > 0.0)
	if hit_pose_active:
		pose_row = PoseRow.HIT
	var pose_frame: int = _pose_frame_for(pose_row)
	var pose_region: Rect2 = pose_region_for(pose_row, pose_frame)
	_phase_one_body.region_rect = pose_region
	_phase_two_body.region_rect = pose_region
	_slam_tell.visible = _boss.state == EnemyBase.State.WIND_UP
	_contact_shadow.visible = _boss.state != EnemyBase.State.DEAD
	if _boss.state == EnemyBase.State.DEAD:
		_stop_radial_pulse()


func _on_phase_changed(_previous_phase: int, current_phase: int) -> void:
	if current_phase >= 1:
		_start_burst_pose()
		_play_radial_pulse()
	_apply_live_state()


func _on_state_changed(previous_state: EnemyBase.State, current_state: EnemyBase.State) -> void:
	if (
		previous_state == EnemyBase.State.ATTACK
		and current_state == EnemyBase.State.RECOVERY
		and _boss.get_phase() >= 1
	):
		_start_burst_pose()
		_play_radial_pulse()
	_pose_state_elapsed = 0.0
	_apply_live_state()


func _pose_frame_for(row: PoseRow) -> int:
	if row == PoseRow.DEFEAT:
		return POSE_FRAME_COUNT - 1
	return int(floor(_pose_state_elapsed / POSE_FRAME_DURATION_SECONDS)) % POSE_FRAME_COUNT


func _start_burst_pose() -> void:
	_burst_pose_elapsed = POSE_BURST_DURATION_SECONDS
	_pose_state_elapsed = 0.0


func _play_radial_pulse() -> void:
	if _radial_tween != null and _radial_tween.is_valid():
		_radial_tween.kill()
	_radial_cue.visible = true
	_radial_cue.scale = Vector2.ONE * (
		RADIAL_CUE_DIAMETER_PX / float(radial_burst_texture.get_height()) * 0.72
	)
	_radial_cue.modulate = Color.WHITE
	var target_scale: Vector2 = Vector2.ONE * (
		RADIAL_CUE_DIAMETER_PX / float(radial_burst_texture.get_height()) * 1.18
	)
	_radial_tween = create_tween().set_parallel()
	_radial_tween.tween_property(
		_radial_cue, "scale", target_scale, RADIAL_PULSE_DURATION_SECONDS
	)
	_radial_tween.tween_property(
		_radial_cue, "modulate:a", 0.0, RADIAL_PULSE_DURATION_SECONDS
	)
	_radial_tween.chain().tween_callback(_radial_cue.hide)


func _stop_radial_pulse() -> void:
	if _radial_tween != null and _radial_tween.is_valid():
		_radial_tween.kill()
	_radial_cue.visible = false
