extends GutTest
## Coverage for FlavorNpc (issue #26): proximity prompt, bark cycling on
## interact, timed bark hiding, and silent degradation without a bark set.

const NPC_SCENE := preload("res://scenes/world/flavor_npc.tscn")
const BARK_SET_SCRIPT := preload("res://scripts/resources/npc_bark_set.gd")


func _make_bark_set() -> NpcBarkSet:
	var bark_set: NpcBarkSet = BARK_SET_SCRIPT.new()
	bark_set.npc_name = "Test NPC"
	var barks: Array[String] = ["First line.", "Second line."]
	bark_set.barks = barks
	return bark_set


func _spawn_npc(bark_set: NpcBarkSet) -> FlavorNpc:
	var npc: FlavorNpc = NPC_SCENE.instantiate()
	npc.bark_set = bark_set
	npc.bark_duration = 0.5
	add_child_autofree(npc)
	return npc


func _player_body() -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"player")
	add_child_autofree(body)
	return body


func test_registers_in_the_npc_group_and_shows_its_name() -> void:
	var npc: FlavorNpc = _spawn_npc(_make_bark_set())

	assert_true(npc.is_in_group(FlavorNpc.NPC_GROUP))
	assert_eq((npc.get_node("%NameLabel") as Label).text, "Test NPC")
	assert_false(npc.is_barking())


func test_player_proximity_toggles_the_prompt() -> void:
	var npc: FlavorNpc = _spawn_npc(_make_bark_set())
	var body: CharacterBody2D = _player_body()
	var prompt: Label = npc.get_node("%PromptLabel") as Label

	assert_false(prompt.visible, "Prompt starts hidden.")

	npc.body_entered.emit(body)
	assert_true(npc.is_player_nearby())
	assert_true(prompt.visible)

	npc.body_exited.emit(body)
	assert_false(npc.is_player_nearby())
	assert_false(prompt.visible)


func test_non_player_bodies_are_ignored() -> void:
	var npc: FlavorNpc = _spawn_npc(_make_bark_set())
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(body)

	npc.body_entered.emit(body)

	assert_false(npc.is_player_nearby())
	assert_false((npc.get_node("%PromptLabel") as Label).visible)


func test_interact_shows_barks_in_order_and_wraps() -> void:
	var npc: FlavorNpc = _spawn_npc(_make_bark_set())
	watch_signals(npc)
	npc.body_entered.emit(_player_body())

	assert_true(npc.interact())
	assert_true(npc.is_barking())
	assert_eq(npc.get_current_bark(), "First line.")
	assert_signal_emitted_with_parameters(npc, "barked", ["First line."])

	npc.interact()
	assert_eq(npc.get_current_bark(), "Second line.")

	npc.interact()
	assert_eq(npc.get_current_bark(), "First line.", "Barks wrap around.")
	assert_signal_emit_count(npc, "barked", 3)


func test_bark_hides_after_its_duration_and_prompt_returns() -> void:
	var npc: FlavorNpc = _spawn_npc(_make_bark_set())
	npc.body_entered.emit(_player_body())
	npc.interact()

	assert_false(
		(npc.get_node("%PromptLabel") as Label).visible,
		"Prompt hides while the NPC is barking."
	)

	await wait_seconds(0.8)

	assert_false(npc.is_barking())
	assert_true(
		(npc.get_node("%PromptLabel") as Label).visible,
		"Prompt returns for the still-nearby player."
	)


func test_npc_without_a_bark_set_warns_and_stays_silent() -> void:
	var npc: FlavorNpc = _spawn_npc(null)
	watch_signals(npc)
	npc.body_entered.emit(_player_body())

	assert_push_warning("no valid bark set")
	assert_false(npc.interact())
	assert_false(npc.is_barking())
	assert_signal_emit_count(npc, "barked", 0)
