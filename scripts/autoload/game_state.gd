extends Node


signal skill_points_changed(current_points: int)
signal skill_unlocked(skill_id: StringName)
signal skills_respecced(refunded_points: int)
signal progress_reset()

const SKILL_TREE_PATH := "res://data/skills/skill_tree.tres"

var skill_tree: SkillTree
var _skill_points: int = 0
var _unlocked_skill_ids: Array[StringName] = []


func _init() -> void:
	skill_tree = _validated_skill_tree(load(SKILL_TREE_PATH) as SkillTree)


static func _validated_skill_tree(loaded_tree: SkillTree) -> SkillTree:
	# assert() is stripped from exported builds (#36), so a missing or invalid
	# resource must fail loudly at startup via push_error and degrade to an
	# empty tree — every public API treats unknown ids as unspendable, so the
	# game keeps running instead of null-crashing on the first skill query.
	if loaded_tree == null:
		push_error(
			"GameState could not load the authored skill tree at '%s'; skills are disabled."
			% SKILL_TREE_PATH
		)
		return SkillTree.new()
	if not loaded_tree.is_graph_valid():
		push_error(
			"GameState loaded an invalid skill tree from '%s'; skills are disabled."
			% SKILL_TREE_PATH
		)
		return SkillTree.new()
	return loaded_tree


func get_skill_points() -> int:
	return _skill_points


func get_unlocked_skill_ids() -> Array[StringName]:
	# Callers receive a copy so progression can only change through validated operations.
	return _unlocked_skill_ids.duplicate()


func is_skill_unlocked(skill_id: StringName) -> bool:
	return _unlocked_skill_ids.has(skill_id)


func award_skill_points(amount: int) -> bool:
	if amount <= 0:
		return false
	_skill_points += amount
	skill_points_changed.emit(_skill_points)
	return true


func can_spend_points(skill_id: StringName) -> bool:
	return skill_tree.can_unlock(skill_id, _unlocked_skill_ids, _skill_points)


func spend_points(skill_id: StringName) -> bool:
	if not can_spend_points(skill_id):
		return false
	var skill: SkillNode = skill_tree.get_node(skill_id)
	_skill_points -= skill.cost
	_unlocked_skill_ids.append(skill_id)
	skill_points_changed.emit(_skill_points)
	skill_unlocked.emit(skill_id)
	return true


func get_spent_skill_points() -> int:
	var spent_points: int = 0
	for skill_id: StringName in _unlocked_skill_ids:
		var skill: SkillNode = skill_tree.get_node(skill_id)
		if skill != null:
			spent_points += skill.cost
	return spent_points


func respec_skills() -> int:
	var refunded_points: int = get_spent_skill_points()
	if _unlocked_skill_ids.is_empty():
		return 0
	_unlocked_skill_ids.clear()
	_skill_points += refunded_points
	skill_points_changed.emit(_skill_points)
	skills_respecced.emit(refunded_points)
	return refunded_points


func restore_progress(skill_points: int, unlocked_skill_ids: Array[StringName]) -> bool:
	# Restores a saved run (issue #19). Ids are validated against the authored
	# tree, deduped, and pruned to their prerequisite closure (issue #76) so a
	# hand-edited or corrupt save can never inject unknown skills or unlocks
	# that spend_points() progression could not reach — and respec can never
	# refund points for them. Existing unlock/point signals re-fire so live
	# consumers (player stats, tree UI) refresh through their normal paths.
	if skill_points < 0:
		return false
	var known_ids: Array[StringName] = []
	for skill_id: StringName in unlocked_skill_ids:
		var saved_skill: SkillNode = skill_tree.get_node(skill_id)
		if saved_skill == null:
			push_warning("GameState dropped unknown saved skill '%s'." % skill_id)
			continue
		if not saved_skill.available:
			push_warning("GameState dropped unavailable saved skill '%s'." % skill_id)
			continue
		if not known_ids.has(skill_id):
			known_ids.append(skill_id)
	var restored_ids: Array[StringName] = _prerequisite_reachable_subset(known_ids)
	_skill_points = skill_points
	_unlocked_skill_ids = restored_ids
	skill_points_changed.emit(_skill_points)
	for skill_id: StringName in restored_ids:
		skill_unlocked.emit(skill_id)
	return true


func _prerequisite_reachable_subset(candidate_ids: Array[StringName]) -> Array[StringName]:
	# Saves serialize unlock order arbitrarily, so admission iterates to a
	# fixpoint instead of trusting array order: a skill is admitted once every
	# prerequisite is itself admitted, which keeps exactly the unlocks normal
	# spend_points() progression could have produced. Invalid entries are
	# pruned individually — matching the unknown-id policy in
	# restore_progress() — rather than rejecting the whole restore, so one bad
	# unlock cannot cost the player their checkpoint and secrets.
	var admitted_ids: Dictionary[StringName, bool] = {}
	var admitted_new_id: bool = true
	while admitted_new_id:
		admitted_new_id = false
		for skill_id: StringName in candidate_ids:
			if admitted_ids.has(skill_id):
				continue
			if _all_prerequisites_admitted(skill_id, admitted_ids):
				admitted_ids[skill_id] = true
				admitted_new_id = true
	var reachable_ids: Array[StringName] = []
	for skill_id: StringName in candidate_ids:
		if admitted_ids.has(skill_id):
			reachable_ids.append(skill_id)
		else:
			push_warning(
				"GameState dropped saved skill '%s' with unmet prerequisites." % skill_id
			)
	return reachable_ids


func _all_prerequisites_admitted(
	skill_id: StringName,
	admitted_ids: Dictionary[StringName, bool],
) -> bool:
	for prerequisite_id: StringName in skill_tree.get_node(skill_id).prerequisite_ids:
		if not admitted_ids.has(prerequisite_id):
			return false
	return true


func reset_progress() -> void:
	var state_changed: bool = _skill_points != 0 or not _unlocked_skill_ids.is_empty()
	_skill_points = 0
	_unlocked_skill_ids.clear()
	if state_changed:
		skill_points_changed.emit(_skill_points)
		progress_reset.emit()
