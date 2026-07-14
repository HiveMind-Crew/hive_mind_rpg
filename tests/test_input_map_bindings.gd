extends GutTest
## Regression contract for the project input map (issue #80). Every documented
## gameplay action must keep its intended physical keyboard and joypad
## bindings: a wrong axis/button index or a dropped controller event must fail
## here instead of shipping while action-name-based tests stay green.

const MOVEMENT_DEADZONE: float = 0.2
const BUTTON_DEADZONE: float = 0.5
const MOVEMENT_EVENT_COUNT: int = 3
const BUTTON_EVENT_COUNT: int = 2

const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"dash",
	&"attack_melee",
	&"ability_relic",
	&"interact",
	&"pause",
]


func test_every_gameplay_action_exists() -> void:
	for action: StringName in GAMEPLAY_ACTIONS:
		assert_true(InputMap.has_action(action), "InputMap should define %s" % action)


func test_all_gameplay_bindings_accept_any_device() -> void:
	# device -1 means "all devices"; a binding pinned to one joypad slot would
	# silently ignore controllers enumerated at any other index.
	for action: StringName in GAMEPLAY_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			assert_eq(
				event.device,
				-1,
				"%s event %s should bind to all devices" % [action, event.as_text()]
			)


func test_keyboard_bindings_use_physical_keycodes() -> void:
	# Physical keycodes keep WASD-style movement layout-independent (AZERTY,
	# Dvorak); a binding re-added as a plain keycode would regress that.
	for action: StringName in GAMEPLAY_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			var key_event: InputEventKey = event as InputEventKey
			if key_event == null:
				continue
			assert_ne(
				key_event.physical_keycode,
				KEY_NONE,
				"%s keyboard binding should use a physical keycode" % action
			)
			assert_eq(
				key_event.keycode,
				KEY_NONE,
				"%s keyboard binding should not use a layout-dependent keycode" % action
			)


func test_move_up_bindings() -> void:
	_assert_movement_action(&"move_up", KEY_W, JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)


func test_move_down_bindings() -> void:
	_assert_movement_action(&"move_down", KEY_S, JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)


func test_move_left_bindings() -> void:
	_assert_movement_action(&"move_left", KEY_A, JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)


func test_move_right_bindings() -> void:
	_assert_movement_action(&"move_right", KEY_D, JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)


func test_dash_bindings() -> void:
	_assert_button_action(&"dash", KEY_SPACE, JOY_BUTTON_A)


func test_attack_melee_bindings() -> void:
	_assert_button_action(&"attack_melee", KEY_J, JOY_BUTTON_X)


func test_ability_relic_bindings() -> void:
	_assert_button_action(&"ability_relic", KEY_K, JOY_BUTTON_Y)


func test_interact_bindings() -> void:
	_assert_button_action(&"interact", KEY_E, JOY_BUTTON_B)


func test_pause_bindings() -> void:
	_assert_button_action(&"pause", KEY_ESCAPE, JOY_BUTTON_START)


## A movement action must bind exactly: physical key, one signed left-stick
## axis direction, and one D-pad button, with the analog deadzone.
func _assert_movement_action(
	action: StringName,
	physical_keycode: Key,
	axis: JoyAxis,
	axis_direction: float,
	dpad_button: JoyButton
) -> void:
	_assert_event_count(action, MOVEMENT_EVENT_COUNT)
	_assert_deadzone(action, MOVEMENT_DEADZONE)
	_assert_key_binding(action, physical_keycode)
	_assert_joypad_axis_binding(action, axis, axis_direction)
	_assert_joypad_button_binding(action, dpad_button)


## A pressed-style action must bind exactly: physical key and one joypad
## button, with the digital deadzone.
func _assert_button_action(
	action: StringName, physical_keycode: Key, button: JoyButton
) -> void:
	_assert_event_count(action, BUTTON_EVENT_COUNT)
	_assert_deadzone(action, BUTTON_DEADZONE)
	_assert_key_binding(action, physical_keycode)
	_assert_joypad_button_binding(action, button)


func _assert_event_count(action: StringName, expected_count: int) -> void:
	assert_eq(
		InputMap.action_get_events(action).size(),
		expected_count,
		"%s should keep exactly %d bindings" % [action, expected_count]
	)


func _assert_deadzone(action: StringName, expected_deadzone: float) -> void:
	assert_almost_eq(
		InputMap.action_get_deadzone(action),
		expected_deadzone,
		0.001,
		"%s deadzone" % action
	)


func _assert_key_binding(action: StringName, physical_keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = -1
	event.physical_keycode = physical_keycode
	assert_true(
		InputMap.action_has_event(action, event),
		"%s should map physical key %s" % [action, OS.get_keycode_string(physical_keycode)]
	)


func _assert_joypad_button_binding(action: StringName, button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	assert_true(
		InputMap.action_has_event(action, event),
		"%s should map joypad button index %d" % [action, button]
	)


func _assert_joypad_axis_binding(
	action: StringName, axis: JoyAxis, direction: float
) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = direction
	assert_true(
		InputMap.action_has_event(action, event),
		"%s should map joypad axis %d toward %.1f" % [action, axis, direction]
	)

	var opposite: InputEventJoypadMotion = event.duplicate() as InputEventJoypadMotion
	opposite.axis_value = -direction
	assert_false(
		InputMap.action_has_event(action, opposite),
		"%s must not respond to axis %d toward %.1f" % [action, axis, -direction]
	)
