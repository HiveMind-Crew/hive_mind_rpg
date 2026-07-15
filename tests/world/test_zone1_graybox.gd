extends GutTest
## Coverage for the Zone 1 graybox (issue #21): painted layout, room/checkpoint/
## secret/boss-door structure, and a BFS walkability proof that the entrance
## reaches every point of interest (the "no softlocks" criterion). The secret
## alcoves hold real persistent pickups (issue #78), so the suite redirects
## SaveManager at a scratch file and resets progression around every test.

const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")
const TEST_SAVE_PATH: String = "user://test_zone1_savegame.json"

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()


func after_each() -> void:
	_delete_test_save()
	_forget_run_state()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	GameState.reset_progress()


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _forget_run_state() -> void:
	SaveManager.checkpoint_scene_path = ""
	SaveManager.checkpoint_position = Vector2.ZERO
	SaveManager.collected_secret_ids.clear()
	SaveManager.completed_milestone_ids.clear()


func _add_zone() -> Zone1Graybox:
	var zone: Zone1Graybox = ZONE_SCENE.instantiate() as Zone1Graybox
	add_child_autofree(zone)
	return zone


func _zone_reveals(zone: Zone1Graybox) -> Array[HiddenRoomReveal]:
	var reveals: Array[HiddenRoomReveal] = []
	for child: Node in zone.get_node("Secrets").get_children():
		var reveal: HiddenRoomReveal = child as HiddenRoomReveal
		if reveal != null:
			reveals.append(reveal)
	return reveals


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

	assert_gte(zone_enemies.size(), 7, "The three authored encounter rooms use the full regular roster.")
	var has_chaser: bool = false
	var has_harasser: bool = false
	var has_brute: bool = false
	var has_flanker: bool = false
	for enemy: EnemyBase in zone_enemies:
		has_chaser = has_chaser or not (
			enemy is RangedHarasser or enemy is ShieldedBrute or enemy is FastFlanker
		)
		has_harasser = has_harasser or enemy is RangedHarasser
		has_brute = has_brute or enemy is ShieldedBrute
		has_flanker = has_flanker or enemy is FastFlanker
		assert_eq(enemy.target, player, "%s should hunt the player." % enemy.name)
		assert_false(zone.is_wall_cell(_cell_of(zone, enemy.global_position)))
	assert_true(has_chaser, "Zone 1 retains the melee chaser baseline.")
	assert_true(has_harasser, "Zone 1 includes a ranged harasser encounter.")
	assert_true(has_brute, "Zone 1 includes a shielded brute encounter.")
	assert_true(has_flanker, "Zone 1 includes a fast flanker encounter.")


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


func test_boss_waits_in_the_arena_and_pays_the_slice_milestone() -> void:
	var zone: Zone1Graybox = _add_zone()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	var boss: BossBase = zone.get_boss()

	assert_not_null(boss)
	assert_eq(boss.target, player, "The boss hunts the player like every enemy.")
	assert_false(zone.is_wall_cell(_cell_of(zone, boss.global_position)))
	assert_eq(boss.defeat_milestone_id, &"zone1_slice_complete")
	assert_gt(boss.reward_skill_points, 0, "The boss kill pays a large reward.")
	assert_eq(boss.get_phase_count(), 2, "The slice boss is a two-phase fight.")

	var points_before: int = GameState.get_skill_points()
	boss.health.take_damage(99999)

	assert_eq(GameState.get_skill_points(), points_before + boss.reward_skill_points)
	assert_true(
		SaveManager.is_milestone_completed(&"zone1_slice_complete"),
		"Killing the boss flags the vertical slice complete."
	)


func test_boss_death_does_not_count_toward_the_door_unseal() -> void:
	var zone: Zone1Graybox = _add_zone()

	zone.get_boss().health.take_damage(99999)

	assert_false(
		zone.is_boss_door_open(),
		"The door is keyed to the encounter chasers, not the fight behind it."
	)


func test_secret_alcoves_hold_reachable_pickups_with_unique_ids() -> void:
	var zone: Zone1Graybox = _add_zone()
	var spawn: Marker2D = zone.get_node("PlayerSpawn") as Marker2D
	var reachable: Dictionary[Vector2i, bool] = _reachable_from(
		zone, _cell_of(zone, spawn.global_position)
	)
	var pickups: Array[SkillPointPickup] = zone.get_secret_pickups()

	assert_eq(pickups.size(), 2, "Both authored alcoves hold a real pickup.")
	var seen_ids: Array[StringName] = []
	for pickup: SkillPointPickup in pickups:
		assert_ne(
			pickup.secret_id, StringName(),
			"%s needs a nonempty id to persist." % pickup.name
		)
		assert_false(seen_ids.has(pickup.secret_id), "%s reuses a secret id." % pickup.name)
		seen_ids.append(pickup.secret_id)
		assert_true(
			reachable.has(_cell_of(zone, pickup.global_position)),
			"%s must be walkable from the entrance." % pickup.name
		)


func test_secret_covers_hide_the_alcoves_until_the_player_enters() -> void:
	var zone: Zone1Graybox = _add_zone()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	var reveals: Array[HiddenRoomReveal] = _zone_reveals(zone)

	assert_eq(reveals.size(), 2, "Each alcove sits behind a hidden-room cover.")
	for reveal: HiddenRoomReveal in reveals:
		var cover: CanvasItem = reveal.get_node("Cover") as CanvasItem
		assert_true(cover.visible, "%s starts covered." % reveal.name)

		reveal.body_entered.emit(player)

		assert_true(reveal.is_revealed())
		assert_false(cover.visible, "%s uncovers for the player." % reveal.name)


func test_collected_secrets_award_points_and_stay_gone_after_reload() -> void:
	var zone: Zone1Graybox = _add_zone()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	assert_eq(GameState.get_skill_points(), 0)

	for pickup: SkillPointPickup in zone.get_secret_pickups():
		pickup.body_entered.emit(player)

	assert_eq(GameState.get_skill_points(), 3, "South pays 1, north pays 2.")
	assert_true(SaveManager.is_secret_collected(&"zone1_alcove_south"))
	assert_true(SaveManager.is_secret_collected(&"zone1_alcove_north"))
	assert_true(SaveManager.has_save(), "Collection writes the save immediately.")

	zone.free()
	var reloaded_zone: Zone1Graybox = _add_zone()
	await wait_physics_frames(1)

	assert_eq(
		reloaded_zone.get_secret_pickups().size(), 0,
		"Collected secrets never respawn on reload."
	)


func test_exit_gate_emits_hub_return_request_on_interact() -> void:
	var zone: Zone1Graybox = _add_zone()
	var exit_zone: InteractableZone = zone.get_node_or_null("%ExitZone") as InteractableZone
	assert_not_null(exit_zone, "Zone 1 has an in-world exit gate at its entrance (#105).")
	if exit_zone == null:
		return

	watch_signals(zone)
	exit_zone.interact()

	assert_signal_emitted(
		zone, "hub_return_requested",
		"The exit gate raises the typed return request for the owner (#68) to consume."
	)
