extends GutTest
## Coverage for RangedHarasser (issue #22): fires dodgeable bolts at range,
## honors its fire cooldown, retreats from a closing player, and its bolts
## never pop on their own shooter.

const HARASSER_SCENE: PackedScene = preload("res://scenes/enemies/ranged_harasser.tscn")
const BOLT_SCENE: PackedScene = preload("res://scenes/enemies/enemy_bolt.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

var _arena: Node2D
var _harasser: RangedHarasser


func before_each() -> void:
	# The arena stands in for the level scene that owns the shooter. Spawners
	# parent bolts to the shooter's parent, so every bolt lands under the
	# arena and is hard-freed with it between tests — a queue_free sweep in
	# after_each never flushes inside GUT's single-frame test run, so bolts
	# would otherwise leak into the next test's group counts.
	_arena = Node2D.new()
	add_child_autofree(_arena)
	_harasser = HARASSER_SCENE.instantiate() as RangedHarasser
	_arena.add_child(_harasser)


func _make_target(offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	var hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	hurtbox.name = "Hurtbox"
	target.add_child(hurtbox)
	add_child_autofree(target)
	target.global_position = _harasser.global_position + offset
	return target


func _run_full_attack_cycle() -> void:
	# CHASE tick decides, then wind-up, attack (fires), recovery, back to CHASE.
	_harasser._physics_process(0.0)
	_harasser._physics_process(_harasser.stats.wind_up_duration)
	_harasser._physics_process(_harasser.stats.attack_duration)
	_harasser._physics_process(_harasser.stats.recovery_duration)


func test_fires_a_bolt_at_the_target_after_a_readable_wind_up() -> void:
	_harasser.set_target(_make_target(Vector2(100.0, 0.0)))

	_harasser._physics_process(0.0)
	assert_eq(_harasser.state, EnemyBase.State.WIND_UP)
	assert_true(_harasser._tell_visual.visible, "The lob needs a readable tell.")

	_harasser._physics_process(_harasser.stats.wind_up_duration)
	assert_eq(_harasser.state, EnemyBase.State.ATTACK)

	var bolts: Array[Node] = get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP)
	assert_eq(bolts.size(), 1, "Exactly one bolt per attack.")
	var bolt: EnemyBolt = bolts[0] as EnemyBolt
	assert_almost_eq(bolt.direction.x, 1.0, 0.001)
	assert_eq(bolt.damage, _harasser.stats.attack_damage)


func test_holds_fire_while_the_cooldown_runs() -> void:
	_harasser.set_target(_make_target(Vector2(100.0, 0.0)))

	_run_full_attack_cycle()
	assert_eq(_harasser.state, EnemyBase.State.CHASE)

	_harasser._physics_process(0.016)

	assert_eq(_harasser.state, EnemyBase.State.CHASE, "No re-fire until the cooldown ends.")
	assert_eq(get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP).size(), 1)


func test_fires_again_after_the_cooldown_elapses() -> void:
	_harasser.set_target(_make_target(Vector2(100.0, 0.0)))
	_run_full_attack_cycle()

	_harasser._physics_process(_harasser.fire_cooldown)
	assert_eq(_harasser.state, EnemyBase.State.WIND_UP, "An elapsed cooldown re-arms the lob.")
	_harasser._physics_process(_harasser.stats.wind_up_duration)

	assert_eq(
		get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP).size(),
		2,
		"The second attack cycle fires exactly one more bolt."
	)


func test_freeing_the_owning_scene_frees_in_flight_bolts() -> void:
	_harasser.set_target(_make_target(Vector2(100.0, 0.0)))
	_harasser._physics_process(0.0)
	_harasser._physics_process(_harasser.stats.wind_up_duration)
	assert_eq(get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP).size(), 1)

	_arena.free()

	assert_eq(
		get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP).size(),
		0,
		"Bolts belong to the shooter's scene and free with it — none survive teardown."
	)


func test_backs_away_from_a_player_inside_its_preferred_range() -> void:
	var target: Node2D = _make_target(Vector2(50.0, 0.0))
	_harasser.set_target(target)

	# Burn the opening shot so the cooldown forces a positioning decision.
	_run_full_attack_cycle()
	target.global_position = _harasser.global_position + Vector2(50.0, 0.0)
	_harasser._physics_process(0.016)

	assert_lt(_harasser.velocity.x, 0.0, "Retreats away from a target to its right.")
	assert_lt(
		absf(_harasser.velocity.x),
		_harasser.stats.move_speed,
		"The retreat is slower than a straight-line run, so it can be cornered."
	)


func test_bolt_ignores_its_own_shooter_but_hits_others() -> void:
	var bolt: EnemyBolt = BOLT_SCENE.instantiate() as EnemyBolt
	var shooter_hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	var victim_hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	add_child_autofree(shooter_hurtbox)
	add_child_autofree(victim_hurtbox)
	bolt.ignored_hurtbox = shooter_hurtbox
	add_child_autofree(bolt)
	watch_signals(shooter_hurtbox)
	watch_signals(victim_hurtbox)

	bolt._on_area_entered(shooter_hurtbox)
	assert_signal_emit_count(shooter_hurtbox, "hit_received", 0)
	assert_false(bolt.is_queued_for_deletion())

	bolt._on_area_entered(victim_hurtbox)
	assert_signal_emit_count(victim_hurtbox, "hit_received", 1)


func test_bolt_expires_at_end_of_lifetime() -> void:
	var bolt: EnemyBolt = BOLT_SCENE.instantiate() as EnemyBolt
	add_child_autofree(bolt)

	bolt._physics_process(bolt.lifetime + 0.1)

	assert_true(bolt.is_queued_for_deletion())
