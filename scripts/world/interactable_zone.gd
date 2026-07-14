class_name InteractableZone
extends Area2D
## Reusable proximity-interaction component (issue #20). A player-group body
## standing inside the area sees the authored prompt; pressing Interact
## (E / gamepad East) while nearby emits interacted. The zone owns only the
## prompt and the press — what an interaction *does* belongs to the owning
## scene, which connects to interacted (signals up, calls down). This keeps
## props like the hub's skill station and zone gate free of hardcoded input
## handling.

signal interacted()
signal player_nearby_changed(nearby: bool)

const INTERACT_ACTION: StringName = &"interact"

@export var player_group: StringName = &"player"
@export var prompt_text: String = "[E] Interact"

var _player_nearby: bool = false

@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	_prompt_label.text = prompt_text
	_prompt_label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed(INTERACT_ACTION):
		# Consume the press so overlapping zones cannot both fire off one event.
		get_viewport().set_input_as_handled()
		interact()


func is_player_nearby() -> bool:
	return _player_nearby


## The explicit interaction contract (also the _unhandled_input path). Public
## so owners and tests can trigger it without synthesizing input events.
func interact() -> void:
	interacted.emit()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	_player_nearby = true
	_prompt_label.show()
	player_nearby_changed.emit(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	_player_nearby = false
	_prompt_label.hide()
	player_nearby_changed.emit(false)
