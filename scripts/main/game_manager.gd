class_name GameManager
extends Node
## Playable startup composition scene (issue #68). The project boots here: the
## manager instances the hub and swaps the active world between the hub and
## Zone 1. Each world scene keeps owning its player, HUD, camera, respawn, and
## checkpoint wiring exactly as authored for standalone F6 runs — the manager
## only consumes their documented signals and markers — so exactly one player
## (and therefore one HUD and one camera) exists at any moment, and the
## autoloads are never duplicated.
##
## Contracts consumed:
## - Hub.zone_entry_requested(zone_scene_path): swap to that zone and drop the
##   player at its authored %ZoneEntrance marker.
## - PauseMenu.return_to_hub_requested(): swap back to the hub. The menu has
##   already unpaused by the time it emits (see pause_menu.gd).

const HUB_SCENE: PackedScene = preload("res://scenes/world/hub.tscn")

@onready var _world_root: Node = %WorldRoot
@onready var _pause_menu: PauseMenu = %PauseMenu

var _current_world: Node2D
var _is_transitioning: bool = false


func _ready() -> void:
	_pause_menu.return_to_hub_requested.connect(_on_return_to_hub_requested)
	_enter_world(HUB_SCENE)


func get_current_world() -> Node2D:
	return _current_world


func is_hub_active() -> bool:
	return _current_world is Hub


func get_player() -> PlayerController:
	if _current_world == null:
		return null
	return _current_world.get_node_or_null("%Player") as PlayerController


func _on_zone_entry_requested(zone_scene_path: String) -> void:
	_request_transition(load(zone_scene_path) as PackedScene)


func _on_return_to_hub_requested() -> void:
	# Already home: the menu simply closed. Reloading the hub here would only
	# teleport the player back to spawn for no reason.
	if is_hub_active():
		return
	_request_transition(HUB_SCENE)


func _request_transition(world_scene: PackedScene) -> void:
	# Deferred: transition requests originate inside callbacks of the very
	# world being freed (gate input, menu button), which must finish first.
	if _is_transitioning or world_scene == null:
		return
	_is_transitioning = true
	_enter_world.call_deferred(world_scene)


func _enter_world(world_scene: PackedScene) -> void:
	if _current_world != null:
		# Immediate free, not queue_free: the incoming world's controllers scan
		# tree-wide groups (checkpoints, resettables, player) in _ready and must
		# never see the outgoing world's nodes.
		_current_world.free()
		_current_world = null
	var world: Node2D = world_scene.instantiate() as Node2D
	_world_root.add_child(world)
	_current_world = world
	var hub: Hub = world as Hub
	if hub != null:
		hub.zone_entry_requested.connect(_on_zone_entry_requested)
	else:
		_move_player_to_zone_entrance(world)
	_is_transitioning = false


func _move_player_to_zone_entrance(world: Node2D) -> void:
	# Zones place their own player at %PlayerSpawn for standalone F6 runs;
	# arriving through the hub gate uses the zone's authored drop-off instead.
	var entrance: Marker2D = world.get_node_or_null("%ZoneEntrance") as Marker2D
	var player: PlayerController = world.get_node_or_null("%Player") as PlayerController
	if entrance == null or player == null:
		return
	player.global_position = entrance.global_position
	var camera_limits: CameraLimits = world.get_node_or_null("%CameraLimits") as CameraLimits
	if camera_limits != null:
		# The drop-off teleport must not smooth-pan the camera from the spawn.
		camera_limits.snap_to_target()
