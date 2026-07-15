class_name PlayerSkillEffectRegistry
extends RefCounted
## Contract between authored skill payloads and live player consumers.

const SUPPORTED_STAT_PARAMETERS: Array[StringName] = [
	&"attack_multiplier",
	&"max_hp_bonus",
	&"max_energy_bonus",
]
const SUPPORTED_ABILITY_MODIFIERS: Dictionary[StringName, Array] = {
	&"starter_relic_bolt": [&"damage_multiplier"],
}
const SUPPORTED_UNLOCKED_ABILITIES: Dictionary[StringName, Array] = {
	&"short_teleport": [&"distance_bonus", &"energy_cost"],
}


static func supports(skill: SkillNode) -> bool:
	if skill == null:
		return false
	match skill.effect_type:
		SkillNode.EffectType.STAT_MODIFIER:
			return _all_parameters_supported(skill.effect_parameters, SUPPORTED_STAT_PARAMETERS)
		SkillNode.EffectType.ABILITY_MODIFIER:
			var ability_id: StringName = skill.effect_parameters.get(&"ability_id", &"")
			if not SUPPORTED_ABILITY_MODIFIERS.has(ability_id):
				return false
			var allowed: Array = SUPPORTED_ABILITY_MODIFIERS[ability_id]
			return _all_parameters_supported(
				skill.effect_parameters, allowed, SkillNode.ABILITY_ID_KEY
			)
		SkillNode.EffectType.UNLOCK_ABILITY:
			var ability_id: StringName = skill.effect_parameters.get(&"ability_id", &"")
			if not SUPPORTED_UNLOCKED_ABILITIES.has(ability_id):
				return false
			var allowed: Array = SUPPORTED_UNLOCKED_ABILITIES[ability_id]
			return _all_parameters_supported(
				skill.effect_parameters, allowed, SkillNode.ABILITY_ID_KEY
			)
	return false


static func _all_parameters_supported(
	parameters: Dictionary[StringName, Variant],
	allowed_keys: Array,
	ignored_key: StringName = &"",
) -> bool:
	for key: StringName in parameters:
		if key == ignored_key:
			continue
		if not allowed_keys.has(key):
			return false
	return not parameters.is_empty()
