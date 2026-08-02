class_name Zone1Graybox
extends Node2D
## Zone 1 "corrupted forest" graybox layout (issue #21): entrance → three
## encounter rooms joined by corridors → boss door → boss-arena stub, with two
## checkpoint shrines and two hidden secret alcoves off the main path.
##
## Like ArenaGraybox, the floor/walls are painted in _ready() from the named
## rect constants below so the layout stays diffable and testable instead of
## living as opaque packed tile data. Walkable space is the union of
## FLOOR_RECTS; every other cell is wall.
##
## Integration points:
## - ZoneEntrance marker: where the hub's zone gate (#20) drops the player.
## - secret_markers group (issue #78): each alcove holds a persistent
##   SkillPointPickup under a HiddenRoomReveal cover — collection awards
##   points once and survives reloads through SaveManager.
## - BossDoor + open_boss_door(): the door unseals when the zone's placed
##   encounters are cleared, opening the way to the Rootheart Colossus
##   (issue #23) waiting at the BossArenaAnchor. Defeating it pays the boss
##   reward and records the persisted zone1_slice_complete milestone.

signal boss_door_opened()
## Emitted when the player uses the entrance exit gate (#105); the main scene
## (#68) consumes this to travel back to the hub. Mirrors
## Hub.zone_entry_requested.
signal hub_return_requested()

# Hand-authored corrupted-forest production atlas — provenance in
# assets/sprites/LICENSES.md. The test-only graybox atlas remains isolated
# under assets/sprites/testing/.
const TILES_TEXTURE: Texture2D = preload("res://assets/sprites/world/zone1_forest_tiles.png")
## Where the exit gate leads on the standalone F6 debug path; under the main
## scene the owner performs the travel instead.
const EXIT_TARGET_HUB_PATH: String = "res://scenes/world/hub.tscn"
const TILE_SOURCE_ID: int = 0
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const FLOOR_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const WALL_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 1)

# 108 x 30 tiles = 1728 x 480 px; the camera follows the player through it.
const ZONE_SIZE_TILES: Vector2i = Vector2i(108, 30)

const ENCOUNTER_ROOM_GROUP: StringName = &"encounter_rooms"
const SECRET_MARKER_GROUP: StringName = &"secret_markers"
const PROP_GROUP: StringName = &"zone1_props"

## Walkable space in tile coordinates (Rect2i is end-exclusive). Order tells
## the story of the route: entrance, corridor, room A (+ its hidden south
## alcove), corridor, room B, corridor, room C (+ its hidden north alcove),
## boss corridor, boss-arena stub behind the door.
const FLOOR_RECTS: Array[Rect2i] = [
	Rect2i(1, 10, 10, 10),   # entrance room
	Rect2i(11, 14, 6, 3),    # corridor west
	Rect2i(17, 8, 16, 14),   # encounter room A
	Rect2i(24, 22, 1, 1),    # secret alcove A neck (1-tile gap, easy to miss)
	Rect2i(22, 23, 5, 4),    # secret alcove A
	Rect2i(33, 14, 6, 3),    # corridor middle
	Rect2i(39, 6, 18, 18),   # encounter room B (largest arena)
	Rect2i(57, 14, 6, 3),    # corridor east
	Rect2i(63, 8, 16, 14),   # encounter room C
	Rect2i(70, 6, 1, 2),     # secret alcove C neck
	Rect2i(68, 2, 6, 4),     # secret alcove C
	Rect2i(79, 13, 6, 5),    # boss corridor (sealed by BossDoor)
	Rect2i(85, 6, 20, 18),   # boss-arena stub (#23 fills this in)
]

@onready var _floor_walls: TileMapLayer = %FloorWalls
@onready var _player_spawn: Marker2D = %PlayerSpawn
@onready var _player: PlayerController = %Player
@onready var _boss_door: StaticBody2D = %BossDoor
@onready var _encounter_rooms: Node2D = %EncounterRooms
@onready var _boss: BossBase = %Boss
@onready var _camera_limits: CameraLimits = %CameraLimits
@onready var _respawn_controller: RespawnController = %RespawnController
@onready var _exit_zone: InteractableZone = %ExitZone

var _boss_door_open: bool = false


func _ready() -> void:
	_floor_walls.tile_set = _build_tile_set()
	_paint_zone()
	_player.position = _player_spawn.position
	# Camera limits come from the same authored geometry the tiles are painted
	# from (issue #65); respawn teleports snap the smoothed camera along.
	_camera_limits.apply_bounds(get_zone_bounds())
	_respawn_controller.respawn_finished.connect(_camera_limits.snap_to_target)
	_exit_zone.interacted.connect(_on_exit_zone_interacted)
	# Each placed EncounterRoom owns and gates its own enemy set: the enemies stay
	# dormant and untargeted until the player physically enters the room (#212).
	# The boss door tracks their authored completion contract, so the zone only
	# listens for each room clearing rather than targeting enemies globally.
	for room: EncounterRoom in get_encounter_rooms():
		room.encounter_completed.connect(_on_encounter_room_completed)
	# The boss lives outside the encounter rooms on purpose: it hunts the player
	# immediately, but its door stays keyed to the rooms, not the fight behind it.
	_boss.set_target(_player)


