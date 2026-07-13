extends Node2D

enum Phase {
	INTRO,
	APPROACH,
	MELEE,
	RETREAT,
	RELIC_AIM,
	TAKE_HIT,
	SHOW_INVULNERABILITY,
	FINISH,
	VICTORY,
}

const CAPTURE_DIR_ENV: String = "HIVE_MIND_CAPTURE_DIR"
const DEFAULT_CAPTURE_DIR: String = "user://combat_feedback_gameplay"
const MAX_CAPTURE_FRAMES: int = 1200
const MELEE_RETRY_INTERVAL: float = 0.45

@onready var _player: PlayerController = $Player
@onready var _enemy: EnemyBase = $MeleeChaser
@onready var _phase_label: Label = $UI/Panel/Margin/VBox/Phase
@onready var _guide_label: Label = $UI/Panel/Margin/VBox/Guide
@onready var _status_label: Label = $UI/Panel/Margin/VBox/Status
@onready var _enemy_feedback: CombatFeedback = $MeleeChaser/CombatFeedback
@onready var _player_feedback: CombatFeedback = $Player/CombatFeedback

var _phase: Phase = Phase.INTRO
var _phase_elapsed: float = 0.0
var _frame_count: int = 0
var _dash_used: bool = false
var _attack_cooldown: float = 0.0
var _relic_fired: bool = false
var _tap_action: StringName = &""
var _tap_frames_remaining: int = 0
var _captured_melee: bool = false
var _captured_relic: bool = false
var _captured_player_hit: bool = false
var _captured_death: bool = false
var _capture_dir: String = DEFAULT_CAPTURE_DIR


func _ready() -> void:
	var configured_capture_dir: String = OS.get_environment(CAPTURE_DIR_ENV)
	if not configured_capture_dir.is_empty():
		_capture_dir = configured_capture_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	_enemy.set_physics_process(false)
	_enemy.health.invulnerability_duration = 0.18
	_player.health.invulnerability_duration = 0.55
	_enemy_feedback.hit_feedback_started.connect(_on_enemy_feedback_started)
	_enemy_feedback.death_feedback_started.connect(_on_enemy_death_feedback_started)
	_player_feedback.hit_feedback_started.connect(_on_player_feedback_started)
	_set_phase_copy(
		"COMBAT FEEDBACK AUTOPILOT",
		"Goal: approach, dash, melee, reposition, cast relic, read the tell, then finish.")


