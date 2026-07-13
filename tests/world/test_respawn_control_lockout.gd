extends GutTest
## Integration coverage for issue #79: while the RespawnController runs the
## death → fade → respawn → fade-in transition, the real PlayerController must
## be fully locked out (no movement, dash, melee, or relic input), and control
## must come back exactly once after the transition completes.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

## Long enough that several physics frames happen mid-fade, short enough to
## keep the suite fast.
const FADE_DURATION: float = 0.15

var _player: PlayerController
var _health: HealthComponent
var _controller: RespawnController
var _fade_rect: ColorRect
var _input_sender: GutInputSender


func before_each() -> void:
	TimeScaleManager.reset()
	GameState.reset_progress()
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.melee_hitstop_duration = 0.0
	add_child_autofree(_player)
	_health = _player.get_node("HealthComponent") as HealthComponent
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child_autofree(_fade_rect)
	_controller = RespawnController.new()
	_controller.save_on_checkpoint = false
	_controller.fade_duration = FADE_DURATION
	# Absolute paths: the player is a sibling of the controller, so relative
	# paths cannot be computed before both are in the tree.
	_controller.player_path = _player.get_path()
	_controller.health_component_path = _health.get_path()
	_controller.fade_rect_path = _fade_rect.get_path()
	add_child_autofree(_controller)
	_input_sender = GutInputSender.new(Input)
	await wait_physics_frames(1)


func after_each() -> void:
	_input_sender.release_all()
	_input_sender.clear()
	for projectile: Node in get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP):
		projectile.free()
	TimeScaleManager.reset()
	GameState.reset_progress()


func _kill_player() -> void:
	_health.take_damage(_health.max_health)


func test_respawn_start_stops_velocity_and_disables_control() -> void:
	# Get the player moving before dying so residual velocity is observable.
	_player._movement.update(Vector2.RIGHT, false, 0.5)
	assert_gt(_player._movement.velocity.length(), 0.0)

	_kill_player()
	await wait_physics_frames(1)

	assert_true(_controller.is_respawning())
	assert_false(_player.is_control_enabled())
	assert_eq(_player._movement.velocity, Vector2.ZERO)
	assert_eq(_player.velocity, Vector2.ZERO)


func test_movement_input_has_no_effect_during_respawn() -> void:
	_kill_player()
	await wait_physics_frames(1)
	assert_true(_controller.is_respawning())

	var position_during_respawn: Vector2 = _player.global_position
	_input_sender.action_down("move_right")
	await wait_physics_frames(4)

	assert_true(_controller.is_respawning())
	assert_eq(_player.global_position, position_during_respawn)


func test_dash_and_melee_are_cancelled_at_respawn_start() -> void:
	# Start a dash (i-frames disable the hurtbox) and a melee swing, then die.
	_player._movement.update(Vector2.RIGHT, true, 0.0)
	assert_eq(_player.movement_state, PlayerMovementStateMachine.State.DASH)
	assert_true(_player.try_melee_attack())

	_kill_player()
	await wait_physics_frames(1)

	assert_ne(_player.movement_state, PlayerMovementStateMachine.State.DASH)
	assert_false(_player._melee.is_swinging)
	var melee_hitbox: Hitbox = _player.get_node("MeleeHitbox") as Hitbox
	assert_false(melee_hitbox.monitoring)


func test_attacks_and_relic_are_blocked_during_respawn() -> void:
	_kill_player()
	await wait_physics_frames(1)
	assert_true(_controller.is_respawning())

	assert_false(_player.try_melee_attack())
	assert_false(_player._melee.is_swinging)
	assert_false(_player.try_relic_ability())
	assert_false(_player.get_parent().has_node("EnergyBolt"))

	_input_sender.action_down("attack_melee")
	_input_sender.action_down("ability_relic")
	await wait_physics_frames(3)

	assert_false(_player._melee.is_swinging)
	assert_false(_player.get_parent().has_node("EnergyBolt"))


func test_control_is_restored_exactly_once_after_respawn_completes() -> void:
	watch_signals(_player)
	_kill_player()
	await wait_physics_frames(1)
	assert_true(_controller.is_respawning())

	await _wait_for_respawn_to_finish()

	assert_false(_controller.is_respawning())
	assert_true(_player.is_control_enabled())
	assert_signal_emit_count(_player, "control_enabled_changed", 2)

	# Control genuinely works again: melee starts and movement input moves.
	assert_true(_player.try_melee_attack())
	var resume_position: Vector2 = _player.global_position
	_input_sender.action_down("move_right")
	await wait_physics_frames(6)
	assert_gt(_player.global_position.x, resume_position.x)


func _wait_for_respawn_to_finish() -> void:
	# respawn_finished fires before the fade-in; poll until the whole
	# transition (including control restore) is done.
	var deadline_frames: int = 120
	while _controller.is_respawning() and deadline_frames > 0:
		deadline_frames -= 1
		await wait_physics_frames(1)
	assert_gt(deadline_frames, 0, "respawn transition never finished")
