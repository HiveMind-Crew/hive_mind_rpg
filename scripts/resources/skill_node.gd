class_name SkillNode
extends Resource


enum Branch {
	STEEL,
	RELIC,
	BODY,
}

enum EffectType {
	STAT_MODIFIER,
	ABILITY_MODIFIER,
	UNLOCK_ABILITY,
}

# Effect payload schema (coordinated with issue #17's generic effect layer,
# which multiplies *_multiplier values and adds *_bonus values per stat):
# - STAT_MODIFIER: one or more numeric *_multiplier / *_bonus parameters.
# - ABILITY_MODIFIER: 'ability_id' plus one or more *_multiplier / *_bonus.
# - UNLOCK_ABILITY: 'ability_id' plus optional *_multiplier / *_bonus /
#   *_cost / *_seconds tuning values.
const ABILITY_ID_KEY := &"ability_id"
const MODIFIER_KEY_SUFFIXES: PackedStringArray = ["_multiplier", "_bonus"]
const UNLOCK_KEY_SUFFIXES: PackedStringArray = ["_multiplier", "_bonus", "_cost", "_seconds"]

@export var id: StringName
@export var branch: Branch = Branch.STEEL
@export_range(0, 99, 1) var cost: int = 0
@export var prerequisite_ids: Array[StringName] = []
@export var effect_type: EffectType = EffectType.STAT_MODIFIER
@export var effect_parameters: Dictionary[StringName, Variant] = {}
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var id_text: String = str(id)

	if id_text.is_empty():
		errors.append("Skill id must not be empty.")
	elif not id_text.is_valid_identifier() or id_text != id_text.to_snake_case():
		errors.append("Skill id '%s' must be a snake_case identifier." % id_text)
	if branch < Branch.STEEL or branch > Branch.BODY:
		errors.append("Skill '%s' has an invalid branch." % id_text)
	if cost < 0:
		errors.append("Skill '%s' cost must not be negative." % id_text)
	if display_name.strip_edges().is_empty():
		errors.append("Skill '%s' must have a display name." % id_text)
	if description.strip_edges().is_empty():
		errors.append("Skill '%s' must have a description." % id_text)

	var seen_prerequisites: Dictionary[StringName, bool] = {}
	for prerequisite_id: StringName in prerequisite_ids:
		if str(prerequisite_id).is_empty():
			errors.append("Skill '%s' has an empty prerequisite id." % id_text)
		elif prerequisite_id == id:
			errors.append("Skill '%s' cannot require itself." % id_text)
		elif seen_prerequisites.has(prerequisite_id):
			errors.append("Skill '%s' repeats prerequisite '%s'." % [id_text, prerequisite_id])
		seen_prerequisites[prerequisite_id] = true

	_validate_effect(errors, id_text)

	return errors


func _validate_effect(errors: PackedStringArray, id_text: String) -> void:
	if effect_type < EffectType.STAT_MODIFIER or effect_type > EffectType.UNLOCK_ABILITY:
		errors.append("Skill '%s' has an invalid effect type." % id_text)
		return

	for key: StringName in effect_parameters:
		var key_text: String = str(key)
		if not key_text.is_valid_identifier() or key_text != key_text.to_snake_case():
			errors.append(
				"Skill '%s' effect parameter key '%s' must be a snake_case identifier."
				% [id_text, key_text]
			)

	match effect_type:
		EffectType.STAT_MODIFIER:
			_validate_stat_modifier_effect(errors, id_text)
		EffectType.ABILITY_MODIFIER:
			_validate_ability_modifier_effect(errors, id_text)
		EffectType.UNLOCK_ABILITY:
			_validate_unlock_ability_effect(errors, id_text)


func _validate_stat_modifier_effect(errors: PackedStringArray, id_text: String) -> void:
	if effect_parameters.is_empty():
		errors.append(
			"Skill '%s' stat modifier effect must define at least one _multiplier or _bonus parameter."
			% id_text
		)
	for key: StringName in effect_parameters:
		if not _key_has_any_suffix(key, MODIFIER_KEY_SUFFIXES):
			errors.append(
				"Skill '%s' stat modifier parameter '%s' must end in _multiplier or _bonus."
				% [id_text, key]
			)
			continue
		_validate_numeric_parameter(errors, id_text, key)


