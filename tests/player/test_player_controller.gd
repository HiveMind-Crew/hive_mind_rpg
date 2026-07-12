extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

const TEST_MELEE_DURATION: float = 0.5

var _player: PlayerController
var _hurtbox: Hurtbox
var _melee_hitbox: Hitbox
var _input_sender: GutInputSender
var _energy: EnergyComponent
var _health: HealthComponent
var _feedback: CombatFeedback
var _body_visual: Polygon2D


func before_each() -> void:
	_reset_hitstop_state()
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.melee_duration = TEST_MELEE_DURATION
	_player.melee_hitstop_duration = 0.0
	add_child_autofree(_player)
	_hurtbox = _player.get_node("Hurtbox") as Hurtbox
	_melee_hitbox = _player.get_node("MeleeHitbox") as Hitbox
	_energy = _player.get_node("EnergyComponent") as EnergyComponent
	_health = _player.get_node("HealthComponent") as HealthComponent
	_feedback = _player.get_node("CombatFeedback") as CombatFeedback
	_body_visual = _player.get_node("Body") as Polygon2D
	_input_sender = GutInputSender.new(Input)


func after_each() -> void:
	_input_sender.release_all()
	_input_sender.clear()
	for projectile: Node in get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP):
		projectile.free()
	_reset_hitstop_state()


func _reset_hitstop_state() -> void:
	TimeScaleManager.reset()


func test_dash_toggles_hurtbox_for_iframe_window() -> void:
	_player._movement.update(Vector2.RIGHT, true, 0.0)

	assert_false(_hurtbox.enabled)

	_player._movement.update(Vector2.RIGHT, false, _player.dash_duration)
	_player._movement.finish_frame(Vector2.RIGHT)

	assert_true(_hurtbox.enabled)


func test_player_hurtbox_applies_damage_to_health_and_hud() -> void:
	var hitbox := Hitbox.new()
	hitbox.damage = 2
	hitbox.impact_type = Hitbox.ImpactType.ENEMY
	add_child_autofree(hitbox)

	_hurtbox.receive_hit(hitbox)

	assert_eq(_health.current_health, _health.max_health - 2)
	var hud: PlayerHud = _player.get_node("PlayerHud") as PlayerHud
	assert_eq(hud.health_value, float(_health.current_health))
	assert_eq(_feedback._active_hit_tint, _feedback.enemy_hit_tint)
	assert_ne(_body_visual.self_modulate, Color.WHITE)


func test_cancel_dash_restores_hurtbox() -> void:
	_player._movement.update(Vector2.RIGHT, true, 0.0)
	_player.cancel_dash()

	assert_true(_hurtbox.enabled)


func test_melee_hitbox_is_disabled_by_default() -> void:
	assert_false(_melee_hitbox.monitoring)
	assert_false(_melee_hitbox.monitorable)
	assert_eq(_melee_hitbox.impact_type, Hitbox.ImpactType.MELEE)
	assert_gt(_melee_hitbox.knockback_strength, 0.0)


func test_melee_attack_opens_hitbox_toward_facing_then_closes_it() -> void:
	_player._movement.update(Vector2.LEFT, false, 0.016)

	assert_true(_player.try_melee_attack())

	await wait_physics_frames(2)

	assert_true(_melee_hitbox.monitoring)
	assert_eq(_melee_hitbox.position, Vector2.LEFT * _player.melee_hitbox_offset)

	_player._melee.update(TEST_MELEE_DURATION)

	await wait_physics_frames(2)

	assert_false(_melee_hitbox.monitoring)


func test_attack_melee_action_starts_swing() -> void:
	_input_sender.action_down("attack_melee")

	await wait_physics_frames(3)

	assert_true(_player._melee.is_swinging)


