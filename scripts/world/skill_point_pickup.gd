class_name SkillPointPickup
extends Area2D
## A hidden skill-point pickup (issue #24). Touching it awards its points
## through GameState and records the collection through SaveManager, which
## writes the save immediately so the reward can never be re-farmed by
## quitting before the next checkpoint. An instance whose secret_id is
## already in the loaded save frees itself before the player can see it.

signal collected(secret_id: StringName, points: int)

const PICKUP_GROUP: StringName = &"skill_point_pickups"

## Unique per placed pickup. An empty id still grants points but cannot be
## persisted, so the pickup would respawn on every visit.
@export var secret_id: StringName = &""
@export_range(1, 10) var points: int = 1
@export var player_group: StringName = &"player"

var _collected: bool = false


func _ready() -> void:
	add_to_group(PICKUP_GROUP)
	if secret_id == StringName():
		push_warning(
			"SkillPointPickup '%s' has no secret_id; it will respawn on every visit." % name
		)
	elif SaveManager.is_secret_collected(secret_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func is_collected() -> bool:
	return _collected


func _on_body_entered(body: Node2D) -> void:
	# body_entered can re-fire while queue_free is still pending, so the flag
	# keeps the payout a one-shot.
	if _collected or not body.is_in_group(player_group):
		return
	_collected = true
	GameState.award_skill_points(points)
	if secret_id != StringName():
		SaveManager.record_secret_collected(secret_id)
	collected.emit(secret_id, points)
	queue_free()
