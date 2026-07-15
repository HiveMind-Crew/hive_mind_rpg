extends GutTest
## Coverage for encounter skill-point rewards (issue #60): clearing a rewarding
## EncounterRoom awards its authored points exactly once, cannot be farmed by
## dying and re-clearing, persists through save/load, and stays silent for rooms
## with no reward or invalid reward data.

const ROOM_SCENE: PackedScene = preload("res://scenes/world/encounter_room.tscn")
const TEST_SAVE_PATH: String = "user://test_encounter_reward_save.json"
const REWARD_ID: StringName = &"test_encounter_reward"


class StubEnemy:
	extends Node2D
	## Duck-typed enemy: the room only needs set_target() and enemy_died.

	signal enemy_died()

	func set_target(_new_target: Node2D) -> void:
		pass

	func die() -> void:
		enemy_died.emit()


var _room: EncounterRoom
var _player: Node2D


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()
	_player = Node2D.new()
	_player.add_to_group(&"player")
	add_child_autofree(_player)


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


func _make_reward(reward_id: StringName, points: int) -> EncounterRewardData:
	var reward: EncounterRewardData = EncounterRewardData.new()
	reward.reward_id = reward_id
	reward.skill_points = points
	return reward


func _build_room(reward: EncounterRewardData, enemy_count: int = 1) -> void:
	_room = ROOM_SCENE.instantiate() as EncounterRoom
	_room.reward_data = reward
	var enemies_root: Node2D = _room.get_node("Enemies") as Node2D
	for index: int in enemy_count:
		var enemy: StubEnemy = StubEnemy.new()
		enemy.name = "StubEnemy%d" % index
		enemies_root.add_child(enemy)
	add_child_autofree(_room)
	watch_signals(_room)


func _stub_enemies() -> Array[StubEnemy]:
	var stubs: Array[StubEnemy] = []
	for node: Node in _room.get_assigned_enemies():
		stubs.append(node as StubEnemy)
	return stubs


func _clear_room() -> void:
	_room._on_body_entered(_player)
	for stub_enemy: StubEnemy in _stub_enemies():
		stub_enemy.die()


func test_clearing_a_rewarding_room_awards_the_authored_points_once() -> void:
	_build_room(_make_reward(REWARD_ID, 3))

	_clear_room()

	assert_true(_room.is_completed())
	assert_eq(GameState.get_skill_points(), 3, "Authored reward is awarded on the first clear.")
	assert_signal_emitted_with_parameters(
		_room, "encounter_reward_awarded", [REWARD_ID, 3]
	)


func test_reward_persists_and_marks_the_milestone_completed() -> void:
	_build_room(_make_reward(REWARD_ID, 2))

	_clear_room()

	assert_true(
		SaveManager.is_milestone_completed(REWARD_ID),
		"A paid reward records its completion id."
	)
	assert_true(SaveManager.has_save(), "The reward saves immediately, not just on quit.")


func test_reward_survives_save_load_round_trip() -> void:
	_build_room(_make_reward(REWARD_ID, 4))
	_clear_room()

	GameState.reset_progress()
	_forget_run_state()
	assert_true(SaveManager.load_game())

	assert_eq(GameState.get_skill_points(), 4, "Awarded points reload from the save.")
	assert_true(
		SaveManager.is_milestone_completed(REWARD_ID),
		"The completion id reloads so the reward stays spent."
	)


func test_dying_and_reclearing_does_not_pay_the_reward_twice() -> void:
	_build_room(_make_reward(REWARD_ID, 5))
	_clear_room()
	assert_eq(GameState.get_skill_points(), 5)

	# RespawnController re-arms the room on death; the die-back loop lets the
	# player fight it again, but the reward must not pay a second time.
	_room.reset_to_spawn()
	await wait_physics_frames(1)
	_clear_room()

	assert_true(_room.is_completed())
	assert_eq(GameState.get_skill_points(), 5, "The reward pays once, never per attempt.")
	assert_signal_emit_count(_room, "encounter_reward_awarded", 1)


func test_previously_completed_reward_is_not_reawarded_on_a_fresh_room() -> void:
	# Simulates relaunching into a world whose reward was already collected in an
	# earlier session: the persisted milestone id suppresses the payout.
	SaveManager.record_milestone_completed(REWARD_ID)
	_build_room(_make_reward(REWARD_ID, 3))

	_clear_room()

	assert_true(_room.is_completed(), "The fight still resolves normally.")
	assert_eq(GameState.get_skill_points(), 0, "An already-collected reward pays nothing.")
	assert_signal_emit_count(_room, "encounter_reward_awarded", 0)


func test_room_without_reward_data_awards_nothing() -> void:
	_build_room(null)

	_clear_room()

	assert_true(_room.is_completed())
	assert_eq(GameState.get_skill_points(), 0)
	assert_signal_emit_count(_room, "encounter_reward_awarded", 0)


func test_invalid_reward_data_warns_and_awards_nothing() -> void:
	_build_room(_make_reward(&"", 2))

	_clear_room()

	assert_eq(GameState.get_skill_points(), 0, "An id-less reward is treated as unset.")
	assert_signal_emit_count(_room, "encounter_reward_awarded", 0)
