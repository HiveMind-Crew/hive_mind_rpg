extends GutTest
## Coverage for the playable startup composition (issue #68): booting into the
## hub, gate travel into Zone 1 at its authored entrance, pause-menu return to
## the hub, checkpoint behavior under the manager, and the singleton
## player/HUD/camera/autoload guarantee across repeated transitions. Worlds
## persist runs through SaveManager, so the suite redirects it at a scratch
## file and resets progression around every test (same conventions as
## test_hub / test_zone1_graybox).

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE_PATH: String = "user://test_game_manager_savegame.json"
const ZONE1_PATH: String = "res://scenes/world/zone1_graybox.tscn"
const HUB_PATH: String = "res://scenes/world/hub.tscn"
const ROOT_SKILL: StringName = &"steel_tempered_edge"

const AUTOLOAD_NAMES: Array[StringName] = [
	&"GameState", &"TimeScaleManager", &"SaveManager", &"AudioManager",
]


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()


func after_each() -> void:
	# A test that fails mid-pause must not freeze the rest of the suite.
	get_tree().paused = false
	TimeScaleManager.reset()
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


func _add_main() -> GameManager:
	var main: GameManager = MAIN_SCENE.instantiate() as GameManager
	add_child_autofree(main)
	return main


## Drives the hub's real gate contract, then waits out the deferred swap.
func _enter_zone1(main: GameManager) -> Zone1Graybox:
	var hub: Hub = main.get_current_world() as Hub
	assert_not_null(hub, "Entering Zone 1 starts from the hub.")
	(hub.get_node("GateZone") as InteractableZone).interact()
	await wait_process_frames(2)
	return main.get_current_world() as Zone1Graybox


## Drives the real pause-menu button contract, then waits out the swap.
func _return_to_hub(main: GameManager) -> Hub:
	var menu: PauseMenu = main.get_node("PauseMenu") as PauseMenu
	menu.open()
	(menu.get_node("%ReturnToHubButton") as Button).pressed.emit()
	await wait_process_frames(2)
	return main.get_current_world() as Hub


func _players_in_tree() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"player")


func _count_huds(node: Node) -> int:
	var count: int = 0
	if node is PlayerHud:
		count += 1
	for child: Node in node.get_children():
		count += _count_huds(child)
	return count


func _count_cameras(node: Node) -> int:
	var count: int = 0
	if node is Camera2D:
		count += 1
	for child: Node in node.get_children():
		count += _count_cameras(child)
	return count


func _autoload_instance_count(autoload_name: StringName) -> int:
	var count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == autoload_name:
			count += 1
	return count


func _assert_single_player_hud_and_camera(context: String) -> void:
	assert_eq(_players_in_tree().size(), 1, "%s: exactly one player." % context)
	assert_eq(_count_huds(get_tree().root), 1, "%s: exactly one HUD." % context)
	assert_eq(_count_cameras(get_tree().root), 1, "%s: exactly one camera." % context)


func test_startup_boots_into_the_hub_with_one_player_hud_and_camera() -> void:
	var main: GameManager = _add_main()

	assert_true(main.is_hub_active(), "The project boots into the hub.")
	var player: PlayerController = main.get_player()
	assert_not_null(player)
	assert_true(player.is_control_enabled(), "Startup hands the player live input.")
	_assert_single_player_hud_and_camera("startup")
	var menu: PauseMenu = main.get_node("PauseMenu") as PauseMenu
	assert_not_null(menu, "The startup scene owns the persistent pause menu.")
	assert_false(menu.is_open())


func test_hub_gate_entry_loads_zone1_at_its_authored_entrance() -> void:
	var main: GameManager = _add_main()

	var zone: Zone1Graybox = await _enter_zone1(main)

	assert_not_null(zone, "The gate leads into Zone 1.")
	assert_false(main.is_hub_active(), "The hub is gone while Zone 1 is active.")
	var entrance: Marker2D = zone.get_node("ZoneEntrance") as Marker2D
	assert_eq(
		main.get_player().global_position,
		entrance.global_position,
		"Gate travel drops the player at the zone's authored entrance."
	)
	_assert_single_player_hud_and_camera("after entering Zone 1")


