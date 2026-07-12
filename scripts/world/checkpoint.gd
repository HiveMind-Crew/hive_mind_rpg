class_name Checkpoint
extends Area2D
## A shrine/beacon checkpoint (issue #18). When a body in the player group
## touches it, the shrine lights up and announces its respawn position. It
## only reports being reached — healing and respawn bookkeeping belong to the
## RespawnController, so this node never reaches up to the player or manager
## (signals up, calls down).

signal checkpoint_reached(respawn_position: Vector2)

const CHECKPOINT_GROUP: StringName = &"checkpoints"

@export var player_group: StringName = &"player"
@export var dormant_color: Color = Color(0.4, 0.42, 0.5, 1.0)
@export var lit_color: Color = Color(0.5, 0.95, 0.72, 1.0)

@onready var _visual: Polygon2D = %Visual
@onready var _respawn_point: Marker2D = %RespawnPoint

var _lit: bool = false


func _ready() -> void:
	add_to_group(CHECKPOINT_GROUP)
	_visual.color = dormant_color
	body_entered.connect(_on_body_entered)


func get_respawn_position() -> Vector2:
	return _respawn_point.global_position


func is_lit() -> bool:
	return _lit


func _on_body_entered(body: Node2D) -> void:
	# Re-touching re-heals and re-arms the respawn point; body_entered only
	# fires on entry, so this stays a per-visit event, not a per-frame one.
	if not body.is_in_group(player_group):
		return
	_lit = true
	_visual.color = lit_color
	checkpoint_reached.emit(get_respawn_position())
