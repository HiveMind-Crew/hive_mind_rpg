extends GutTest
## Coverage for InteractableZone (issue #20): proximity prompt, the explicit
## interact contract, and the keyboard/joypad Interact paths through the real
## input map.

const ZONE_SCENE := preload("res://scenes/world/interactable_zone.tscn")


func _spawn_zone(prompt_text: String = "[E] Interact") -> InteractableZone:
	var zone: InteractableZone = ZONE_SCENE.instantiate()
	zone.prompt_text = prompt_text
	add_child_autofree(zone)
	return zone


func _player_body() -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"player")
	add_child_autofree(body)
	return body


func test_zone_scans_the_player_body_layer_only() -> void:
	var zone: InteractableZone = _spawn_zone()

	assert_eq(
		zone.collision_mask, CollisionLayers.PLAYER_BODY,
		"Actor bodies left the default layer (issue #128); the zone must scan "
		+ "PLAYER_BODY or real overlap never fires (issue #135)."
	)
	assert_eq(zone.collision_layer, 0, "A pure sensor occupies no physics layer.")


func test_prompt_starts_hidden_with_the_authored_text() -> void:
	var zone: InteractableZone = _spawn_zone("[E] Skill Tree")
	var prompt: Label = zone.get_node("%PromptLabel") as Label

	assert_false(prompt.visible, "Prompt starts hidden.")
	assert_eq(prompt.text, "[E] Skill Tree")


func test_player_proximity_toggles_the_prompt() -> void:
	var zone: InteractableZone = _spawn_zone()
	watch_signals(zone)
	var body: CharacterBody2D = _player_body()
	var prompt: Label = zone.get_node("%PromptLabel") as Label

	zone.body_entered.emit(body)
	assert_true(zone.is_player_nearby())
	assert_true(prompt.visible)
	assert_signal_emitted_with_parameters(zone, "player_nearby_changed", [true])

	zone.body_exited.emit(body)
	assert_false(zone.is_player_nearby())
	assert_false(prompt.visible)
	assert_signal_emitted_with_parameters(zone, "player_nearby_changed", [false])
	assert_signal_emit_count(zone, "player_nearby_changed", 2)


func test_non_player_bodies_are_ignored() -> void:
	var zone: InteractableZone = _spawn_zone()
	watch_signals(zone)
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(body)

	zone.body_entered.emit(body)

	assert_false(zone.is_player_nearby())
	assert_false((zone.get_node("%PromptLabel") as Label).visible)
	assert_signal_emit_count(zone, "player_nearby_changed", 0)


func test_explicit_interact_emits_the_contract_signal() -> void:
	var zone: InteractableZone = _spawn_zone()
	watch_signals(zone)

	zone.interact()

	assert_signal_emit_count(zone, "interacted", 1)


func test_keyboard_interact_fires_only_while_the_player_is_nearby() -> void:
	var zone: InteractableZone = _spawn_zone()
	watch_signals(zone)
	var input_sender: GutInputSender = GutInputSender.new(Input)

	await _press_and_release_key(input_sender, KEY_E)
	assert_signal_emit_count(zone, "interacted", 0, "Far away: the press is ignored.")

	zone.body_entered.emit(_player_body())
	await _press_and_release_key(input_sender, KEY_E)
	assert_signal_emit_count(zone, "interacted", 1)

	input_sender.clear()


func test_physical_joypad_east_button_interacts() -> void:
	# Physical controller path (issue #80): a real B-button event, not a
	# synthetic "interact" action, must reach the zone through the input map.
	var zone: InteractableZone = _spawn_zone()
	watch_signals(zone)
	zone.body_entered.emit(_player_body())
	var input_sender: GutInputSender = GutInputSender.new(Input)
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_B
	press.pressed = true
	input_sender.send_event(press)
	Input.flush_buffered_events()

	await wait_process_frames(2)

	assert_signal_emit_count(zone, "interacted", 1)

	var release: InputEventJoypadButton = press.duplicate() as InputEventJoypadButton
	release.pressed = false
	input_sender.send_event(release)
	Input.flush_buffered_events()
	input_sender.clear()


func _press_and_release_key(input_sender: GutInputSender, keycode: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = keycode
	press.pressed = true
	input_sender.send_event(press)
	Input.flush_buffered_events()
	await wait_process_frames(2)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	input_sender.send_event(release)
	Input.flush_buffered_events()
	await wait_process_frames(1)
