extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

const TEST_MELEE_DURATION: float = 0.5

var _player: PlayerController
var _hurtbox: Hurtbox
var _melee_hitbox: Hitbox
var _input_sender: GutInputSender


func before_each() -> void:
	_reset_hitstop_state()
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.melee_duration = TEST_MELEE_DURATION
	_player.melee_hitstop_duration = 0.0
	add_child_autofree(_player)
	_hurtbox = _player.get_node("Hurtbox") as Hurtbox
	_melee_hitbox = _player.get_node("MeleeHitbox") as Hitbox
	_input_sender = GutInputSender.new(Input)


func after_each() -> void:
	_input_sender.release_all()
	_input_sender.clear()
	_reset_hitstop_state()


func _reset_hitstop_state() -> void:
	PlayerController._active_hitstop_count = 0
	PlayerController._pre_hitstop_time_scale = 1.0
	Engine.time_scale = 1.0


func test_dash_toggles_hurtbox_for_iframe_window() -> void:
	_player._movement.update(Vector2.RIGHT, true, 0.0)

	assert_false(_hurtbox.enabled)

	_player._movement.update(Vector2.RIGHT, false, _player.dash_duration)
	_player._movement.finish_frame(Vector2.RIGHT)

	assert_true(_hurtbox.enabled)


func test_cancel_dash_restores_hurtbox() -> void:
	_player._movement.update(Vector2.RIGHT, true, 0.0)
	_player.cancel_dash()

	assert_true(_hurtbox.enabled)


func test_melee_hitbox_is_disabled_by_default() -> void:
	assert_false(_melee_hitbox.monitoring)
	assert_false(_melee_hitbox.monitorable)


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
	Engine.time_scale = 0.25

	_player._start_hitstop()

	assert_eq(Engine.time_scale, 0.5)

	_player._end_hitstop()

	assert_eq(Engine.time_scale, 0.25)


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


func test_ending_hitstop_twice_does_not_underflow_shared_count() -> void:
	_player.melee_hitstop_duration = 5.0
	_player.melee_hitstop_time_scale = 0.5
	_player._start_hitstop()
	_player._end_hitstop()
	_player._end_hitstop()

	assert_eq(PlayerController._active_hitstop_count, 0)
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
