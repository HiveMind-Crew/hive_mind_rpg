class_name RangedHarasser
extends EnemyBase
## Ranged harasser (issue #22) — the Spore Lobber. Holds its distance, backs
## away from an approaching player, and lobs slow dodgeable bolts on a
## cooldown. The retreat is slower than a run and far slower than a dash, so
## the counter is closing the gap: up close its swat is weak and it corners
## easily. stats.attack_range doubles as its firing range.

@export var bolt_scene: PackedScene
## Closer than this it backs away; between here and stats.attack_range it
## stands its ground and fires.
@export_range(1.0, 512.0, 1.0) var preferred_range: float = 90.0
@export_range(0.1, 2.0, 0.01) var retreat_speed_ratio: float = 0.75
@export_range(0.0, 10.0, 0.01) var fire_cooldown: float = 1.6
@export_range(1.0, 128.0, 1.0) var bolt_spawn_offset: float = 20.0

var _fire_cooldown_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	_fire_cooldown_remaining = maxf(_fire_cooldown_remaining - maxf(delta, 0.0), 0.0)
	super(delta)


func reset_to_spawn() -> void:
	super()
	_fire_cooldown_remaining = 0.0


func _update_chase() -> void:
	if not is_instance_valid(target):
		_transition_to(State.IDLE)
		return
	var distance_to_target: float = global_position.distance_to(target.global_position)
	if distance_to_target > stats.aggro_range:
		velocity = Vector2.ZERO
		return
	_attack_direction = global_position.direction_to(target.global_position)
	if distance_to_target <= stats.attack_range and _fire_cooldown_remaining <= 0.0:
		velocity = Vector2.ZERO
		_transition_to(State.WIND_UP)
		return
	if distance_to_target < preferred_range:
		velocity = -_attack_direction * stats.move_speed * retreat_speed_ratio
	elif distance_to_target > stats.attack_range:
		# Aggroed but out of firing range: close in until the lob connects.
		velocity = _attack_direction * stats.move_speed
	else:
		velocity = Vector2.ZERO


func _transition_to(new_state: State) -> void:
	super(new_state)
	# Fire exactly when the wind-up commits into ATTACK (base may refuse the
	# transition, e.g. when dead — then state won't match).
	if new_state == State.ATTACK and state == State.ATTACK:
		_fire_cooldown_remaining = fire_cooldown
		_fire_bolt()


func _fire_bolt() -> void:
	if bolt_scene == null:
		push_warning("RangedHarasser '%s' has no bolt scene; it fires nothing." % name)
		return
	var bolt: EnemyBolt = bolt_scene.instantiate() as EnemyBolt
	if bolt == null:
		push_warning("RangedHarasser '%s' bolt scene is not an EnemyBolt." % name)
		return
	bolt.direction = _attack_direction
	bolt.damage = stats.attack_damage
	bolt.ignored_hurtbox = hurtbox
	# Same parenting the player's relic bolt uses, so bolts outlive a dead shooter.
	var projectile_parent: Node = get_parent()
	projectile_parent.add_child(bolt)
	bolt.global_position = global_position + _attack_direction * bolt_spawn_offset
