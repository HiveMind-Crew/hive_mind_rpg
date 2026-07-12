extends GutTest
## Coverage for the Zone 1 graybox (issue #21): painted layout, room/checkpoint/
## secret/boss-door structure, and a BFS walkability proof that the entrance
## reaches every point of interest (the "no softlocks" criterion).

const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]


func _add_zone() -> Zone1Graybox:
	var zone: Zone1Graybox = ZONE_SCENE.instantiate() as Zone1Graybox
	add_child_autofree(zone)
	return zone


func _cell_of(zone: Zone1Graybox, world_position: Vector2) -> Vector2i:
	var layer: TileMapLayer = zone.get_node("FloorWalls") as TileMapLayer
	return layer.local_to_map(layer.to_local(world_position))


## Flood fill over floor cells; FLOOR_RECTS all sit inside the zone bounds, so
## is_wall_cell also bounds the search.
func _reachable_from(zone: Zone1Graybox, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var visited: Dictionary[Vector2i, bool] = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset: Vector2i in CARDINAL_OFFSETS:
			var next_cell: Vector2i = cell + offset
			if visited.has(next_cell) or zone.is_wall_cell(next_cell):
				continue
			visited[next_cell] = true
			frontier.append(next_cell)
	return visited


func test_zone_paints_every_cell_with_floor_or_wall() -> void:
	var zone: Zone1Graybox = _add_zone()
	var layer: TileMapLayer = zone.get_node("FloorWalls") as TileMapLayer

	var expected_cell_count: int = (
		Zone1Graybox.ZONE_SIZE_TILES.x * Zone1Graybox.ZONE_SIZE_TILES.y
	)
	assert_eq(layer.get_used_cells().size(), expected_cell_count)
	assert_eq(
		layer.get_cell_atlas_coords(Vector2i.ZERO),
		Zone1Graybox.WALL_TILE_ATLAS_COORDS,
		"Zone corner should be a wall."
	)
	var entrance_rect: Rect2i = Zone1Graybox.FLOOR_RECTS[0]
	assert_eq(
		layer.get_cell_atlas_coords(entrance_rect.position),
		Zone1Graybox.FLOOR_TILE_ATLAS_COORDS,
		"Entrance room cells should be floor."
	)


func test_only_wall_tiles_have_collision() -> void:
	var zone: Zone1Graybox = _add_zone()
	var layer: TileMapLayer = zone.get_node("FloorWalls") as TileMapLayer
	var atlas: TileSetAtlasSource = (
		layer.tile_set.get_source(Zone1Graybox.TILE_SOURCE_ID) as TileSetAtlasSource
	)

	assert_eq(layer.tile_set.get_physics_layers_count(), 1)
	var wall_data: TileData = atlas.get_tile_data(Zone1Graybox.WALL_TILE_ATLAS_COORDS, 0)
	var floor_data: TileData = atlas.get_tile_data(Zone1Graybox.FLOOR_TILE_ATLAS_COORDS, 0)
	assert_eq(wall_data.get_collision_polygons_count(0), 1)
	assert_eq(floor_data.get_collision_polygons_count(0), 0)


func test_player_spawns_at_marker_on_floor_in_player_group() -> void:
	var zone: Zone1Graybox = _add_zone()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	var spawn: Marker2D = zone.get_node("PlayerSpawn") as Marker2D

	assert_not_null(player)
	assert_true(player.is_in_group(&"player"), "Checkpoints key off the player group.")
	assert_eq(player.position, spawn.position)
	assert_false(zone.is_wall_cell(_cell_of(zone, spawn.global_position)))


func test_zone_has_three_encounter_rooms_two_checkpoints_two_secrets() -> void:
	var zone: Zone1Graybox = _add_zone()

	var rooms: Array[Node] = get_tree().get_nodes_in_group(Zone1Graybox.ENCOUNTER_ROOM_GROUP)
	var secrets: Array[Node] = get_tree().get_nodes_in_group(Zone1Graybox.SECRET_MARKER_GROUP)
	var checkpoints: Array[Node] = get_tree().get_nodes_in_group(Checkpoint.CHECKPOINT_GROUP)

	assert_gte(rooms.size(), 3, "Zone 1 needs ~3 encounter rooms.")
	assert_gte(secrets.size(), 2, "Zone 1 needs 2+ secrets.")
	assert_eq(checkpoints.size(), 2, "Zone 1 places two shrines.")
	for node: Node in rooms + secrets + checkpoints:
		var point: Node2D = node as Node2D
		assert_false(
			zone.is_wall_cell(_cell_of(zone, point.global_position)),
			"%s must sit on a floor cell." % point.name
		)


func test_every_point_of_interest_is_reachable_from_the_entrance() -> void:
	var zone: Zone1Graybox = _add_zone()
	var spawn: Marker2D = zone.get_node("PlayerSpawn") as Marker2D
	var reachable: Dictionary[Vector2i, bool] = _reachable_from(
		zone, _cell_of(zone, spawn.global_position)
	)

	var points_of_interest: Array[Node] = []
	points_of_interest.append_array(get_tree().get_nodes_in_group(Zone1Graybox.ENCOUNTER_ROOM_GROUP))
	points_of_interest.append_array(get_tree().get_nodes_in_group(Zone1Graybox.SECRET_MARKER_GROUP))
	points_of_interest.append_array(get_tree().get_nodes_in_group(Checkpoint.CHECKPOINT_GROUP))
	for enemy: EnemyBase in zone.get_zone_enemies():
		points_of_interest.append(enemy)
	points_of_interest.append(zone.get_node("ZoneEntrance"))
	points_of_interest.append(zone.get_node("BossArenaAnchor"))
	assert_gt(points_of_interest.size(), 8, "The sweep should cover the whole route.")

	for node: Node in points_of_interest:
		var point: Node2D = node as Node2D
		assert_true(
			reachable.has(_cell_of(zone, point.global_position)),
			"%s must be walkable from the entrance (no softlocks)." % point.name
		)


func test_zone_enemies_stand_on_floor_and_target_the_player() -> void:
	var zone: Zone1Graybox = _add_zone()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	var zone_enemies: Array[EnemyBase] = zone.get_zone_enemies()

	assert_gte(zone_enemies.size(), 4, "Each encounter room is populated.")
	for enemy: EnemyBase in zone_enemies:
		assert_eq(enemy.target, player, "%s should hunt the player." % enemy.name)
		assert_false(zone.is_wall_cell(_cell_of(zone, enemy.global_position)))


func test_boss_door_starts_sealed_and_opens_on_request() -> void:
	var zone: Zone1Graybox = _add_zone()
	watch_signals(zone)
	var door: StaticBody2D = zone.get_node("BossDoor") as StaticBody2D
	var door_shape: CollisionShape2D = door.get_node("CollisionShape2D") as CollisionShape2D

	assert_false(zone.is_boss_door_open())
	assert_true(door.visible)
	assert_false(door_shape.disabled)

	zone.open_boss_door()
	zone.open_boss_door()
	await wait_physics_frames(1)

	assert_true(zone.is_boss_door_open())
	assert_false(door.visible)
	assert_true(door_shape.disabled)
	assert_signal_emit_count(zone, "boss_door_opened", 1)


func test_clearing_every_encounter_unseals_the_boss_door() -> void:
	var zone: Zone1Graybox = _add_zone()
	watch_signals(zone)
	var zone_enemies: Array[EnemyBase] = zone.get_zone_enemies()

	for index: int in zone_enemies.size():
		assert_false(
			zone.is_boss_door_open(),
			"Door must stay sealed until the last enemy falls."
		)
		zone_enemies[index].health.take_damage(99999)

	assert_true(zone.is_boss_door_open())
	assert_signal_emit_count(zone, "boss_door_opened", 1)
