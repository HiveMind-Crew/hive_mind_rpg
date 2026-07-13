extends GutTest
## Coverage for the Rootheart Colossus (issue #23): phase 2 is new behavior —
## a radial bolt burst on waking and after every slam, plus a faster chase —
## while phase 1 stays a plain heavy slammer.

const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/rootheart_colossus.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

var _arena: Node2D
var _colossus: RootheartColossus


func before_each() -> void:
	GameState.reset_progress()
	# The arena stands in for the level scene that owns the boss. Burst bolts
	# are parented to the boss's parent, so they land under the arena and are
	# hard-freed with it between tests instead of leaking into later group
	# counts (a queue_free sweep never flushes inside GUT's single-frame run).
	_arena = Node2D.new()
	add_child_autofree(_arena)
	_colossus = BOSS_SCENE.instantiate() as RootheartColossus
	_arena.add_child(_colossus)
	_colossus.health.invulnerability_duration = 0.0


func after_each() -> void:
	GameState.reset_progress()


func _make_target(offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	var hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	hurtbox.name = "Hurtbox"
	target.add_child(hurtbox)
	add_child_autofree(target)
	target.global_position = _colossus.global_position + offset
	return target


func _live_bolt_count() -> int:
	return get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP).size()


func _run_full_slam_cycle() -> void:
	_colossus._physics_process(0.0)
	_colossus._physics_process(_colossus.stats.wind_up_duration)
	_colossus._physics_process(_colossus.stats.attack_duration)


func test_phase_one_chases_at_authored_speed_with_no_bolts() -> void:
	_colossus.set_target(_make_target(Vector2(200.0, 0.0)))

	_colossus._physics_process(0.016)

	assert_eq(_colossus.state, EnemyBase.State.CHASE)
	assert_almost_eq(_colossus.velocity.length(), _colossus.stats.move_speed, 0.1)
	assert_eq(_live_bolt_count(), 0, "Phase 1 is melee only.")


func test_waking_at_half_health_fires_a_radial_burst() -> void:
	_colossus.health.take_damage(15)

	assert_eq(_colossus.get_phase(), 1)
	assert_eq(
		_live_bolt_count(), _colossus.burst_bolt_count,
		"The wake detonates a full ring of bolts."
	)

	var directions: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP):
		var bolt: EnemyBolt = node as EnemyBolt
		assert_false(
			directions.has(bolt.direction),
			"Burst bolts fan out in distinct directions."
		)
		directions.append(bolt.direction)


func test_phase_two_chase_is_faster() -> void:
	_colossus.set_target(_make_target(Vector2(200.0, 0.0)))
	_colossus.health.take_damage(15)

	_colossus._physics_process(0.016)

	assert_eq(_colossus.state, EnemyBase.State.CHASE)
	assert_almost_eq(
		_colossus.velocity.length(),
		_colossus.stats.move_speed * _colossus.phase_two_speed_multiplier,
		0.1
	)


func test_phase_two_slam_recovery_fires_another_burst() -> void:
	_colossus.set_target(_make_target(Vector2(30.0, 0.0)))
	_colossus.health.take_damage(15)
	var bolts_after_wake: int = _live_bolt_count()

	_run_full_slam_cycle()

	assert_eq(_colossus.state, EnemyBase.State.RECOVERY)
	assert_eq(
		_live_bolt_count(), bolts_after_wake + _colossus.burst_bolt_count,
		"Every phase-2 slam ends in a bullet ring."
	)


func test_phase_one_slam_recovery_stays_quiet() -> void:
	_colossus.set_target(_make_target(Vector2(30.0, 0.0)))

	_run_full_slam_cycle()

	assert_eq(_colossus.state, EnemyBase.State.RECOVERY)
	assert_eq(_live_bolt_count(), 0, "Phase 1 recoveries fire nothing.")


func test_freeing_the_owning_scene_frees_in_flight_burst_bolts() -> void:
	_colossus.health.take_damage(15)
	assert_eq(_live_bolt_count(), _colossus.burst_bolt_count)

	_arena.free()

	assert_eq(
		_live_bolt_count(),
		0,
		"Burst bolts belong to the boss's scene and free with it — none survive teardown."
	)
