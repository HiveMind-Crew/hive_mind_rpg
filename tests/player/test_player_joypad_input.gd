extends GutTest
## Physical controller coverage for the player (issue #80): drives real
## InputEventJoypadMotion / InputEventJoypadButton (and physical-keycode
## keyboard) events through the Input singleton — not synthetic action names —
## and asserts the mapped gameplay responses: movement, dash, melee, relic.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

const GAMEPLAY_BUTTONS: Array[JoyButton] = [
	JOY_BUTTON_A,
	JOY_BUTTON_B,
	JOY_BUTTON_X,
	JOY_BUTTON_Y,
	JOY_BUTTON_START,
	JOY_BUTTON_DPAD_UP,
	JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT,
]

var _player: PlayerController
var _input_sender: GutInputSender


func before_each() -> void:
	TimeScaleManager.reset()
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_input_sender = GutInputSender.new(Input)


func after_each() -> void:
	_release_all_joypad_input()
	_input_sender.release_all()
	_input_sender.clear()
	for projectile: Node in get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP):
		projectile.free()
	TimeScaleManager.reset()


func test_left_stick_moves_player_in_all_four_directions() -> void:
	await _assert_physical_input_moves_player(
		_joy_motion(JOY_AXIS_LEFT_X, 1.0), _joy_motion(JOY_AXIS_LEFT_X, 0.0), Vector2.RIGHT
	)
	await _assert_physical_input_moves_player(
		_joy_motion(JOY_AXIS_LEFT_X, -1.0), _joy_motion(JOY_AXIS_LEFT_X, 0.0), Vector2.LEFT
	)
	await _assert_physical_input_moves_player(
		_joy_motion(JOY_AXIS_LEFT_Y, -1.0), _joy_motion(JOY_AXIS_LEFT_Y, 0.0), Vector2.UP
	)
	await _assert_physical_input_moves_player(
		_joy_motion(JOY_AXIS_LEFT_Y, 1.0), _joy_motion(JOY_AXIS_LEFT_Y, 0.0), Vector2.DOWN
	)


func test_dpad_moves_player_in_all_four_directions() -> void:
	await _assert_physical_input_moves_player(
		_joy_button(JOY_BUTTON_DPAD_RIGHT, true),
		_joy_button(JOY_BUTTON_DPAD_RIGHT, false),
		Vector2.RIGHT
	)
	await _assert_physical_input_moves_player(
		_joy_button(JOY_BUTTON_DPAD_LEFT, true),
		_joy_button(JOY_BUTTON_DPAD_LEFT, false),
		Vector2.LEFT
	)
	await _assert_physical_input_moves_player(
		_joy_button(JOY_BUTTON_DPAD_UP, true),
		_joy_button(JOY_BUTTON_DPAD_UP, false),
		Vector2.UP
	)
	await _assert_physical_input_moves_player(
		_joy_button(JOY_BUTTON_DPAD_DOWN, true),
		_joy_button(JOY_BUTTON_DPAD_DOWN, false),
		Vector2.DOWN
	)


func test_physical_w_key_moves_player_up() -> void:
	_send(_physical_key(KEY_W, true))

	await wait_physics_frames(3)

	assert_eq(_player.movement_state, PlayerMovementStateMachine.State.MOVE)
	assert_almost_eq(
		_player.velocity.normalized().distance_to(Vector2.UP), 0.0, 0.001
	)

	_send(_physical_key(KEY_W, false))


func test_joypad_bottom_face_button_triggers_dash_with_iframes() -> void:
	var hurtbox: Hurtbox = _player.get_node("Hurtbox") as Hurtbox
	watch_signals(_player)
	_send(_joy_motion(JOY_AXIS_LEFT_X, 1.0))

	await wait_physics_frames(2)

	_send(_joy_button(JOY_BUTTON_A, true))

	await wait_physics_frames(3)

	assert_eq(_player.movement_state, PlayerMovementStateMachine.State.DASH)
	assert_signal_emitted(_player, "dash_started")
	assert_false(hurtbox.enabled, "dash i-frames disable the hurtbox")


func test_joypad_left_face_button_starts_melee_swing() -> void:
	watch_signals(_player)
	_send(_joy_button(JOY_BUTTON_X, true))

	await wait_physics_frames(3)

	assert_true(_player._melee.is_swinging)
	assert_signal_emitted(_player, "melee_swing_started")


func test_joypad_top_face_button_fires_relic_bolt() -> void:
	watch_signals(_player)
	_send(_joy_button(JOY_BUTTON_Y, true))

	await wait_physics_frames(3)

	# Energy regenerates passively each physics frame, so assert the spend
	# happened rather than an exact value.
	assert_lt(_player.energy.current_energy, _player.energy.max_energy)
	assert_true(_player.get_parent().has_node("EnergyBolt"))
	assert_signal_emitted(_player, "relic_ability_fired")


## Presses the physical input, asserts the player accelerates in the mapped
## direction, then releases and lets friction settle back to idle so the next
## direction starts clean.
func _assert_physical_input_moves_player(
	press_event: InputEvent, release_event: InputEvent, expected_direction: Vector2
) -> void:
	_send(press_event)

	await wait_physics_frames(3)

	assert_eq(
		_player.movement_state,
		PlayerMovementStateMachine.State.MOVE,
		"%s should move the player" % press_event.as_text()
	)
	assert_almost_eq(
		_player.velocity.normalized().distance_to(expected_direction),
		0.0,
		0.001,
		"%s should move the player toward %s" % [press_event.as_text(), expected_direction]
	)

	_send(release_event)

	await wait_physics_frames(8)

	assert_eq(
		_player.movement_state,
		PlayerMovementStateMachine.State.IDLE,
		"releasing %s should stop the player" % release_event.as_text()
	)


func _send(event: InputEvent) -> void:
	_input_sender.send_event(event)
	# Sends are buffered like real hardware input; flush so the action state
	# is visible to the next physics frame deterministically.
	Input.flush_buffered_events()


func _release_all_joypad_input() -> void:
	_input_sender.send_event(_joy_motion(JOY_AXIS_LEFT_X, 0.0))
	_input_sender.send_event(_joy_motion(JOY_AXIS_LEFT_Y, 0.0))
	for button: JoyButton in GAMEPLAY_BUTTONS:
		_input_sender.send_event(_joy_button(button, false))
	_input_sender.send_event(_physical_key(KEY_W, false))
	Input.flush_buffered_events()


func _joy_motion(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _joy_button(button_index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = pressed
	return event


func _physical_key(physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	return event
