extends GutTest
## Presentation contract for the Zone 1 HD 2D prototype (issue #141): the
## copied source assets are real PNGs at the documented dimensions, the
## integrated background is the recomposed v2 plate with no baked gameplay
## affordances (not the rejected v1 shrine plate), the zone installs the HD
## layer on the entrance → room A route, every new HD node filters linearly
## per-node, only the selected legacy display nodes and the covered-route
## scenery (display props + exit-gate marker polygon) are hidden (and only
## visually), gameplay/collision contracts are untouched, live mechanical
## signals mirror onto the static art, and the zone-local HUD treatment is
## applied without layout changes.

const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")
const TEST_SAVE_PATH: String = "user://test_zone1_hd_presentation_savegame.json"

const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

## Copied production-prototype assets and their required source dimensions,
## matching the provenance rows in assets/sprites/LICENSES.md.
const EXPECTED_ASSET_DIMENSIONS: Dictionary[String, Vector2i] = {
	"res://assets/sprites/hd_prototype/encounter_room_background.png": Vector2i(1024, 576),
	"res://assets/sprites/hd_prototype/player_wanderer.png": Vector2i(180, 274),
	"res://assets/sprites/hd_prototype/relic_hound.png": Vector2i(162, 286),
	"res://assets/sprites/hd_prototype/checkpoint_shrine.png": Vector2i(249, 330),
}

## Un-deleted originals the copies were made from (provenance requirement).
const SOURCE_REFERENCE_PATHS: Array[String] = [
	"res://assets/reference/hd_prototype/source_plates/encounter_room_background_v2.png",
	"res://assets/reference/hd_prototype/source_plates/extracted/player_wanderer.png",
	"res://assets/reference/hd_prototype/source_plates/extracted/relic_hound.png",
	"res://assets/reference/hd_prototype/source_plates/extracted/checkpoint_shrine.png",
]

## The integrated background must be the recomposed v2 plate with no baked
## gameplay affordances, not the rejected v1 plate whose painted shrine at a
## non-interactable location failed independent review.
const BACKGROUND_COPY_PATH: String = "res://assets/sprites/hd_prototype/encounter_room_background.png"
const BACKGROUND_V2_REFERENCE_PATH: String = "res://assets/reference/hd_prototype/source_plates/encounter_room_background_v2.png"
const REJECTED_BACKGROUND_V1_PATH: String = "res://assets/reference/hd_prototype/source_plates/encounter_room_background.png"
const BACKGROUND_V2_MD5: String = "b952852f4b8ce1acc1447525033a55c3"

## Display-only prop sprites whose position lies inside COVERED_ROUTE_RECT —
## the painted plate replaces them, so leaving them visible would double up
## scenery over the HD art.
const COVERED_ROUTE_PROP_NAMES: Array[String] = [
	"TreeRoomA",
	"RootRuinRoomA",
	"StumpCorridorWest",
	"StoneCorridorMiddle",
	"StoneAlcoveSouth",
]