func test_pause_menu_return_restores_the_hub_without_duplicates() -> void:
	var main: GameManager = _add_main()
	await _enter_zone1(main)

	var hub: Hub = await _return_to_hub(main)

	assert_not_null(hub, "Return to hub restores the hub world.")
	assert_false(get_tree().paused, "The pause menu unpauses before the swap.")
	assert_eq(Engine.time_scale, 1.0)
	var spawn: Marker2D = hub.get_node("PlayerSpawn") as Marker2D
	assert_eq(
		main.get_player().position,
		spawn.position,
		"The restored hub places the player at its own spawn."
	)
	_assert_single_player_hud_and_camera("after returning to the hub")


func test_return_to_hub_while_in_the_hub_is_a_no_op() -> void:
	var main: GameManager = _add_main()
	var world_before: Node2D = main.get_current_world()

	var hub: Hub = await _return_to_hub(main)

	assert_eq(
		hub, world_before,
		"Returning to the hub from the hub keeps the same world instance."
	)


func test_hud_stays_bound_to_the_player_across_transitions() -> void:
	var main: GameManager = _add_main()

	var zone: Zone1Graybox = await _enter_zone1(main)

	var player: PlayerController = main.get_player()
	var hud: PlayerHud = player.get_node("%PlayerHud") as PlayerHud
	assert_eq(
		hud.health_value, float(player.health.current_health),
		"Zone 1's HUD reflects the live health component."
	)
	assert_not_null(zone)

	await _return_to_hub(main)

	player = main.get_player()
	hud = player.get_node("%PlayerHud") as PlayerHud
	assert_eq(
		hud.health_value, float(player.health.current_health),
		"The restored hub's HUD reflects the live health component."
	)


func test_zone_checkpoint_still_arms_respawn_and_saves_under_main() -> void:
	var main: GameManager = _add_main()
	var zone: Zone1Graybox = await _enter_zone1(main)
	var respawn: RespawnController = zone.get_node("%RespawnController") as RespawnController
	var checkpoint: Checkpoint = (
		zone.get_node("Checkpoints/CheckpointEntrance") as Checkpoint
	)

	checkpoint.body_entered.emit(main.get_player())

	assert_true(checkpoint.is_lit())
	assert_eq(
		respawn.get_respawn_position(),
		checkpoint.get_respawn_position(),
		"Shrines keep arming the zone's respawn point under the manager."
	)
	assert_true(SaveManager.has_save(), "Reaching the shrine still saves the run.")


func test_repeated_transitions_keep_singletons_and_working_contracts() -> void:
	var main: GameManager = _add_main()

	for round_trip: int in 2:
		var zone: Zone1Graybox = await _enter_zone1(main)
		assert_not_null(zone, "Round trip %d enters Zone 1." % round_trip)
		_assert_single_player_hud_and_camera("round trip %d, in zone" % round_trip)

		var hub: Hub = await _return_to_hub(main)
		assert_not_null(hub, "Round trip %d returns to the hub." % round_trip)
		_assert_single_player_hud_and_camera("round trip %d, in hub" % round_trip)

	for autoload_name: StringName in AUTOLOAD_NAMES:
		assert_eq(
			_autoload_instance_count(autoload_name), 1,
			"Transitions never duplicate the %s autoload." % autoload_name
		)


## Simulates a relaunch: the on-disk save is reloaded into memory (what
## SaveManager._ready does at boot) so a freshly added Main sees a prior run.
func _reload_saved_run() -> void:
	GameState.reset_progress()
	_forget_run_state()
	assert_true(SaveManager.load_game(), "Precondition: the saved run reloads from disk.")


func test_startup_continues_into_the_saved_zone_at_the_checkpoint() -> void:
	var checkpoint_position: Vector2 = Vector2(321, 654)
	GameState.award_skill_points(5)
	GameState.spend_points(ROOT_SKILL)
	SaveManager.record_checkpoint(ZONE1_PATH, checkpoint_position)
	_reload_saved_run()

	var main: GameManager = _add_main()
	await wait_process_frames(2)

	var zone: Zone1Graybox = main.get_current_world() as Zone1Graybox
	assert_not_null(zone, "A saved checkpoint continues into that world, not the hub.")
	assert_false(main.is_hub_active())
	assert_eq(
		main.get_player().global_position, checkpoint_position,
		"Continue drops the player on the saved checkpoint, not the zone entrance."
	)
	assert_eq(GameState.get_skill_points(), 4, "Continue restores saved skill points.")
	assert_true(GameState.is_skill_unlocked(ROOT_SKILL), "Continue restores saved unlocks.")
	_assert_single_player_hud_and_camera("after continue")


