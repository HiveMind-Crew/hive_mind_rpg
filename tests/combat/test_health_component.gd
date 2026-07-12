extends GutTest

const HEALTH_COMPONENT_SCENE: PackedScene = preload("res://scenes/combat/health_component.tscn")

var _health: HealthComponent


func before_each() -> void:
	_health = HEALTH_COMPONENT_SCENE.instantiate() as HealthComponent
	_health.max_health = 10
	_health.invulnerability_duration = 0.0
	add_child_autofree(_health)


func test_starts_at_max_health() -> void:
	assert_eq(_health.current_health, 10)
	assert_false(_health.is_dead)


func test_initial_broadcast_reaches_connections_made_after_its_ready() -> void:
	# Consumers connect in their own _ready, which runs after this child's;
	# the deferred initial emission must still reach them (issue #35).
	var late_health: HealthComponent = HEALTH_COMPONENT_SCENE.instantiate() as HealthComponent
	late_health.max_health = 7
	watch_signals(late_health)
	add_child_autofree(late_health)

	assert_signal_emit_count(
		late_health, "health_changed", 0,
		"The initial broadcast must be deferred, not synchronous with _ready."
	)

	await wait_frames(1)

	assert_signal_emit_count(late_health, "health_changed", 1)
	assert_signal_emitted_with_parameters(late_health, "health_changed", [7, 7])


func test_initial_broadcast_reports_live_values_not_a_ready_snapshot() -> void:
	# Damage in the same frame as _ready must not be overwritten by a stale
	# initial broadcast.
	var late_health: HealthComponent = HEALTH_COMPONENT_SCENE.instantiate() as HealthComponent
	late_health.max_health = 7
	late_health.invulnerability_duration = 0.0
	add_child_autofree(late_health)
	late_health.take_damage(3)
	watch_signals(late_health)

	await wait_frames(1)

	assert_signal_emitted_with_parameters(late_health, "health_changed", [4, 7])


func test_damage_is_bounded_at_zero_and_emits_death_once() -> void:
	watch_signals(_health)

	assert_true(_health.take_damage(50))
	assert_eq(_health.current_health, 0)
	assert_true(_health.is_dead)
	assert_signal_emit_count(_health, "health_changed", 1)
	assert_signal_emitted_with_parameters(
		_health,
		"damaged",
		[50, Vector2.ZERO, Hitbox.ImpactType.GENERIC]
	)
	assert_signal_emit_count(_health, "died", 1)

	assert_false(_health.take_damage(1), "A dead component rejects further damage.")
	assert_signal_emit_count(_health, "died", 1)


func test_non_positive_damage_is_rejected() -> void:
	assert_false(_health.take_damage(0))
	assert_false(_health.take_damage(-5))
	assert_eq(_health.current_health, 10)


func test_healing_is_bounded_at_max_health() -> void:
	_health.take_damage(7)
	watch_signals(_health)

	assert_true(_health.heal(20))
	assert_eq(_health.current_health, 10)
	assert_signal_emitted_with_parameters(_health, "health_changed", [10, 10])
	assert_false(_health.heal(1), "Healing at full health has no effect.")


func test_dead_component_cannot_be_healed_implicitly() -> void:
	_health.take_damage(10)
	assert_false(_health.heal(5))
	assert_eq(_health.current_health, 0)


func test_invulnerability_rejects_damage_until_window_expires() -> void:
	_health.invulnerability_duration = 0.05
	watch_signals(_health)

	assert_true(_health.take_damage(2))
	assert_true(_health.is_invulnerable)
	assert_signal_emitted_with_parameters(_health, "invulnerability_changed", [true])
	assert_false(_health.take_damage(2))
	assert_eq(_health.current_health, 8)
	assert_signal_emit_count(_health, "damaged", 1)

	# Leave more than one scheduler frame beyond the configured window.
	await wait_seconds(0.15)

	assert_false(_health.is_invulnerable)
	assert_signal_emitted_with_parameters(_health, "invulnerability_changed", [false])
	assert_true(_health.take_damage(2))
	assert_eq(_health.current_health, 6)


func test_apply_hit_preserves_knockback_and_impact_type_in_damage_signal() -> void:
	watch_signals(_health)
	var knockback := Vector2(7.0, -3.0)

	assert_true(_health.apply_hit(2, knockback, Hitbox.ImpactType.RELIC))

	assert_signal_emitted_with_parameters(
		_health,
		"damaged",
		[2, knockback, Hitbox.ImpactType.RELIC]
	)


func test_restore_full_health_revives_and_clears_invulnerability() -> void:
	_health.invulnerability_duration = 1.0
	_health.take_damage(10)

	_health.restore_full_health()

	assert_eq(_health.current_health, 10)
	assert_false(_health.is_dead)
	assert_false(_health.is_invulnerable)


func test_raising_max_health_grants_the_new_health_and_emits() -> void:
	_health.take_damage(4)
	watch_signals(_health)

	_health.set_max_health(15)

	assert_eq(_health.max_health, 15)
	assert_eq(_health.current_health, 11)
	assert_signal_emit_count(_health, "health_changed", 1)


func test_lowering_max_health_clamps_current_but_never_kills() -> void:
	_health.set_max_health(3)

	assert_eq(_health.max_health, 3)
	assert_eq(_health.current_health, 3)

	_health.set_max_health(1)
	assert_eq(_health.current_health, 1)
	assert_false(_health.is_dead)


func test_max_health_changes_never_resurrect_the_dead() -> void:
	_health.take_damage(10)
	assert_true(_health.is_dead)

	_health.set_max_health(20)

	assert_eq(_health.current_health, 0)
	assert_true(_health.is_dead)


func test_setting_the_same_max_health_is_a_silent_no_op() -> void:
	watch_signals(_health)

	_health.set_max_health(10)

	assert_signal_emit_count(_health, "health_changed", 0)
