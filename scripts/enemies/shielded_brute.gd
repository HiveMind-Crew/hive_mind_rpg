class_name ShieldedBrute
extends EnemyBase
## Shielded brute (issue #22) — the Rootbound Warden. Slow and heavy, with a
## shield plate that blocks any hit arriving inside its frontal arc. It turns
## slower than a dashing player strafes, and cannot turn at all while
## committed (wind-up through recovery) or staggered — so the counter is
## positioning: dash around it, or bait the swing and punish the exposed
## back through its long recovery.

signal hit_blocked()

@export_range(10.0, 180.0, 1.0) var shield_arc_degrees: float = 100.0
@export_range(10.0, 720.0, 1.0) var turn_speed_degrees: float = 110.0

var _facing: Vector2 = Vector2.DOWN

@onready var _shield_visual: Polygon2D = %ShieldVisual


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.IDLE or state == State.CHASE:
		_turn_toward_target(maxf(delta, 0.0))
	_shield_visual.rotation = _facing.angle()


func get_facing() -> Vector2:
	return _facing


func reset_to_spawn() -> void:
	super()
	_facing = Vector2.DOWN


func _turn_toward_target(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired_facing: Vector2 = global_position.direction_to(target.global_position)
	if desired_facing.is_zero_approx():
		return
	var max_turn: float = deg_to_rad(turn_speed_degrees) * delta
	var turn: float = clampf(_facing.angle_to(desired_facing), -max_turn, max_turn)
	_facing = _facing.rotated(turn).normalized()


func _on_hit_received(damage: int, knockback: Vector2, impact_type: int) -> void:
	if _is_hit_blocked(knockback):
		hit_blocked.emit()
		return
	super(damage, knockback, impact_type)


func _is_hit_blocked(knockback: Vector2) -> bool:
	if state == State.DEAD:
		return false
	var toward_attacker: Vector2 = _direction_to_attacker(knockback)
	if toward_attacker.is_zero_approx():
		return false
	return absf(_facing.angle_to(toward_attacker)) <= deg_to_rad(shield_arc_degrees) * 0.5


func _direction_to_attacker(knockback: Vector2) -> Vector2:
	# Knockback pushes from the attacker toward us, so its opposite points
	# home. Zero-knockback hits (the current melee default) fall back to the
	# target's position — at melee range the player effectively is the origin.
	if not knockback.is_zero_approx():
		return -knockback.normalized()
	if is_instance_valid(target):
		return global_position.direction_to(target.global_position)
	return Vector2.ZERO
