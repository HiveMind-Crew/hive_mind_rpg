class_name SkillTreeScreen
extends Control
## Skill tree menu: three branch columns (Steel / Relic / Body) built from the
## authored SkillTree resource, a detail panel for the focused node, and
## spend/respec actions. All progression state lives in the GameState
## autoload; this screen only reads it and reacts to its signals.

const SKILL_NODE_BUTTON_SCENE := preload("res://scenes/ui/skill_node_button.tscn")

# Columns are laid out left-to-right in this order; must match the column
# containers in skill_tree_screen.tscn.
const BRANCH_ORDER: Array[SkillNode.Branch] = [
	SkillNode.Branch.STEEL,
	SkillNode.Branch.RELIC,
	SkillNode.Branch.BODY,
]

# DEBUG ONLY: points granted when the screen runs standalone (F6), where no
# gameplay exists to earn points. Enough to unlock one full branch.
const DEBUG_STANDALONE_POINTS := 9

const ROW_SEPARATION := 4
const NO_PREREQUISITES_TEXT := "Requires: —"

var _tree: SkillTree
var _buttons_by_id: Dictionary[StringName, SkillNodeButton] = {}
# _button_grid[column][row] is an Array of SkillNodeButton; row == prereq depth.
var _button_grid: Array[Array] = []
var _displayed_skill_id: StringName = &""

@onready var _points_label: Label = %PointsLabel
@onready var _respec_button: Button = %RespecButton
@onready var _steel_column: VBoxContainer = %SteelColumn
@onready var _relic_column: VBoxContainer = %RelicColumn
@onready var _body_column: VBoxContainer = %BodyColumn
@onready var _detail_name_label: Label = %DetailNameLabel
@onready var _detail_cost_label: Label = %DetailCostLabel
@onready var _detail_description_label: Label = %DetailDescriptionLabel
@onready var _detail_prereq_label: Label = %DetailPrereqLabel
@onready var _detail_status_label: Label = %DetailStatusLabel


func _ready() -> void:
	_tree = GameState.skill_tree
	_grant_debug_points_if_standalone()
	_build_branch_columns()
	_wire_focus_neighbors()
	GameState.skill_points_changed.connect(_on_skill_points_changed)
	GameState.skill_unlocked.connect(_on_skill_unlocked)
	GameState.skills_respecced.connect(_on_skills_respecced)
	GameState.progress_reset.connect(_on_progress_reset)
	_respec_button.pressed.connect(_on_respec_button_pressed)
	_refresh_points_label(GameState.get_skill_points())
	_refresh_node_states()
	_clear_detail_panel()
	# Containers finish sizing a frame later; focus after that so gamepad
	# users land on a node immediately.
	_grab_initial_focus.call_deferred()


func _grant_debug_points_if_standalone() -> void:
	# DEBUG PATH: only taken when this scene is run directly with F6, i.e. it
	# IS the current scene instead of being opened from the running game.
	# Without gameplay there is no way to earn points, so grant a test budget
	# once (and only into a fresh GameState) to make spend/respec exercisable.
	if get_tree().current_scene != self:
		return
	if GameState.get_skill_points() > 0 or not GameState.get_unlocked_skill_ids().is_empty():
		return
	GameState.award_skill_points(DEBUG_STANDALONE_POINTS)


func _build_branch_columns() -> void:
	var columns: Array[VBoxContainer] = [_steel_column, _relic_column, _body_column]
	for branch_index: int in BRANCH_ORDER.size():
		var rows: Array[Array] = SkillTreeDisplay.get_branch_rows(_tree, BRANCH_ORDER[branch_index])
		var column_grid: Array = []
		for row: Array in rows:
			var row_container := HBoxContainer.new()
			row_container.alignment = BoxContainer.ALIGNMENT_CENTER
			row_container.add_theme_constant_override("separation", ROW_SEPARATION)
			columns[branch_index].add_child(row_container)
			var row_buttons: Array = []
			for node: SkillNode in row:
				var button := SKILL_NODE_BUTTON_SCENE.instantiate() as SkillNodeButton
				button.setup(node)
				button.pressed.connect(_on_node_button_pressed.bind(node.id))
				button.focus_entered.connect(_on_node_button_focused.bind(node.id))
				row_container.add_child(button)
				_buttons_by_id[node.id] = button
				row_buttons.append(button)
			column_grid.append(row_buttons)
		_button_grid.append(column_grid)


