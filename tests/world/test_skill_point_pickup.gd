extends GutTest
## Coverage for SkillPointPickup (issue #24): a player touch pays out exactly
## once, records the secret in the save, and an already-collected pickup
## removes itself before it can be seen or re-collected.

const PICKUP_SCENE := preload("res://scenes/world/skill_point_pickup.tscn")
const TEST_SAVE_PATH: String = "user://test_pickup_savegame.json"
const SECRET_ID: StringName = &"test_secret_pickup"


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


func _spawn_pickup(secret_id: StringName = SECRET_ID, pickup_points: int = 1) -> SkillPointPickup:
	var pickup: SkillPointPickup = PICKUP_SCENE.instantiate()
	pickup.secret_id = secret_id
	pickup.points = pickup_points
	add_child_autofree(pickup)
	return pickup


func _player_body() -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"player")
	add_child_autofree(body)
	return body


func test_registers_in_the_pickup_group() -> void:
	var pickup: SkillPointPickup = _spawn_pickup()

	assert_true(pickup.is_in_group(SkillPointPickup.PICKUP_GROUP))


func test_player_touch_awards_points_records_secret_and_frees() -> void:
	var pickup: SkillPointPickup = _spawn_pickup(SECRET_ID, 2)
	watch_signals(pickup)

	pickup.body_entered.emit(_player_body())

	assert_true(pickup.is_collected())
	assert_eq(GameState.get_skill_points(), 2)
	assert_true(SaveManager.is_secret_collected(SECRET_ID))
	assert_true(SaveManager.has_save())
	assert_signal_emit_count(pickup, "collected", 1)
	assert_signal_emitted_with_parameters(pickup, "collected", [SECRET_ID, 2])

	await wait_physics_frames(1)
	assert_false(is_instance_valid(pickup))


func test_non_player_body_is_ignored() -> void:
	var pickup: SkillPointPickup = _spawn_pickup()
	watch_signals(pickup)
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(body)

	pickup.body_entered.emit(body)

	assert_false(pickup.is_collected())
	assert_eq(GameState.get_skill_points(), 0)
	assert_false(SaveManager.is_secret_collected(SECRET_ID))
	assert_signal_emit_count(pickup, "collected", 0)


func test_double_touch_only_pays_out_once() -> void:
	var pickup: SkillPointPickup = _spawn_pickup()
	watch_signals(pickup)
	var body: CharacterBody2D = _player_body()

	pickup.body_entered.emit(body)
	pickup.body_entered.emit(body)

	assert_eq(GameState.get_skill_points(), 1)
	assert_signal_emit_count(pickup, "collected", 1)


func test_already_collected_pickup_frees_itself_on_spawn() -> void:
	SaveManager.record_secret_collected(SECRET_ID)

	var pickup: SkillPointPickup = _spawn_pickup()
	await wait_physics_frames(1)

	assert_false(is_instance_valid(pickup))
	assert_eq(GameState.get_skill_points(), 0)


func test_pickup_without_secret_id_warns_and_cannot_persist() -> void:
	var pickup: SkillPointPickup = _spawn_pickup(&"", 1)

	pickup.body_entered.emit(_player_body())

	assert_push_warning("has no secret_id")
	assert_eq(GameState.get_skill_points(), 1)
	assert_false(SaveManager.has_save())
	assert_true(SaveManager.collected_secret_ids.is_empty())
