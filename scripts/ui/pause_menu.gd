class_name PauseMenu
extends CanvasLayer
## Reusable pause screen (issue #69). Pausing does two composing things:
## 1. Holds a 0.0 modifier on TimeScaleManager — never writing
##    Engine.time_scale directly — so global time ownership stays with the
##    manager and pause composes with combat hitstop. (Time scale alone is not
##    a pause: at scale 0 Godot still runs _physics_process with delta 0, so
##    input-driven gameplay could still fire.)
## 2. Sets get_tree().paused, which actually stops gameplay and enemy AI
##    callbacks. This scene runs with PROCESS_MODE_ALWAYS so the menu itself
##    stays interactive. The menu assumes it is the sole owner of the tree's
##    paused flag.
##
## Signals up, calls down: the menu never changes scenes itself. The owning
## scene connects to return_to_hub_requested (wired for real by the startup
## flow, issue #68) and performs the transition.

signal menu_opened()
signal menu_closed()
signal return_to_hub_requested()

const PAUSE_ACTION: StringName = &"pause"

var _pause_token: int = TimeScaleManager.INVALID_TOKEN

@onready var _resume_button: Button = %ResumeButton
@onready var _return_to_hub_button: Button = %ReturnToHubButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_return_to_hub_button.pressed.connect(_on_return_to_hub_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _exit_tree() -> void:
	# A menu removed mid-pause (scene change, test teardown) must never leave
	# the whole game frozen.
	if is_open():
		get_tree().paused = false
	_release_pause_token()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(PAUSE_ACTION):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _pause_token != TimeScaleManager.INVALID_TOKEN


func open() -> void:
	if is_open():
		return
	_pause_token = TimeScaleManager.acquire_modifier(0.0)
	get_tree().paused = true
	visible = true
	_resume_button.grab_focus()
	menu_opened.emit()


func close() -> void:
	if not is_open():
		return
	get_tree().paused = false
	_release_pause_token()
	visible = false
	menu_closed.emit()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _release_pause_token() -> void:
	if _pause_token == TimeScaleManager.INVALID_TOKEN:
		return
	TimeScaleManager.release_modifier(_pause_token)
	_pause_token = TimeScaleManager.INVALID_TOKEN


func _on_resume_pressed() -> void:
	close()


func _on_return_to_hub_pressed() -> void:
	# Unpause before the owner changes scenes so the next scene never starts
	# with a leaked 0.0 modifier.
	close()
	return_to_hub_requested.emit()


func _on_quit_pressed() -> void:
	close()
	get_tree().quit()
