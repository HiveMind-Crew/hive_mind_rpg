class_name NpcBarkSet
extends Resource
## Authored bark lines for one hub flavor NPC (issue #26). Barks are short
## one-liners cycled in authored order — lore is delivered in passing, never
## through dialogue trees (DESIGN.md §6, pillar 4).

@export var npc_name: String = ""
@export var barks: Array[String] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if npc_name.strip_edges().is_empty():
		errors.append("NPC name must not be empty.")
	if barks.is_empty():
		errors.append("NPC '%s' needs at least one bark line." % npc_name)
	for index: int in barks.size():
		if barks[index].strip_edges().is_empty():
			errors.append("NPC '%s' bark %d must not be blank." % [npc_name, index])
	return errors


func is_valid() -> bool:
	return validate().is_empty()
