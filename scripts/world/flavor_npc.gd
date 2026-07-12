class_name FlavorNpc
extends Area2D
## A hub flavor NPC (issue #26): standing near it shows an interact prompt,
## and pressing Interact shows its next authored bark line for a few seconds.
## Barks cycle in authored order from a data-driven NpcBarkSet. Deliberately
## self-contained — the hub (#20) can drop instances in without any wiring,
## and the NPC never reaches up the tree.

signal barked(bark_text: String)

const NPC_GROUP: StringName = &"flavor_npcs"

@export var bark_set: NpcBarkSet
@export var player_group: StringName = &"player"
@export_range(0.5, 30.0, 0.1) var bark_duration: float = 3.0

var _player_nearby: bool = false
var _next_bark_index: int = 0

@onready var _name_label: Label = %NameLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _bark_label: Label = %BarkLabel
@onready var _bark_timer: Timer = %BarkTimer


func _ready() -> void:
	add_to_group(NPC_GROUP)
	if bark_set == null or not bark_set.is_valid():
		push_warning("FlavorNpc '%s' has no valid bark set; it will stay silent." % name)
	_name_label.text = bark_set.npc_name if bark_set != null else ""
	_prompt_label.hide()
	_bark_label.hide()
	_bark_timer.timeout.connect(_on_bark_timer_timeout)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed(&"interact"):
		interact()


func is_player_nearby() -> bool:
	return _player_nearby


func is_barking() -> bool:
	return _bark_label.visible


func get_current_bark() -> String:
	return _bark_label.text if is_barking() else ""


func interact() -> bool:
	if bark_set == null or not bark_set.is_valid():
		return false
	var bark_text: String = bark_set.barks[_next_bark_index % bark_set.barks.size()]
	_next_bark_index = (_next_bark_index + 1) % bark_set.barks.size()
	_bark_label.text = bark_text
	_bark_label.show()
	_prompt_label.hide()
	_bark_timer.start(bark_duration)
	barked.emit(bark_text)
	return true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	_player_nearby = true
	if not is_barking():
		_prompt_label.show()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	_player_nearby = false
	_prompt_label.hide()


func _on_bark_timer_timeout() -> void:
	_bark_label.hide()
	if _player_nearby:
		_prompt_label.show()
