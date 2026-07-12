class_name PlayerMovementStateMachine
extends RefCounted

signal state_changed(previous_state: State, current_state: State)
signal dash_started()
signal dash_ended()

enum State {
	IDLE,
	MOVE,
	DASH,
}

var state: State = State.IDLE
var velocity: Vector2 = Vector2.ZERO
var dash_cooldown_remaining: float:
	get:
		return _dash_cooldown_remaining
var last_move_direction: Vector2:
	get:
		return _last_move_direction

var _move_speed: float
var _acceleration: float
var _friction: float
var _dash_speed: float
var _dash_duration: float
var _dash_cooldown: float
var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_direction: Vector2 = Vector2.DOWN
var _last_move_direction: Vector2 = Vector2.DOWN
var _dash_finishes_after_frame: bool = false


func _init(
	move_speed: float,
	acceleration: float,
	friction: float,
	dash_speed: float,
	dash_duration: float,
	dash_cooldown: float
) -> void:
	_move_speed = maxf(move_speed, 0.0)
	_acceleration = maxf(acceleration, 0.0)
	_friction = maxf(friction, 0.0)
	_dash_speed = maxf(dash_speed, 0.0)
	_dash_duration = maxf(dash_duration, 0.0)
	_dash_cooldown = maxf(dash_cooldown, 0.0)


func update(input_direction: Vector2, dash_requested: bool, delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	var direction: Vector2 = input_direction.limit_length(1.0)
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - safe_delta, 0.0)

	if state == State.DASH:
		_update_dash(direction, safe_delta)
		return

	if not direction.is_zero_approx():
		_last_move_direction = direction.normalized()

	if dash_requested and _dash_cooldown_remaining <= 0.0:
		_start_dash(direction)
		_update_dash(direction, safe_delta)
		return

	_update_ground_movement(direction, safe_delta)


func finish_frame(input_direction: Vector2) -> void:
	if state != State.DASH or not _dash_finishes_after_frame:
		return
	_dash_finishes_after_frame = false
	var direction: Vector2 = input_direction.limit_length(1.0)
	if not direction.is_zero_approx():
		_last_move_direction = direction.normalized()
	velocity = direction * _move_speed
	dash_ended.emit()
	_set_state(State.IDLE if direction.is_zero_approx() else State.MOVE)


func cancel_dash() -> void:
	if state != State.DASH:
		return
	_dash_time_remaining = 0.0
	_dash_finishes_after_frame = false
	velocity = Vector2.ZERO
	dash_ended.emit()
	_set_state(State.IDLE)


func _start_dash(input_direction: Vector2) -> void:
	_dash_direction = (
		input_direction.normalized()
		if not input_direction.is_zero_approx()
		else _last_move_direction
	)
	_dash_time_remaining = _dash_duration
	_dash_finishes_after_frame = _dash_duration <= 0.0
	_dash_cooldown_remaining = _dash_cooldown
	velocity = _dash_direction * _dash_speed
	_set_state(State.DASH)
	dash_started.emit()


func _update_dash(_input_direction: Vector2, delta: float) -> void:
	if delta <= 0.0:
		velocity = _dash_direction * _dash_speed
		return
	var active_dash_time: float = minf(_dash_time_remaining, delta)
	_dash_time_remaining = maxf(_dash_time_remaining - active_dash_time, 0.0)
	# Scaling the last frame prevents physics tick size from changing dash distance.
	velocity = _dash_direction * _dash_speed * (active_dash_time / delta)
	_dash_finishes_after_frame = _dash_time_remaining <= 0.0


func _update_ground_movement(input_direction: Vector2, delta: float) -> void:
	if input_direction.is_zero_approx():
		velocity = velocity.move_toward(Vector2.ZERO, _friction * delta)
		_set_state(State.IDLE if velocity.is_zero_approx() else State.MOVE)
		return

	var target_velocity: Vector2 = input_direction * _move_speed
	velocity = velocity.move_toward(target_velocity, _acceleration * delta)
	_set_state(State.MOVE)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous_state: State = state
	state = next_state
	state_changed.emit(previous_state, state)
