class_name PlayerMeleeAttack
extends RefCounted

signal swing_started(direction: Vector2)
signal swing_ended()

var is_swinging: bool:
	get:
		return _is_swinging

var swing_direction: Vector2:
	get:
		return _swing_direction

var swing_time_remaining: float:
	get:
		return _swing_time_remaining

var _swing_duration: float
var _swing_time_remaining: float = 0.0
var _swing_direction: Vector2 = Vector2.DOWN
var _is_swinging: bool = false
var _hit_target_ids: Dictionary[int, bool] = {}


func _init(swing_duration: float) -> void:
	_swing_duration = maxf(swing_duration, 0.0)


func try_start_swing(direction: Vector2) -> bool:
	if _is_swinging:
		return false
	if not direction.is_zero_approx():
		_swing_direction = direction.normalized()
	_swing_time_remaining = _swing_duration
	_hit_target_ids.clear()
	_is_swinging = true
	swing_started.emit(_swing_direction)
	if _swing_duration <= 0.0:
		_end_swing()
	return true


func update(delta: float) -> void:
	if not _is_swinging:
		return
	_swing_time_remaining = maxf(_swing_time_remaining - maxf(delta, 0.0), 0.0)
	if _swing_time_remaining <= 0.0:
		_end_swing()


func register_hit(target_id: int) -> bool:
	if not _is_swinging or _hit_target_ids.has(target_id):
		return false
	_hit_target_ids[target_id] = true
	return true


func cancel_swing() -> void:
	if not _is_swinging:
		return
	_end_swing()


func _end_swing() -> void:
	_is_swinging = false
	_swing_time_remaining = 0.0
	swing_ended.emit()
