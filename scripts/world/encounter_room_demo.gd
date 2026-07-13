class_name EncounterRoomDemo
extends Node2D
## F6 sandbox for the encounter room (issue #66): walk the actor (WASD / left
## stick) through the west doorway — the room seals both doors and wakes its
## chasers. Press Interact (E) beside a chaser to strike it. Clearing both
## reopens the doors and completes the encounter; dying to them respawns the
## actor at the start with the whole encounter re-armed.

const MOVE_SPEED: float = 90.0
const STRIKE_DAMAGE: int = 2
const STRIKE_RANGE: float = 48.0

@onready var _actor: CharacterBody2D = %Actor
@onready var _actor_health: HealthComponent = %ActorHealth
@onready var _actor_hurtbox: Hurtbox = %ActorHurtbox
@onready var _hp_label: Label = %HpLabel
@onready var _status_label: Label = %StatusLabel
@onready var _room: EncounterRoom = %EncounterRoom
@onready var _respawn: RespawnController = %RespawnController


func _ready() -> void:
	_actor_hurtbox.hit_received.connect(_actor_health.apply_hit)
	_actor_health.health_changed.connect(_on_health_changed)
	_room.encounter_started.connect(_on_encounter_started)
	_room.encounter_completed.connect(_on_encounter_completed)
	_respawn.respawn_finished.connect(_on_respawn_finished)


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
		_strike_nearest_enemy()


func _strike_nearest_enemy() -> void:
	var nearest: EnemyBase = null
	var nearest_distance: float = STRIKE_RANGE
	for node: Node in _room.get_assigned_enemies():
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy.health.is_dead:
			continue
		var distance: float = _actor.global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		nearest.health.take_damage(STRIKE_DAMAGE)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_hp_label.text = "HP %d/%d" % [current_health, maximum_health]


func _on_encounter_started() -> void:
	_status_label.text = "Sealed in! Strike the chasers with E."


func _on_encounter_completed() -> void:
	_status_label.text = "Encounter complete — the doors are open."


func _on_respawn_finished() -> void:
	_status_label.text = "Down! The encounter re-armed — walk back in."
