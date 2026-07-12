extends GutTest
## Pure-logic coverage for PlayerStatCalculator against the authored skill
## tree, so the generic *_multiplier / *_bonus aggregation stays correct as
## skill data evolves.

const STEEL_ATTACK: StringName = &"steel_tempered_edge"
const BODY_HP: StringName = &"body_scar_tissue"
const BODY_ENERGY: StringName = &"body_deep_reserves"
const RELIC_BOLT: StringName = &"relic_resonant_spark"
const RELIC_TELEPORT: StringName = &"relic_fold_step"
const BOLT_ABILITY: StringName = &"starter_relic_bolt"

var _tree: SkillTree


func before_all() -> void:
	_tree = GameState.skill_tree


func test_no_unlocks_yields_identity_stats() -> void:
	var none: Array[StringName] = []
	assert_eq(PlayerStatCalculator.get_stat_multiplier(_tree, none, &"attack"), 1.0)
	assert_eq(PlayerStatCalculator.get_stat_bonus(_tree, none, &"max_hp"), 0.0)
	assert_eq(
		PlayerStatCalculator.get_ability_multiplier(_tree, none, BOLT_ABILITY, &"damage"), 1.0
	)
	assert_true(PlayerStatCalculator.get_granted_ability_ids(_tree, none).is_empty())


func test_attack_multiplier_reads_stat_modifier_nodes() -> void:
	var unlocked: Array[StringName] = [STEEL_ATTACK]
	assert_almost_eq(
		PlayerStatCalculator.get_stat_multiplier(_tree, unlocked, &"attack"), 1.1, 0.0001
	)


func test_stat_bonuses_sum_per_stat_key() -> void:
	var unlocked: Array[StringName] = [BODY_HP, BODY_ENERGY]
	assert_eq(PlayerStatCalculator.get_stat_bonus(_tree, unlocked, &"max_hp"), 10.0)
	assert_eq(PlayerStatCalculator.get_stat_bonus(_tree, unlocked, &"max_energy"), 15.0)


func test_ability_multiplier_is_scoped_to_its_ability_id() -> void:
	var unlocked: Array[StringName] = [RELIC_BOLT]
	assert_almost_eq(
		PlayerStatCalculator.get_ability_multiplier(_tree, unlocked, BOLT_ABILITY, &"damage"),
		1.15,
		0.0001
	)
	assert_eq(
		PlayerStatCalculator.get_ability_multiplier(_tree, unlocked, &"dash", &"damage"), 1.0
	)
	# ABILITY_MODIFIER nodes never leak into flat stat multipliers.
	assert_eq(PlayerStatCalculator.get_stat_multiplier(_tree, unlocked, &"damage"), 1.0)


func test_unlock_ability_nodes_report_granted_ability_ids() -> void:
	var unlocked: Array[StringName] = [RELIC_TELEPORT]
	assert_eq(
		PlayerStatCalculator.get_granted_ability_ids(_tree, unlocked),
		[&"short_teleport"] as Array[StringName]
	)


func test_unknown_ids_and_null_tree_are_harmless() -> void:
	var unlocked: Array[StringName] = [&"not_a_real_skill"]
	assert_eq(PlayerStatCalculator.get_stat_multiplier(_tree, unlocked, &"attack"), 1.0)
	assert_eq(PlayerStatCalculator.get_stat_multiplier(null, unlocked, &"attack"), 1.0)
