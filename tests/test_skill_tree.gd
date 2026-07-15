extends GutTest


const SKILL_TREE_PATH := "res://data/skills/skill_tree.tres"


func test_authored_tree_loads_and_is_valid() -> void:
	var tree: SkillTree = load(SKILL_TREE_PATH) as SkillTree

	assert_not_null(tree)
	assert_eq(tree.nodes.size(), 15)
	assert_true(tree.is_graph_valid(), "Authored skill tree should have a valid graph.")
	assert_eq(_count_branch(tree, SkillNode.Branch.STEEL), 5)
	assert_eq(_count_branch(tree, SkillNode.Branch.RELIC), 5)
	assert_eq(_count_branch(tree, SkillNode.Branch.BODY), 5)


func test_valid_graph_accepts_prerequisite_chain() -> void:
	var root: SkillNode = _make_skill(&"root")
	var child: SkillNode = _make_skill(&"child", [&"root"])
	var tree: SkillTree = _make_tree([root, child])

	assert_true(tree.is_graph_valid())


func test_validation_rejects_duplicate_ids() -> void:
	var tree: SkillTree = _make_tree([_make_skill(&"same"), _make_skill(&"same")])

	assert_true(_contains_error(tree.validate_graph(), "Duplicate skill id 'same'."))


func test_validation_rejects_missing_prerequisite() -> void:
	var tree: SkillTree = _make_tree([_make_skill(&"child", [&"missing"])])

	assert_true(_contains_error(tree.validate_graph(), "requires missing skill 'missing'"))


func test_validation_rejects_cycle() -> void:
	var first: SkillNode = _make_skill(&"first", [&"third"])
	var second: SkillNode = _make_skill(&"second", [&"first"])
	var third: SkillNode = _make_skill(&"third", [&"second"])
	var tree: SkillTree = _make_tree([first, second, third])

	assert_true(_contains_error(tree.validate_graph(), "Skill prerequisite cycle:"))


func test_validation_rejects_negative_cost_even_if_set_by_code() -> void:
	var skill: SkillNode = _make_skill(&"invalid_cost")
	skill.cost = -1

	assert_true(_contains_error(skill.validate(), "cost must not be negative"))


func test_unlock_requires_every_prerequisite() -> void:
	var root_a: SkillNode = _make_skill(&"root_a")
	var root_b: SkillNode = _make_skill(&"root_b")
	var hybrid: SkillNode = _make_skill(&"hybrid", [&"root_a", &"root_b"])
	var tree: SkillTree = _make_tree([root_a, root_b, hybrid])

	assert_false(tree.can_unlock(&"hybrid", [&"root_a"], 10))
	assert_true(tree.can_unlock(&"hybrid", [&"root_a", &"root_b"], 10))


func test_unlock_rejects_insufficient_points() -> void:
	var skill: SkillNode = _make_skill(&"expensive")
	skill.cost = 3
	var tree: SkillTree = _make_tree([skill])

	assert_false(tree.can_unlock(&"expensive", [], 2))
	assert_eq(tree.spend_points(&"expensive", [], 2), -1)


func test_unlock_rejects_unavailable_authored_skills() -> void:
	var skill: SkillNode = _make_skill(&"future_skill")
	skill.available = false
	var tree: SkillTree = _make_tree([skill])

	assert_false(tree.can_unlock(skill.id, [], 10))
	assert_true(_contains_error(tree.get_unlock_errors(skill.id, [], 10), "not available"))


func test_spending_returns_remaining_points_without_mutating_state() -> void:
	var skill: SkillNode = _make_skill(&"affordable")
	skill.cost = 2
	var unlocked_ids: Array[StringName] = []
	var tree: SkillTree = _make_tree([skill])

	assert_eq(tree.spend_points(&"affordable", unlocked_ids, 5), 3)
	assert_true(unlocked_ids.is_empty())


func test_unlock_rejects_already_unlocked_and_unknown_skills() -> void:
	var skill: SkillNode = _make_skill(&"known")
	var tree: SkillTree = _make_tree([skill])

	assert_false(tree.can_unlock(&"known", [&"known"], 10))
	assert_false(tree.can_unlock(&"unknown", [], 10))


func test_unlock_rejects_skills_from_an_invalid_graph() -> void:
	var tree: SkillTree = _make_tree([
		_make_skill(&"duplicate"),
		_make_skill(&"duplicate"),
	])

	assert_false(tree.can_unlock(&"duplicate", [], 10))
	assert_true(_contains_error(
		tree.get_unlock_errors(&"duplicate", [], 10),
		"Skill tree graph is invalid.",
	))


func _make_skill(
	id: StringName,
	prerequisite_ids: Array[StringName] = [],
) -> SkillNode:
	var skill := SkillNode.new()
	skill.id = id
	skill.cost = 1
	skill.prerequisite_ids = prerequisite_ids
	skill.effect_parameters = {&"attack_multiplier": 1.1}
	skill.display_name = str(id).capitalize()
	skill.description = "Test skill."
	return skill


func _make_tree(tree_nodes: Array[SkillNode]) -> SkillTree:
	var tree := SkillTree.new()
	tree.nodes = tree_nodes
	return tree


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false


func _count_branch(tree: SkillTree, branch: SkillNode.Branch) -> int:
	var count: int = 0
	for node: SkillNode in tree.nodes:
		if node.branch == branch:
			count += 1
	return count
