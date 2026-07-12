extends GutTest

const FEEDBACK_SCENE: PackedScene = preload("res://scenes/combat/combat_feedback.tscn")

var _actor: Node2D
var _health: HealthComponent
var _visual: Polygon2D
var _feedback: CombatFeedback


func before_each() -> void:
	TimeScaleManager.reset()
	_actor = Node2D.new()
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_health.max_health = 10
	_health.invulnerability_duration = 0.2
	_visual = Polygon2D.new()
	_visual.name = "Visual"
	_visual.color = Color(0.4, 0.5, 0.6, 1.0)
	_feedback = FEEDBACK_SCENE.instantiate() as CombatFeedback
	_feedback.health_path = NodePath("../HealthComponent")
	_feedback.visual_path = NodePath("../Visual")
	_actor.add_child(_health)
	_actor.add_child(_visual)
	_actor.add_child(_feedback)
	add_child_autofree(_actor)


func after_each() -> void:
	TimeScaleManager.reset()


func test_melee_and_relic_hits_use_distinct_replaceable_tints() -> void:
	watch_signals(_feedback)

	assert_true(_health.apply_hit(1, Vector2.RIGHT, Hitbox.ImpactType.MELEE))
	assert_eq(_feedback._active_hit_tint, _feedback.melee_hit_tint)
	assert_signal_emitted_with_parameters(
		_feedback, "hit_feedback_started", [Hitbox.ImpactType.MELEE]
	)

	_health.restore_full_health()
	assert_true(_health.apply_hit(1, Vector2.RIGHT, Hitbox.ImpactType.RELIC))
	assert_eq(_feedback._active_hit_tint, _feedback.relic_hit_tint)
	assert_ne(_feedback.melee_hit_tint, _feedback.relic_hit_tint)
	assert_signal_emitted_with_parameters(
		_feedback, "hit_feedback_started", [Hitbox.ImpactType.RELIC]
	)


func test_invulnerability_pulses_visual_without_accepting_extra_hits() -> void:
	watch_signals(_feedback)

	assert_true(_health.apply_hit(1, Vector2.ZERO, Hitbox.ImpactType.ENEMY))
	assert_true(_health.is_invulnerable)
	assert_false(_health.apply_hit(1, Vector2.ZERO, Hitbox.ImpactType.ENEMY))
	assert_signal_emit_count(_feedback, "hit_feedback_started", 1)

	var interval_msec: int = roundi(_feedback.invulnerability_pulse_interval * 1000.0)
	_feedback._render_feedback(interval_msec)
	assert_almost_eq(
		_visual.self_modulate.a,
		_feedback.enemy_hit_tint.a * _feedback.invulnerability_alpha,
		0.001
	)
	_feedback._render_feedback(interval_msec * 2)
	assert_almost_eq(_visual.self_modulate.a, _feedback.enemy_hit_tint.a, 0.001)


func test_death_tint_persists_until_health_is_restored() -> void:
	_health.invulnerability_duration = 0.0
	watch_signals(_feedback)

	assert_true(
		_health.apply_hit(
			_health.max_health,
			Vector2.ZERO,
			Hitbox.ImpactType.RELIC
		)
	)

	assert_eq(_visual.self_modulate, _feedback.death_tint)
	assert_signal_emitted(_feedback, "death_feedback_started")

	_feedback._render_feedback(Time.get_ticks_msec() + 5000)
	assert_eq(_visual.self_modulate, _feedback.death_tint)

	_health.restore_full_health()
	assert_eq(_visual.self_modulate, Color.WHITE)


func test_feedback_does_not_change_hitstop_or_base_time_scale() -> void:
	TimeScaleManager.set_base_time_scale(0.8)
	var hitstop_token: int = TimeScaleManager.acquire_modifier(0.25)
	var modifier_count: int = TimeScaleManager.get_modifier_count()

	assert_true(_health.apply_hit(1, Vector2.ZERO, Hitbox.ImpactType.MELEE))
	_feedback._render_feedback(Time.get_ticks_msec() + 1000)

	assert_eq(TimeScaleManager.get_modifier_count(), modifier_count)
	assert_eq(Engine.time_scale, 0.25)
	TimeScaleManager.release_modifier(hitstop_token)
	assert_eq(Engine.time_scale, 0.8)
