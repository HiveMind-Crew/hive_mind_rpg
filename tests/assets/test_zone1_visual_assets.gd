extends GutTest
## Structural regression coverage for issue #95 production art. These checks keep
## canonical asset paths, frame regions, and atlas category rows from drifting
## back to test graybox textures without attempting subjective art evaluation.

const CHASER_SHEET_PATH: String = "res://assets/sprites/enemies/melee_chaser.png"
const CHASER_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/melee_chaser_frames.tres")
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")
const FOREST_ATLAS_PATH: String = "res://assets/sprites/world/zone1_forest_tiles.png"
const CHASER_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/melee_chaser.png")
const FOREST_TEXTURE: Texture2D = preload("res://assets/sprites/world/zone1_forest_tiles.png")
var _png_signature: PackedByteArray = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
const CHASER_FRAME_SIZE: Vector2i = Vector2i(24, 24)
const TILE_SIZE: Vector2i = Vector2i(16, 16)


func test_production_pngs_have_valid_signatures_and_manifest_dimensions() -> void:
	_assert_png_dimensions(CHASER_SHEET_PATH, CHASER_TEXTURE, Vector2i(144, 240))
	_assert_png_dimensions(FOREST_ATLAS_PATH, FOREST_TEXTURE, Vector2i(128, 80))


func test_chaser_sprite_frames_match_manifest_animation_contract() -> void:
	_assert_animation_frame_count(&"idle_down", 4)
	_assert_animation_frame_count(&"idle_up", 4)
	_assert_animation_frame_count(&"idle_side", 4)
	_assert_animation_frame_count(&"walk_down", 6)
	_assert_animation_frame_count(&"walk_up", 6)
	_assert_animation_frame_count(&"walk_side", 6)
	_assert_animation_frame_count(&"windup", 3)
	_assert_animation_frame_count(&"attack_melee", 3)
	_assert_animation_frame_count(&"hurt", 2)
	_assert_animation_frame_count(&"death", 5)


func test_chaser_scene_uses_the_animated_production_visual() -> void:
	var chaser: EnemyBase = CHASER_SCENE.instantiate() as EnemyBase
	add_child_autofree(chaser)

	var visual: AnimatedSprite2D = chaser.get_node("BodyVisual") as AnimatedSprite2D
	assert_not_null(visual)
	assert_eq(visual.sprite_frames, CHASER_FRAMES)
	assert_eq(visual.animation, &"idle_down")

	chaser.state = EnemyBase.State.WIND_UP
	chaser._apply_state_visuals()
	assert_eq(visual.animation, &"windup")
	assert_eq(visual.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_chaser_selects_directional_clips_and_mirrors_the_side_facing() -> void:
	var chaser: EnemyBase = CHASER_SCENE.instantiate() as EnemyBase
	var target: Node2D = Node2D.new()
	add_child_autofree(chaser)
	add_child_autofree(target)
	chaser.set_target(target)
	var visual: AnimatedSprite2D = chaser.get_node("BodyVisual") as AnimatedSprite2D

	target.global_position = Vector2.UP * 64.0
	chaser.state = EnemyBase.State.CHASE
	chaser._apply_state_visuals()
	assert_eq(visual.animation, &"walk_up")

	target.global_position = Vector2.RIGHT * 64.0
	chaser._apply_state_visuals()
	assert_eq(visual.animation, &"walk_side")
	assert_false(visual.flip_h)

	target.global_position = Vector2.LEFT * 64.0
	chaser._apply_state_visuals()
	assert_true(visual.flip_h)


func test_forest_atlas_has_manifest_category_rows() -> void:
	var atlas: Image = FOREST_TEXTURE.get_image()
	# Row 0: six floor variants; row 1: eight wall variants.
	for column: int in 6:
		_assert_tile_has_pixels(atlas, Vector2i(column, 0))
	for column: int in 8:
		_assert_tile_has_pixels(atlas, Vector2i(column, 1))
	# Rows 2 and 3 provide twelve edge/transition tiles, then four static veins.
	for column: int in 8:
		_assert_tile_has_pixels(atlas, Vector2i(column, 2))
	for column: int in 4:
		_assert_tile_has_pixels(atlas, Vector2i(column, 3))
	for column: int in 4:
		_assert_tile_has_pixels(atlas, Vector2i(column + 4, 3))
	# Row 4 holds two independently authored four-frame shimmer loops.
	for column: int in 8:
		_assert_tile_has_pixels(atlas, Vector2i(column, 4))


func test_zone_uses_forest_atlas_not_graybox_testing_art() -> void:
	var zone: Zone1Graybox = ZONE_SCENE.instantiate() as Zone1Graybox
	add_child_autofree(zone)
	await wait_process_frames(1)

	var floor_walls: TileMapLayer = zone.get_node("FloorWalls") as TileMapLayer
	var atlas: TileSetAtlasSource = floor_walls.tile_set.get_source(Zone1Graybox.TILE_SOURCE_ID) as TileSetAtlasSource
	assert_not_null(atlas)
	assert_eq(atlas.texture.resource_path, FOREST_ATLAS_PATH)
	assert_ne(atlas.texture.resource_path, "res://assets/sprites/testing/graybox_tiles.png")
	assert_true(atlas.has_tile(Zone1Graybox.FLOOR_TILE_ATLAS_COORDS))
	assert_true(atlas.has_tile(Zone1Graybox.WALL_TILE_ATLAS_COORDS))


func _assert_png_dimensions(path: String, texture: Texture2D, expected_size: Vector2i) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Asset should exist: %s" % path)
	if file == null:
		return
	assert_eq(file.get_buffer(_png_signature.size()), _png_signature, "%s must be a real PNG" % path)
	file.close()
	assert_eq(texture.get_size(), Vector2(expected_size), "%s dimensions" % path)


func _assert_animation_frame_count(animation_name: StringName, expected_count: int) -> void:
	assert_true(CHASER_FRAMES.has_animation(animation_name))
	assert_eq(CHASER_FRAMES.get_frame_count(animation_name), expected_count)


func _assert_tile_has_pixels(image: Image, tile_coords: Vector2i) -> void:
	var origin: Vector2i = tile_coords * TILE_SIZE
	var has_opaque_pixel: bool = false
	for y: int in TILE_SIZE.y:
		for x: int in TILE_SIZE.x:
			if image.get_pixelv(origin + Vector2i(x, y)).a > 0.0:
				has_opaque_pixel = true
				break
		if has_opaque_pixel:
			break
	assert_true(has_opaque_pixel, "Atlas tile %s should contain authored pixels" % tile_coords)
