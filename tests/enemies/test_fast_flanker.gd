extends GutTest
## Coverage for FastFlanker (issue #22): orbits outside melee reach between
## darts, lunges with real motion when it commits, honors its dart cooldown,
## flips orbit direction when staggered, and dies in two hits.

const FLANKER_SCENE: PackedScene = preload("res://scenes/enemies/fast_flanker.tscn")

var _flanker: FastFlanker


func before_each() -> void:
	_flanker = FLANKER_SCENE.instantiate() as FastFlanker
	add_child_autofree(_flanker)
	_flanker.health.invulnerability_duration = 0.0


func _make_target(offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	target.global_position = _flanker.global_position + offset
	return target


func _run_full_dart_cycle() -> void:
	_flanker._physics_process(0.0)
	_flanker._physics_process(_flanker.stats.wind_up_duration)
	_flanker._physics_process(_flanker.stats.attack_duration)
	_flanker._physics_process(_flanker.stats.recovery_duration)


func test_darts_with_a_committed_lunge_when_ready() -> void:
	_flanker.set_target(_make_target(Vector2(90.0, 0.0)))

	_flanker._physics_process(0.0)
	assert_eq(_flanker.state, EnemyBase.State.WIND_UP)
	assert_true(_flanker._tell_visual.visible, "The dart needs a readable tell.")

	_flanker._physics_process(_flanker.stats.wind_up_duration)
	assert_eq(_flanker.state, EnemyBase.State.ATTACK)
	assert_almost_eq(
		_flanker.velocity.x,
		_flanker.stats.move_speed * _flanker.lunge_speed_ratio,
		0.001,
		"The lunge carries motion, unlike the base standing swing."
	)


func test_orbits_the_target_while_the_dart_cooldown_runs() -> void:
	var target: Node2D = _make_target(Vector2(90.0, 0.0))
	_flanker.set_target(target)

	_run_full_dart_cycle()
	assert_eq(_flanker.state, EnemyBase.State.CHASE)

	# Re-seat on the orbit ring so the tick is purely tangential.
	_flanker.global_position = target.global_position + Vector2(-_flanker.orbit_range, 0.0)
	_flanker._physics_process(0.016)

	assert_eq(_flanker.state, EnemyBase.State.CHASE, "No dart while cooling down.")
	assert_almost_eq(_flanker.velocity.length(), _flanker.stats.move_speed, 0.1)
	assert_lt(
		absf(_flanker.velocity.x), 1.0,
		"On the ring, motion is tangential — circling, not approaching."
	)
	assert_gt(absf(_flanker.velocity.y), 1.0)


func test_stagger_flips_the_orbit_direction() -> void:
	var target: Node2D = _make_target(Vector2(90.0, 0.0))
	_flanker.set_target(target)
	_run_full_dart_cycle()

	_flanker.global_position = target.global_position + Vector2(-_flanker.orbit_range, 0.0)
	_flanker._physics_process(0.016)
	var orbit_y_before: float = _flanker.velocity.y

	_flanker._on_hit_received(1, Vector2.ZERO, Hitbox.ImpactType.GENERIC)
	assert_eq(_flanker.state, EnemyBase.State.STAGGER)
	_flanker._physics_process(_flanker.stats.stagger_duration)
	assert_eq(_flanker.state, EnemyBase.State.CHASE)

	_flanker.global_position = target.global_position + Vector2(-_flanker.orbit_range, 0.0)
	_flanker._physics_process(0.016)

	assert_lt(
		_flanker.velocity.y * orbit_y_before, 0.0,
		"After a stagger the flanker circles the other way."
	)


func test_paper_thin_health_dies_in_two_hits() -> void:
	_flanker._on_hit_received(1, Vector2.ZERO, Hitbox.ImpactType.GENERIC)
	assert_eq(_flanker.state, EnemyBase.State.STAGGER)

	_flanker._on_hit_received(1, Vector2.ZERO, Hitbox.ImpactType.GENERIC)

	assert_eq(_flanker.state, EnemyBase.State.DEAD)
	assert_true(_flanker.health.is_dead)
