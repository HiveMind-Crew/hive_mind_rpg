class_name EncounterRoom
extends Area2D
## Reusable encounter controller (issue #66). Drop one over a room, parent the
## room's enemies under its enemies root, and point exit_paths at the barriers
## that should seal the fight. Enemies stay dormant (never given a target)
## until a player-group body enters the trigger; entering seals every
## configured exit and hands the player to each enemy. Once every assigned
## enemy has died, the exits reopen and encounter_completed fires exactly once
## per attempt.
##
## Both interfaces are duck-typed so the controller never hardcodes enemy
## types or stats:
## - Enemy: any enemies-root child with a set_target(Node2D) method and an
##   enemy_died() signal (EnemyBase satisfies both).
## - Exit: a node with seal()/open() methods takes over its own presentation;
##   anything else is treated as a physical barrier — sealing shows the
##   CanvasItem and enables its collision shapes, opening does the reverse
##   (the Zone 1 boss-door pattern).
##
## The room joins RespawnController's resettable group: on player death,
## reset_to_spawn() rebuilds the assigned enemies from pristine copies
## captured before any activation and returns the room to dormant — even if
## it was already completed, matching the die-back-to-a-checkpoint loop where
## the world re-arms (DESIGN.md §3).

signal encounter_started()
signal encounter_completed()
signal encounter_reward_awarded(reward_id: StringName, skill_points: int)

enum State {
	DORMANT,
	ACTIVE,
	COMPLETED,
}

## Same group Zone 1 uses to count its placed encounter rooms.
const ENCOUNTER_ROOM_GROUP: StringName = &"encounter_rooms"

@export var player_group: StringName = &"player"
## Container whose children are this room's assigned enemies.
@export var enemies_root_path: NodePath = ^"Enemies"
## Barriers sealed while the encounter is active (see exit interface above).
@export var exit_paths: Array[NodePath] = []
## Optional authored payout. A null reward keeps the room reusable for fights
## that should not advance progression.
@export var reward_data: EncounterRewardData

var state: State = State.DORMANT

var _enemies_root: Node
var _exits: Array[Node] = []
var _live_enemies: Array[Node] = []
## Pristine duplicates captured before any wiring or activation, so
## reset_to_spawn() can rebuild the encounter without knowing enemy internals.
var _enemy_templates: Array[Node] = []
var _defeated_count: int = 0
var _exits_sealed: bool = false


func _ready() -> void:
	add_to_group(ENCOUNTER_ROOM_GROUP)
	add_to_group(RespawnController.RESETTABLE_GROUP)
	_enemies_root = get_node_or_null(enemies_root_path)
	if _enemies_root == null:
		push_warning(
			"EncounterRoom '%s' found no enemies root at '%s'." % [name, enemies_root_path]
		)
	else:
		for child: Node in _enemies_root.get_children():
			_adopt_enemy(child)
	for path: NodePath in exit_paths:
		var exit_node: Node = get_node_or_null(path)
		if exit_node == null:
			push_warning("EncounterRoom '%s' found no exit at '%s'." % [name, path])
			continue
		_exits.append(exit_node)
	body_entered.connect(_on_body_entered)
	# A dormant room guarantees open exits, however the barriers were authored.
	_set_exits_sealed(false)


func _notification(what: int) -> void:
	# Templates live outside the tree, so the room frees them by hand.
	if what == NOTIFICATION_PREDELETE:
		for template: Node in _enemy_templates:
			if is_instance_valid(template):
				template.free()


func is_active() -> bool:
	return state == State.ACTIVE


func is_completed() -> bool:
	return state == State.COMPLETED


func are_exits_sealed() -> bool:
	return _exits_sealed


func get_assigned_enemies() -> Array[Node]:
	return _live_enemies.duplicate()


## Starts the encounter for the given player. Usually driven by the room's own
## trigger, but public so a zone script can also start rooms directly
## (calls down).
func activate(player: Node2D) -> void:
	if state != State.DORMANT:
		return
	if _defeated_count >= _live_enemies.size():
		# Nothing left to fight (empty room, or every enemy was defeated while
		# dormant); never trap the player behind sealed exits.
		_complete()
		return
	state = State.ACTIVE
	_set_exits_sealed(true)
	for enemy: Node in _live_enemies:
		enemy.call(&"set_target", player)
	encounter_started.emit()


## Restores the initial dormant room: exits open and fresh, untargeted copies
## of the assigned enemies. Called by RespawnController on player death. If
## the player respawns inside the trigger, body_entered will not re-fire; the
## zone decides whether to call activate() again.
func reset_to_spawn() -> void:
	for enemy: Node in _live_enemies:
		if not is_instance_valid(enemy):
			continue
		var parent: Node = enemy.get_parent()
		if parent != null:
			parent.remove_child(enemy)
		enemy.queue_free()
	_live_enemies.clear()
	_defeated_count = 0
	state = State.DORMANT
	for template: Node in _enemy_templates:
		var fresh: Node = template.duplicate()
		_enemies_root.add_child(fresh)
		_track_enemy(fresh)
	_set_exits_sealed(false)


func _adopt_enemy(node: Node) -> void:
	if not (node.has_method(&"set_target") and node.has_signal(&"enemy_died")):
		push_warning(
			"EncounterRoom '%s' skipped '%s': enemies need set_target() and enemy_died."
			% [name, node.name]
		)
		return
	# Duplicate before connecting so the template carries no room wiring.
	_enemy_templates.append(node.duplicate())
	_track_enemy(node)


func _track_enemy(enemy: Node) -> void:
	_live_enemies.append(enemy)
	enemy.connect(&"enemy_died", _on_enemy_died)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group):
		activate(body)


func _on_enemy_died() -> void:
	_defeated_count += 1
	if state == State.ACTIVE and _defeated_count >= _live_enemies.size():
		_complete()


func _complete() -> void:
	# Only reachable once per DORMANT → ACTIVE cycle, so the completion signal
	# is one-shot per attempt.
	state = State.COMPLETED
	_set_exits_sealed(false)
	encounter_completed.emit()
	_award_completion_reward()


func _award_completion_reward() -> void:
	if reward_data == null:
		return
	if not reward_data.is_valid():
		push_warning("EncounterRoom '%s' has invalid reward data." % name)
		return
	if SaveManager.is_encounter_completed(reward_data.reward_id):
		return
	if not GameState.award_skill_points(reward_data.skill_points):
		return
	# Record after awarding so the immediate save contains both the completion
	# id and the updated point total.
	SaveManager.record_encounter_completed(reward_data.reward_id)
	encounter_reward_awarded.emit(reward_data.reward_id, reward_data.skill_points)


func _set_exits_sealed(sealed: bool) -> void:
	_exits_sealed = sealed
	for exit_node: Node in _exits:
		var custom_method: StringName = &"seal" if sealed else &"open"
		if exit_node.has_method(custom_method):
			exit_node.call(custom_method)
			continue
		var barrier: CanvasItem = exit_node as CanvasItem
		if barrier != null:
			barrier.visible = sealed
		_set_barrier_collision(exit_node, sealed)


func _set_barrier_collision(barrier: Node, enabled: bool) -> void:
	# Deferred: physics properties cannot safely change while overlaps flush,
	# and sealing runs inside the body_entered callback.
	for shape: Node in barrier.find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred(&"disabled", not enabled)
	for polygon: Node in barrier.find_children("*", "CollisionPolygon2D", true, false):
		polygon.set_deferred(&"disabled", not enabled)
