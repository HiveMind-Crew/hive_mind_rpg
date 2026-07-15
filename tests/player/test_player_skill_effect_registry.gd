extends GutTest

const SKILL_TREE_PATH: String = "res://data/skills/skill_tree.tres"


func test_every_purchasable_skill_has_a_live_runtime_consumer() -> void:
	var tree: SkillTree = load(SKILL_TREE_PATH) as SkillTree
	var unsupported_ids: Array[StringName] = []
	for skill: SkillNode in tree.nodes:
		if skill.available and not PlayerSkillEffectRegistry.supports(skill):
			unsupported_ids.append(skill.id)

	assert_true(
		unsupported_ids.is_empty(),
		"Purchasable skills without runtime consumers: %s" % [unsupported_ids],
	)


func test_unfinished_authored_skills_cannot_be_purchased() -> void:
	var tree: SkillTree = load(SKILL_TREE_PATH) as SkillTree

	assert_false(tree.can_unlock(&"relic_echo_burst", [&"relic_resonant_spark"], 99))
	assert_true(
		"not available" in tree.get_unlock_errors(
			&"relic_echo_burst", [&"relic_resonant_spark"], 99
		)[0]
	)


func test_short_teleport_is_registered_as_a_supported_active_ability() -> void:
	var tree: SkillTree = load(SKILL_TREE_PATH) as SkillTree
	var fold_step: SkillNode = tree.get_node(&"relic_fold_step")

	assert_true(fold_step.available)
	assert_true(PlayerSkillEffectRegistry.supports(fold_step))