func _validate_ability_modifier_effect(errors: PackedStringArray, id_text: String) -> void:
	_validate_ability_id(errors, id_text)
	var modifier_count: int = 0
	for key: StringName in effect_parameters:
		if key == ABILITY_ID_KEY:
			continue
		if not _key_has_any_suffix(key, MODIFIER_KEY_SUFFIXES):
			errors.append(
				"Skill '%s' ability modifier parameter '%s' must end in _multiplier or _bonus."
				% [id_text, key]
			)
			continue
		modifier_count += 1
		_validate_numeric_parameter(errors, id_text, key)
	if modifier_count == 0:
		errors.append(
			"Skill '%s' ability modifier effect must define at least one _multiplier or _bonus parameter."
			% id_text
		)


func _validate_unlock_ability_effect(errors: PackedStringArray, id_text: String) -> void:
	_validate_ability_id(errors, id_text)
	for key: StringName in effect_parameters:
		if key == ABILITY_ID_KEY:
			continue
		if not _key_has_any_suffix(key, UNLOCK_KEY_SUFFIXES):
			errors.append(
				"Skill '%s' ability unlock parameter '%s' must end in _multiplier, _bonus, _cost, or _seconds."
				% [id_text, key]
			)
			continue
		_validate_numeric_parameter(errors, id_text, key)


func _validate_ability_id(errors: PackedStringArray, id_text: String) -> void:
	if not effect_parameters.has(ABILITY_ID_KEY):
		errors.append("Skill '%s' effect requires an 'ability_id' parameter." % id_text)
		return
	var value: Variant = effect_parameters[ABILITY_ID_KEY]
	# #17's PlayerStatCalculator compares ability ids as StringName, so a plain
	# String payload would silently fail those comparisons.
	if typeof(value) != TYPE_STRING_NAME:
		errors.append(
			"Skill '%s' effect parameter 'ability_id' must be a StringName." % id_text
		)
		return
	var ability_text: String = str(value)
	if not ability_text.is_valid_identifier() or ability_text != ability_text.to_snake_case():
		errors.append(
			"Skill '%s' ability id '%s' must be a snake_case identifier."
			% [id_text, ability_text]
		)


func _validate_numeric_parameter(
	errors: PackedStringArray,
	id_text: String,
	key: StringName,
) -> void:
	var value: Variant = effect_parameters[key]
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		errors.append(
			"Skill '%s' effect parameter '%s' must be an int or float." % [id_text, key]
		)
		return
	var number: float = value
	if not is_finite(number):
		errors.append(
			"Skill '%s' effect parameter '%s' must be a finite number." % [id_text, key]
		)
		return
	var key_text: String = str(key)
	if key_text.ends_with("_multiplier") and number <= 0.0:
		errors.append(
			"Skill '%s' effect parameter '%s' must be greater than zero." % [id_text, key]
		)
	elif key_text.ends_with("_bonus") and number == 0.0:
		# A zero bonus would author an inert skill; reject it as a mistake.
		errors.append("Skill '%s' effect parameter '%s' must not be zero." % [id_text, key])
	elif key_text.ends_with("_cost") and number < 0.0:
		errors.append("Skill '%s' effect parameter '%s' must not be negative." % [id_text, key])
	elif key_text.ends_with("_seconds") and number <= 0.0:
		errors.append(
			"Skill '%s' effect parameter '%s' must be greater than zero." % [id_text, key]
		)


func _key_has_any_suffix(key: StringName, suffixes: PackedStringArray) -> bool:
	var key_text: String = str(key)
	for suffix: String in suffixes:
		# A bare suffix like '_bonus' names no stat, so require a prefix.
		if key_text.length() > suffix.length() and key_text.ends_with(suffix):
			return true
	return false
