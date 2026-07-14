extends GutTest

const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

var _enemy: EnemyBase
var _feedback: CombatFeedback


func before_each() -> void:
	_enemy = CHASER_SCENE.instantiate() as EnemyBase
	add_child_autofree(_enemy)
	_feedback = _enemy.get_node("CombatFeedback") as CombatFeedback


func test_authored_stats_configure_composed_combat_components() -> void:
	assert_not_null(_enemy.stats)
	assert_eq(_enemy.health.max_health, _enemy.stats.max_health)
	assert_eq(_enemy.attack_hitbox.damage, _enemy.stats.attack_damage)
	assert_true(_enemy.is_in_group(EnemyBase.ENEMY_GROUP))


func test_chases_target_inside_aggro_range() -> void:
	var target: Node2D = _make_target(Vector2(100.0, 0.0))
	_enemy.set_target(target)

	_enemy._physics_process(0.016)

	assert_eq(_enemy.state, EnemyBase.State.CHASE)
	assert_eq(_enemy.velocity, Vector2.RIGHT * _enemy.stats.move_speed)


func test_close_target_triggers_readable_wind_up_before_attack() -> void:
	var target: Node2D = _make_target(Vector2(20.0, 0.0))
	_enemy.set_target(target)
	_enemy._physics_process(0.0)

	assert_eq(_enemy.state, EnemyBase.State.WIND_UP)
	var visual: AnimatedSprite2D = _enemy.get_node("BodyVisual") as AnimatedSprite2D
	assert_eq(visual.animation, &"windup", "The authored windup frame is the tell.")
	assert_false(_enemy.attack_hitbox.monitoring)

	_enemy._physics_process(_enemy.stats.wind_up_duration)
	await wait_physics_frames(2)

	assert_eq(_enemy.state, EnemyBase.State.ATTACK)
	assert_true(_enemy.attack_hitbox.monitoring)


func test_attack_damages_target_then_enters_recovery() -> void:
	var target: Node2D = _make_target(Vector2(20.0, 0.0), true)
	var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
	_enemy.set_target(target)
	_enemy._physics_process(0.0)
	_enemy._physics_process(_enemy.stats.wind_up_duration)

	await wait_physics_frames(3)

	assert_eq(health.current_health, health.max_health - _enemy.stats.attack_damage)
	_enemy._physics_process(_enemy.stats.attack_duration)
	assert_eq(_enemy.state, EnemyBase.State.RECOVERY)


func test_hit_staggers_and_lethal_hit_dies() -> void:
	_enemy.health.invulnerability_duration = 0.0
	var hitbox := Hitbox.new()
	hitbox.damage = 1
	add_child_autofree(hitbox)
	_enemy._on_hit_received(
		hitbox.damage,
		Vector2.ZERO,
		Hitbox.ImpactType.MELEE
	)
	assert_eq(_enemy.state, EnemyBase.State.STAGGER)
	assert_eq(_feedback._active_hit_tint, _feedback.melee_hit_tint)

	hitbox.damage = _enemy.health.current_health
	_enemy._on_hit_received(
		hitbox.damage,
		Vector2.ZERO,
		Hitbox.ImpactType.MELEE
	)
	assert_eq(_enemy.state, EnemyBase.State.DEAD)
	assert_true(_enemy.health.is_dead)
	assert_false(_enemy.hurtbox.enabled)
	assert_eq(_enemy._body_visual.self_modulate, _feedback.death_tint)


func test_authored_enemy_attack_has_readable_impact_metadata() -> void:
	assert_eq(_enemy.attack_hitbox.impact_type, Hitbox.ImpactType.ENEMY)
	assert_gt(_enemy.attack_hitbox.knockback_strength, 0.0)


func test_reset_to_spawn_revives_and_rearms_at_the_spawn_point() -> void:
	var spawn_position: Vector2 = _enemy.global_position
	_enemy.health.invulnerability_duration = 0.0
	_enemy.global_position += Vector2(40.0, 0.0)
	_enemy._on_hit_received(99999, Vector2.ZERO, Hitbox.ImpactType.GENERIC)
	assert_eq(_enemy.state, EnemyBase.State.DEAD)

	_enemy.reset_to_spawn()

	assert_eq(_enemy.global_position, spawn_position)
	assert_eq(_enemy.state, EnemyBase.State.IDLE)
	assert_eq(_enemy.health.current_health, _enemy.health.max_health)
	assert_true(_enemy.hurtbox.enabled, "A reset enemy takes hits again.")


func _make_target(offset: Vector2, with_health: bool = false) -> Node2D:
	var target := Node2D.new()
	var hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	hurtbox.name = "Hurtbox"
	target.add_child(hurtbox)
	if with_health:
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.invulnerability_duration = 0.0
		target.add_child(health)
		hurtbox.hit_received.connect(health.apply_hit)
	add_child_autofree(target)
	target.global_position = _enemy.global_position + offset
	return target
