extends GutTest


const GAME_STATE_SCRIPT := preload("res://scripts/autoload/game_state.gd")
const ROOT_SKILL: StringName = &"steel_tempered_edge"
const CHILD_SKILL: StringName = &"steel_follow_through"
const EXPENSIVE_SKILL: StringName = &"steel_guard_breaker"


func before_each() -> void:
	GameState.reset_progress()


func after_each() -> void:
	GameState.reset_progress()


func test_loads_authored_skill_tree() -> void:
	assert_not_null(GameState.skill_tree)
	assert_eq(GameState.skill_tree.nodes.size(), 15)
	assert_true(GameState.skill_tree.is_graph_valid())


func test_can_initialize_outside_the_autoload_runtime() -> void:
	var isolated_game_state := GAME_STATE_SCRIPT.new()

	assert_not_null(isolated_game_state.skill_tree)
	assert_eq(isolated_game_state.get_skill_points(), 0)
	assert_true(isolated_game_state.get_unlocked_skill_ids().is_empty())

	isolated_game_state.free()


func test_awards_positive_skill_points() -> void:
	assert_true(GameState.award_skill_points(3))
	assert_eq(GameState.get_skill_points(), 3)


func test_rejects_zero_and_negative_skill_point_awards() -> void:
	assert_false(GameState.award_skill_points(0))
	assert_false(GameState.award_skill_points(-2))
	assert_eq(GameState.get_skill_points(), 0)


func test_spending_unlocks_skill_and_deducts_its_cost() -> void:
	GameState.award_skill_points(3)

	assert_true(GameState.spend_points(ROOT_SKILL))
	assert_eq(GameState.get_skill_points(), 2)
	assert_true(GameState.is_skill_unlocked(ROOT_SKILL))
	assert_eq(GameState.get_unlocked_skill_ids(), [ROOT_SKILL])


func test_spending_requires_every_prerequisite() -> void:
	GameState.award_skill_points(3)

	assert_false(GameState.spend_points(CHILD_SKILL))
	assert_eq(GameState.get_skill_points(), 3)
	assert_false(GameState.is_skill_unlocked(CHILD_SKILL))


func test_spending_rejects_insufficient_points_and_unknown_skills() -> void:
	assert_false(GameState.spend_points(ROOT_SKILL))
	GameState.award_skill_points(5)
	assert_false(GameState.spend_points(&"unknown_skill"))
	assert_eq(GameState.get_skill_points(), 5)


func test_spending_rejects_duplicate_unlocks() -> void:
	GameState.award_skill_points(3)
	assert_true(GameState.spend_points(ROOT_SKILL))

	assert_false(GameState.spend_points(ROOT_SKILL))
	assert_eq(GameState.get_skill_points(), 2)
	assert_eq(GameState.get_unlocked_skill_ids(), [ROOT_SKILL])


func test_unlocked_id_snapshot_cannot_mutate_game_state() -> void:
	GameState.award_skill_points(1)
	GameState.spend_points(ROOT_SKILL)
	var unlocked_snapshot: Array[StringName] = GameState.get_unlocked_skill_ids()

	unlocked_snapshot.clear()

	assert_true(GameState.is_skill_unlocked(ROOT_SKILL))


func test_reports_total_points_spent_across_unlocked_skills() -> void:
	GameState.award_skill_points(6)
	GameState.spend_points(ROOT_SKILL)
	GameState.spend_points(CHILD_SKILL)
	GameState.spend_points(EXPENSIVE_SKILL)

	assert_eq(GameState.get_spent_skill_points(), 4)
	assert_eq(GameState.get_skill_points(), 2)


func test_respec_refunds_every_spent_point_and_clears_unlocks() -> void:
	GameState.award_skill_points(6)
	GameState.spend_points(ROOT_SKILL)
	GameState.spend_points(CHILD_SKILL)
	GameState.spend_points(EXPENSIVE_SKILL)

	assert_eq(GameState.respec_skills(), 4)
	assert_eq(GameState.get_skill_points(), 6)
	assert_true(GameState.get_unlocked_skill_ids().is_empty())
	assert_eq(GameState.get_spent_skill_points(), 0)


func test_empty_respec_is_a_no_op() -> void:
	GameState.award_skill_points(2)

	assert_eq(GameState.respec_skills(), 0)
	assert_eq(GameState.get_skill_points(), 2)


func test_award_emits_point_change_but_rejected_award_does_not() -> void:
	watch_signals(GameState)

	GameState.award_skill_points(2)
	GameState.award_skill_points(0)

	assert_signal_emit_count(GameState, "skill_points_changed", 1)
	assert_signal_emitted_with_parameters(GameState, "skill_points_changed", [2])


func test_spend_emits_point_and_unlock_signals_only_on_success() -> void:
	GameState.award_skill_points(1)
	watch_signals(GameState)

	GameState.spend_points(ROOT_SKILL)
	GameState.spend_points(ROOT_SKILL)

	assert_signal_emit_count(GameState, "skill_points_changed", 1)
	assert_signal_emitted_with_parameters(GameState, "skill_points_changed", [0])
	assert_signal_emit_count(GameState, "skill_unlocked", 1)
	assert_signal_emitted_with_parameters(GameState, "skill_unlocked", [ROOT_SKILL])


func test_respec_emits_refund_and_point_signals_only_when_skills_are_unlocked() -> void:
	GameState.award_skill_points(2)
	GameState.spend_points(ROOT_SKILL)
	watch_signals(GameState)

	GameState.respec_skills()
	GameState.respec_skills()

	assert_signal_emit_count(GameState, "skill_points_changed", 1)
	assert_signal_emitted_with_parameters(GameState, "skill_points_changed", [2])
	assert_signal_emit_count(GameState, "skills_respecced", 1)
	assert_signal_emitted_with_parameters(GameState, "skills_respecced", [1])


func test_reset_progress_clears_all_state() -> void:
	GameState.award_skill_points(2)
	GameState.spend_points(ROOT_SKILL)

	GameState.reset_progress()

	assert_eq(GameState.get_skill_points(), 0)
	assert_true(GameState.get_unlocked_skill_ids().is_empty())


func test_restore_progress_sets_points_and_unlocks_and_signals() -> void:
	watch_signals(GameState)

	var restored: bool = GameState.restore_progress(4, [ROOT_SKILL, CHILD_SKILL])

	assert_true(restored)
	assert_eq(GameState.get_skill_points(), 4)
	assert_true(GameState.is_skill_unlocked(ROOT_SKILL))
	assert_true(GameState.is_skill_unlocked(CHILD_SKILL))
	assert_signal_emit_count(GameState, "skill_points_changed", 1)
	assert_signal_emit_count(GameState, "skill_unlocked", 2)


func test_restore_progress_drops_unknown_and_duplicate_ids() -> void:
	var restored: bool = GameState.restore_progress(
		1, [ROOT_SKILL, ROOT_SKILL, &"not_a_skill"]
	)

	assert_true(restored)
	assert_eq(GameState.get_unlocked_skill_ids(), [ROOT_SKILL])


func test_restore_progress_rejects_negative_points() -> void:
	GameState.award_skill_points(2)

	assert_false(GameState.restore_progress(-1, []))
	assert_eq(GameState.get_skill_points(), 2)
