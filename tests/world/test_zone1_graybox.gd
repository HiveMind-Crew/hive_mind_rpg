extends GutTest
## Coverage for the Zone 1 graybox (issue #21): painted layout, room/checkpoint/
## secret/boss-door structure, and a BFS walkability proof that the entrance
## reaches every point of interest (the "no softlocks" criterion). The secret
## alcoves hold real persistent pickups (issue #78), so the suite redirects
## SaveManager at a scratch file and resets progression around every test.

const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")
const ENCOUNTER_SEAL_PATH: String = "res://assets/sprites/world/hd/encounter_seal.png"
const ENCOUNTER_SEAL_TEXTURE: Texture2D = preload(ENCOUNTER_SEAL_PATH)
const TEST_SAVE_PATH: String = "user://test_zone1_savegame.json"
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

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


func test_zone_enemies_stand_on_floor_and_stay_dormant_until_entered() -> void:
	var zone: Zone1Graybox = _add_zone()
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
		# Enemies belong to a room now: they stay untargeted and idle until the
		# player physically enters that room (#212).
		assert_null(enemy.target, "%s must stay dormant before its room is entered." % enemy.name)
		assert_eq(enemy.state, EnemyBase.State.IDLE, "%s must idle while dormant." % enemy.name)
		assert_false(zone.is_wall_cell(_cell_of(zone, enemy.global_position)))
	assert_true(has_chaser, "Zone 1 retains the melee chaser baseline.")
	assert_true(has_harasser, "Zone 1 includes a ranged harasser encounter.")
	assert_true(has_brute, "Zone 1 includes a shielded brute encounter.")
	assert_true(has_flanker, "Zone 1 includes a fast flanker encounter.")


## Each room owns exactly its authored enemy set under its own Enemies root, and
## the placed rooms are real EncounterRoom controllers (not bare markers).
func test_each_room_owns_only_its_authored_enemy_set() -> void:
	var zone: Zone1Graybox = _add_zone()
	var rooms: Array[EncounterRoom] = zone.get_encounter_rooms()

	assert_eq(rooms.size(), 3, "Zone 1 places three real encounter rooms.")
	var room_a: EncounterRoom = rooms[0]
	var room_b: EncounterRoom = rooms[1]
	var room_c: EncounterRoom = rooms[2]
	assert_eq(room_a.get_assigned_enemies().size(), 2, "Room A owns its melee + flanker pair.")
	assert_eq(room_b.get_assigned_enemies().size(), 4, "Room B owns the largest split fight.")
	assert_eq(room_c.get_assigned_enemies().size(), 2, "Room C owns the pre-boss pair.")
	for room: EncounterRoom in rooms:
		assert_true(room.is_in_group(EncounterRoom.ENCOUNTER_ROOM_GROUP))
		assert_true(
			room.is_in_group(RespawnController.RESETTABLE_GROUP),
			"%s re-arms through the death respawn flow." % room.name
		)
		assert_eq(room.state, EncounterRoom.State.DORMANT, "%s starts dormant." % room.name)
		assert_false(room.are_exits_sealed(), "%s keeps its barriers open until entered." % room.name)


func _player_enter_room(zone: Zone1Graybox, room: EncounterRoom) -> void:
	# Drive real player entry: teleport the actual player body onto the room
	# trigger and let the physics overlap fire body_entered.
	var player: PlayerController = zone.get_node("Player") as PlayerController
	player.global_position = room.global_position
	await wait_physics_frames(3)


func _clear_room(zone: Zone1Graybox, room: EncounterRoom) -> void:
	await _player_enter_room(zone, room)
	for node: Node in room.get_assigned_enemies():
		(node as EnemyBase).health.take_damage(99999)
	await wait_physics_frames(1)