func _physics_process(delta: float) -> void:
	_frame_count += 1
	_phase_elapsed += maxf(delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_update_tap_release()
	_update_status()
	if _frame_count >= MAX_CAPTURE_FRAMES:
		_shutdown("Safety timeout reached")
		return

	match _phase:
		Phase.INTRO:
			if _phase_elapsed >= 1.0:
				_transition_to(Phase.APPROACH)
		Phase.APPROACH:
			_approach_enemy(true)
			if _distance_to_enemy() <= 34.0:
				_clear_movement()
				_transition_to(Phase.MELEE)
		Phase.MELEE:
			_face_enemy()
			if _attack_cooldown <= 0.0:
				_tap(&"attack_melee")
				_attack_cooldown = MELEE_RETRY_INTERVAL
			if _enemy.health.current_health <= 3:
				_transition_to(Phase.RETREAT)
		Phase.RETREAT:
			_set_horizontal_movement(-1.0)
			if _phase_elapsed >= 0.75:
				_clear_movement()
				_transition_to(Phase.RELIC_AIM)
		Phase.RELIC_AIM:
			if _phase_elapsed < 0.12:
				_set_horizontal_movement(1.0)
			elif not _relic_fired:
				_clear_movement()
				_tap(&"ability_relic")
				_relic_fired = true
			if _enemy.health.current_health <= 2:
				_enemy.set_physics_process(true)
				_enemy.set_target(_player)
				_transition_to(Phase.TAKE_HIT)
		Phase.TAKE_HIT:
			if _distance_to_enemy() > 25.0:
				_approach_enemy(false)
			else:
				_clear_movement()
			if _player.health.current_health < _player.health.max_health:
				_clear_movement()
				_transition_to(Phase.SHOW_INVULNERABILITY)
		Phase.SHOW_INVULNERABILITY:
			_clear_movement()
			if _phase_elapsed >= 0.8:
				_transition_to(Phase.FINISH)
		Phase.FINISH:
			if _enemy.state == EnemyBase.State.DEAD:
				_clear_movement()
				_transition_to(Phase.VICTORY)
			elif _distance_to_enemy() > 34.0:
				_approach_enemy(false)
			else:
				_clear_movement()
				_face_enemy()
				if _attack_cooldown <= 0.0:
					_tap(&"attack_melee")
					_attack_cooldown = MELEE_RETRY_INTERVAL
		Phase.VICTORY:
			_clear_movement()
			if _phase_elapsed >= 1.5:
				_shutdown("Capture complete")


func _transition_to(next_phase: Phase) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0
	match _phase:
		Phase.APPROACH:
			_set_phase_copy("1 · APPROACH + DASH", "Close distance under player input; dash once to engage.")
		Phase.MELEE:
			_set_phase_copy("2 · MELEE IMPACT", "Warm steel flash, short knockback, readable stagger.")
		Phase.RETREAT:
			_set_phase_copy("3 · REPOSITION", "Create space before changing tools.")
		Phase.RELIC_AIM:
			_set_phase_copy("4 · RELIC IMPACT", "Face the target and fire: cyan tech flash, stronger knockback.")
		Phase.TAKE_HIT:
			_set_phase_copy("5 · READ THE ENEMY", "Stop attacking, enter range, and let the telegraph resolve.")
		Phase.SHOW_INVULNERABILITY:
			_set_phase_copy("6 · PLAYER HIT + I-FRAMES", "Red impact flash transitions into a visible invulnerability pulse.")
		Phase.FINISH:
			_set_phase_copy("7 · FINISH THE FIGHT", "Re-engage with melee while respecting recovery windows.")
		Phase.VICTORY:
			_set_phase_copy("8 · DEFEATED", "Persistent death tint keeps the outcome readable.")


func _approach_enemy(allow_dash: bool) -> void:
	var direction: float = signf(_enemy.global_position.x - _player.global_position.x)
	_set_horizontal_movement(direction)
	if allow_dash and not _dash_used and _phase_elapsed >= 0.25:
		_tap(&"dash")
		_dash_used = true


func _face_enemy() -> void:
	var direction: float = signf(_enemy.global_position.x - _player.global_position.x)
	_set_horizontal_movement(direction)
	# Keep authored movement held while attacking. Collision keeps the actors
	# separated, and the input remains visible regardless of node process order.


func _set_horizontal_movement(direction: float) -> void:
	if direction < 0.0:
		Input.action_press(&"move_left")
		Input.action_release(&"move_right")
	else:
		Input.action_press(&"move_right")
		Input.action_release(&"move_left")


func _clear_movement() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")


func _tap(action: StringName) -> void:
	if not _tap_action.is_empty():
		return
	_tap_action = action
	_tap_frames_remaining = 1
	Input.action_press(action)


func _update_tap_release() -> void:
	if _tap_action.is_empty():
		return
	_tap_frames_remaining -= 1
	if _tap_frames_remaining > 0:
		return
	Input.action_release(_tap_action)
	_tap_action = &""


func _distance_to_enemy() -> float:
	return _player.global_position.distance_to(_enemy.global_position)


func _update_status() -> void:
	_status_label.text = "Player HP %d/%d   ·   Enemy HP %d/%d   ·   Distance %.0f px" % [
		_player.health.current_health,
		_player.health.max_health,
		_enemy.health.current_health,
		_enemy.health.max_health,
		_distance_to_enemy(),
	]


func _set_phase_copy(title: String, guide: String) -> void:
	_phase_label.text = title
	_guide_label.text = guide


func _on_enemy_feedback_started(impact_type: int) -> void:
	if impact_type == Hitbox.ImpactType.MELEE and not _captured_melee:
		_captured_melee = true
		_capture_after_draw("01_melee_impact.png")
	elif impact_type == Hitbox.ImpactType.RELIC and not _captured_relic:
		_captured_relic = true
		_capture_after_draw("02_relic_impact.png")


func _on_player_feedback_started(_impact_type: int) -> void:
	if _captured_player_hit:
		return
	_captured_player_hit = true
	_capture_after_draw("03_player_hit.png")


func _on_enemy_death_feedback_started() -> void:
	if _captured_death:
		return
	_captured_death = true
	_capture_after_draw("04_enemy_death.png")


func _capture_after_draw(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var capture_path: String = ProjectSettings.globalize_path(_capture_dir.path_join(file_name))
	var error: Error = image.save_png(capture_path)
	if error != OK:
		push_error("Could not save capture frame '%s': %s" % [file_name, error_string(error)])


func _shutdown(message: String) -> void:
	_clear_movement()
	if not _tap_action.is_empty():
		Input.action_release(_tap_action)
	_phase_label.text = message
	get_tree().quit()
