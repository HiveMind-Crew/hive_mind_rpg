extends GutTest

const COMBAT_TEXTURE: Texture2D = preload("res://assets/sprites/fx/combat_fx_hd.png")
const RELIC_ORB_TEXTURE: Texture2D = preload("res://assets/sprites/fx/relic_orb_fx.png")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func test_generated_fx_sheets_have_manifest_dimensions() -> void:
	assert_eq(COMBAT_TEXTURE.get_size(), Vector2(384.0, 256.0))
	assert_eq(RELIC_ORB_TEXTURE.get_size(), Vector2(768.0, 288.0))


func test_combat_effects_have_authored_frame_counts_and_do_not_loop() -> void:
	_assert_effect(CombatFxSpawner.SLASH, 4)
	_assert_effect(CombatFxSpawner.SPARK, 4)
	_assert_effect(CombatFxSpawner.DASH, 3)
	_assert_effect(CombatFxSpawner.DISSOLVE, 6)


func test_combat_one_shots_keep_legacy_timing_and_self_clean() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	CombatFxSpawner.spawn_slash(parent, Vector2.ZERO, Vector2.RIGHT)
	CombatFxSpawner.spawn_spark(parent, Vector2.ZERO)
	CombatFxSpawner.spawn_dash_trail(parent, Vector2.ZERO, Vector2.RIGHT)
	CombatFxSpawner.spawn_dissolve(parent, Vector2.ZERO)

	assert_eq(_animated_fx_count(parent), 4)
	for effect: AnimatedSprite2D in _animated_fx_children(parent):
		assert_eq(
			effect.sprite_frames.get_animation_speed(effect.animation),
			CombatFxSpawner.COMBAT_FPS,
			"Combat FX retain the legacy 12 FPS presentation lifetime."
		)

	# The longest combat one-shot is the six-frame dissolve: 6 / 12 = 0.5 s.
	await get_tree().create_timer(0.6).timeout
	assert_eq(_animated_fx_count(parent), 0, "Every one-shot FX frees itself after animation_finished.")


