class_name PlayerStatCalculator
extends RefCounted
## Pure aggregation of unlocked skill effects into derived player stats
## (issue #17). Kept free of Node/scene dependencies so GUT can test it
## headlessly, and fully generic over effect_parameters keys:
##
## - STAT_MODIFIER nodes: every `*_multiplier` parameter multiplies into that
##   stat's multiplier, every `*_bonus` parameter sums into that stat's bonus.
## - ABILITY_MODIFIER nodes: the same rule, scoped to one `ability_id`.
##
## A new stat node is therefore a .tres-only change: author a SkillNode whose
## effect_parameters reuse an existing key (or introduce a new key that a
## gameplay consumer reads) and the aggregation picks it up with no code here.

const MULTIPLIER_SUFFIX := "_multiplier"
const BONUS_SUFFIX := "_bonus"


## Product of `<stat_key>_multiplier` across unlocked STAT_MODIFIER nodes.
static func get_stat_multiplier(
	tree: SkillTree,
	unlocked_ids: Array[StringName],
	stat_key: StringName,
) -> float:
	var parameter_key: StringName = StringName(str(stat_key) + MULTIPLIER_SUFFIX)
	var multiplier: float = 1.0
	for node: SkillNode in _unlocked_nodes(tree, unlocked_ids):
		if node.effect_type != SkillNode.EffectType.STAT_MODIFIER:
			continue
		var value: Variant = node.effect_parameters.get(parameter_key)
		if value is float or value is int:
			multiplier *= float(value)
	return multiplier


## Sum of `<stat_key>_bonus` across unlocked STAT_MODIFIER nodes.
static func get_stat_bonus(
	tree: SkillTree,
	unlocked_ids: Array[StringName],
	stat_key: StringName,
) -> float:
	var parameter_key: StringName = StringName(str(stat_key) + BONUS_SUFFIX)
	var bonus: float = 0.0
	for node: SkillNode in _unlocked_nodes(tree, unlocked_ids):
		if node.effect_type != SkillNode.EffectType.STAT_MODIFIER:
			continue
		var value: Variant = node.effect_parameters.get(parameter_key)
		if value is float or value is int:
			bonus += float(value)
	return bonus


## Product of `<stat_key>_multiplier` across unlocked ABILITY_MODIFIER nodes
## whose `ability_id` matches.
static func get_ability_multiplier(
	tree: SkillTree,
	unlocked_ids: Array[StringName],
	ability_id: StringName,
	stat_key: StringName,
) -> float:
	var parameter_key: StringName = StringName(str(stat_key) + MULTIPLIER_SUFFIX)
	var multiplier: float = 1.0
	for node: SkillNode in _unlocked_nodes(tree, unlocked_ids):
		if node.effect_type != SkillNode.EffectType.ABILITY_MODIFIER:
			continue
		if node.effect_parameters.get(&"ability_id") != ability_id:
			continue
		var value: Variant = node.effect_parameters.get(parameter_key)
		if value is float or value is int:
			multiplier *= float(value)
	return multiplier


## Ability ids granted by unlocked UNLOCK_ABILITY nodes.
static func get_granted_ability_ids(
	tree: SkillTree,
	unlocked_ids: Array[StringName],
) -> Array[StringName]:
	var ability_ids: Array[StringName] = []
	for node: SkillNode in _unlocked_nodes(tree, unlocked_ids):
		if node.effect_type != SkillNode.EffectType.UNLOCK_ABILITY:
			continue
		var ability_id: Variant = node.effect_parameters.get(&"ability_id")
		if ability_id is StringName and not ability_ids.has(ability_id):
			ability_ids.append(ability_id)
	return ability_ids


static func _unlocked_nodes(
	tree: SkillTree,
	unlocked_ids: Array[StringName],
) -> Array[SkillNode]:
	var nodes: Array[SkillNode] = []
	if tree == null:
		return nodes
	for skill_id: StringName in unlocked_ids:
		var node: SkillNode = tree.get_node(skill_id)
		if node != null:
			nodes.append(node)
	return nodes
