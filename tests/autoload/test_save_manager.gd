extends GutTest
## Coverage for the SaveManager autoload (issue #19): save/load round trips,
## checkpoint recording, quit saving, and graceful degradation on missing,
## corrupt, or malformed save files.

const TEST_SAVE_PATH: String = "user://test_savegame.json"
const ROOT_SKILL: StringName = &"steel_tempered_edge"


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


func _write_raw_save(raw_text: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(raw_text)
	file.close()


func test_save_then_load_round_trips_progression_and_checkpoint() -> void:
	GameState.award_skill_points(5)
	GameState.spend_points(ROOT_SKILL)
	SaveManager.record_checkpoint("res://scenes/world/arena_graybox.tscn", Vector2(120, 40))

	GameState.reset_progress()
	_forget_run_state()

	assert_true(SaveManager.load_game())
	assert_eq(GameState.get_skill_points(), 4)
	assert_true(GameState.is_skill_unlocked(ROOT_SKILL))
	assert_eq(SaveManager.checkpoint_scene_path, "res://scenes/world/arena_graybox.tscn")
	assert_eq(SaveManager.checkpoint_position, Vector2(120, 40))
	assert_true(SaveManager.has_checkpoint())


func test_record_checkpoint_writes_the_save_file() -> void:
	watch_signals(SaveManager)
	assert_false(SaveManager.has_save())

	SaveManager.record_checkpoint("res://somewhere.tscn", Vector2(9, 9))

	assert_true(SaveManager.has_save())
	assert_signal_emit_count(SaveManager, "game_saved", 1)


func test_quit_request_saves_the_game() -> void:
	GameState.award_skill_points(2)

	SaveManager._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

	assert_true(SaveManager.has_save())
	GameState.reset_progress()
	assert_true(SaveManager.load_game())
	assert_eq(GameState.get_skill_points(), 2)


func test_missing_save_loads_as_new_game_without_crashing() -> void:
	assert_false(SaveManager.load_game())
	assert_eq(GameState.get_skill_points(), 0)
	assert_false(SaveManager.has_checkpoint())


func test_corrupt_save_falls_back_to_new_game() -> void:
	_write_raw_save("{ not valid json ]]]")

	assert_false(SaveManager.load_game())
	assert_eq(GameState.get_skill_points(), 0)
	assert_true(GameState.get_unlocked_skill_ids().is_empty())


func test_wrong_shape_save_falls_back_to_new_game() -> void:
	_write_raw_save('{"version": 1, "skill_points": "many", "unlocked_skill_ids": 7}')

	assert_false(SaveManager.load_game())
	assert_eq(GameState.get_skill_points(), 0)


func test_unknown_skill_ids_in_save_are_dropped_on_load() -> void:
	_write_raw_save(JSON.stringify({
		"version": 1,
		"skill_points": 3,
		"unlocked_skill_ids": ["steel_tempered_edge", "hacked_super_skill"],
		"checkpoint": {"scene_path": "", "x": 0, "y": 0},
		"collected_secret_ids": [],
	}))

	assert_true(SaveManager.load_game())
	assert_eq(GameState.get_skill_points(), 3)
	assert_true(GameState.is_skill_unlocked(ROOT_SKILL))
	assert_false(GameState.is_skill_unlocked(&"hacked_super_skill"))


func test_clear_save_removes_file_and_resets_run_state() -> void:
	GameState.award_skill_points(2)
	SaveManager.record_checkpoint("res://somewhere.tscn", Vector2(9, 9))

	SaveManager.clear_save()

	assert_false(SaveManager.has_save())
	assert_false(SaveManager.has_checkpoint())
	assert_eq(GameState.get_skill_points(), 0)
