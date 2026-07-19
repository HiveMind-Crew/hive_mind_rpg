class_name RootheartHdPresentation
extends Node2D
## Presentation-only adapter for the Rootheart Colossus (issue #155).
## BossBase and RootheartColossus remain the sole owners of phase, combat
## state, attack timing, burst spawning, collision, rewards, and defeat. This
## node mirrors those live signals onto the illustrated body and threat cues.

const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const BODY_DISPLAY_HEIGHT_PX: float = 96.0
const BODY_OFFSET: Vector2 = Vector2(0.0, -16.0)
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
	_slam_tell = _build_sprite(
		"SlamTell", slam_tell_texture, SLAM_TELL_DIAMETER_PX, Vector2.ZERO
	)
	_slam_tell.show_behind_parent = true
	_radial_cue = _build_sprite(
		"RadialBurstCue", radial_burst_texture, RADIAL_CUE_DIAMETER_PX, Vector2.ZERO
	)
	_radial_cue.show_behind_parent = true
	_radial_cue.visible = false

	_boss.phase_changed.connect(_on_phase_changed)
	_boss.state_changed.connect(_on_state_changed)
	_apply_live_state()


func _process(_delta: float) -> void:
	# Reset-to-checkpoint restores phase after EnemyBase emits its state change,
	# so sample the authoritative boss state each frame instead of caching it.
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
	var state_tint: Color = state_tint_for(_boss.state)
	_phase_one_body.modulate = state_tint
	_phase_two_body.modulate = state_tint
	_phase_one_body.self_modulate = _legacy_body.self_modulate
	_phase_two_body.self_modulate = _legacy_body.self_modulate
	_slam_tell.visible = _boss.state == EnemyBase.State.WIND_UP
	_contact_shadow.visible = _boss.state != EnemyBase.State.DEAD
	if _boss.state == EnemyBase.State.DEAD:
		_stop_radial_pulse()


func _on_phase_changed(_previous_phase: int, current_phase: int) -> void:
	if current_phase >= 1:
		_play_radial_pulse()
	_apply_live_state()


func _on_state_changed(previous_state: EnemyBase.State, current_state: EnemyBase.State) -> void:
	if (
		previous_state == EnemyBase.State.ATTACK
		and current_state == EnemyBase.State.RECOVERY
		and _boss.get_phase() >= 1
	):
		_play_radial_pulse()
	_apply_live_state()


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
