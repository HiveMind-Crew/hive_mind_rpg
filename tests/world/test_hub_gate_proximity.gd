extends GutTest
## Regression coverage for issue #135: the hub's Zone 1 gate must react to the
## real player body physically overlapping %GateZone under the main/GameManager
## composition. Issue #128 moved actor bodies onto dedicated physics layers,
## which silently stopped the gate's Area2D (still scanning the default WORLD
## mask) from ever seeing the player in live runs while signal-level tests
## stayed green. These tests never emit body_entered or call gate.interact()
## by hand — they move the live player through the physics server and press
## the real keyboard/joypad Interact bindings, then follow the transition all
## the way into Zone 1. Save hygiene mirrors test_main_scene/test_hub: worlds
## persist runs through SaveManager, so it is redirected at a scratch file and
## progression resets around every test.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE_PATH: String = "user://test_hub_gate_proximity_savegame.json"
## Deferred world swaps land within a frame or two; walking in/out of the zone
## takes tens of physics frames. Generous so headless runs never flake.
const DEADLINE_FRAMES: int = 240

var _manager: GameManager
var _input_sender: GutInputSender


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()
	_input_sender = GutInputSender.new(Input)
	_manager = MAIN_SCENE.instantiate() as GameManager
	add_child_autofree(_manager)
	await wait_physics_frames(2)


func after_each() -> void:
	_input_sender.release_all()
	_input_sender.clear()
	get_tree().paused = false
	TimeScaleManager.reset()
	_delete_test_save()
	_forget_run_state()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	GameState.reset_progress()


func test_walking_onto_the_gate_shows_the_prompt_and_walking_off_hides_it() -> void:
	var gate: InteractableZone = _gate()
	var prompt: Label = gate.get_node("%PromptLabel") as Label
	var player: PlayerController = _manager.get_player()

	player.global_position = gate.global_position + Vector2(-60.0, 0.0)
	await wait_physics_frames(2)
	assert_false(gate.is_player_nearby(), "Out of range: no proximity yet.")
	assert_false(prompt.visible)

	_input_sender.action_down(&"move_right")
	await _wait_until(
		func() -> bool: return gate.is_player_nearby(),
		"the walking player never physically entered the gate zone"
	)
	_input_sender.action_up(&"move_right")

	assert_true(prompt.visible, "Real overlap shows the proximity prompt.")
	assert_eq(prompt.text, "[E] Enter Zone 1")

	_input_sender.action_down(&"move_left")
	await _wait_until(
		func() -> bool: return not gate.is_player_nearby(),
		"the walking player never physically left the gate zone"
	)
	_input_sender.action_up(&"move_left")

	assert_false(prompt.visible, "Leaving the overlap hides the prompt again.")


func test_keyboard_interact_at_the_real_gate_travels_to_zone1() -> void:
	await _stand_player_on_gate()

	await _press_and_release_key(KEY_E)
	await _wait_until(
		func() -> bool: return _manager.get_current_world() is Zone1Graybox,
		"pressing E on the gate never swapped the world to Zone 1"
	)

	_assert_player_arrived_in_zone1()


func test_joypad_east_at_the_real_gate_travels_to_zone1() -> void:
	await _stand_player_on_gate()

	await _press_and_release_joypad(JOY_BUTTON_B)
	await _wait_until(
		func() -> bool: return _manager.get_current_world() is Zone1Graybox,
		"pressing controller East on the gate never swapped the world to Zone 1"
	)

	_assert_player_arrived_in_zone1()


func test_mobile_use_touch_at_the_real_gate_travels_to_zone1() -> void:
	await _stand_player_on_gate()
	var controls: MobileVirtualControls = _manager.get_node("MobileVirtualControls") as MobileVirtualControls
	assert_not_null(controls)
	if controls == null:
		return
	# Headless test environments are not touch displays; explicitly enable the
	# component's documented test override and use its public touch contract.
	controls.force_touch_controls = true
	controls.set_forced_viewport_size(Vector2(1280, 720))

	controls.handle_touch_pressed(7, controls.get_button_center(&"interact"))
	Input.flush_buffered_events()
	await _wait_until(
		func() -> bool: return _manager.get_current_world() is Zone1Graybox,
		"the mobile USE touch never dispatched an interaction event to the gate"
	)
	controls.handle_touch_released(7)
	Input.flush_buffered_events()

	_assert_player_arrived_in_zone1()


func _hub() -> Hub:
	return _manager.get_current_world() as Hub


func _gate() -> InteractableZone:
	return _hub().get_node("%GateZone") as InteractableZone


## Places the live player body on the gate and lets the physics server
## register the Area2D overlap — no proximity signal is emitted by hand.
func _stand_player_on_gate() -> void:
	_manager.get_player().global_position = _gate().global_position
	await wait_physics_frames(2)
	assert_true(
		_gate().is_player_nearby(),
		"Precondition: physical overlap must register before interacting."
	)


func _assert_player_arrived_in_zone1() -> void:
	assert_false(_manager.is_hub_active(), "The hub hands the world to Zone 1.")
	var zone: Zone1Graybox = _manager.get_current_world() as Zone1Graybox
	assert_not_null(zone)
	if zone == null:
		return
	var player: PlayerController = _manager.get_player()
	var entrance: Marker2D = zone.get_node("%ZoneEntrance") as Marker2D
	assert_not_null(player, "Zone 1 owns the one live player after the swap.")
	assert_lt(
		player.global_position.distance_to(entrance.global_position), 1.0,
		"The gate drops the player at Zone 1's authored entrance."
	)


func _wait_until(condition: Callable, timeout_message: String) -> void:
	var frames_left: int = DEADLINE_FRAMES
	while frames_left > 0 and not bool(condition.call()):
		frames_left -= 1
		await wait_physics_frames(1)
	assert_gt(frames_left, 0, "Timed out: %s." % timeout_message)


func _press_and_release_key(keycode: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = keycode
	press.pressed = true
	_input_sender.send_event(press)
	Input.flush_buffered_events()
	await wait_process_frames(2)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	_input_sender.send_event(release)
	Input.flush_buffered_events()
	await wait_process_frames(1)


func _press_and_release_joypad(button_index: JoyButton) -> void:
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	_input_sender.send_event(press)
	Input.flush_buffered_events()
	await wait_process_frames(2)
	var release: InputEventJoypadButton = press.duplicate() as InputEventJoypadButton
	release.pressed = false
	_input_sender.send_event(release)
	Input.flush_buffered_events()
	await wait_process_frames(1)


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _forget_run_state() -> void:
	SaveManager.checkpoint_scene_path = ""
	SaveManager.checkpoint_position = Vector2.ZERO
	SaveManager.collected_secret_ids.clear()
	SaveManager.completed_milestone_ids.clear()
