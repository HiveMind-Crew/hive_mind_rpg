class_name ArenaGraybox
extends Node2D

## Graybox combat arena (issue #11): the shared integration ground for
## movement, melee (#9), relic abilities (#10), and enemy AI (#12).
## The TileMapLayer floor/walls are painted in _ready() from the named
## constants below, so the layout stays diffable in one place instead of
## living as opaque packed tile data in the .tscn.

# Self-made 2-tile placeholder atlas (CC0) — see assets/sprites/testing/README.md.
const TILES_TEXTURE: Texture2D = preload("res://assets/sprites/testing/graybox_tiles.png")
const TILE_SOURCE_ID: int = 0
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const FLOOR_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const WALL_TILE_ATLAS_COORDS: Vector2i = Vector2i(1, 0)

# 52 x 30 tiles = 832 x 480 px — a bit larger than one 640x360 screen so
# there is room to dash around obstacles while the camera follows.
const ARENA_SIZE_TILES: Vector2i = Vector2i(52, 30)

# Interior obstacle blocks, in tile coordinates. They break line of sight and
# give dodge/positioning play something to work against.
const OBSTACLE_RECTS: Array[Rect2i] = [
	Rect2i(10, 7, 2, 6),
	Rect2i(24, 13, 5, 2),
	Rect2i(38, 6, 2, 7),
	Rect2i(16, 21, 7, 1),
	Rect2i(31, 20, 2, 2),
]

@onready var _floor_walls: TileMapLayer = %FloorWalls
@onready var _player_spawn: Marker2D = %PlayerSpawn
@onready var _player: PlayerController = %Player


func _ready() -> void:
	_floor_walls.tile_set = _build_tile_set()
	_paint_arena()
	_player.position = _player_spawn.position


## True for the outer perimeter and every cell inside an obstacle block.
func is_wall_cell(coords: Vector2i) -> bool:
	if coords.x == 0 or coords.y == 0:
		return true
	if coords.x == ARENA_SIZE_TILES.x - 1 or coords.y == ARENA_SIZE_TILES.y - 1:
		return true
	for rect: Rect2i in OBSTACLE_RECTS:
		if rect.has_point(coords):
			return true
	return false


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


func _paint_arena() -> void:
	_floor_walls.clear()
	for y: int in ARENA_SIZE_TILES.y:
		for x: int in ARENA_SIZE_TILES.x:
			var coords: Vector2i = Vector2i(x, y)
			var atlas_coords: Vector2i = FLOOR_TILE_ATLAS_COORDS
			if is_wall_cell(coords):
				atlas_coords = WALL_TILE_ATLAS_COORDS
			_floor_walls.set_cell(coords, TILE_SOURCE_ID, atlas_coords)
