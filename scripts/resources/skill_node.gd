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

	return errors