func test_relic_flight_loops_and_reads_from_the_hd_sheet() -> void:
	var visual: AnimatedSprite2D = CombatFxSpawner.create_relic_flight_visual(Vector2.RIGHT)
	autofree(visual)
	var flight: SpriteFrames = visual.sprite_frames
	assert_eq(flight.get_frame_count(CombatFxSpawner.RELIC_FLIGHT), 4)
	assert_true(flight.get_animation_loop(CombatFxSpawner.RELIC_FLIGHT))
	assert_eq(visual.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(visual.scale, Vector2.ONE * CombatFxSpawner.RELIC_FLIGHT_SCALE)
	var first_frame: AtlasTexture = flight.get_frame_texture(CombatFxSpawner.RELIC_FLIGHT, 0) as AtlasTexture
	assert_not_null(first_frame)
	assert_eq(first_frame.atlas, RELIC_ORB_TEXTURE)
	assert_eq(first_frame.region, Rect2(0.0, 96.0, 128.0, 64.0))


func test_relic_cast_and_impact_are_linear_filtered_one_shots() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	CombatFxSpawner.spawn_relic_cast(parent, Vector2.ZERO, Vector2.RIGHT)
	CombatFxSpawner.spawn_relic_impact(parent, Vector2.ZERO)
	var cast: AnimatedSprite2D = parent.get_child(0) as AnimatedSprite2D
	var impact: AnimatedSprite2D = parent.get_child(1) as AnimatedSprite2D
	assert_not_null(cast)
	assert_not_null(impact)
	assert_eq(cast.sprite_frames.get_frame_count(CombatFxSpawner.RELIC_CAST), 6)
	assert_false(cast.sprite_frames.get_animation_loop(CombatFxSpawner.RELIC_CAST))
	assert_eq(cast.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(impact.sprite_frames.get_frame_count(CombatFxSpawner.RELIC_IMPACT), 6)
	assert_false(impact.sprite_frames.get_animation_loop(CombatFxSpawner.RELIC_IMPACT))
	assert_eq(impact.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(impact.rotation, 0.0)


func test_relic_orb_sheet_keeps_readable_core_trail_and_contained_impact() -> void:
	var image: Image = RELIC_ORB_TEXTURE.get_image()
	# The exact collision center stays a bright visual anchor in every looping
	# frame, while pixels behind it significantly outnumber the quiet lead side.
	for frame: int in CombatFxSpawner.RELIC_FLIGHT_FRAMES:
		var origin: Vector2i = Vector2i(frame * CombatFxSpawner.RELIC_FLIGHT_CELL.x, CombatFxSpawner.RELIC_FLIGHT_ROW_Y)
		var core: Color = image.get_pixelv(origin + Vector2i(64, 32))
		assert_gt(core.a, 0.95, "Flight frame %d keeps an opaque core at collision center." % frame)
		assert_gt(core.r, 0.8, "Flight frame %d keeps the core white-hot." % frame)
		var rear_pixels: int = _opaque_pixel_count(image, Rect2i(origin + Vector2i(14, 18), Vector2i(44, 28)))
		var lead_pixels: int = _opaque_pixel_count(image, Rect2i(origin + Vector2i(78, 18), Vector2i(36, 28)))
		assert_gt(rear_pixels, 200, "Flight frame %d has a substantial rearward trail." % frame)
		assert_lt(lead_pixels, 8, "Flight frame %d keeps the leading side quiet." % frame)
	# The impact dissipates inside its atlas cell rather than touching an edge.
	for frame: int in CombatFxSpawner.RELIC_IMPACT_FRAMES:
		var impact_origin: Vector2i = Vector2i(frame * CombatFxSpawner.RELIC_IMPACT_CELL.x, CombatFxSpawner.RELIC_IMPACT_ROW_Y)
		assert_eq(_opaque_pixel_count(image, Rect2i(impact_origin, Vector2i(128, 12))), 0)
		assert_eq(_opaque_pixel_count(image, Rect2i(impact_origin + Vector2i(0, 116), Vector2i(128, 12))), 0)
		assert_eq(_opaque_pixel_count(image, Rect2i(impact_origin, Vector2i(12, 128))), 0)
		assert_eq(_opaque_pixel_count(image, Rect2i(impact_origin + Vector2i(116, 0), Vector2i(12, 128))), 0)


func test_relic_cast_rotation_is_truthful_for_all_eight_directions() -> void:
	for direction: Vector2 in [
		Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
		Vector2(1.0, 1.0).normalized(), Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(), Vector2(1.0, -1.0).normalized(),
	]:
		var parent: Node2D = Node2D.new()
		add_child_autofree(parent)
		CombatFxSpawner.spawn_relic_cast(parent, Vector2.ZERO, direction)
		var cast: AnimatedSprite2D = parent.get_child(0) as AnimatedSprite2D
		assert_not_null(cast)
		assert_almost_eq(cast.rotation, direction.angle(), 0.0001)
		var flight: AnimatedSprite2D = CombatFxSpawner.create_relic_flight_visual(direction)
		autofree(flight)
		assert_almost_eq(flight.rotation, direction.angle(), 0.0001)


func test_player_actions_spawn_visual_only_effects() -> void:
	var parent: Node2D = Node2D.new()
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(parent)
	parent.add_child(player)

	player._movement.update(Vector2.RIGHT, true, 0.0)
	assert_eq(_animated_fx_count(parent), 1)

	assert_true(player.try_melee_attack())
	assert_eq(_animated_fx_count(parent), 2)


func _assert_effect(animation_name: StringName, expected_frames: int) -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	match animation_name:
		CombatFxSpawner.SLASH:
			CombatFxSpawner.spawn_slash(parent, Vector2.ZERO, Vector2.RIGHT)
		CombatFxSpawner.SPARK:
			CombatFxSpawner.spawn_spark(parent, Vector2.ZERO)
		CombatFxSpawner.DASH:
			CombatFxSpawner.spawn_dash_trail(parent, Vector2.ZERO, Vector2.RIGHT)
		CombatFxSpawner.DISSOLVE:
			CombatFxSpawner.spawn_dissolve(parent, Vector2.ZERO)
	var effect: AnimatedSprite2D = parent.get_child(0) as AnimatedSprite2D
	assert_not_null(effect)
	assert_eq(effect.sprite_frames.get_frame_count(animation_name), expected_frames)
	assert_false(effect.sprite_frames.get_animation_loop(animation_name))
	# Combat feedback is now stylized-HD and linear-filtered, matching the relic FX.
	assert_eq(effect.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	var first_frame: AtlasTexture = effect.sprite_frames.get_frame_texture(animation_name, 0) as AtlasTexture
	assert_not_null(first_frame)
	assert_eq(first_frame.atlas, COMBAT_TEXTURE, "HD combat effects read from the shared HD sheet.")


func _animated_fx_children(parent: Node2D) -> Array[AnimatedSprite2D]:
	var effects: Array[AnimatedSprite2D] = []
	for child: Node in parent.get_children():
		if child is AnimatedSprite2D:
			effects.append(child as AnimatedSprite2D)
	return effects


func _animated_fx_count(parent: Node2D) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is AnimatedSprite2D:
			count += 1
	return count


func _opaque_pixel_count(image: Image, region: Rect2i) -> int:
	var count: int = 0
	for y: int in region.size.y:
		for x: int in region.size.x:
			if image.get_pixelv(region.position + Vector2i(x, y)).a > 0.0:
				count += 1
	return count
