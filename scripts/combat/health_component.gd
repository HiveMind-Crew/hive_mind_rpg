class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal died()

@export_range(1, 100000, 1) var max_health: int = 10
@export_range(0.0, 10.0, 0.01) var invulnerability_duration: float = 0.2

var current_health: int:
	get:
		return _current_health

var is_invulnerable: bool:
	get:
		return is_instance_valid(_invulnerability_timer) and not _invulnerability_timer.is_stopped()

var is_dead: bool:
	get:
		return _current_health <= 0

var _current_health: int = 0
var _invulnerability_timer: Timer


func _ready() -> void:
	_current_health = max_health
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.one_shot = true
	add_child(_invulnerability_timer)
	health_changed.emit(_current_health, max_health)


func set_max_health(new_max_health: int) -> void:
	# Runtime max-HP changes (skill unlocks/respec, issue #17). Growth also
	# grants the new health immediately; shrinking clamps. Death state is
	# never changed here — a dead actor stays dead until respawn heals it.
	new_max_health = maxi(new_max_health, 1)
	if new_max_health == max_health:
		return
	var gained_health: int = new_max_health - max_health
	max_health = new_max_health
	if not is_dead:
		if gained_health > 0:
			_current_health += gained_health
		_current_health = clampi(_current_health, 1, max_health)
	health_changed.emit(_current_health, max_health)


func take_damage(amount: int) -> bool:
	if amount <= 0 or is_dead or is_invulnerable:
		return false

	_current_health = maxi(_current_health - amount, 0)
	health_changed.emit(_current_health, max_health)
	if is_dead:
		died.emit()
	else:
		_start_invulnerability()
	return true


func heal(amount: int) -> bool:
	if amount <= 0 or is_dead or _current_health >= max_health:
		return false

	_current_health = mini(_current_health + amount, max_health)
	health_changed.emit(_current_health, max_health)
	return true


func restore_full_health() -> void:
	_current_health = max_health
	_invulnerability_timer.stop()
	health_changed.emit(_current_health, max_health)


func apply_hit(damage: int, _knockback: Vector2) -> void:
	take_damage(damage)


func _start_invulnerability() -> void:
	if invulnerability_duration <= 0.0:
		return
	_invulnerability_timer.start(invulnerability_duration)
