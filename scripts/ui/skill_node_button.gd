class_name SkillNodeButton
extends Button
## One selectable node in the skill tree screen. Purely presentational:
## the screen configures it, restyles it, and listens to its built-in
## pressed/focus_entered signals — this button never reaches up the tree.

# Graybox state palette (no art pass yet): tint the whole button so the
# three states read at a glance even without icons.
const UNLOCKED_COLOR := Color(0.45, 0.95, 0.55)
const AVAILABLE_COLOR := Color(0.55, 0.9, 1.0)
const LOCKED_COLOR := Color(0.45, 0.45, 0.52)

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
			modulate = UNLOCKED_COLOR
		SkillTreeDisplay.State.AVAILABLE:
			modulate = AVAILABLE_COLOR
		SkillTreeDisplay.State.LOCKED:
			modulate = LOCKED_COLOR
