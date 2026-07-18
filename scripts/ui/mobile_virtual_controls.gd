class_name MobileVirtualControls
extends CanvasLayer
## Landscape-first touch controls for the Web playtest. This component only
## presses/releases existing InputMap actions; player/combat/world systems keep
## their normal ownership of movement, attacks, gates, and control lockouts.

const MOVE_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
]
const BUTTON_ACTIONS: Array[StringName] = [
	&"attack_melee",
	&"ability_relic",
	&"dash",
	&"interact",
]
const ALL_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"attack_melee",
	&"ability_relic",
	&"dash",
	&"interact",
]
const STICK_RADIUS_PX: float = 84.0
const STICK_DEADZONE: float = 0.28
const BUTTON_RADIUS_PX: float = 42.0
const EDGE_MARGIN_PX: float = 28.0

@export var force_touch_controls: bool = false

var _root: Control
var _stick_base: Panel
var _stick_knob: Panel
var _action_buttons: Dictionary[StringName, Panel] = {}
var _rotate_label: Label
var _stick_touch_index: int = -1
var _stick_center: Vector2 = Vector2.ZERO
var _stick_position: Vector2 = Vector2.ZERO
var _button_centers: Dictionary[StringName, Vector2] = {}
var _touch_actions: Dictionary[int, StringName] = {}
var _action_touch_counts: Dictionary[StringName, int] = {}
## Only these actions were pressed synthetically by this overlay. Keeping this
## separate prevents a touch-layout refresh from releasing a real keyboard or
## controller action on desktop.
var _synthetic_actions: Dictionary[StringName, bool] = {}
var _forced_viewport_size: Vector2 = Vector2.ZERO
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visuals()
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()


func _exit_tree() -> void:
	_release_all_actions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all_actions()


func _process(_delta: float) -> void:
	if get_tree().paused:
		_release_all_actions()
		if not _was_paused:
			_root.visible = false
		_was_paused = true
		return
	if _was_paused:
		_was_paused = false
		_refresh_layout()


func _input(event: InputEvent) -> void:
	if not _can_accept_touch():
		return
	var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
	if screen_touch != null:
		if screen_touch.pressed:
			handle_touch_pressed(screen_touch.index, screen_touch.position)
		else:
			handle_touch_released(screen_touch.index)
		get_viewport().set_input_as_handled()
		return
	var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
	if screen_drag != null:
		handle_touch_dragged(screen_drag.index, screen_drag.position)
		get_viewport().set_input_as_handled()


## Public touch entry points keep the mobile input contract testable without a
## device and are used by the real InputEventScreenTouch/ScreenDrag handlers.
func handle_touch_pressed(touch_index: int, position: Vector2) -> void:
	if not _can_accept_touch():
		return
	if _stick_touch_index == -1 and position.distance_to(_stick_center) <= STICK_RADIUS_PX * 1.35:
		_stick_touch_index = touch_index
		_update_stick(position)
		return
	for action: StringName in BUTTON_ACTIONS:
		var center: Vector2 = _button_centers.get(action, Vector2.ZERO)
		if position.distance_to(center) <= BUTTON_RADIUS_PX:
			_touch_actions[touch_index] = action
			_press_action(action)
			return


func handle_touch_dragged(touch_index: int, position: Vector2) -> void:
	if touch_index == _stick_touch_index:
		_update_stick(position)


func handle_touch_released(touch_index: int) -> void:
	if touch_index == _stick_touch_index:
		_stick_touch_index = -1
		_stick_position = _stick_center
		_update_movement_actions(Vector2.ZERO)
		_update_stick_visual(Vector2.ZERO)
	var action: StringName = _touch_actions.get(touch_index, &"")
	if not action.is_empty():
		_touch_actions.erase(touch_index)
		_release_action(action)


func is_touch_overlay_visible() -> bool:
	return _root.visible and not _rotate_label.visible


func is_rotate_message_visible() -> bool:
	return _rotate_label.visible


func get_stick_center() -> Vector2:
	return _stick_center


func get_button_center(action: StringName) -> Vector2:
	return _button_centers.get(action, Vector2.ZERO)


func get_pressed_action_count(action: StringName) -> int:
	return _action_touch_counts.get(action, 0)


## Test-only viewport override. A zero value restores the real viewport size.
func set_forced_viewport_size(size: Vector2) -> void:
	_forced_viewport_size = size
	_refresh_layout()


func _build_visuals() -> void:
	_root = Control.new()
	_root.name = "TouchOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stick_base = _make_panel(Color(0.04, 0.08, 0.1, 0.50), STICK_RADIUS_PX, "MOVE")
	_root.add_child(_stick_base)
	_stick_knob = _make_panel(Color(0.18, 0.75, 0.82, 0.72), STICK_RADIUS_PX * 0.42, "")
	_root.add_child(_stick_knob)

	var labels: Dictionary[StringName, String] = {
		&"attack_melee": "ATK",
		&"ability_relic": "REL",
		&"dash": "DASH",
		&"interact": "USE",
	}
	for action: StringName in BUTTON_ACTIONS:
		var panel: Panel = _make_panel(Color(0.12, 0.08, 0.18, 0.72), BUTTON_RADIUS_PX, labels[action])
		_action_buttons[action] = panel
		_root.add_child(panel)

	_rotate_label = Label.new()
	_rotate_label.name = "RotateLandscapeMessage"
	_rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_label.text = "Rotate device for landscape controls"
	_rotate_label.add_theme_font_size_override("font_size", 22)
	_rotate_label.add_theme_color_override("font_color", Color(0.86, 0.95, 0.96, 1.0))
	_rotate_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 1.0))
	_rotate_label.add_theme_constant_override("outline_size", 6)
	_rotate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_rotate_label)


