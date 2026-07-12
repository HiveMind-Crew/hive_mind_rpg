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


func test_damage_is_bounded_at_zero_and_emits_death_once() -> void:
	watch_signals(_health)

	assert_true(_health.take_damage(50))
	assert_eq(_health.current_health, 0)
	assert_true(_health.is_dead)
	assert_signal_emit_count(_health, "health_changed", 1)
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

	assert_true(_health.take_damage(2))
	assert_true(_health.is_invulnerable)
	assert_false(_health.take_damage(2))
	assert_eq(_health.current_health, 8)

	# Leave more than one scheduler frame beyond the configured window.
	await wait_seconds(0.15)

	assert_false(_health.is_invulnerable)
	assert_true(_health.take_damage(2))
	assert_eq(_health.current_health, 6)


func test_restore_full_health_revives_and_clears_invulnerability() -> void:
	_health.invulnerability_duration = 1.0
	_health.take_damage(10)

	_health.restore_full_health()

	assert_eq(_health.current_health, 10)
	assert_false(_health.is_dead)
	assert_false(_health.is_invulnerable)