func test_relic_ability_spends_energy_and_spawns_bolt_in_facing_direction() -> void:
	_player._movement.update(Vector2(1.0, -0.8), false, 0.016)
	watch_signals(_player)

	assert_true(_player.try_relic_ability())

	var bolt: EnergyBolt = _player.get_parent().get_node("EnergyBolt") as EnergyBolt
	assert_not_null(bolt)
	assert_eq(bolt.impact_type, Hitbox.ImpactType.RELIC)
	assert_gt(bolt.knockback_strength, _melee_hitbox.knockback_strength)
	assert_almost_eq(bolt.direction.distance_to(Vector2(1.0, -1.0).normalized()), 0.0, 0.001)
	assert_eq(_energy.current_energy, _energy.max_energy - _player.energy_bolt_cost)
	assert_signal_emitted(_player, "relic_ability_fired")


func test_relic_ability_is_blocked_at_zero_energy() -> void:
	assert_true(_energy.spend(_energy.max_energy))
	watch_signals(_player)

	assert_false(_player.try_relic_ability())
	assert_signal_emitted(_player, "relic_ability_blocked")
	assert_false(_player.get_parent().has_node("EnergyBolt"))


func test_relic_action_fires_ability() -> void:
	_input_sender.action_down("ability_relic")

	await wait_physics_frames(3)

	assert_lt(_energy.current_energy, _energy.max_energy)
	assert_true(_player.get_parent().has_node("EnergyBolt"))


func test_energy_bolt_damages_a_hurtbox_once() -> void:
	var target: Node2D = _create_target(Vector2(48.0, 0.0))
	var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
	_player._movement.update(Vector2.RIGHT, false, 0.016)

	assert_true(_player.try_relic_ability())
	await wait_physics_frames(10)

	assert_eq(health.current_health, health.max_health - _player.energy_bolt_damage)


func test_relic_aim_snaps_to_eight_directions() -> void:
	assert_eq(PlayerController.snap_to_eight_directions(Vector2.RIGHT), Vector2.RIGHT)
	assert_almost_eq(
		PlayerController.snap_to_eight_directions(Vector2(0.8, 1.0)).distance_to(
			Vector2(1.0, 1.0).normalized()
		),
		0.0,
		0.001
	)


func test_swing_hits_overlapping_target_once_and_fresh_swing_hits_again() -> void:
	var target: Node2D = _create_target(Vector2(14.0, 0.0))
	var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
	var target_hurtbox: Hurtbox = target.get_node("Hurtbox") as Hurtbox
	_player._movement.update(Vector2.RIGHT, false, 0.016)
	_player.try_melee_attack()

	await wait_physics_frames(3)

	assert_eq(health.current_health, health.max_health - _player.melee_damage)

	# A target leaving and re-entering the hitbox mid-swing must not be hit twice.
	_player._on_melee_hitbox_area_entered(target_hurtbox)

	assert_eq(health.current_health, health.max_health - _player.melee_damage)

	_player._melee.update(TEST_MELEE_DURATION)

	await wait_physics_frames(2)

	_player.try_melee_attack()

	await wait_physics_frames(3)

	assert_eq(health.current_health, health.max_health - 2 * _player.melee_damage)


func test_melee_ignores_players_own_hurtbox() -> void:
	watch_signals(_hurtbox)
	_player.try_melee_attack()
	_player._on_melee_hitbox_area_entered(_hurtbox)

	assert_signal_not_emitted(_hurtbox, "hit_received")


func test_landed_hit_applies_hitstop() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	var target: Node2D = _create_target(Vector2(14.0, 0.0))
	var target_hurtbox: Hurtbox = target.get_node("Hurtbox") as Hurtbox
	_player._movement.update(Vector2.RIGHT, false, 0.016)
	_player.try_melee_attack()
	_player._on_melee_hitbox_area_entered(target_hurtbox)

	assert_eq(Engine.time_scale, 0.5)


func test_freeing_player_mid_swing_restores_hitstop_and_ends_swing() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.melee_hitstop_duration = 5.0
	player.melee_hitstop_time_scale = 0.5
	add_child(player)
	player.try_melee_attack()
	var melee: PlayerMeleeAttack = player._melee
	player._start_hitstop()

	assert_eq(Engine.time_scale, 0.5)

	player.free()

	assert_eq(Engine.time_scale, 1.0)
	assert_false(melee.is_swinging)