func _on_exit_zone_interacted() -> void:
	hub_return_requested.emit()
	_return_to_hub_if_standalone()


func _return_to_hub_if_standalone() -> void:
	# DEBUG PATH: mirrors Hub._enter_target_zone_if_standalone(). Only taken
	# when the zone is run directly with F6, where no owner exists to consume
	# hub_return_requested, so travel directly to keep the zone explorable.
	if get_tree().current_scene != self:
		return
	get_tree().change_scene_to_file.call_deferred(EXIT_TARGET_HUB_PATH)


## The painted tile area in world pixels — the camera never shows past it.
func get_zone_bounds() -> Rect2:
	return Rect2(_floor_walls.global_position, Vector2(ZONE_SIZE_TILES * TILE_SIZE))


## True outside the zone bounds and for every cell not inside a floor rect.
func is_wall_cell(coords: Vector2i) -> bool:
	for rect: Rect2i in FLOOR_RECTS:
		if rect.has_point(coords):
			return false
	return true


## The zone's placed encounter rooms in authored route order (west to east).
func get_encounter_rooms() -> Array[EncounterRoom]:
	var rooms: Array[EncounterRoom] = []
	for child: Node in _encounter_rooms.get_children():
		var room: EncounterRoom = child as EncounterRoom
		if room != null:
			rooms.append(room)
	return rooms


## Every regular enemy across the placed encounter rooms. Enemies are owned by
## their room now, so this aggregates each room's assigned set (the boss stays
## separate). Reflects live enemies, which a room rebuilds on reset.
func get_zone_enemies() -> Array[EnemyBase]:
	var zone_enemies: Array[EnemyBase] = []
	for room: EncounterRoom in get_encounter_rooms():
		for node: Node in room.get_assigned_enemies():
			var enemy: EnemyBase = node as EnemyBase
			if enemy != null:
				zone_enemies.append(enemy)
	return zone_enemies


func get_zone_props() -> Array[CanvasItem]:
	var props: Array[CanvasItem] = []
	for node: Node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop: CanvasItem = node as CanvasItem
		if prop != null and is_ancestor_of(prop):
			props.append(prop)
	return props


## The zone's still-uncollected secret pickups (already-collected ones free
## themselves on spawn, so this is also the "what's left to find" list).
func get_secret_pickups() -> Array[SkillPointPickup]:
	var pickups: Array[SkillPointPickup] = []
	for node: Node in get_tree().get_nodes_in_group(SkillPointPickup.PICKUP_GROUP):
		var pickup: SkillPointPickup = node as SkillPointPickup
		if pickup != null and is_ancestor_of(pickup):
			pickups.append(pickup)
	return pickups


func get_boss() -> BossBase:
	return _boss


func is_boss_door_open() -> bool:
	return _boss_door_open


func open_boss_door() -> void:
	if _boss_door_open:
		return
	_boss_door_open = true
	_boss_door.hide()
	# Deferred: physics properties cannot safely change while overlaps flush.
	var door_shape: CollisionShape2D = _boss_door.get_node("CollisionShape2D") as CollisionShape2D
	door_shape.set_deferred("disabled", true)
	boss_door_opened.emit()


func _on_encounter_room_completed() -> void:
	# Authored contract: the boss door unseals once every placed encounter room is
	# cleared in the same run. reset_to_spawn() re-arms rooms on death (the
	# die-back loop), so is_completed() reads false for a room the player must
	# re-clear — but its one-shot reward never re-pays.
	for room: EncounterRoom in get_encounter_rooms():
		if not room.is_completed():
			return
	open_boss_door()


func _build_tile_set() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_physics_layer()

	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = TILES_TEXTURE
	atlas.texture_region_size = TILE_SIZE
	atlas.create_tile(FLOOR_TILE_ATLAS_COORDS)
	atlas.create_tile(WALL_TILE_ATLAS_COORDS)
	# The source must join the TileSet before editing TileData collision,
	# otherwise the tiles don't know about the physics layer yet.
	tile_set.add_source(atlas, TILE_SOURCE_ID)

	var wall_data: TileData = atlas.get_tile_data(WALL_TILE_ATLAS_COORDS, 0)
	wall_data.add_collision_polygon(0)
	var half_tile: Vector2 = Vector2(TILE_SIZE) / 2.0
	wall_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half_tile.x, -half_tile.y),
		Vector2(half_tile.x, -half_tile.y),
		Vector2(half_tile.x, half_tile.y),
		Vector2(-half_tile.x, half_tile.y),
	]))

	return tile_set


func _paint_zone() -> void:
	_floor_walls.clear()
	for y: int in ZONE_SIZE_TILES.y:
		for x: int in ZONE_SIZE_TILES.x:
			var coords: Vector2i = Vector2i(x, y)
			var atlas_coords: Vector2i = FLOOR_TILE_ATLAS_COORDS
			if is_wall_cell(coords):
				atlas_coords = WALL_TILE_ATLAS_COORDS
			_floor_walls.set_cell(coords, TILE_SOURCE_ID, atlas_coords)
