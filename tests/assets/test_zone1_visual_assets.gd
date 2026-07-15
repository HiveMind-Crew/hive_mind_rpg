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
const HARASSER_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/ranged_harasser.png")
const BRUTE_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/shielded_brute.png")
const FLANKER_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/fast_flanker.png")
const HARASSER_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/ranged_harasser_frames.tres")
const BRUTE_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/shielded_brute_frames.tres")
const FLANKER_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/fast_flanker_frames.tres")
const HARASSER_SCENE: PackedScene = preload("res://scenes/enemies/ranged_harasser.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/enemies/shielded_brute.tscn")
const FLANKER_SCENE: PackedScene = preload("res://scenes/enemies/fast_flanker.tscn")
const FOREST_TEXTURE: Texture2D = preload("res://assets/sprites/world/zone1_forest_tiles.png")
const PROPS_ATLAS_PATH: String = "res://assets/sprites/world/zone1_props.png"
const PROPS_TEXTURE: Texture2D = preload("res://assets/sprites/world/zone1_props.png")
const PROP_FRAMES: SpriteFrames = preload("res://assets/sprites/world/zone1_props_frames.tres")
var _png_signature: PackedByteArray = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
const CHASER_FRAME_SIZE: Vector2i = Vector2i(24, 24)
const TILE_SIZE: Vector2i = Vector2i(16, 16)


func test_production_pngs_have_valid_signatures_and_manifest_dimensions() -> void:
	_assert_png_dimensions(CHASER_SHEET_PATH, CHASER_TEXTURE, Vector2i(192, 320))
	_assert_png_dimensions(FOREST_ATLAS_PATH, FOREST_TEXTURE, Vector2i(128, 80))
	_assert_png_dimensions(PROPS_ATLAS_PATH, PROPS_TEXTURE, Vector2i(128, 96))


func test_zone_prop_atlas_has_a_complete_four_frame_machine_glow_loop() -> void:
	assert_true(PROP_FRAMES.has_animation(&"glow"))
	assert_eq(PROP_FRAMES.get_frame_count(&"glow"), 4)
	for frame_index: int in 4:
		var frame_texture: AtlasTexture = PROP_FRAMES.get_frame_texture(&"glow", frame_index) as AtlasTexture
		assert_not_null(frame_texture)
		if frame_texture != null:
			assert_eq(frame_texture.atlas, PROPS_TEXTURE)
			assert_eq(frame_texture.region.size, Vector2(32.0, 32.0))
			assert_eq(frame_texture.region.position, Vector2(float(frame_index * 32), 48.0))


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


func test_regular_enemy_roster_uses_distinct_production_sheets_and_animated_visuals() -> void:
	_assert_regular_enemy_art(HARASSER_SCENE, HARASSER_FRAMES, HARASSER_TEXTURE, "res://assets/sprites/enemies/ranged_harasser.png")
	_assert_regular_enemy_art(BRUTE_SCENE, BRUTE_FRAMES, BRUTE_TEXTURE, "res://assets/sprites/enemies/shielded_brute.png")
	_assert_regular_enemy_art(FLANKER_SCENE, FLANKER_FRAMES, FLANKER_TEXTURE, "res://assets/sprites/enemies/fast_flanker.png")


func _assert_regular_enemy_art(
	scene: PackedScene, frames: SpriteFrames, texture: Texture2D, texture_path: String
) -> void:
	_assert_png_dimensions(texture_path, texture, Vector2i(192, 320))
	for animation_name: StringName in [
		&"idle_down", &"idle_up", &"idle_side", &"walk_down", &"walk_up", &"walk_side",
		&"windup", &"attack_melee", &"hurt", &"death",
	]:
		assert_true(frames.has_animation(animation_name), "%s animation must exist." % animation_name)
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var visual: AnimatedSprite2D = enemy.get_node("BodyVisual") as AnimatedSprite2D
	assert_not_null(visual)
	assert_eq(visual.sprite_frames, frames)
	assert_eq(visual.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	enemy.state = EnemyBase.State.WIND_UP
	enemy._apply_state_visuals()
	assert_eq(visual.animation, &"windup")


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
	assert_eq(visual.animation, &"walk_side")
	assert_true(visual.flip_h)

	target.global_position = Vector2.UP * 64.0
	chaser._apply_state_visuals()
	assert_eq(visual.animation, &"walk_up")
	assert_false(visual.flip_h, "Non-side clips reset a stale left-facing flip.")


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
