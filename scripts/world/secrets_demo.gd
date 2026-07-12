class_name SecretsDemo
extends Node2D
## F6 sandbox for secrets & skill-point pickups (issue #24): walk (WASD /
## left stick) over the open diamond, then poke the wall on the right — a
## hidden room reveals itself with a bigger payout inside. Collections write
## to the save, so re-running the scene keeps them gone. Press Interact (E)
## to clear the save and start over.

const MOVE_SPEED: float = 90.0

@onready var _actor: CharacterBody2D = %Actor
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	GameState.skill_points_changed.connect(_on_skill_points_changed)
	_on_skill_points_changed(GameState.get_skill_points())


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	_actor.velocity = direction * MOVE_SPEED
	_actor.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		SaveManager.clear_save()
		get_tree().reload_current_scene()


func _on_skill_points_changed(current_points: int) -> void:
	_status_label.text = "Skill points: %d" % current_points
