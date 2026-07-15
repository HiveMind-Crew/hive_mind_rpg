extends GutTest


const GAME_STATE_SCRIPT := preload("res://scripts/autoload/game_state.gd")
const ROOT_SKILL: StringName = &"relic_resonant_spark"
const CHILD_SKILL: StringName = &"relic_fold_step"
const UNAVAILABLE_SKILL: StringName = &"steel_follow_through"
const UNAVAILABLE_DEEP_SKILL: StringName = &"steel_comet_lunge"


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


func test_missing_skill_tree_falls_back_to_an_empty_tree() -> void:
	var fallback_tree: SkillTree = GAME_STATE_SCRIPT._validated_skill_tree(null)

	assert_not_null(fallback_tree)
	assert_true(fallback_tree.nodes.is_empty())
	assert_push_error("could not load the authored skill tree")


func test_invalid_skill_tree_falls_back_to_an_empty_tree() -> void:
	var broken_tree := SkillTree.new()
	broken_tree.nodes.append(null)

	var fallback_tree: SkillTree = GAME_STATE_SCRIPT._validated_skill_tree(broken_tree)

	assert_not_null(fallback_tree)
	assert_true(fallback_tree.nodes.is_empty())
	assert_push_error("invalid skill tree")


func test_valid_skill_tree_passes_validation_unchanged() -> void:
	var authored_tree: SkillTree = load("res://data/skills/skill_tree.tres")

	assert_eq(GAME_STATE_SCRIPT._validated_skill_tree(authored_tree), authored_tree)


func test_public_api_degrades_safely_on_the_fallback_tree() -> void:
	var isolated_game_state := GAME_STATE_SCRIPT.new()
	isolated_game_state.skill_tree = SkillTree.new()
	isolated_game_state.award_skill_points(5)

	assert_false(isolated_game_state.can_spend_points(ROOT_SKILL))
	assert_false(isolated_game_state.spend_points(ROOT_SKILL))
	assert_eq(isolated_game_state.get_spent_skill_points(), 0)
	assert_eq(isolated_game_state.get_skill_points(), 5)

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
	GameState.award_skill_points(3)
	GameState.spend_points(ROOT_SKILL)
	GameState.spend_points(CHILD_SKILL)

	assert_eq(GameState.get_spent_skill_points(), 3)
	assert_eq(GameState.get_skill_points(), 0)


func test_respec_refunds_every_spent_point_and_clears_unlocks() -> void:
	GameState.award_skill_points(3)
	GameState.spend_points(ROOT_SKILL)
	GameState.spend_points(CHILD_SKILL)

	assert_eq(GameState.respec_skills(), 3)
	assert_eq(GameState.get_skill_points(), 3)
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


func test_restore_progress_prunes_child_skill_missing_its_prerequisite() -> void:
	watch_signals(GameState)

	var restored: bool = GameState.restore_progress(0, [CHILD_SKILL])

	assert_true(restored)
	assert_false(GameState.is_skill_unlocked(CHILD_SKILL))
	assert_true(GameState.get_unlocked_skill_ids().is_empty())
	assert_signal_emit_count(GameState, "skill_unlocked", 0)
	assert_push_warning("unmet prerequisites")


func test_restore_progress_prunes_chain_above_a_missing_root() -> void:
	var restored: bool = GameState.restore_progress(0, [CHILD_SKILL])

	assert_true(restored)
	assert_true(GameState.get_unlocked_skill_ids().is_empty())


func test_restore_progress_drops_unavailable_authored_skills() -> void:
	var restored: bool = GameState.restore_progress(0, [ROOT_SKILL, UNAVAILABLE_SKILL])

	assert_true(restored)
	assert_eq(GameState.get_unlocked_skill_ids(), [ROOT_SKILL])
	assert_false(GameState.is_skill_unlocked(UNAVAILABLE_SKILL))
	assert_push_warning("unavailable saved skill")


func test_restore_progress_accepts_valid_ids_serialized_out_of_order() -> void:
	var restored: bool = GameState.restore_progress(
		2, [CHILD_SKILL, ROOT_SKILL]
	)

	assert_true(restored)
	assert_eq(
		GameState.get_unlocked_skill_ids(), [CHILD_SKILL, ROOT_SKILL]
	)
	assert_eq(GameState.get_skill_points(), 2)


func test_restore_progress_still_drops_unknown_and_duplicate_ids_before_closure() -> void:
	var restored: bool = GameState.restore_progress(
		1, [ROOT_SKILL, ROOT_SKILL, &"not_a_skill", CHILD_SKILL, CHILD_SKILL]
	)

	assert_true(restored)
	assert_eq(GameState.get_unlocked_skill_ids(), [ROOT_SKILL, CHILD_SKILL])


func test_respec_cannot_refund_pruned_restored_skills() -> void:
	GameState.restore_progress(0, [UNAVAILABLE_SKILL])

	assert_eq(GameState.respec_skills(), 0)
	assert_eq(GameState.get_skill_points(), 0)


func test_respec_refunds_only_the_valid_part_of_a_restored_set() -> void:
	GameState.restore_progress(0, [ROOT_SKILL, UNAVAILABLE_DEEP_SKILL])

	assert_eq(GameState.respec_skills(), 1)
	assert_eq(GameState.get_skill_points(), 1)
