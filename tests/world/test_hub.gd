extends GutTest
## Coverage for the hub graybox (issue #20): painted single-screen layout,
## checkpoint shrine setup, the skill-tree station's input lock + screen
## lifecycle, and the zone gate's typed entry request. The shrine persists
## through SaveManager, so the suite redirects it at a scratch file and resets
## progression around every test (same conventions as test_zone1_graybox).

const HUB_SCENE: PackedScene = preload("res://scenes/world/hub.tscn")
const TEST_SAVE_PATH: String = "user://test_hub_savegame.json"


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()


func after_each() -> void:
	_delete_test_save()
	_forget_run_state()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	GameState.reset_progress()


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _forget_run_state() -> void:
	SaveManager.checkpoint_scene_path = ""
	SaveManager.checkpoint_position = Vector2.ZERO
	SaveManager.collected_secret_ids.clear()
	SaveManager.completed_milestone_ids.clear()


func _add_hub() -> Hub:
	var hub: Hub = HUB_SCENE.instantiate() as Hub
	add_child_autofree(hub)
	return hub


func _cell_of(hub: Hub, world_position: Vector2) -> Vector2i:
	var layer: TileMapLayer = hub.get_node("FloorWalls") as TileMapLayer
	return layer.local_to_map(layer.to_local(world_position))


func test_hub_paints_every_cell_and_only_walls_collide() -> void:
	var hub: Hub = _add_hub()
	var layer: TileMapLayer = hub.get_node("FloorWalls") as TileMapLayer
	var atlas: TileSetAtlasSource = (
		layer.tile_set.get_source(Hub.TILE_SOURCE_ID) as TileSetAtlasSource
	)

	var expected_cell_count: int = Hub.HUB_SIZE_TILES.x * Hub.HUB_SIZE_TILES.y
	assert_eq(layer.get_used_cells().size(), expected_cell_count)
	assert_eq(
		layer.get_cell_atlas_coords(Vector2i.ZERO),
		Hub.WALL_TILE_ATLAS_COORDS,
		"Hub corner should be a wall."
	)
	var wall_data: TileData = atlas.get_tile_data(Hub.WALL_TILE_ATLAS_COORDS, 0)
	var floor_data: TileData = atlas.get_tile_data(Hub.FLOOR_TILE_ATLAS_COORDS, 0)
	assert_eq(wall_data.get_collision_polygons_count(0), 1)
	assert_eq(floor_data.get_collision_polygons_count(0), 0)


func test_player_spawns_at_marker_on_floor_in_player_group() -> void:
	var hub: Hub = _add_hub()
	var player: PlayerController = hub.get_node("Player") as PlayerController
	var spawn: Marker2D = hub.get_node("PlayerSpawn") as Marker2D

	assert_not_null(player)
	assert_true(player.is_in_group(&"player"), "Zones and the shrine key off the player group.")
	assert_true(player.is_control_enabled(), "The hub starts with gameplay input live.")
	assert_eq(player.position, spawn.position)
	assert_false(hub.is_wall_cell(_cell_of(hub, spawn.global_position)))


func test_hub_props_sit_on_floor_inside_the_single_screen() -> void:
	var hub: Hub = _add_hub()

	var props: Array[Node2D] = [
		hub.get_node("Checkpoint") as Node2D,
		hub.get_node("StationZone") as Node2D,
		hub.get_node("GateZone") as Node2D,
	]
	for prop: Node2D in props:
		assert_false(
			hub.is_wall_cell(_cell_of(hub, prop.global_position)),
			"%s must sit on a floor cell." % prop.name
		)
	assert_eq(hub.get_hub_bounds().size, Vector2(640, 368), "One-screen settlement room.")


