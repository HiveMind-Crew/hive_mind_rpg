class_name CheckpointRespawnDemo
extends Node2D
## F6 sandbox for the checkpoint + respawn system (issue #18): walk the actor
## (WASD / left stick) onto the shrine to heal and arm the respawn point, then
## press Interact (E) to take damage. On death the screen fades, the actor
## returns to the last checkpoint at full health, and skill progress is kept.

const MOVE_SPEED: float = 90.0
const SELF_DAMAGE: int = 1

@onready var _actor: CharacterBody2D = %Actor
@onready var _health: HealthComponent = %ActorHealth
@onready var _hp_label: Label = %HpLabel
@onready var _status_label: Label = %StatusLabel
@onready var _respawn: RespawnController = %RespawnController


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	_respawn.respawn_started.connect(_on_respawn_started)
	_respawn.respawn_finished.connect(_on_respawn_finished)
	_on_health_changed(_health.current_health, _health.max_health)


func _physics_process(_delta: float) -> void:
	if _respawn.is_respawning():
		_actor.velocity = Vector2.ZERO
		return
	var direction: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	_actor.velocity = direction * MOVE_SPEED
	_actor.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not _respawn.is_respawning():
		_health.take_damage(SELF_DAMAGE)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_hp_label.text = "HP %d/%d" % [current_health, maximum_health]


func _on_respawn_started() -> void:
	_status_label.text = "Down! Respawning at the last checkpoint..."


func _on_respawn_finished() -> void:
	_status_label.text = "Respawned. Skill points kept: %d" % GameState.get_skill_points()
