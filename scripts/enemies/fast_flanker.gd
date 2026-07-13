class_name FastFlanker
extends EnemyBase
## Fast flanker (issue #22) — the Glitch Stalker. Circles its prey just
## outside melee reach, then darts in with a committed lunge on a cooldown.
## Paper-thin: the counter is holding your swing for the moment it commits.
## Staggering it flips its orbit direction, so it can't be shepherded in one
## circle forever.

@export_range(1.0, 512.0, 1.0) var orbit_range: float = 90.0
@export_range(0.0, 10.0, 0.01) var dart_cooldown: float = 1.8
@export_range(1.0, 10.0, 0.1) var lunge_speed_ratio: float = 3.0

var _orbit_sign: float = 1.0
var _dart_cooldown_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	_dart_cooldown_remaining = maxf(_dart_cooldown_remaining - maxf(delta, 0.0), 0.0)
	super(delta)


func reset_to_spawn() -> void:
	super()
	_dart_cooldown_remaining = 0.0
	_orbit_sign = 1.0


func _update_chase() -> void:
	if not is_instance_valid(target):
		_transition_to(State.IDLE)
		return
	var to_target: Vector2 = target.global_position - global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target > stats.aggro_range:
		velocity = Vector2.ZERO
		return
	if distance_to_target > 0.0:
		_attack_direction = to_target / distance_to_target
	if _dart_cooldown_remaining <= 0.0 and distance_to_target <= stats.attack_range:
		velocity = Vector2.ZERO
		_transition_to(State.WIND_UP)
		return
	# Orbit: tangential motion blended with a pull back onto the orbit ring.
	var tangent: Vector2 = _attack_direction.orthogonal() * _orbit_sign
	var ring_pull: float = clampf((distance_to_target - orbit_range) / orbit_range, -1.0, 1.0)
	velocity = (tangent + _attack_direction * ring_pull).normalized() * stats.move_speed


func _update_timed_state(delta: float) -> void:
	super(delta)
	# The dart itself: unlike the base's standing swing, the lunge carries
	# motion along the committed direction.
	if state == State.ATTACK:
		velocity = _attack_direction * stats.move_speed * lunge_speed_ratio


func _transition_to(new_state: State) -> void:
	super(new_state)
	if new_state != state:
		return
	if state == State.RECOVERY:
		_dart_cooldown_remaining = dart_cooldown
	elif state == State.STAGGER:
		_orbit_sign = -_orbit_sign
