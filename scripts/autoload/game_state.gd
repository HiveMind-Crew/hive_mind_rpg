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
	# tree and deduped so a hand-edited or corrupt save can never inject
	# unknown skills; existing unlock/point signals re-fire so live consumers
	# (player stats, tree UI) refresh through their normal paths.
	if skill_points < 0:
		return false
	var restored_ids: Array[StringName] = []
	for skill_id: StringName in unlocked_skill_ids:
		if skill_tree.get_node(skill_id) == null:
			push_warning("GameState dropped unknown saved skill '%s'." % skill_id)
			continue
		if not restored_ids.has(skill_id):
			restored_ids.append(skill_id)
	_skill_points = skill_points
	_unlocked_skill_ids = restored_ids
	skill_points_changed.emit(_skill_points)
	for skill_id: StringName in restored_ids:
		skill_unlocked.emit(skill_id)
	return true


func reset_progress() -> void:
	var state_changed: bool = _skill_points != 0 or not _unlocked_skill_ids.is_empty()
	_skill_points = 0
	_unlocked_skill_ids.clear()
	if state_changed:
		skill_points_changed.emit(_skill_points)
		progress_reset.emit()
