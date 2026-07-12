extends Node


# Sole owner of Engine.time_scale. Other systems must call this API so their
# base-scale changes compose deterministically with temporary modifiers.
signal time_scale_changed(current_time_scale: float)

const INVALID_TOKEN: int = -1

var _base_time_scale: float = 1.0
var _modifiers: Dictionary[int, float] = {}
var _next_token: int = 0


func _ready() -> void:
	_base_time_scale = maxf(Engine.time_scale, 0.0)
	_apply_time_scale()


func set_base_time_scale(time_scale: float) -> void:
	_base_time_scale = maxf(time_scale, 0.0)
	_apply_time_scale()


func acquire_modifier(time_scale: float) -> int:
	var token: int = _next_token
	_next_token += 1
	_modifiers[token] = maxf(time_scale, 0.0)
	_apply_time_scale()
	return token


func release_modifier(token: int) -> bool:
	if not _modifiers.erase(token):
		return false
	_apply_time_scale()
	return true


func reset() -> void:
	_base_time_scale = 1.0
	_modifiers.clear()
	_apply_time_scale()


func get_effective_time_scale() -> float:
	var effective_time_scale: float = _base_time_scale
	for modifier_time_scale: float in _modifiers.values():
		effective_time_scale = minf(effective_time_scale, modifier_time_scale)
	return effective_time_scale


func get_modifier_count() -> int:
	return _modifiers.size()


func _apply_time_scale() -> void:
	var next_time_scale: float = get_effective_time_scale()
	if is_equal_approx(Engine.time_scale, next_time_scale):
		return
	Engine.time_scale = next_time_scale
	time_scale_changed.emit(next_time_scale)
