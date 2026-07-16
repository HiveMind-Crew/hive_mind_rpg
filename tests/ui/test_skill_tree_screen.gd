extends GutTest
## Scene-level coverage for the skill tree screen: it builds a button per
## authored skill and its spend/respec buttons drive GameState correctly.
## Node-heavy, so this stays a focused smoke test on top of the pure-logic
## SkillTreeDisplay suite.

const SCREEN_SCENE := preload("res://scenes/ui/skill_tree_screen.tscn")
const ROOT: StringName = &"steel_tempered_edge"

var _screen: SkillTreeScreen


func before_each() -> void:
	GameState.reset_progress()
	_screen = SCREEN_SCENE.instantiate()
	add_child_autofree(_screen)
	await wait_physics_frames(2)


func after_each() -> void:
	GameState.reset_progress()


func test_builds_a_button_for_every_authored_skill() -> void:
	assert_eq(_count_node_buttons(_screen), GameState.skill_tree.nodes.size())


func test_points_label_tracks_awarded_points() -> void:
	GameState.award_skill_points(3)
	await wait_physics_frames(1)
	var label: Label = _screen.get_node("%PointsLabel")
	assert_eq(label.text, "Points: 3")


func test_pressing_an_available_node_spends_points_and_unlocks_it() -> void:
	GameState.award_skill_points(1)
	await wait_physics_frames(1)
	var button: SkillNodeButton = _find_button(_screen, ROOT)
	assert_not_null(button)
	button.pressed.emit()

	assert_true(GameState.is_skill_unlocked(ROOT))
	assert_eq(GameState.get_skill_points(), 0)


func test_respec_button_refunds_points_and_relocks_skills() -> void:
	GameState.award_skill_points(1)
	await wait_physics_frames(1)
	_find_button(_screen, ROOT).pressed.emit()

	var respec_button: Button = _screen.get_node("%RespecButton")
	respec_button.pressed.emit()

	assert_eq(GameState.get_skill_points(), 1)
	assert_false(GameState.is_skill_unlocked(ROOT))


func _count_node_buttons(root: Node) -> int:
	var total: int = 1 if root is SkillNodeButton else 0
	for child: Node in root.get_children():
		total += _count_node_buttons(child)
	return total


func test_all_branch_columns_and_detail_fit_within_the_viewport() -> void:
	# Regression: the three branch columns plus the detail panel must fit inside
	# the project render width. The detail panel used to balloon to fit long
	# single-line "Locked: ..." status text, pushing the outer columns off both
	# edges of the screen (unreadable/unreachable) until its labels were set to
	# wrap. Show the worst case — a deep locked node whose status names its
	# missing prerequisites — then assert nothing is clipped.
	_screen._show_node_details(&"steel_comet_lunge")
	await wait_physics_frames(2)

	var viewport_width: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_width")
	)
	var columns: Control = _screen.get_node("Margin/Layout/Columns") as Control
	var left_edge: float = columns.global_position.x
	var right_edge: float = columns.global_position.x + columns.size.x

	assert_gte(left_edge, -0.5, "The leftmost branch column must not be clipped off-screen.")
	assert_lte(
		right_edge, viewport_width + 0.5,
		"The detail panel must not be clipped off the right edge of the screen."
	)


func _find_button(root: Node, skill_id: StringName) -> SkillNodeButton:
	if root is SkillNodeButton and (root as SkillNodeButton).skill_id == skill_id:
		return root
	for child: Node in root.get_children():
		var found: SkillNodeButton = _find_button(child, skill_id)
		if found != null:
			return found
	return null
