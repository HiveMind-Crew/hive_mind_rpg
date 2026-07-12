extends GutTest

const ARENA_SCENE: PackedScene = preload("res://scenes/world/arena_graybox.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/world/target_dummy.tscn")
const HITBOX_SCENE: PackedScene = preload("res://scenes/combat/hitbox.tscn")


func _add_arena() -> ArenaGraybox:
	var arena: ArenaGraybox = ARENA_SCENE.instantiate() as ArenaGraybox
	add_child_autofree(arena)
	return arena


func _add_dummy() -> TargetDummy:
	var dummy: TargetDummy = DUMMY_SCENE.instantiate() as TargetDummy
	add_child_autofree(dummy)
	return dummy


func test_arena_paints_every_cell_with_floor_or_wall() -> void:
	var arena: ArenaGraybox = _add_arena()
	var layer: TileMapLayer = arena.get_node("FloorWalls") as TileMapLayer

	var expected_cell_count: int = (
		ArenaGraybox.ARENA_SIZE_TILES.x * ArenaGraybox.ARENA_SIZE_TILES.y
	)
	assert_eq(layer.get_used_cells().size(), expected_cell_count)
	assert_eq(
		layer.get_cell_atlas_coords(Vector2i.ZERO),
		ArenaGraybox.WALL_TILE_ATLAS_COORDS,
		"Perimeter corner should be a wall."
	)
	var first_obstacle: Rect2i = ArenaGraybox.OBSTACLE_RECTS[0]
	assert_eq(
		layer.get_cell_atlas_coords(first_obstacle.position),
		ArenaGraybox.WALL_TILE_ATLAS_COORDS,
		"Obstacle cells should be walls."
	)
	assert_eq(
		layer.get_cell_atlas_coords(Vector2i(1, 1)),
		ArenaGraybox.FLOOR_TILE_ATLAS_COORDS,
		"Interior cells outside obstacles should be floor."
	)


func test_only_wall_tiles_have_collision() -> void:
	var arena: ArenaGraybox = _add_arena()
	var layer: TileMapLayer = arena.get_node("FloorWalls") as TileMapLayer
	var atlas: TileSetAtlasSource = (
		layer.tile_set.get_source(ArenaGraybox.TILE_SOURCE_ID) as TileSetAtlasSource
	)

	assert_eq(layer.tile_set.get_physics_layers_count(), 1)
	var wall_data: TileData = atlas.get_tile_data(ArenaGraybox.WALL_TILE_ATLAS_COORDS, 0)
	var floor_data: TileData = atlas.get_tile_data(ArenaGraybox.FLOOR_TILE_ATLAS_COORDS, 0)
	assert_eq(wall_data.get_collision_polygons_count(0), 1)
	assert_eq(floor_data.get_collision_polygons_count(0), 0)


func test_player_starts_at_spawn_marker_on_floor() -> void:
	var arena: ArenaGraybox = _add_arena()
	var player: PlayerController = arena.get_node("Player") as PlayerController
	var spawn: Marker2D = arena.get_node("PlayerSpawn") as Marker2D

	assert_not_null(player)
	assert_eq(player.position, spawn.position)
	var layer: TileMapLayer = arena.get_node("FloorWalls") as TileMapLayer
	var spawn_cell: Vector2i = layer.local_to_map(layer.to_local(spawn.global_position))
	assert_false(arena.is_wall_cell(spawn_cell), "Player spawn must be on a floor cell.")


func test_arena_contains_at_least_three_target_dummies_on_floor() -> void:
	var arena: ArenaGraybox = _add_arena()
	var layer: TileMapLayer = arena.get_node("FloorWalls") as TileMapLayer

	var dummies: Array[Node] = get_tree().get_nodes_in_group(TargetDummy.TARGET_DUMMY_GROUP)
	assert_gte(dummies.size(), 3)
	for node: Node in dummies:
		var dummy: TargetDummy = node as TargetDummy
		var cell: Vector2i = layer.local_to_map(layer.to_local(dummy.global_position))
		assert_false(
			arena.is_wall_cell(cell),
			"Dummy at %s must stand on a floor cell." % dummy.global_position
		)


func test_arena_contains_targeted_melee_chaser_on_floor() -> void:
	var arena: ArenaGraybox = _add_arena()
	var layer: TileMapLayer = arena.get_node("FloorWalls") as TileMapLayer
	var chaser: EnemyBase = arena.get_node("Enemies/MeleeChaser") as EnemyBase
	var player: PlayerController = arena.get_node("Player") as PlayerController

	assert_not_null(chaser)
	assert_eq(chaser.target, player)
	var cell: Vector2i = layer.local_to_map(layer.to_local(chaser.global_position))
	assert_false(arena.is_wall_cell(cell))


func test_dummy_takes_damage_and_updates_hp_label() -> void:
	var dummy: TargetDummy = _add_dummy()
	var hurtbox: Hurtbox = dummy.get_node("Hurtbox") as Hurtbox
	var health: HealthComponent = dummy.get_node("HealthComponent") as HealthComponent
	var hp_label: Label = dummy.get_node("HpLabel") as Label
	var hitbox: Hitbox = HITBOX_SCENE.instantiate() as Hitbox
	hitbox.damage = 2
	add_child_autofree(hitbox)

	assert_eq(hp_label.text, "%d/%d" % [health.max_health, health.max_health])
	hurtbox.receive_hit(hitbox)
	assert_eq(health.current_health, health.max_health - 2)
	assert_eq(hp_label.text, "%d/%d" % [health.max_health - 2, health.max_health])


func test_defeated_dummy_disables_hurtbox_and_shows_ko() -> void:
	var dummy: TargetDummy = _add_dummy()
	var hurtbox: Hurtbox = dummy.get_node("Hurtbox") as Hurtbox
	var health: HealthComponent = dummy.get_node("HealthComponent") as HealthComponent
	var hp_label: Label = dummy.get_node("HpLabel") as Label
	var hitbox: Hitbox = HITBOX_SCENE.instantiate() as Hitbox
	hitbox.damage = health.max_health
	add_child_autofree(hitbox)

	hurtbox.receive_hit(hitbox)
	assert_true(health.is_dead)
	assert_false(hurtbox.enabled, "Defeated dummy should stop receiving hits.")
	assert_eq(hp_label.text, TargetDummy.DEFEATED_LABEL_TEXT)