func test_shrine_setup_lights_heals_and_persists_on_player_touch() -> void:
	var hub: Hub = _add_hub()
	var player: PlayerController = hub.get_node("Player") as PlayerController
	var checkpoint: Checkpoint = hub.get_node("Checkpoint") as Checkpoint
	var respawn: RespawnController = hub.get_node("RespawnController") as RespawnController

	assert_true(checkpoint.is_in_group(Checkpoint.CHECKPOINT_GROUP))
	assert_false(checkpoint.is_lit())

	checkpoint.body_entered.emit(player)

	assert_true(checkpoint.is_lit())
	assert_eq(
		respawn.get_respawn_position(),
		checkpoint.get_respawn_position(),
		"The shrine arms the hub's respawn point."
	)
	assert_eq(SaveManager.checkpoint_position, checkpoint.get_respawn_position())
	assert_true(SaveManager.has_save(), "Reaching the shrine saves the run.")


func test_station_interact_opens_the_skill_tree_and_locks_player_input() -> void:
	var hub: Hub = _add_hub()
	var player: PlayerController = hub.get_node("Player") as PlayerController
	var station: InteractableZone = hub.get_node("StationZone") as InteractableZone

	assert_false(hub.is_skill_tree_open())

	station.interact()

	assert_true(hub.is_skill_tree_open())
	assert_false(player.is_control_enabled(), "Gameplay input suspends behind the menu.")
	var layer: CanvasLayer = hub.get_node("ScreenLayer") as CanvasLayer
	assert_eq(layer.get_child_count(), 1)
	assert_not_null(layer.get_child(0) as SkillTreeScreen)


func test_station_interact_again_closes_the_screen_and_restores_input() -> void:
	var hub: Hub = _add_hub()
	var player: PlayerController = hub.get_node("Player") as PlayerController
	var station: InteractableZone = hub.get_node("StationZone") as InteractableZone

	station.interact()
	station.interact()
	await wait_process_frames(2)

	assert_false(hub.is_skill_tree_open())
	assert_true(player.is_control_enabled())
	assert_eq(
		(hub.get_node("ScreenLayer") as CanvasLayer).get_child_count(), 0,
		"The closed screen frees itself."
	)


func test_keyboard_interact_at_the_station_drives_the_full_toggle() -> void:
	var hub: Hub = _add_hub()
	var player: PlayerController = hub.get_node("Player") as PlayerController
	var station: InteractableZone = hub.get_node("StationZone") as InteractableZone
	station.body_entered.emit(player)
	var input_sender: GutInputSender = GutInputSender.new(Input)

	await _press_and_release_key(input_sender, KEY_E)
	assert_true(hub.is_skill_tree_open(), "E at the station opens the screen.")
	assert_false(player.is_control_enabled())

	await _press_and_release_key(input_sender, KEY_E)
	assert_false(hub.is_skill_tree_open(), "E again closes it.")
	assert_true(player.is_control_enabled())

	input_sender.clear()


func test_gate_interact_emits_a_typed_zone_entry_request() -> void:
	var hub: Hub = _add_hub()
	watch_signals(hub)
	var gate: InteractableZone = hub.get_node("GateZone") as InteractableZone

	gate.interact()

	assert_signal_emit_count(hub, "zone_entry_requested", 1)
	assert_signal_emitted_with_parameters(
		hub, "zone_entry_requested", [Hub.GATE_TARGET_ZONE_PATH]
	)
	assert_eq(
		Hub.GATE_TARGET_ZONE_PATH, "res://scenes/world/zone1_graybox.tscn",
		"The slice gate leads to Zone 1."
	)


func test_gate_stays_inert_while_the_skill_tree_screen_is_open() -> void:
	var hub: Hub = _add_hub()
	watch_signals(hub)
	var station: InteractableZone = hub.get_node("StationZone") as InteractableZone
	var gate: InteractableZone = hub.get_node("GateZone") as InteractableZone

	station.interact()
	gate.interact()

	assert_true(hub.is_skill_tree_open(), "The menu keeps input ownership.")
	assert_signal_emit_count(hub, "zone_entry_requested", 0)


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
