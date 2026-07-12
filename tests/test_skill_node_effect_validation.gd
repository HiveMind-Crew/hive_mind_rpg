extends GutTest


func test_rejects_out_of_range_effect_types() -> void:
	var too_high: SkillNode = _make_skill(&"too_high")
	too_high.effect_type = 99
	var negative: SkillNode = _make_skill(&"negative")
	negative.effect_type = -1

	assert_true(_contains_error(too_high.validate(), "invalid effect type"))
	assert_true(_contains_error(negative.validate(), "invalid effect type"))


func test_stat_modifier_rejects_empty_parameters() -> void:
	var skill: SkillNode = _make_skill(&"inert_stat")
	skill.effect_type = SkillNode.EffectType.STAT_MODIFIER
	skill.effect_parameters = {}

	assert_true(_contains_error(
		skill.validate(),
		"must define at least one _multiplier or _bonus parameter",
	))


func test_stat_modifier_rejects_unsupported_key() -> void:
	var skill: SkillNode = _make_skill(&"bad_key")
	skill.effect_type = SkillNode.EffectType.STAT_MODIFIER
	skill.effect_parameters = {&"attack_power": 1.5}

	assert_true(_contains_error(
		skill.validate(),
		"parameter 'attack_power' must end in _multiplier or _bonus",
	))


func test_stat_modifier_rejects_non_numeric_value() -> void:
	var skill: SkillNode = _make_skill(&"bad_value")
	skill.effect_type = SkillNode.EffectType.STAT_MODIFIER
	skill.effect_parameters = {&"attack_multiplier": "big"}

	assert_true(_contains_error(
		skill.validate(),
		"parameter 'attack_multiplier' must be an int or float",
	))


func test_stat_modifier_rejects_non_positive_multiplier() -> void:
	var zero: SkillNode = _make_skill(&"zero_multiplier")
	zero.effect_parameters = {&"attack_multiplier": 0.0}
	var negative: SkillNode = _make_skill(&"negative_multiplier")
	negative.effect_parameters = {&"attack_multiplier": -1.5}

	assert_true(_contains_error(
		zero.validate(),
		"parameter 'attack_multiplier' must be greater than zero",
	))
	assert_true(_contains_error(
		negative.validate(),
		"parameter 'attack_multiplier' must be greater than zero",
	))


func test_stat_modifier_rejects_non_finite_multiplier() -> void:
	var skill: SkillNode = _make_skill(&"infinite_multiplier")
	skill.effect_parameters = {&"attack_multiplier": INF}

	assert_true(_contains_error(
		skill.validate(),
		"parameter 'attack_multiplier' must be a finite number",
	))


func test_stat_modifier_rejects_zero_bonus() -> void:
	var skill: SkillNode = _make_skill(&"inert_bonus")
	skill.effect_parameters = {&"max_hp_bonus": 0}

	assert_true(_contains_error(
		skill.validate(),
		"parameter 'max_hp_bonus' must not be zero",
	))


func test_stat_modifier_rejects_non_snake_case_key() -> void:
	var skill: SkillNode = _make_skill(&"bad_key_case")
	skill.effect_parameters = {&"Attack_Multiplier": 1.1}

	assert_true(_contains_error(
		skill.validate(),
		"parameter key 'Attack_Multiplier' must be a snake_case identifier",
	))


func test_stat_modifier_accepts_generic_multiplier_and_bonus_payload() -> void:
	var skill: SkillNode = _make_skill(&"valid_stat")
	skill.effect_type = SkillNode.EffectType.STAT_MODIFIER
	skill.effect_parameters = {
		&"attack_multiplier": 1.1,
		&"max_hp_bonus": 10,
	}

	assert_eq(skill.validate(), PackedStringArray())


func test_ability_modifier_requires_ability_id() -> void:
	var skill: SkillNode = _make_skill(&"no_ability")
	skill.effect_type = SkillNode.EffectType.ABILITY_MODIFIER
	skill.effect_parameters = {&"damage_multiplier": 1.15}

	assert_true(_contains_error(skill.validate(), "requires an 'ability_id' parameter"))


func test_ability_modifier_requires_at_least_one_modifier() -> void:
	var skill: SkillNode = _make_skill(&"no_modifier")
	skill.effect_type = SkillNode.EffectType.ABILITY_MODIFIER
	skill.effect_parameters = {&"ability_id": &"dash"}

	assert_true(_contains_error(
		skill.validate(),
		"must define at least one _multiplier or _bonus parameter",
	))


func test_ability_modifier_accepts_valid_payload() -> void:
	var skill: SkillNode = _make_skill(&"valid_ability_modifier")
	skill.effect_type = SkillNode.EffectType.ABILITY_MODIFIER
	skill.effect_parameters = {&"ability_id": &"dash", &"recovery_time_multiplier": 0.8}

	assert_eq(skill.validate(), PackedStringArray())


