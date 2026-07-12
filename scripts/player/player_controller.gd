class_name PlayerController
extends CharacterBody2D

signal movement_state_changed(
	previous_state: PlayerMovementStateMachine.State,
	current_state: PlayerMovementStateMachine.State
)
signal dash_started()
signal dash_ended()
signal melee_swing_started(direction: Vector2)
signal melee_swing_ended()

@export_range(1.0, 1000.0, 1.0) var move_speed: float = 120.0
@export_range(1.0, 10000.0, 1.0) var acceleration: float = 1400.0
@export_range(1.0, 10000.0, 1.0) var friction: float = 1800.0
@export_range(1.0, 2000.0, 1.0) var dash_speed: float = 320.0
@export_range(0.01, 2.0, 0.01) var dash_duration: float = 0.14
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.45
@export_range(1, 1000, 1) var melee_damage: int = 1
@export_range(0.01, 2.0, 0.01) var melee_duration: float = 0.12
@export_range(1.0, 64.0, 1.0) var melee_hitbox_offset: float = 14.0
@export_range(0.0, 1.0, 0.01) var melee_hitstop_duration: float = 0.05
@export_range(0.01, 1.0, 0.01) var melee_hitstop_time_scale: float = 0.05

@onready var _hurtbox: Hurtbox = %Hurtbox
@onready var _melee_hitbox: Hitbox = %MeleeHitbox

var movement_state: PlayerMovementStateMachine.State:
	get:
		return _movement.state

# Shared across all players so overlapping hitstops nest instead of clobbering
# a time scale set elsewhere (pause, slow motion, another player's hitstop).
static var _active_hitstop_count: int = 0
static var _pre_hitstop_time_scale: float = 1.0

var _movement: PlayerMovementStateMachine
var _melee: PlayerMeleeAttack
var _hitstop_active: bool = false


func _ready() -> void:
	_movement = PlayerMovementStateMachine.new(
		move_speed,
		acceleration,
		friction,
		dash_speed,
		dash_duration,
		dash_cooldown
	)
	_movement.state_changed.connect(_on_movement_state_changed)
	_movement.dash_started.connect(_on_dash_started)
	_movement.dash_ended.connect(_on_dash_ended)
	_melee = PlayerMeleeAttack.new(melee_duration)
	_melee.swing_started.connect(_on_melee_swing_started)
	_melee.swing_ended.connect(_on_melee_swing_ended)
	_melee_hitbox.damage = melee_damage
	_melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	_movement.update(input_direction, Input.is_action_just_pressed(&"dash"), delta)
	velocity = _movement.velocity
	move_and_slide()
	_movement.finish_frame(input_direction)
	if Input.is_action_just_pressed(&"attack_melee"):
		try_melee_attack()
	_melee.update(delta)


func cancel_dash() -> void:
	_movement.cancel_dash()


func try_melee_attack() -> bool:
	return _melee.try_start_swing(_movement.last_move_direction)


func _exit_tree() -> void:
	if is_instance_valid(_movement):
		_movement.cancel_dash()
	if is_instance_valid(_melee):
		_melee.cancel_swing()
	_end_hitstop()


func _on_movement_state_changed(
	previous_state: PlayerMovementStateMachine.State,
	current_state: PlayerMovementStateMachine.State
) -> void:
	movement_state_changed.emit(previous_state, current_state)


func _on_dash_started() -> void:
	_hurtbox.set_enabled(false)
	dash_started.emit()


func _on_dash_ended() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.set_enabled(true)
	dash_ended.emit()


func _on_melee_swing_started(direction: Vector2) -> void:
	_melee_hitbox.position = direction * melee_hitbox_offset
	# Deferred: physics properties cannot safely change while an overlap query is flushing.
	_melee_hitbox.set_deferred("monitoring", true)
	melee_swing_started.emit(direction)


func _on_melee_swing_ended() -> void:
	if is_instance_valid(_melee_hitbox):
		_melee_hitbox.set_deferred("monitoring", false)
	melee_swing_ended.emit()


func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	var target_hurtbox: Hurtbox = area as Hurtbox
	if target_hurtbox == null or target_hurtbox == _hurtbox:
		return
	if not _melee.register_hit(target_hurtbox.get_instance_id()):
		return
	target_hurtbox.receive_hit(_melee_hitbox)
	_start_hitstop()


func _start_hitstop() -> void:
	if melee_hitstop_duration <= 0.0 or _hitstop_active:
		return
	_hitstop_active = true
	if _active_hitstop_count == 0:
		_pre_hitstop_time_scale = Engine.time_scale
		Engine.time_scale = melee_hitstop_time_scale
	_active_hitstop_count += 1
	var timer: SceneTreeTimer = get_tree().create_timer(
		melee_hitstop_duration, true, false, true
	)
	timer.timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	if not _hitstop_active:
		return
	_hitstop_active = false
	_active_hitstop_count = maxi(_active_hitstop_count - 1, 0)
	if _active_hitstop_count == 0:
		Engine.time_scale = _pre_hitstop_time_scale