func _wire_focus_neighbors() -> void:
	# Explicit neighbors so arrow keys / d-pad walk the grid predictably:
	# up/down move along a branch, left/right cross rows and branch columns.
	for column_index: int in _button_grid.size():
		var column: Array = _button_grid[column_index]
		for row_index: int in column.size():
			var row: Array = column[row_index]
			for button_index: int in row.size():
				_wire_button_neighbors(column_index, row_index, button_index)
	# Respec sits above the middle branch column, so pressing down lands there.
	@warning_ignore("integer_division")
	var middle_column: int = _button_grid.size() / 2
	var respec_landing: SkillNodeButton = _button_at(middle_column, 0, 0)
	if respec_landing != null:
		_respec_button.focus_neighbor_bottom = _respec_button.get_path_to(respec_landing)


func _wire_button_neighbors(column_index: int, row_index: int, button_index: int) -> void:
	var column: Array = _button_grid[column_index]
	var row: Array = column[row_index]
	var button: SkillNodeButton = row[button_index]

	if row_index > 0:
		var above: SkillNodeButton = _button_at(column_index, row_index - 1, button_index)
		if above != null:
			button.focus_neighbor_top = button.get_path_to(above)
	else:
		# Top row hands focus up to the respec button.
		button.focus_neighbor_top = button.get_path_to(_respec_button)

	if row_index < column.size() - 1:
		var below: SkillNodeButton = _button_at(column_index, row_index + 1, button_index)
		if below != null:
			button.focus_neighbor_bottom = button.get_path_to(below)

	if button_index > 0:
		var left_sibling: SkillNodeButton = row[button_index - 1]
		button.focus_neighbor_left = button.get_path_to(left_sibling)
	elif column_index > 0:
		var left_column_size: int = (_button_grid[column_index - 1] as Array).size()
		var left_target: SkillNodeButton = _button_at(
			column_index - 1, row_index, left_column_size
		)
		if left_target != null:
			button.focus_neighbor_left = button.get_path_to(left_target)

	if button_index < row.size() - 1:
		var right_sibling: SkillNodeButton = row[button_index + 1]
		button.focus_neighbor_right = button.get_path_to(right_sibling)
	elif column_index < _button_grid.size() - 1:
		var right_target: SkillNodeButton = _button_at(column_index + 1, row_index, 0)
		if right_target != null:
			button.focus_neighbor_right = button.get_path_to(right_target)


func _button_at(column_index: int, row_index: int, preferred_index: int) -> SkillNodeButton:
	# Clamps row/button indexes so navigation from a wide/deep column still
	# lands somewhere sensible in a narrower/shallower one.
	var column: Array = _button_grid[column_index]
	if column.is_empty():
		return null
	var row: Array = column[clampi(row_index, 0, column.size() - 1)]
	if row.is_empty():
		return null
	return row[clampi(preferred_index, 0, row.size() - 1)]


func _grab_initial_focus() -> void:
	var unlocked_ids: Array[StringName] = GameState.get_unlocked_skill_ids()
	var points: int = GameState.get_skill_points()
	var first_button: SkillNodeButton = null
	for skill_id: StringName in _buttons_by_id:
		var button: SkillNodeButton = _buttons_by_id[skill_id]
		if first_button == null:
			first_button = button
		var state: SkillTreeDisplay.State = SkillTreeDisplay.classify_node(
			_tree, skill_id, unlocked_ids, points
		)
		if state == SkillTreeDisplay.State.AVAILABLE:
			button.grab_focus()
			return
	if first_button != null:
		first_button.grab_focus()


