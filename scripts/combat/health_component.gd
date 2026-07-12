class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int, knockback: Vector2, impact_type: int)
signal invulnerability_changed(is_invulnerable: bool)
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
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)
	# Deferred (issue #35): children _ready before their parents, so an
	# immediate emission is lost on every consumer that connects in its own
	# _ready. The broadcast reads live values at fire time, so state changes
	# in the same frame can't be overwritten by a stale snapshot.
	_broadcast_initial_health.call_deferred()


func _broadcast_initial_health() -> void:
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
	return _apply_damage(amount, Vector2.ZERO, Hitbox.ImpactType.GENERIC)


func apply_hit(damage: int, knockback: Vector2, impact_type: int) -> bool:
	return _apply_damage(damage, knockback, impact_type)


func _apply_damage(amount: int, knockback: Vector2, impact_type: int) -> bool:
	if amount <= 0 or is_dead or is_invulnerable:
		return false

	_current_health = maxi(_current_health - amount, 0)
	health_changed.emit(_current_health, max_health)
	if is_dead:
		# Placeholder SFX (issue #25) live here so every actor with health —
		# player, dummies, enemies — reads the same on hit and death.
		AudioManager.play_sfx(&"death")
		damaged.emit(amount, knockback, impact_type)
		died.emit()
	else:
		AudioManager.play_sfx(&"hit")
		_start_invulnerability()
		damaged.emit(amount, knockback, impact_type)
	return true


func heal(amount: int) -> bool:
	if amount <= 0 or is_dead or _current_health >= max_health:
		return false

	_current_health = mini(_current_health + amount, max_health)
	health_changed.emit(_current_health, max_health)
	return true


func restore_full_health() -> void:
	_current_health = max_health
	var was_invulnerable: bool = is_invulnerable
	_invulnerability_timer.stop()
	if was_invulnerable:
		invulnerability_changed.emit(false)
	health_changed.emit(_current_health, max_health)


func _start_invulnerability() -> void:
	if invulnerability_duration <= 0.0:
		return
	_invulnerability_timer.start(invulnerability_duration)
	invulnerability_changed.emit(true)


func _on_invulnerability_timeout() -> void:
	invulnerability_changed.emit(false)