func test_startup_with_no_save_boots_into_the_hub() -> void:
	# before_each clears the scratch save, so this is the fresh-boot path.
	var main: GameManager = _add_main()

	assert_true(main.is_hub_active(), "A run with no checkpoint starts a new game in the hub.")
	assert_false(SaveManager.has_checkpoint())


func test_continue_with_a_missing_saved_scene_falls_back_to_the_hub() -> void:
	SaveManager.checkpoint_scene_path = "res://scenes/world/does_not_exist.tscn"
	SaveManager.checkpoint_position = Vector2(10, 20)

	var main: GameManager = _add_main()
	await wait_process_frames(1)

	assert_true(main.is_hub_active(), "A missing saved scene path falls back to the hub safely.")


func test_continue_with_a_non_world_saved_scene_falls_back_to_the_hub() -> void:
	# A stale save pointing at the composition root must not recurse into another
	# GameManager; it degrades to the hub.
	SaveManager.checkpoint_scene_path = "res://scenes/main/main.tscn"
	SaveManager.checkpoint_position = Vector2.ZERO

	var main: GameManager = _add_main()
	await wait_process_frames(1)

	assert_true(main.is_hub_active(), "A saved non-world scene falls back to the hub safely.")
	_assert_single_player_hud_and_camera("after non-world fallback")


func test_new_game_wipes_the_prior_run_and_opens_the_hub() -> void:
	GameState.award_skill_points(3)
	SaveManager.record_checkpoint(ZONE1_PATH, Vector2(1, 2))
	_reload_saved_run()
	var main: GameManager = _add_main()
	await wait_process_frames(2)
	assert_false(main.is_hub_active(), "Precondition: the saved run continued into Zone 1.")

	main.start_new_game()
	await wait_process_frames(2)

	assert_true(main.is_hub_active(), "New Game opens the hub.")
	assert_eq(GameState.get_skill_points(), 0, "New Game resets progression.")
	assert_false(SaveManager.has_save(), "New Game clears the save file.")
	assert_false(SaveManager.has_checkpoint(), "New Game forgets the checkpoint.")
	_assert_single_player_hud_and_camera("after new game")


func test_continue_keeps_collected_secrets_that_new_game_then_clears() -> void:
	SaveManager.record_secret_collected(&"secret_alpha")
	SaveManager.record_checkpoint(HUB_PATH, Vector2(5, 5))
	_reload_saved_run()

	var main: GameManager = _add_main()
	await wait_process_frames(2)
	assert_true(
		SaveManager.is_secret_collected(&"secret_alpha"),
		"Continue leaves already-collected secrets collected."
	)

	main.start_new_game()
	await wait_process_frames(1)
	assert_false(
		SaveManager.is_secret_collected(&"secret_alpha"),
		"New Game forgets collected secrets."
	)


func test_zone_checkpoint_records_the_world_scene_not_the_composition_root() -> void:
	var main: GameManager = _add_main()
	var zone: Zone1Graybox = await _enter_zone1(main)
	var checkpoint: Checkpoint = zone.get_node("Checkpoints/CheckpointEntrance") as Checkpoint

	checkpoint.body_entered.emit(main.get_player())

	assert_eq(
		SaveManager.checkpoint_scene_path, zone.scene_file_path,
		"Checkpoints under the manager save the world scene so Continue can reopen it."
	)
	assert_ne(
		SaveManager.checkpoint_scene_path, "res://scenes/main/main.tscn",
		"The saved scene must be the world, never the composition root."
	)


func test_zone1_exit_gate_returns_to_the_hub() -> void:
	var main: GameManager = _add_main()
	var zone: Zone1Graybox = await _enter_zone1(main)
	assert_not_null(zone, "Precondition: gate travel into Zone 1 works.")
	if zone == null:
		return

	var exit_zone: InteractableZone = zone.get_node_or_null("%ExitZone") as InteractableZone
	assert_not_null(exit_zone, "Zone 1 exposes its in-world exit gate (#105).")
	if exit_zone == null:
		return
	exit_zone.interact()
	await wait_process_frames(2)

	assert_true(main.is_hub_active(), "The exit gate travels back to the hub.")
	_assert_single_player_hud_and_camera("after exit-gate return")
