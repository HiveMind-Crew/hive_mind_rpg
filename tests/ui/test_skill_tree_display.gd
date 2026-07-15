extends GutTest
## Pure-logic coverage for SkillTreeDisplay, exercised against the authored
## skill tree so the layout/state helpers stay correct as data evolves.

const ROOT: StringName = &"steel_tempered_edge"
const CHILD: StringName = &"steel_follow_through"
const SIBLING: StringName = &"steel_reversal"
const DEEP: StringName = &"steel_comet_lunge"
const ACTIVE_ROOT: StringName = &"relic_resonant_spark"
const ACTIVE_CHILD: StringName = &"relic_fold_step"

var _tree: SkillTree


func before_all() -> void:
	_tree = GameState.skill_tree


func test_root_node_is_locked_without_points_and_available_with_them() -> void:
	var none: Array[StringName] = []
	assert_eq(SkillTreeDisplay.classify_node(_tree, ACTIVE_ROOT, none, 0), SkillTreeDisplay.State.LOCKED)
	assert_eq(SkillTreeDisplay.classify_node(_tree, ACTIVE_ROOT, none, 1), SkillTreeDisplay.State.AVAILABLE)


func test_unlocked_node_reports_unlocked_even_with_points() -> void:
	var unlocked: Array[StringName] = [ACTIVE_ROOT]
	assert_eq(SkillTreeDisplay.classify_node(_tree, ACTIVE_ROOT, unlocked, 5), SkillTreeDisplay.State.UNLOCKED)


func test_child_is_locked_until_its_prerequisite_is_unlocked() -> void:
	var none: Array[StringName] = []
	assert_eq(SkillTreeDisplay.classify_node(_tree, ACTIVE_CHILD, none, 9), SkillTreeDisplay.State.LOCKED)
	var unlocked: Array[StringName] = [ACTIVE_ROOT]
	assert_eq(SkillTreeDisplay.classify_node(_tree, ACTIVE_CHILD, unlocked, 9), SkillTreeDisplay.State.AVAILABLE)


func test_prerequisite_depth_follows_the_chain() -> void:
	assert_eq(SkillTreeDisplay.get_prerequisite_depth(_tree, ROOT), 0)
	assert_eq(SkillTreeDisplay.get_prerequisite_depth(_tree, CHILD), 1)
	assert_eq(SkillTreeDisplay.get_prerequisite_depth(_tree, DEEP), 3)


func test_branch_rows_group_by_depth_preserving_authored_order() -> void:
	var rows: Array[Array] = SkillTreeDisplay.get_branch_rows(_tree, SkillNode.Branch.STEEL)
	assert_eq(rows.size(), 4)
	assert_eq(rows[0].size(), 1)
	assert_eq((rows[0][0] as SkillNode).id, ROOT)
	assert_eq(rows[1].size(), 2)
	assert_eq((rows[1][0] as SkillNode).id, CHILD)
	assert_eq((rows[1][1] as SkillNode).id, SIBLING)


func test_lock_reasons_empty_for_unlocked_and_nonempty_for_locked() -> void:
	var none: Array[StringName] = []
	assert_false(SkillTreeDisplay.get_lock_reasons(_tree, ACTIVE_CHILD, none, 0).is_empty())
	var unlocked: Array[StringName] = [ACTIVE_ROOT]
	assert_true(SkillTreeDisplay.get_lock_reasons(_tree, ACTIVE_ROOT, unlocked, 0).is_empty())


func test_prerequisite_names_reflect_node_prerequisites() -> void:
	assert_eq(SkillTreeDisplay.get_prerequisite_names(_tree, ROOT).size(), 0)
	assert_eq(SkillTreeDisplay.get_prerequisite_names(_tree, DEEP).size(), 2)
