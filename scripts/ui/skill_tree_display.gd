class_name SkillTreeDisplay
extends RefCounted
## Pure, stateless helpers that translate skill tree data + progression state
## into display decisions (node states, layout depth, tooltip text).
## Kept free of Node/scene dependencies so GUT can test them headlessly.


enum State {
	LOCKED,
	AVAILABLE,
	UNLOCKED,
}


static func classify_node(
	tree: SkillTree,
	skill_id: StringName,
	unlocked_ids: Array[StringName],
	available_points: int,
) -> State:
	if unlocked_ids.has(skill_id):
		return State.UNLOCKED
	if tree.can_unlock(skill_id, unlocked_ids, available_points):
		return State.AVAILABLE
	return State.LOCKED


static func get_lock_reasons(
	tree: SkillTree,
	skill_id: StringName,
	unlocked_ids: Array[StringName],
	available_points: int,
) -> PackedStringArray:
	# Unlocked nodes are not locked, so they never have lock reasons even
	# though SkillTree.get_unlock_errors() reports "already unlocked" for them.
	if unlocked_ids.has(skill_id):
		return PackedStringArray()
	return tree.get_unlock_errors(skill_id, unlocked_ids, available_points)


static func get_prerequisite_names(tree: SkillTree, skill_id: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	var node: SkillNode = tree.get_node(skill_id)
	if node == null:
		return names
	for prerequisite_id: StringName in node.prerequisite_ids:
		var prerequisite: SkillNode = tree.get_node(prerequisite_id)
		if prerequisite != null:
			names.append(prerequisite.display_name)
	return names


static func get_prerequisite_depth(tree: SkillTree, skill_id: StringName) -> int:
	# Depth drives the row a node lands on inside its branch column:
	# roots sit at depth 0, everything else one row below its deepest prereq.
	var memoized_depths: Dictionary[StringName, int] = {}
	return _compute_depth(tree, skill_id, memoized_depths)


static func get_branch_rows(tree: SkillTree, branch: SkillNode.Branch) -> Array[Array]:
	# Rows of SkillNode grouped by prerequisite depth, preserving authored
	# order inside each row. Row index == depth, with no gaps left empty.
	var nodes_by_depth: Dictionary[int, Array] = {}
	var max_depth: int = -1
	for node: SkillNode in tree.nodes:
		if node == null or node.branch != branch:
			continue
		var depth: int = get_prerequisite_depth(tree, node.id)
		if not nodes_by_depth.has(depth):
			nodes_by_depth[depth] = []
		nodes_by_depth[depth].append(node)
		max_depth = maxi(max_depth, depth)

	var rows: Array[Array] = []
	for depth: int in max_depth + 1:
		rows.append(nodes_by_depth.get(depth, []))
	return rows


static func _compute_depth(
	tree: SkillTree,
	skill_id: StringName,
	memoized_depths: Dictionary[StringName, int],
) -> int:
	if memoized_depths.has(skill_id):
		return memoized_depths[skill_id]
	var node: SkillNode = tree.get_node(skill_id)
	if node == null:
		return 0
	# Guards against prerequisite cycles in unvalidated trees: a node seen
	# again while its own depth is being computed contributes depth 0.
	memoized_depths[skill_id] = 0
	var depth: int = 0
	for prerequisite_id: StringName in node.prerequisite_ids:
		depth = maxi(depth, _compute_depth(tree, prerequisite_id, memoized_depths) + 1)
	memoized_depths[skill_id] = depth
	return depth