func test_hitstop_restores_pre_existing_time_scale() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	TimeScaleManager.set_base_time_scale(0.75)

	_player._start_hitstop()

	assert_eq(Engine.time_scale, 0.5)

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.75)


func test_overlapping_hitstops_only_restore_after_last_one_ends() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	var other_player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	other_player.melee_hitstop_duration = 5.0
	other_player.melee_hitstop_time_scale = 0.5
	add_child_autofree(other_player)
	_player._start_hitstop()
	other_player._start_hitstop()

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.5)

	other_player._end_hitstop()

	assert_eq(Engine.time_scale, 1.0)


func test_freeing_one_of_two_hitstopped_players_does_not_restore_early() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	var other_player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	other_player.melee_hitstop_duration = 5.0
	other_player.melee_hitstop_time_scale = 0.5
	add_child(other_player)
	_player._start_hitstop()
	other_player._start_hitstop()

	other_player.free()

	assert_eq(Engine.time_scale, 0.5)

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 1.0)


func test_hitstop_end_preserves_external_time_scale_change() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	_player._start_hitstop()

	# Another system pauses through the shared coordinator while hitstop is active.
	TimeScaleManager.set_base_time_scale(0.0)

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.0)
	assert_eq(TimeScaleManager.get_modifier_count(), 0)


func test_overlapping_hitstops_preserve_external_time_scale_change() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	var other_player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	other_player.melee_hitstop_duration = 5.0
	other_player.melee_hitstop_time_scale = 0.5
	add_child_autofree(other_player)
	_player._start_hitstop()
	other_player._start_hitstop()

	TimeScaleManager.set_base_time_scale(0.1)

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.1)

	other_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.1)


func test_same_scale_external_change_survives_hitstop_end() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	_player._start_hitstop()

	# This was the false-positive case for float equality ownership checks.
	TimeScaleManager.set_base_time_scale(0.5)
	_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.5)


func test_stale_timeout_generation_is_ignored() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	_player._start_hitstop()
	var stale_generation: int = _player._hitstop_generation
	_player._end_hitstop()
	_player._start_hitstop()

	_player._on_hitstop_timer_timeout(stale_generation)

	assert_eq(Engine.time_scale, 0.5)
	assert_eq(TimeScaleManager.get_modifier_count(), 1)

	_player._on_hitstop_timer_timeout(_player._hitstop_generation)

	assert_eq(Engine.time_scale, 1.0)
	assert_eq(TimeScaleManager.get_modifier_count(), 0)


func test_stale_timer_after_reparent_does_not_end_new_hitstop() -> void:
	_player.melee_hitstop_duration = 0.1
	_player.melee_hitstop_time_scale = 0.5
	_player._start_hitstop()

	remove_child(_player)

	assert_eq(Engine.time_scale, 1.0)

	add_child(_player)
	_player.melee_hitstop_duration = 5.0
	_player._start_hitstop()

	assert_eq(Engine.time_scale, 0.5)

	# Real time long enough for the first hitstop's 0.1 s timer to fire.
	await wait_seconds(0.4)

	assert_eq(Engine.time_scale, 0.5)

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 1.0)


func test_ending_hitstop_twice_does_not_release_another_modifier() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	_player._start_hitstop()
	_player._end_hitstop()
	_player._end_hitstop()

	assert_eq(TimeScaleManager.get_modifier_count(), 0)
	assert_eq(Engine.time_scale, 1.0)


func _create_target(position_offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	var target_hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	target_hurtbox.name = "Hurtbox"
	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	health.invulnerability_duration = 0.0
	target.add_child(target_hurtbox)
	target.add_child(health)
	add_child_autofree(target)
	target.global_position = _player.global_position + position_offset
	target_hurtbox.hit_received.connect(health.apply_hit)
	return target
