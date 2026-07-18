class_name SkillNodeButton
extends Button
## One selectable node in the skill tree screen. Purely presentational:
## the screen configures it, restyles it, and listens to its built-in
## pressed/focus_entered signals — this button never reaches up the tree.

const UNLOCKED_COLOR := Color(0.47, 0.92, 0.48)
const AVAILABLE_COLOR := Color(0.31, 0.91, 0.96)
const LOCKED_COLOR := Color(0.48, 0.49, 0.45)

var skill_id: StringName = &""


func _ready() -> void:
	# Hovering should drive the same detail panel as keyboard/gamepad focus,
	# so hover simply moves focus instead of being a separate code path.
	mouse_entered.connect(grab_focus)


func setup(skill: SkillNode) -> void:
	skill_id = skill.id
	text = "%s [%d]" % [skill.display_name, skill.cost]
	name = str(skill.id).to_pascal_case()


func set_display_state(state: SkillTreeDisplay.State) -> void:
	match state:
		SkillTreeDisplay.State.UNLOCKED:
			modulate = Color(0.72, 1.0, 0.72, 1.0)
		SkillTreeDisplay.State.AVAILABLE:
			modulate = Color.WHITE
		SkillTreeDisplay.State.LOCKED:
			modulate = Color(0.52, 0.55, 0.52, 1.0)
