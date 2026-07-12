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
## - secret_markers group: where the #24 pickups/hidden-room covers go.
## - BossDoor + open_boss_door() + BossArenaAnchor: where the #23 boss
##   framework attaches. Until then the door unseals when the zone's placed
##   encounters are cleared, so the walkthrough loop is complete.

signal boss_door_opened()

# Self-made 2-tile placeholder atlas (CC0) — see assets/sprites/testing/README.md.
const TILES_TEXTURE: Texture2D = preload("res://assets/sprites/testing/graybox_tiles.png")
const TILE_SOURCE_ID: int = 0
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const FLOOR_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const WALL_TILE_ATLAS_COORDS: Vector2i = Vector2i(1, 0)

# 108 x 30 tiles = 1728 x 480 px; the camera follows the player through it.
const ZONE_SIZE_TILES: Vector2i = Vector2i(108, 30)

const ENCOUNTER_ROOM_GROUP: StringName = &"encounter_rooms"
const SECRET_MARKER_GROUP: StringName = &"secret_markers"

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
@onready var _enemies_root: Node2D = %Enemies

var _boss_door_open: bool = false


func _ready() -> void:
	_floor_walls.tile_set = _build_tile_set()
	_paint_zone()
	_player.position = _player_spawn.position
	for enemy: EnemyBase in get_zone_enemies():
		enemy.set_target(_player)
		enemy.enemy_died.connect(_on_zone_enemy_died)


## True outside the zone bounds and for every cell not inside a floor rect.
func is_wall_cell(coords: Vector2i) -> bool:
	for rect: Rect2i in FLOOR_RECTS:
		if rect.has_point(coords):
			return false
	return true


func get_zone_enemies() -> Array[EnemyBase]:
	var zone_enemies: Array[EnemyBase] = []
	for child: Node in _enemies_root.get_children():
		var enemy: EnemyBase = child as EnemyBase
		if enemy != null:
			zone_enemies.append(enemy)
	return zone_enemies


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


func _on_zone_enemy_died() -> void:
	# Stand-in gate rule until the #23 boss framework takes over the door.
	for enemy: EnemyBase in get_zone_enemies():
		if enemy.state != EnemyBase.State.DEAD:
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
