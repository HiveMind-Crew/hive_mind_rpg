class_name Hub
extends Node2D
## Safe settlement hub (issue #20), graybox pass: one 640x360 screen holding
## the player spawn, a checkpoint shrine, the skill-tree station, and the gate
## to Zone 1. Like the other grayboxes, the floor/walls are painted in
## _ready() from the named constants below so the layout stays diffable
## instead of living as opaque packed tile data.
##
## Interaction wiring:
## - Station: a self-contained SkillTreeStation prop (#67) that owns the
##   skill-tree screen lifecycle and the player input lock; the hub only asks
##   it is_screen_open() to keep the gate inert behind the menu.
## - Gate: emits zone_entry_requested for the scene owner (#68) to consume.
##   The hub itself only changes scene on the debug F6 path, where no owner
##   exists to listen.
## - Shrine: the RespawnController consumes checkpoint_reached exactly as in
##   Zone 1, so touching the shrine heals and persists the run (#18/#19).

signal zone_entry_requested(zone_scene_path: String)

## Where the gate leads: Zone 1's graybox (#21) is the slice's only zone; its
## ZoneEntrance marker is the documented drop-off for this gate.
const GATE_TARGET_ZONE_PATH: String = "res://scenes/world/zone1_graybox.tscn"

# Self-made 2-tile placeholder atlas (CC0) — see assets/sprites/testing/README.md.
const TILES_TEXTURE: Texture2D = preload("res://assets/sprites/testing/graybox_tiles.png")
const TILE_SOURCE_ID: int = 0
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const FLOOR_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)
const WALL_TILE_ATLAS_COORDS: Vector2i = Vector2i(1, 0)

# 40 x 23 tiles = 640 x 368 px — one settlement room, one screen.
const HUB_SIZE_TILES: Vector2i = Vector2i(40, 23)

@onready var _floor_walls: TileMapLayer = %FloorWalls
@onready var _player_spawn: Marker2D = %PlayerSpawn
@onready var _player: PlayerController = %Player
@onready var _station: SkillTreeStation = %SkillTreeStation
@onready var _gate_zone: InteractableZone = %GateZone
@onready var _camera_limits: CameraLimits = %CameraLimits


func _ready() -> void:
	_floor_walls.tile_set = _build_tile_set()
	_paint_hub()
	_player.position = _player_spawn.position
	_camera_limits.apply_bounds(get_hub_bounds())
	_gate_zone.interacted.connect(_on_gate_zone_interacted)


## The painted tile area in world pixels — the camera never shows past it.
func get_hub_bounds() -> Rect2:
	return Rect2(_floor_walls.global_position, Vector2(HUB_SIZE_TILES * TILE_SIZE))


## True for the outer perimeter; the settlement room itself is open floor.
func is_wall_cell(coords: Vector2i) -> bool:
	if coords.x <= 0 or coords.y <= 0:
		return true
	return coords.x >= HUB_SIZE_TILES.x - 1 or coords.y >= HUB_SIZE_TILES.y - 1


func is_skill_tree_open() -> bool:
	return _station.is_screen_open()


func _on_gate_zone_interacted() -> void:
	# The interact press that closes the station screen must never also travel;
	# while the menu owns input the gate stays inert.
	if is_skill_tree_open():
		return
	zone_entry_requested.emit(GATE_TARGET_ZONE_PATH)
	_enter_target_zone_if_standalone()


func _enter_target_zone_if_standalone() -> void:
	# DEBUG PATH: only taken when the hub is run directly with F6, i.e. it IS
	# the current scene instead of living under the main scene. There, nothing
	# can consume zone_entry_requested (#68 owns real transitions), so travel
	# directly to keep the standalone hub explorable end to end.
	if get_tree().current_scene != self:
		return
	get_tree().change_scene_to_file.call_deferred(GATE_TARGET_ZONE_PATH)


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


func _paint_hub() -> void:
	_floor_walls.clear()
	for y: int in HUB_SIZE_TILES.y:
		for x: int in HUB_SIZE_TILES.x:
			var coords: Vector2i = Vector2i(x, y)
			var atlas_coords: Vector2i = FLOOR_TILE_ATLAS_COORDS
			if is_wall_cell(coords):
				atlas_coords = WALL_TILE_ATLAS_COORDS
			_floor_walls.set_cell(coords, TILE_SOURCE_ID, atlas_coords)