func test_unlock_ability_rejects_empty_parameters() -> void:
	var skill: SkillNode = _make_skill(&"empty_unlock")
	skill.effect_type = SkillNode.EffectType.UNLOCK_ABILITY
	skill.effect_parameters = {}

	assert_true(_contains_error(skill.validate(), "requires an 'ability_id' parameter"))


func test_unlock_ability_rejects_bad_ability_ids() -> void:
	var empty_id: SkillNode = _make_unlock_skill(&"empty_id", &"")
	var not_snake: SkillNode = _make_unlock_skill(&"not_snake", &"Dash Lunge")
	var wrong_type: SkillNode = _make_skill(&"wrong_type")
	wrong_type.effect_type = SkillNode.EffectType.UNLOCK_ABILITY
	wrong_type.effect_parameters = {&"ability_id": 7}

	assert_true(_contains_error(empty_id.validate(), "must be a snake_case identifier"))
	assert_true(_contains_error(not_snake.validate(), "must be a snake_case identifier"))
	assert_true(_contains_error(
		wrong_type.validate(),
		"'ability_id' must be a StringName",
	))


func test_ability_modifier_rejects_plain_string_ability_id() -> void:
	var skill: SkillNode = _make_skill(&"string_ability_modifier")
	skill.effect_type = SkillNode.EffectType.ABILITY_MODIFIER
	skill.effect_parameters = {&"ability_id": "dash", &"damage_multiplier": 1.15}

	assert_true(_contains_error(
		skill.validate(),
		"'ability_id' must be a StringName",
	))


func test_unlock_ability_rejects_plain_string_ability_id() -> void:
	var skill: SkillNode = _make_skill(&"string_unlock")
	skill.effect_type = SkillNode.EffectType.UNLOCK_ABILITY
	skill.effect_parameters = {&"ability_id": "dash_lunge"}

	assert_true(_contains_error(
		skill.validate(),
		"'ability_id' must be a StringName",
	))


func test_unlock_ability_rejects_unsupported_key() -> void:
	var skill: SkillNode = _make_unlock_skill(&"extra_key", &"dash_lunge")
	skill.effect_parameters[&"color"] = 3

	assert_true(_contains_error(
		skill.validate(),
		"parameter 'color' must end in _multiplier, _bonus, _cost, or _seconds",
	))


func test_unlock_ability_rejects_invalid_tuning_values() -> void:
	var negative_cost: SkillNode = _make_unlock_skill(&"negative_cost", &"echo_burst")
	negative_cost.effect_parameters[&"energy_cost"] = -5
	var zero_seconds: SkillNode = _make_unlock_skill(&"zero_seconds", &"time_stutter")
	zero_seconds.effect_parameters[&"duration_seconds"] = 0.0

	assert_true(_contains_error(
		negative_cost.validate(),
		"parameter 'energy_cost' must not be negative",
	))
	assert_true(_contains_error(
		zero_seconds.validate(),
		"parameter 'duration_seconds' must be greater than zero",
	))


func test_unlock_ability_accepts_valid_payloads() -> void:
	var bare: SkillNode = _make_unlock_skill(&"bare_unlock", &"melee_combo_finisher")
	var tuned: SkillNode = _make_unlock_skill(&"tuned_unlock", &"time_stutter")
	tuned.effect_parameters[&"energy_cost"] = 35
	tuned.effect_parameters[&"duration_seconds"] = 1.25
	tuned.effect_parameters[&"damage_multiplier"] = 1.4

	assert_eq(bare.validate(), PackedStringArray())
	assert_eq(tuned.validate(), PackedStringArray())


func test_graph_validation_rejects_malformed_effect_payloads() -> void:
	var bad_type: SkillNode = _make_skill(&"bad_type")
	bad_type.effect_type = 99
	var missing_ability: SkillNode = _make_skill(&"missing_ability")
	missing_ability.effect_type = SkillNode.EffectType.UNLOCK_ABILITY
	missing_ability.effect_parameters = {}
	var tree := SkillTree.new()
	tree.nodes = [bad_type, missing_ability]

	assert_false(tree.is_graph_valid())


func _make_skill(id: StringName) -> SkillNode:
	var skill := SkillNode.new()
	skill.id = id
	skill.cost = 1
	skill.effect_type = SkillNode.EffectType.STAT_MODIFIER
	skill.effect_parameters = {&"attack_multiplier": 1.1}
	skill.display_name = str(id).capitalize()
	skill.description = "Test skill."
	return skill


func _make_unlock_skill(id: StringName, ability_id: StringName) -> SkillNode:
	var skill: SkillNode = _make_skill(id)
	skill.effect_type = SkillNode.EffectType.UNLOCK_ABILITY
	skill.effect_parameters = {&"ability_id": ability_id}
	return skill


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