func _refresh_node_states() -> void:
	var unlocked_ids: Array[StringName] = GameState.get_unlocked_skill_ids()
	var points: int = GameState.get_skill_points()
	for skill_id: StringName in _buttons_by_id:
		var state: SkillTreeDisplay.State = SkillTreeDisplay.classify_node(
			_tree, skill_id, unlocked_ids, points
		)
		_buttons_by_id[skill_id].set_display_state(state)


func _refresh_points_label(current_points: int) -> void:
	_points_label.text = "Points: %d" % current_points


func _show_node_details(skill_id: StringName) -> void:
	var node: SkillNode = _tree.get_node(skill_id)
	if node == null:
		return
	_displayed_skill_id = skill_id
	var unlocked_ids: Array[StringName] = GameState.get_unlocked_skill_ids()
	var points: int = GameState.get_skill_points()

	_detail_name_label.text = node.display_name
	_detail_cost_label.text = "Cost: %d" % node.cost
	_detail_description_label.text = node.description

	var prerequisite_names: PackedStringArray = SkillTreeDisplay.get_prerequisite_names(
		_tree, skill_id
	)
	if prerequisite_names.is_empty():
		_detail_prereq_label.text = NO_PREREQUISITES_TEXT
	else:
		_detail_prereq_label.text = "Requires: %s" % ", ".join(prerequisite_names)

	var state: SkillTreeDisplay.State = SkillTreeDisplay.classify_node(
		_tree, skill_id, unlocked_ids, points
	)
	match state:
		SkillTreeDisplay.State.UNLOCKED:
			_set_detail_status("Unlocked", SkillNodeButton.UNLOCKED_COLOR)
		SkillTreeDisplay.State.AVAILABLE:
			_set_detail_status("Available — press Accept to unlock", SkillNodeButton.AVAILABLE_COLOR)
		SkillTreeDisplay.State.LOCKED:
			var reasons: PackedStringArray = SkillTreeDisplay.get_lock_reasons(
				_tree, skill_id, unlocked_ids, points
			)
			_set_detail_status("Locked: %s" % " ".join(reasons), SkillNodeButton.LOCKED_COLOR)


func _set_detail_status(status_text: String, status_color: Color) -> void:
	_detail_status_label.text = status_text
	_detail_status_label.add_theme_color_override("font_color", status_color)


func _refresh_displayed_details() -> void:
	if _displayed_skill_id != &"":
		_show_node_details(_displayed_skill_id)


func _clear_detail_panel() -> void:
	_displayed_skill_id = &""
	_detail_name_label.text = "Select a skill"
	_detail_cost_label.text = ""
	_detail_description_label.text = "Move with arrows / d-pad. Accept unlocks the focused skill."
	_detail_prereq_label.text = ""
	_detail_status_label.text = ""


func _on_node_button_pressed(skill_id: StringName) -> void:
	# GameState validates the spend; on success its signals drive the visual
	# refresh, so a rejected press (locked node) is simply a no-op here.
	GameState.spend_points(skill_id)


func _on_node_button_focused(skill_id: StringName) -> void:
	_show_node_details(skill_id)


func _on_respec_button_pressed() -> void:
	GameState.respec_skills()


func _on_skill_points_changed(current_points: int) -> void:
	_refresh_points_label(current_points)
	_refresh_node_states()
	_refresh_displayed_details()


func _on_skill_unlocked(_skill_id: StringName) -> void:
	_refresh_node_states()
	_refresh_displayed_details()


func _on_skills_respecced(_refunded_points: int) -> void:
	_refresh_node_states()
	_refresh_displayed_details()


func _on_progress_reset() -> void:
	_refresh_points_label(GameState.get_skill_points())
	_refresh_node_states()
	_refresh_displayed_details()