func _make_panel(color: Color, radius: float, label_text: String) -> Panel:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	# This overlay is positioned directly under a plain Control rather than a
	# Container, so custom_minimum_size alone does not assign its drawn rect.
	panel.size = panel.custom_minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.54, 0.94, 1.0, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(radius))
	panel.add_theme_stylebox_override("panel", style)
	if not label_text.is_empty():
		var label: Label = Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.93, 0.98, 1.0, 1.0))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(label)
	return panel


func _refresh_layout() -> void:
	if _root == null:
		return
	var size: Vector2 = _get_viewport_size()
	var touch_enabled: bool = _touch_controls_available()
	var landscape: bool = size.x > size.y
	_root.visible = touch_enabled
	_rotate_label.visible = touch_enabled and not landscape
	_stick_base.visible = touch_enabled and landscape
	_stick_knob.visible = touch_enabled and landscape
	for button: Panel in _action_buttons.values():
		button.visible = touch_enabled and landscape
	if not touch_enabled or not landscape:
		_release_all_actions()
		return
	_stick_center = Vector2(EDGE_MARGIN_PX + STICK_RADIUS_PX, size.y - EDGE_MARGIN_PX - STICK_RADIUS_PX)
	_place_centered(_stick_base, _stick_center)
	if _stick_touch_index == -1:
		_stick_position = _stick_center
	_update_stick_visual((_stick_position - _stick_center).limit_length(STICK_RADIUS_PX))

	var action_positions: Dictionary[StringName, Vector2] = {
		&"attack_melee": Vector2(size.x - EDGE_MARGIN_PX - BUTTON_RADIUS_PX, size.y - EDGE_MARGIN_PX - BUTTON_RADIUS_PX),
		&"ability_relic": Vector2(size.x - EDGE_MARGIN_PX - BUTTON_RADIUS_PX * 3.0, size.y - EDGE_MARGIN_PX - BUTTON_RADIUS_PX),
		&"dash": Vector2(size.x - EDGE_MARGIN_PX - BUTTON_RADIUS_PX, size.y - EDGE_MARGIN_PX - BUTTON_RADIUS_PX * 3.0),
		&"interact": Vector2(size.x - EDGE_MARGIN_PX - BUTTON_RADIUS_PX * 3.0, size.y - EDGE_MARGIN_PX - BUTTON_RADIUS_PX * 3.0),
	}
	_button_centers = action_positions
	for action: StringName in BUTTON_ACTIONS:
		_place_centered(_action_buttons[action], action_positions[action])


func _place_centered(control: Control, center: Vector2) -> void:
	control.position = center - control.custom_minimum_size * 0.5


func _update_stick(position: Vector2) -> void:
	_stick_position = position
	var stick_offset: Vector2 = (position - _stick_center).limit_length(STICK_RADIUS_PX)
	_update_stick_visual(stick_offset)
	_update_movement_actions(stick_offset / STICK_RADIUS_PX)


func _update_stick_visual(stick_offset: Vector2) -> void:
	if _stick_knob == null:
		return
	_place_centered(_stick_knob, _stick_center + stick_offset)


func _update_movement_actions(direction: Vector2) -> void:
	if direction.length() < STICK_DEADZONE:
		for action: StringName in MOVE_ACTIONS:
			_release_action_fully(action)
		return
	_set_movement_action(&"move_left", direction.x < -STICK_DEADZONE)
	_set_movement_action(&"move_right", direction.x > STICK_DEADZONE)
	_set_movement_action(&"move_up", direction.y < -STICK_DEADZONE)
	_set_movement_action(&"move_down", direction.y > STICK_DEADZONE)


func _set_movement_action(action: StringName, active: bool) -> void:
	if active:
		if get_pressed_action_count(action) == 0:
			_action_touch_counts[action] = 1
			_dispatch_action_event(action, true)
			_synthetic_actions[action] = true
	else:
		_release_action_fully(action)


func _press_action(action: StringName) -> void:
	var count: int = get_pressed_action_count(action) + 1
	_action_touch_counts[action] = count
	if count == 1:
		_dispatch_action_event(action, true)
		_synthetic_actions[action] = true


func _release_action(action: StringName) -> void:
	var count: int = get_pressed_action_count(action)
	if count <= 1:
		_release_action_fully(action)
		return
	_action_touch_counts[action] = count - 1


func _release_action_fully(action: StringName) -> void:
	_action_touch_counts.erase(action)
	if _synthetic_actions.has(action):
		_dispatch_action_event(action, false)
		_synthetic_actions.erase(action)


func _dispatch_action_event(action: StringName, pressed: bool) -> void:
	# Keep polled movement/combat controllers in sync with the virtual state.
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	# action_press only changes polled state. Parsing the matching event also
	# reaches contextual _unhandled_input owners such as the Hub gate.
	Input.parse_input_event(event)


func _release_all_actions() -> void:
	_stick_touch_index = -1
	_touch_actions.clear()
	for action: StringName in ALL_ACTIONS:
		_release_action_fully(action)
	if _stick_center != Vector2.ZERO:
		_stick_position = _stick_center
		_update_stick_visual(Vector2.ZERO)


func _can_accept_touch() -> bool:
	return _touch_controls_available() and _is_landscape() and not get_tree().paused


func _touch_controls_available() -> bool:
	return force_touch_controls or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())


func _is_landscape() -> bool:
	var size: Vector2 = _get_viewport_size()
	return size.x > size.y


func _get_viewport_size() -> Vector2:
	if _forced_viewport_size != Vector2.ZERO:
		return _forced_viewport_size
	return get_viewport().get_visible_rect().size
