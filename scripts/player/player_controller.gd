class_name PlayerController
extends CharacterBody2D

signal movement_state_changed(
	previous_state: PlayerMovementStateMachine.State,
	current_state: PlayerMovementStateMachine.State
)
signal dash_started()
signal dash_ended()

@export_range(1.0, 1000.0, 1.0) var move_speed: float = 120.0
@export_range(1.0, 10000.0, 1.0) var acceleration: float = 1400.0
@export_range(1.0, 10000.0, 1.0) var friction: float = 1800.0
@export_range(1.0, 2000.0, 1.0) var dash_speed: float = 320.0
@export_range(0.01, 2.0, 0.01) var dash_duration: float = 0.14
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.45

@onready var _hurtbox: Hurtbox = %Hurtbox

var movement_state: PlayerMovementStateMachine.State:
	get:
		return _movement.state

var _movement: PlayerMovementStateMachine


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


func cancel_dash() -> void:
	_movement.cancel_dash()


func _exit_tree() -> void:
	if is_instance_valid(_movement):
		_movement.cancel_dash()


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
