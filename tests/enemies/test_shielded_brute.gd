extends GutTest
## Coverage for ShieldedBrute (issue #22): frontal hits are blocked, flanking
## hits land, the shield can't track while the brute is committed, and the
## turn rate is slow enough to strafe around.

const BRUTE_SCENE: PackedScene = preload("res://scenes/enemies/shielded_brute.tscn")

var _brute: ShieldedBrute


func before_each() -> void:
	_brute = BRUTE_SCENE.instantiate() as ShieldedBrute
	add_child_autofree(_brute)
	_brute.health.invulnerability_duration = 0.0


func _make_target(offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	target.global_position = _brute.global_position + offset
	return target


func _face_right() -> void:
	# Far target so the brute stays in CHASE while it turns; a generous delta
	# lets the clamped turn finish in one tick (90° at 110°/s).
	_brute.set_target(_make_target(Vector2(200.0, 0.0)))
	_brute._physics_process(1.0)


func test_turns_toward_its_target_at_a_limited_rate() -> void:
	_brute.set_target(_make_target(Vector2(200.0, 0.0)))

	# From the default DOWN facing, a quarter turn takes ~0.8s at 110°/s.
	_brute._physics_process(0.1)
	var early_facing: Vector2 = _brute.get_facing()
	assert_lt(early_facing.x, 0.9, "A tenth of a second is not enough to face RIGHT.")

	_brute._physics_process(1.0)
	assert_gt(_brute.get_facing().x, 0.99, "Given time, the shield tracks the target.")


func test_shield_visual_is_visible_and_tracks_the_blocking_arc() -> void:
	_face_right()
	var shield: Polygon2D = _brute.get_node("ShieldVisual") as Polygon2D

	assert_true(shield.visible, "The block direction must remain visible to the player.")
	assert_almost_eq(shield.rotation, _brute.get_facing().angle(), 0.001)


func test_blocks_hits_arriving_inside_the_frontal_arc() -> void:
	_face_right()
	watch_signals(_brute)

	# The attacker stands to the right (in front), so knockback pushes LEFT.
	_brute._on_hit_received(1, Vector2.LEFT * 10.0, Hitbox.ImpactType.GENERIC)

	assert_signal_emit_count(_brute, "hit_blocked", 1)
	assert_eq(_brute.health.current_health, _brute.health.max_health)
	assert_ne(_brute.state, EnemyBase.State.STAGGER)


func test_hits_from_behind_land_and_stagger() -> void:
	_face_right()
	watch_signals(_brute)

	# The attacker stands to the left (behind), so knockback pushes RIGHT.
	_brute._on_hit_received(1, Vector2.RIGHT * 10.0, Hitbox.ImpactType.GENERIC)

	assert_signal_emit_count(_brute, "hit_blocked", 0)
	assert_eq(_brute.health.current_health, _brute.health.max_health - 1)
	assert_eq(_brute.state, EnemyBase.State.STAGGER)


func test_zero_knockback_hits_fall_back_to_target_position() -> void:
	_face_right()
	var target: Node2D = _brute.target as Node2D
	watch_signals(_brute)

	# Target in front + zero-knockback melee → blocked.
	_brute._on_hit_received(1, Vector2.ZERO, Hitbox.ImpactType.GENERIC)
	assert_signal_emit_count(_brute, "hit_blocked", 1)

	# Teleport the target behind before the shield can turn → the hit lands.
	target.global_position = _brute.global_position + Vector2(-200.0, 0.0)
	_brute._on_hit_received(1, Vector2.ZERO, Hitbox.ImpactType.GENERIC)
	assert_eq(_brute.health.current_health, _brute.health.max_health - 1)
	assert_eq(_brute.state, EnemyBase.State.STAGGER)


func test_shield_freezes_while_committed_to_an_attack() -> void:
	_face_right()
	var target: Node2D = _brute.target as Node2D

	# Step into melee range: the next chase tick commits to WIND_UP.
	target.global_position = _brute.global_position + Vector2(20.0, 0.0)
	_brute._physics_process(0.016)
	assert_eq(_brute.state, EnemyBase.State.WIND_UP)

	# The player dashes behind mid-wind-up; the shield must not follow.
	target.global_position = _brute.global_position + Vector2(-200.0, 0.0)
	_brute._physics_process(0.016)
	assert_gt(_brute.get_facing().x, 0.99, "Committed brutes cannot turn.")


func test_dead_brute_blocks_nothing() -> void:
	_face_right()
	_brute.health.take_damage(99999)
	assert_eq(_brute.state, EnemyBase.State.DEAD)
	watch_signals(_brute)

	_brute._on_hit_received(1, Vector2.LEFT * 10.0, Hitbox.ImpactType.GENERIC)

	assert_signal_emit_count(_brute, "hit_blocked", 0)
