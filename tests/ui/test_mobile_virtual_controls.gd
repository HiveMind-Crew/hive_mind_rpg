extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _controls: MobileVirtualControls


func before_each() -> void:
	_controls = MobileVirtualControls.new()
	_controls.force_touch_controls = true
	add_child_autofree(_controls)
	_controls.set_forced_viewport_size(Vector2(1280, 720))


func after_each() -> void:
	get_tree().paused = false
	for action: StringName in MobileVirtualControls.ALL_ACTIONS:
		Input.action_release(action)


func test_landscape_touch_mode_shows_overlay() -> void:
	assert_true(_controls.is_touch_overlay_visible())
	assert_false(_controls.is_rotate_message_visible())


func test_portrait_shows_rotate_message_and_releases_actions() -> void:
	_controls.handle_touch_pressed(1, _controls.get_button_center(&"dash"))
	assert_true(Input.is_action_pressed(&"dash"))

	_controls.set_forced_viewport_size(Vector2(720, 1280))

	assert_false(_controls.is_touch_overlay_visible())
	assert_true(_controls.is_rotate_message_visible())
	assert_false(Input.is_action_pressed(&"dash"))


func test_stick_deadzone_does_not_press_movement() -> void:
	_controls.handle_touch_pressed(1, _controls.get_stick_center() + Vector2(8, 0))

	for action: StringName in MobileVirtualControls.MOVE_ACTIONS:
		assert_false(Input.is_action_pressed(action), "%s must stay released inside deadzone." % action)


func test_stick_diagonal_presses_existing_movement_actions() -> void:
	_controls.handle_touch_pressed(4, _controls.get_stick_center() + Vector2(65, -65))

	assert_true(Input.is_action_pressed(&"move_right"))
	assert_true(Input.is_action_pressed(&"move_up"))
	assert_false(Input.is_action_pressed(&"move_left"))
	assert_false(Input.is_action_pressed(&"move_down"))

	_controls.handle_touch_released(4)
	assert_false(Input.is_action_pressed(&"move_right"))
	assert_false(Input.is_action_pressed(&"move_up"))


func test_action_buttons_press_and_release_named_actions() -> void:
	for action: StringName in MobileVirtualControls.BUTTON_ACTIONS:
		_controls.handle_touch_pressed(action.hash(), _controls.get_button_center(action))
		assert_true(Input.is_action_pressed(action), "%s should use the existing InputMap action." % action)
		_controls.handle_touch_released(action.hash())
		assert_false(Input.is_action_pressed(action), "%s must release when its touch ends." % action)


func test_move_and_action_can_be_held_simultaneously() -> void:
	_controls.handle_touch_pressed(1, _controls.get_stick_center() + Vector2(-70, 0))
	_controls.handle_touch_pressed(2, _controls.get_button_center(&"attack_melee"))

	assert_true(Input.is_action_pressed(&"move_left"))
	assert_true(Input.is_action_pressed(&"attack_melee"))

	_controls.handle_touch_released(2)
	assert_true(Input.is_action_pressed(&"move_left"))
	assert_false(Input.is_action_pressed(&"attack_melee"))


func test_multiple_touches_on_one_button_release_only_after_last_touch() -> void:
	var action: StringName = &"ability_relic"
	var center: Vector2 = _controls.get_button_center(action)
	_controls.handle_touch_pressed(1, center)
	_controls.handle_touch_pressed(2, center)

	assert_eq(_controls.get_pressed_action_count(action), 2)
	_controls.handle_touch_released(1)
	assert_true(Input.is_action_pressed(action))
	assert_eq(_controls.get_pressed_action_count(action), 1)
	_controls.handle_touch_released(2)
	assert_false(Input.is_action_pressed(action))


func test_focus_loss_releases_every_synthetic_action() -> void:
	_controls.handle_touch_pressed(1, _controls.get_stick_center() + Vector2(70, 0))
	_controls.handle_touch_pressed(2, _controls.get_button_center(&"dash"))
	assert_true(Input.is_action_pressed(&"move_right"))
	assert_true(Input.is_action_pressed(&"dash"))

	_controls.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)

	for action: StringName in MobileVirtualControls.ALL_ACTIONS:
		assert_false(Input.is_action_pressed(action), "%s must not stick after focus loss." % action)


func test_pause_hides_overlay_and_releases_synthetic_actions() -> void:
	_controls.handle_touch_pressed(1, _controls.get_button_center(&"dash"))
	get_tree().paused = true
	_controls._process(0.0)

	assert_false(_controls.is_touch_overlay_visible())
	assert_false(Input.is_action_pressed(&"dash"))

	get_tree().paused = false
	_controls._process(0.0)
	assert_true(_controls.is_touch_overlay_visible())


func test_main_owns_controls_above_world_transitions() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)

	var controls: MobileVirtualControls = main.get_node("MobileVirtualControls") as MobileVirtualControls
	assert_not_null(controls)
	assert_eq(controls.get_parent(), main)
	assert_not_null(main.get_node("WorldRoot"))
