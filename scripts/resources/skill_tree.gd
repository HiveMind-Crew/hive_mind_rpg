class_name SkillTree
extends Resource


@export var nodes: Array[SkillNode] = []


func validate_graph() -> PackedStringArray:
	var errors := PackedStringArray()
	var nodes_by_id: Dictionary[StringName, SkillNode] = {}

	for index: int in nodes.size():
		var node: SkillNode = nodes[index]
		if node == null:
			errors.append("Skill tree contains a null node at index %d." % index)
			continue
		errors.append_array(node.validate())
		if nodes_by_id.has(node.id):
			errors.append("Duplicate skill id '%s'." % node.id)
		else:
			nodes_by_id[node.id] = node

	for node: SkillNode in nodes:
		if node == null:
			continue
		for prerequisite_id: StringName in node.prerequisite_ids:
			if not nodes_by_id.has(prerequisite_id):
				errors.append(
					"Skill '%s' requires missing skill '%s'." % [node.id, prerequisite_id]
				)

	var visit_states: Dictionary[StringName, int] = {}
	var path: Array[StringName] = []
	for node_id: StringName in nodes_by_id:
		if visit_states.get(node_id, 0) == 0:
			_detect_cycles(node_id, nodes_by_id, visit_states, path, errors)

	return errors


func is_graph_valid() -> bool:
	return validate_graph().is_empty()


func get_node(node_id: StringName) -> SkillNode:
	for node: SkillNode in nodes:
		if node != null and node.id == node_id:
			return node
	return null


func get_unlock_errors(
	node_id: StringName,
	unlocked_ids: Array[StringName],
	available_points: int,
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not validate_graph().is_empty():
		errors.append("Skill tree graph is invalid.")
		return errors
	var node: SkillNode = get_node(node_id)
	if node == null:
		errors.append("Unknown skill id '%s'." % node_id)
		return errors
	if not node.available:
		errors.append("Skill '%s' is not available in this build." % node_id)
	if unlocked_ids.has(node_id):
		errors.append("Skill '%s' is already unlocked." % node_id)
	if available_points < node.cost:
		errors.append(
			"Skill '%s' costs %d points, but only %d are available."
			% [node_id, node.cost, available_points]
		)
	for prerequisite_id: StringName in node.prerequisite_ids:
		if not unlocked_ids.has(prerequisite_id):
			errors.append(
				"Skill '%s' requires '%s' to be unlocked." % [node_id, prerequisite_id]
			)
	return errors


func can_unlock(
	node_id: StringName,
	unlocked_ids: Array[StringName],
	available_points: int,
) -> bool:
	return get_unlock_errors(node_id, unlocked_ids, available_points).is_empty()


func spend_points(
	node_id: StringName,
	unlocked_ids: Array[StringName],
	available_points: int,
) -> int:
	if not can_unlock(node_id, unlocked_ids, available_points):
		return -1
	var node: SkillNode = get_node(node_id)
	return available_points - node.cost


func _detect_cycles(
	node_id: StringName,
	nodes_by_id: Dictionary[StringName, SkillNode],
	visit_states: Dictionary[StringName, int],
	path: Array[StringName],
	errors: PackedStringArray,
) -> void:
	visit_states[node_id] = 1
	path.append(node_id)
	var node: SkillNode = nodes_by_id[node_id]
	for prerequisite_id: StringName in node.prerequisite_ids:
		if not nodes_by_id.has(prerequisite_id):
			continue
		var prerequisite_state: int = visit_states.get(prerequisite_id, 0)
		if prerequisite_state == 0:
			_detect_cycles(prerequisite_id, nodes_by_id, visit_states, path, errors)
		elif prerequisite_state == 1:
			var cycle_start: int = path.find(prerequisite_id)
			var cycle_ids: Array[StringName] = path.slice(cycle_start)
			cycle_ids.append(prerequisite_id)
			var cycle_labels := PackedStringArray()
			for cycle_id: StringName in cycle_ids:
				cycle_labels.append(str(cycle_id))
			errors.append("Skill prerequisite cycle: %s." % " -> ".join(cycle_labels))
	path.pop_back()
	visit_states[node_id] = 2
