class_name NpcBarksDemo
extends Node2D
## F6 sandbox for hub flavor NPCs (issue #26): walk (WASD / left stick) up to
## an NPC and press Interact (E) to hear its next bark line. The NPCs handle
## their own prompts and barks; placement in the real hub follows #20.

const MOVE_SPEED: float = 90.0

@onready var _actor: CharacterBody2D = %Actor


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	_actor.velocity = direction * MOVE_SPEED
	_actor.move_and_slide()