func test_zone_props_are_authored_non_colliding_set_dressing() -> void:
	var zone: Zone1Graybox = _add_zone()
	var props: Array[CanvasItem] = zone.get_zone_props()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	var named_route_props: Array[StringName] = [
		&"StumpCorridorWest", &"StoneCorridorMiddle", &"StumpCorridorEast",
		&"StoneAlcoveSouth", &"StumpAlcoveNorth",
	]

	assert_gte(props.size(), 12, "Rooms, corridors, secrets, and the boss approach need set dressing.")
	for prop: CanvasItem in props:
		var prop_node: Node2D = prop as Node2D
		assert_not_null(prop_node)
		assert_eq(prop.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_false(zone.is_wall_cell(_cell_of(zone, prop_node.global_position)))
		assert_gte(prop_node.global_position.distance_to(player.global_position), 48.0)
		for enemy: EnemyBase in zone.get_zone_enemies():
			assert_gte(
				prop_node.global_position.distance_to(enemy.global_position), 48.0,
				"%s must not obscure an enemy spawn." % prop.name
			)
	for prop_name: StringName in named_route_props:
		assert_not_null(zone.get_node_or_null(NodePath("Props/%s" % prop_name)), "%s is required." % prop_name)

	for machine_name: StringName in [&"RelicMachineRoomB", &"RelicMachineRoomC"]:
		var machine: AnimatedSprite2D = zone.get_node(NodePath("Props/%s" % machine_name)) as AnimatedSprite2D
		assert_not_null(machine)
		if machine != null:
			assert_eq(machine.sprite_frames, preload("res://assets/sprites/world/zone1_props_frames.tres"))
			assert_eq(machine.animation, &"glow")
			assert_true(machine.is_playing())


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


func test_encounter_seal_asset_and_scene_contract_are_hd_and_non_mechanical() -> void:
	var file: FileAccess = FileAccess.open(ENCOUNTER_SEAL_PATH, FileAccess.READ)
	assert_not_null(file)
	assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
	assert_eq(ENCOUNTER_SEAL_TEXTURE.get_size(), Vector2(192.0, 384.0))
	var image: Image = ENCOUNTER_SEAL_TEXTURE.get_image()
	var used: Rect2i = image.get_used_rect()
	assert_gt(used.position.x, 0, "Seal keeps a transparent left margin.")
	assert_gt(used.position.y, 0, "Seal keeps a transparent top margin.")
	assert_lt(used.end.x, image.get_width(), "Seal keeps a transparent right margin.")
	assert_lt(used.end.y, image.get_height(), "Seal keeps a transparent bottom margin.")

	var zone: Zone1Graybox = _add_zone()
	for room: EncounterRoom in zone.get_encounter_rooms():
		for barrier_name: StringName in [&"BarrierWest", &"BarrierEast"]:
			var barrier: StaticBody2D = room.get_node(NodePath(barrier_name)) as StaticBody2D
			assert_not_null(barrier.get_node_or_null("CollisionShape2D"))
			assert_null(barrier.get_node_or_null("Visual"), "Legacy rectangle must not remain live.")
			var seal: Sprite2D = barrier.get_node("SealHdVisual") as Sprite2D
			assert_eq(seal.texture, ENCOUNTER_SEAL_TEXTURE)
			assert_eq(seal.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
			assert_eq(seal.scale, Vector2(0.18, 0.18))


func test_entering_a_room_activates_only_it_and_seals_its_barriers() -> void:
	var zone: Zone1Graybox = _add_zone()
	var rooms: Array[EncounterRoom] = zone.get_encounter_rooms()
	var player: PlayerController = zone.get_node("Player") as PlayerController

	await _player_enter_room(zone, rooms[0])

	assert_true(rooms[0].is_active(), "Real player entry activates room A.")
	assert_true(rooms[0].are_exits_sealed(), "Room A seals its exit barriers on entry.")
	var barrier: StaticBody2D = rooms[0].get_node("BarrierEast") as StaticBody2D
	var barrier_shape: CollisionShape2D = barrier.get_node("CollisionShape2D") as CollisionShape2D
	assert_true(barrier.visible, "Sealed barriers become visible walls.")
	assert_false(barrier_shape.disabled, "Sealed barriers collide during combat.")
	for node: Node in rooms[0].get_assigned_enemies():
		assert_eq((node as EnemyBase).target, player, "Room A enemies wake to the player.")

	# Later rooms stay dormant and untargeted while the player fights room A.
	for later_index: int in [1, 2]:
		assert_eq(
			rooms[later_index].state, EncounterRoom.State.DORMANT,
			"%s must stay dormant while an earlier room is active." % rooms[later_index].name
		)
		for node: Node in rooms[later_index].get_assigned_enemies():
			assert_null((node as EnemyBase).target, "Dormant rooms never target the player early.")


func test_clearing_a_room_reopens_its_barriers_and_leaves_later_rooms_dormant() -> void:
	var zone: Zone1Graybox = _add_zone()
	var rooms: Array[EncounterRoom] = zone.get_encounter_rooms()

	await _clear_room(zone, rooms[0])

	assert_true(rooms[0].is_completed(), "Room A completes when its set is cleared.")
	assert_false(rooms[0].are_exits_sealed(), "Cleared rooms reopen their barriers.")
	var barrier: StaticBody2D = rooms[0].get_node("BarrierEast") as StaticBody2D
	assert_false(barrier.visible, "Reopened barriers stop drawing as walls.")
	assert_false(zone.is_boss_door_open(), "One cleared room does not open the boss door.")
	for later_index: int in [1, 2]:
		assert_eq(rooms[later_index].state, EncounterRoom.State.DORMANT)


func test_clearing_every_room_unseals_the_boss_door() -> void:
	var zone: Zone1Graybox = _add_zone()
	watch_signals(zone)
	var rooms: Array[EncounterRoom] = zone.get_encounter_rooms()

	for index: int in rooms.size():
		assert_false(
			zone.is_boss_door_open(),
			"Door stays sealed until the authored room contract is met."
		)
		await _clear_room(zone, rooms[index])

	assert_true(zone.is_boss_door_open(), "Clearing every placed room unseals the door.")
	assert_signal_emit_count(zone, "boss_door_opened", 1)


func test_room_rewards_award_unique_points_once_and_survive_save_load() -> void:
	var zone: Zone1Graybox = _add_zone()
	var rooms: Array[EncounterRoom] = zone.get_encounter_rooms()

	var reward_ids: Array[StringName] = []
	var expected_total: int = 0
	for room: EncounterRoom in rooms:
		assert_not_null(room.reward_data, "%s is an authored milestone room." % room.name)
		assert_true(room.reward_data.is_valid(), "%s reward must be valid." % room.name)
		assert_false(reward_ids.has(room.reward_data.reward_id), "Room reward ids must be unique.")
		reward_ids.append(room.reward_data.reward_id)
		expected_total += room.reward_data.skill_points

	for room: EncounterRoom in rooms:
		await _clear_room(zone, room)

	assert_eq(GameState.get_skill_points(), expected_total, "Every room pays its authored points once.")
	for reward_id: StringName in reward_ids:
		assert_true(SaveManager.is_milestone_completed(reward_id), "%s persisted." % reward_id)

	# Relaunch the zone against the same save: milestones suppress a second payout.
	GameState.reset_progress()
	assert_true(SaveManager.load_game())
	var reloaded: Zone1Graybox = _add_zone()
	for room: EncounterRoom in reloaded.get_encounter_rooms():
		await _clear_room(reloaded, room)

	assert_eq(
		GameState.get_skill_points(), expected_total,
		"Re-clearing already-collected rooms in a fresh load pays nothing extra."
	)


func test_dying_re_arms_rooms_without_double_paying_rewards() -> void:
	var zone: Zone1Graybox = _add_zone()
	var rooms: Array[EncounterRoom] = zone.get_encounter_rooms()
	var respawn: RespawnController = zone.get_node("RespawnController") as RespawnController

	await _clear_room(zone, rooms[0])
	var points_after_first: int = GameState.get_skill_points()
	assert_gt(points_after_first, 0, "Room A paid on the first clear.")

	# Simulate the die-back loop: every resettable re-arms.
	respawn.respawn()
	await wait_physics_frames(1)

	assert_eq(rooms[0].state, EncounterRoom.State.DORMANT, "Room A re-arms after respawn.")
	assert_eq(rooms[0].get_assigned_enemies().size(), 2, "Rebuilt room A restores its enemy set.")
	# The rebuilt enemies must not double their HD adapter bodies (#212).
	var rebuilt: EnemyBase = rooms[0].get_assigned_enemies()[0] as EnemyBase
	var adapter: Node = rebuilt.get_node("HdPresentation")
	assert_eq(adapter.get_child_count(), 2, "Revived enemy keeps a single HD body + facing accent.")

	await _clear_room(zone, rooms[0])
	assert_eq(
		GameState.get_skill_points(), points_after_first,
		"Re-clearing a room after death never pays its reward twice."
	)


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
		assert_false(
			cover.visible,
			"%s legacy cover is suppressed by Zone1HdPresentation; its sensor stays live." % reveal.name
		)

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
