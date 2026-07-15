class_name RespawnController
extends Node
## Coordinates checkpoints and death → respawn (issue #18). Owns the current
## respawn position, heals the player when a shrine is reached, and on death
## fades out, resets the zone's enemies, returns the player to the last
## checkpoint at full health, and fades back in.
##
## Skill progression in GameState is deliberately never touched here: dying
## costs no skill points or unlocks (DESIGN.md §5 — "no XP/currency loss").

signal player_died()
signal respawn_started()
signal respawn_finished()

## Nodes in this group get reset_to_spawn() called on respawn, if they define
## it. Enemies (#12) can opt in without this system depending on their class.
const RESETTABLE_GROUP: StringName = &"resettable"

@export var player_path: NodePath
@export var health_component_path: NodePath
## Optional full-screen ColorRect for the death fade. When absent, respawn is
## instantaneous (used by tests and any fade-free context).
@export var fade_rect_path: NodePath
@export_range(0.0, 2.0, 0.01) var fade_duration: float = 0.35
## Persist the run via SaveManager whenever a shrine is reached (issue #19).
## Tests and throwaway sandboxes opt out.
@export var save_on_checkpoint: bool = true

var _player: Node2D
var _health: HealthComponent
var _fade_rect: ColorRect
var _respawn_position: Vector2
var _is_respawning: bool = false


func _ready() -> void:
	_player = get_node(player_path) as Node2D
	_health = get_node(health_component_path) as HealthComponent
	if fade_rect_path != NodePath():
		_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	# Until the player reaches a shrine, their start position is the respawn.
	_respawn_position = _player.global_position
	_health.died.connect(_on_player_died)
	for node: Node in get_tree().get_nodes_in_group(Checkpoint.CHECKPOINT_GROUP):
		var checkpoint := node as Checkpoint
		if checkpoint != null:
			checkpoint.checkpoint_reached.connect(_on_checkpoint_reached)


func get_respawn_position() -> Vector2:
	return _respawn_position


func is_respawning() -> bool:
	return _is_respawning


func respawn() -> void:
	# Reset enemies first so the player never lands on top of a live one.
	_reset_resettables()
	_player.global_position = _respawn_position
	_health.restore_full_health()
	respawn_finished.emit()


func _on_checkpoint_reached(respawn_position: Vector2) -> void:
	_respawn_position = respawn_position
	# Reaching a shrine heals; a dead player is handled by the respawn flow.
	if not _health.is_dead:
		_health.restore_full_health()
	if save_on_checkpoint:
		SaveManager.record_checkpoint(_world_scene_path(), respawn_position)


func _world_scene_path() -> String:
	# The scene to reload for this checkpoint is the world this controller lives
	# in — its own scene root — not get_tree().current_scene, which becomes the
	# composition root (Main) once GameManager hosts the world (issue #63).
	# owner is that world root in both standalone F6 runs and the composed tree.
	var scene_root: Node = owner if owner != null else self
	if not scene_root.scene_file_path.is_empty():
		return scene_root.scene_file_path
	# Hand-built trees (tests) have no packed scene root; fall back to the
	# active scene so the recorded path stays a best effort rather than empty.
	var current_scene: Node = get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""


func _on_player_died() -> void:
	if _is_respawning:
		return
	_is_respawning = true
	# Lock the player out for the whole transition (issue #79): a dead player
	# must not move, dash, attack, or fire the relic behind the fade.
	_set_player_control_enabled(false)
	player_died.emit()
	respawn_started.emit()
	await _fade_to(1.0)
	respawn()
	await _fade_to(0.0)
	_is_respawning = false
	_set_player_control_enabled(true)


func _set_player_control_enabled(enabled: bool) -> void:
	# Duck-typed: tests and lightweight demos drive plain Node2D stand-ins
	# that have no control gate.
	if _player != null and _player.has_method(&"set_control_enabled"):
		_player.call(&"set_control_enabled", enabled)


func _reset_resettables() -> void:
	for node: Node in get_tree().get_nodes_in_group(RESETTABLE_GROUP):
		if node.has_method(&"reset_to_spawn"):
			node.call(&"reset_to_spawn")


func _fade_to(target_alpha: float) -> void:
	if _fade_rect == null:
		return
	if fade_duration <= 0.0:
		_fade_rect.color.a = target_alpha
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, fade_duration)
	await tween.finished