## Props east of the room B seam keep their legacy presentation.
const UNCOVERED_PROP_NAMES: Array[String] = [
	"TreeRoomB",
	"RelicMachineRoomB",
	"TreeRoomC",
	"RelicMachineRoomC",
	"RootRuinBossApproach",
	"StumpCorridorEast",
	"StumpAlcoveNorth",
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


func _presentation_of(zone: Zone1Graybox) -> Zone1HdPresentation:
	return zone.get_node("HdPresentation") as Zone1HdPresentation


func test_hd_assets_are_real_pngs_with_documented_dimensions() -> void:
	for asset_path: String in EXPECTED_ASSET_DIMENSIONS:
		var file: FileAccess = FileAccess.open(asset_path, FileAccess.READ)
		assert_not_null(file, "Missing HD prototype asset: %s" % asset_path)
		if file == null:
			continue
		assert_eq(
			file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE,
			"%s must be a real PNG file." % asset_path
		)
		var texture: Texture2D = load(asset_path) as Texture2D
		assert_not_null(texture, "%s must import as a texture." % asset_path)
		assert_eq(
			Vector2i(texture.get_width(), texture.get_height()),
			EXPECTED_ASSET_DIMENSIONS[asset_path],
			"%s dimensions must match the documented source." % asset_path
		)
	for reference_path: String in SOURCE_REFERENCE_PATHS:
		assert_true(
			FileAccess.file_exists(reference_path),
			"Original source reference must not be deleted: %s" % reference_path
		)


func test_background_copy_is_the_v2_plate_without_baked_affordances() -> void:
	assert_eq(
		FileAccess.get_md5(BACKGROUND_COPY_PATH), BACKGROUND_V2_MD5,
		"Integrated background must be the recomposed v2 no-affordance plate."
	)
	assert_eq(
		FileAccess.get_md5(BACKGROUND_V2_REFERENCE_PATH), BACKGROUND_V2_MD5,
		"v2 source reference must match the documented plate content."
	)
	assert_ne(
		FileAccess.get_md5(BACKGROUND_COPY_PATH),
		FileAccess.get_md5(REJECTED_BACKGROUND_V1_PATH),
		"Rejected v1 plate (baked shrine, false affordance) must not be integrated."
	)


func test_covered_route_scenery_and_exit_gate_visual_are_hidden() -> void:
	var zone: Zone1Graybox = _add_zone()
	var presentation: Zone1HdPresentation = _presentation_of(zone)

	# The plate paints the entrance route's scenery, so the legacy display
	# props under it and the exit-gate marker polygon must not draw on top.
	assert_false(
		(zone.get_node("ExitGateVisual") as Polygon2D).visible,
		"Exit-gate marker polygon must not draw over the HD plate."
	)
	for prop_name: String in COVERED_ROUTE_PROP_NAMES:
		var prop: Node2D = zone.get_node("Props/%s" % prop_name) as Node2D
		assert_true(
			Zone1HdPresentation.COVERED_ROUTE_RECT.has_point(prop.position),
			"%s belongs to the covered route." % prop_name
		)
		assert_false(prop.visible, "%s must be hidden under the HD plate." % prop_name)
	for prop_name: String in UNCOVERED_PROP_NAMES:
		var prop: Node2D = zone.get_node("Props/%s" % prop_name) as Node2D
		assert_false(
			Zone1HdPresentation.COVERED_ROUTE_RECT.has_point(prop.position),
			"%s lies outside the covered route." % prop_name
		)
		assert_true(prop.visible, "%s must keep its legacy presentation." % prop_name)
	# Exactly the exit-gate visual + the covered props are hidden, and only
	# visually: every prop node stays in the tree under Props.
	assert_eq(
		presentation.get_hidden_legacy_scenery().size(),
		COVERED_ROUTE_PROP_NAMES.size() + 1
	)
	assert_eq(zone.get_zone_props().size(), 12, "No prop node may be removed.")

	# The exit interaction is untouched: the Area2D keeps sensing and the
	# prompt survives — only the marker polygon is hidden.
	var exit_zone: InteractableZone = zone.get_node("ExitZone") as InteractableZone
	assert_true(exit_zone.monitoring, "ExitZone must keep sensing the player.")
	assert_eq(exit_zone.prompt_text, "[E] Return to Hub")

	# Secret-alcove reveal mechanics stay intact: covers are mechanical
	# (hidden-room reveal), draw above the plate, and keep their pickups.
	assert_true((zone.get_node("Secrets/AlcoveSouthReveal/Cover") as Polygon2D).visible)
	assert_true((zone.get_node("Secrets/AlcoveSouthReveal") as Area2D).monitoring)
	assert_eq(zone.get_secret_pickups().size(), 2)


func test_zone_installs_hd_layer_on_entrance_first_encounter_route() -> void:
	var zone: Zone1Graybox = _add_zone()
	var presentation: Zone1HdPresentation = _presentation_of(zone)

	assert_not_null(presentation)
	# The covered route ends exactly on encounter room B's west doorway so the
	# HD/legacy seam is a room boundary (room B is FLOOR_RECTS[6]).
	var room_b_left_px: float = float(
		Zone1Graybox.FLOOR_RECTS[6].position.x * Zone1Graybox.TILE_SIZE.x
	)
	assert_eq(Zone1HdPresentation.COVERED_ROUTE_RECT, Rect2(0, 0, room_b_left_px, 480))

	var drawn: Rect2 = presentation.get_background_world_rect()
	assert_almost_eq(drawn.position, Vector2.ZERO, Vector2(0.01, 0.01))
	assert_almost_eq(
		drawn.size, Zone1HdPresentation.COVERED_ROUTE_RECT.size, Vector2(0.01, 0.01)
	)

	# Draw order: over the legacy tiles, under props/actors/interactables.
	assert_gt(presentation.get_index(), zone.get_node("FloorWalls").get_index())
	assert_lt(presentation.get_index(), zone.get_node("Props").get_index())


func test_all_hd_nodes_use_per_node_linear_filtering_only() -> void:
	var zone: Zone1Graybox = _add_zone()
	var presentation: Zone1HdPresentation = _presentation_of(zone)

	var hd_sprites: Array[Sprite2D] = presentation.get_hd_sprites()
	assert_eq(hd_sprites.size(), 4)
	for sprite: Sprite2D in hd_sprites:
		assert_not_null(sprite.texture)
		assert_eq(
			sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR,
			"%s must filter linearly per-node." % sprite.name
		)
	# The production adapter must not flip the project or hidden legacy state
	# drivers to linear: they keep their explicit nearest filter.
	var floor_walls: TileMapLayer = zone.get_node("FloorWalls") as TileMapLayer
	assert_eq(floor_walls.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var other_chaser_visual: AnimatedSprite2D = (
		zone.get_node("Enemies/ChaserRoomB1/BodyVisual") as AnimatedSprite2D
	)
	assert_eq(other_chaser_visual.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_only_selected_legacy_display_nodes_are_hidden_and_only_visually() -> void:
	var zone: Zone1Graybox = _add_zone()
	var presentation: Zone1HdPresentation = _presentation_of(zone)

	var player_body: AnimatedSprite2D = zone.get_node("Player/Body") as AnimatedSprite2D
	var chaser_visual: AnimatedSprite2D = (
		zone.get_node("Enemies/ChaserRoomA/BodyVisual") as AnimatedSprite2D
	)
	var shrine_visual: Polygon2D = (
		zone.get_node("Checkpoints/CheckpointEntrance/Visual") as Polygon2D
	)
	for legacy_visual: CanvasItem in [player_body, chaser_visual, shrine_visual]:
		assert_false(legacy_visual.visible, "%s should be hidden." % legacy_visual.name)
	# Hidden nodes stay in the tree as the live mechanical state source.
	assert_not_null(player_body.get_script(), "PlayerVisual driver must stay attached.")
	assert_not_null(player_body.sprite_frames)
	assert_not_null(chaser_visual.sprite_frames)

	# Other regular enemies now carry their own production HD adapter; their
	# legacy visuals remain hidden state drivers rather than drawing twice.
	var other_chaser_visual: AnimatedSprite2D = (
		zone.get_node("Enemies/ChaserRoomB1/BodyVisual") as AnimatedSprite2D
	)
	assert_false(other_chaser_visual.visible)
	assert_not_null(zone.get_node("Enemies/ChaserRoomB1/HdPresentation"))
	var other_shrine_visual: Polygon2D = (
		zone.get_node("Checkpoints/CheckpointRoomC/Visual") as Polygon2D
	)
	assert_true(other_shrine_visual.visible)

	# The HD replacements ride the same actors, so gameplay motion moves them.
	assert_eq(
		presentation.get_player_sprite().get_parent(),
		zone.get_node("Player/HdPresentation"),
		"Zone 1 must reuse the player-wide HD display instead of adding a duplicate body."
	)
	assert_eq(
		presentation.get_chaser_sprite().get_parent().get_parent(),
		zone.get_node("Enemies/ChaserRoomA")
	)
	assert_eq(
		presentation.get_shrine_sprite().get_parent(),
		zone.get_node("Checkpoints/CheckpointEntrance")
	)


func test_collision_and_gameplay_contracts_are_unchanged() -> void:
	var zone: Zone1Graybox = _add_zone()

	var player: PlayerController = zone.get_node("Player") as PlayerController
	var player_shape: CollisionShape2D = (
		player.get_node("CollisionShape2D") as CollisionShape2D
	)
	var capsule: CapsuleShape2D = player_shape.shape as CapsuleShape2D
	assert_false(player_shape.disabled)
	assert_eq(capsule.radius, 7.0)
	assert_eq(capsule.height, 20.0)
	assert_eq(player.position, (zone.get_node("PlayerSpawn") as Marker2D).position)
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	assert_eq(camera.zoom, Vector2(2, 2), "Prototype keeps the measured 2x camera.")

	var chaser: EnemyBase = zone.get_node("Enemies/ChaserRoomA") as EnemyBase
	var chaser_shape: CollisionShape2D = (
		chaser.get_node("CollisionShape2D") as CollisionShape2D
	)
	var circle: CircleShape2D = chaser_shape.shape as CircleShape2D
	assert_false(chaser_shape.disabled)
	assert_eq(circle.radius, 10.0)
	assert_eq(chaser.collision_layer, CollisionLayers.ENEMY_BODY)
	assert_eq(chaser.collision_mask, CollisionLayers.WORLD)

	var checkpoint: Checkpoint = (
		zone.get_node("Checkpoints/CheckpointEntrance") as Checkpoint
	)
	assert_true(checkpoint.monitoring, "Shrine must keep sensing the player.")
	assert_false(checkpoint.monitorable)
	assert_eq(checkpoint.collision_layer, 0)
	assert_eq(checkpoint.collision_mask, CollisionLayers.PLAYER_BODY)
	var checkpoint_shape: CollisionShape2D = (
		checkpoint.get_node("CollisionShape2D") as CollisionShape2D
	)
	assert_eq((checkpoint_shape.shape as RectangleShape2D).size, Vector2(24, 24))
	assert_eq(
		(checkpoint.get_node("RespawnPoint") as Marker2D).position, Vector2(0, 22)
	)


func test_live_mechanical_signals_mirror_onto_static_hd_art() -> void:
	var zone: Zone1Graybox = _add_zone()
	var presentation: Zone1HdPresentation = _presentation_of(zone)
	var player_body: AnimatedSprite2D = zone.get_node("Player/Body") as AnimatedSprite2D
	var chaser: EnemyBase = zone.get_node("Enemies/ChaserRoomA") as EnemyBase

	var flash_tint: Color = Color(1.0, 0.45, 0.45, 1.0)
	player_body.flip_h = true
	player_body.self_modulate = flash_tint
	chaser.state = EnemyBase.State.WIND_UP
	presentation._process(0.0)
	var enemy_presentation: EnemyHdPresentation = (
		chaser.get_node("HdPresentation") as EnemyHdPresentation
	)
	enemy_presentation._process(0.0)

	assert_true(presentation.get_player_sprite().flip_h)
	assert_eq(presentation.get_player_sprite().self_modulate, flash_tint)
	assert_eq(enemy_presentation.get_body_sprite().modulate, EnemyBase.WIND_UP_COLOR)
	assert_eq(
		Zone1HdPresentation.state_tint_for(EnemyBase.State.DEAD), EnemyBase.DEAD_COLOR
	)
	assert_eq(
		Zone1HdPresentation.state_tint_for(EnemyBase.State.CHASE), Color.WHITE
	)


func test_entrance_shrine_lights_when_checkpoint_reached() -> void:
	var zone: Zone1Graybox = _add_zone()
	var presentation: Zone1HdPresentation = _presentation_of(zone)
	var checkpoint: Checkpoint = (
		zone.get_node("Checkpoints/CheckpointEntrance") as Checkpoint
	)

	assert_eq(
		presentation.get_shrine_sprite().modulate,
		Zone1HdPresentation.SHRINE_DORMANT_MODULATE
	)
	checkpoint.checkpoint_reached.emit(checkpoint.get_respawn_position())
	assert_eq(
		presentation.get_shrine_sprite().modulate,
		Zone1HdPresentation.SHRINE_LIT_MODULATE
	)


func test_hud_treatment_present_without_layout_changes() -> void:
	var zone: Zone1Graybox = _add_zone()

	var panel: PanelContainer = (
		zone.get_node("Player/PlayerHud/MarginContainer/PanelContainer") as PanelContainer
	)
	assert_true(
		panel.has_theme_stylebox_override("panel"),
		"Zone-local HUD treatment must be applied."
	)
	# Shared HUD structure and sizing stay intact — treatment is skin-only.
	var health_bar: ProgressBar = panel.get_node("Bars/HealthBar") as ProgressBar
	var energy_bar: ProgressBar = panel.get_node("Bars/EnergyBar") as ProgressBar
	assert_eq(health_bar.custom_minimum_size, Vector2(170, 8))
	assert_eq(energy_bar.custom_minimum_size, Vector2(170, 8))
	assert_not_null(zone.get_node("Player/PlayerHud").get_script())
