extends GutTest
## Structural and state-mirroring coverage for the presentation-only HD player
## layer (issues #150/#165). PlayerVisual remains the logical animation/state
## owner; the HD body is a four-cell directional atlas selected by facing_label.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ATLAS_PATH: String = "res://assets/sprites/player/hd/player_directional_atlas.png"
const HD_ATLAS: Texture2D = preload("res://assets/sprites/player/hd/player_directional_atlas.png")
const MELEE_ATLAS_PATH: String = "res://assets/sprites/player/hd/player_melee_body_atlas.png"
const DASH_ATLAS_PATH: String = "res://assets/sprites/player/hd/player_dash_body_atlas.png"
const RELIC_ATLAS_PATH: String = "res://assets/sprites/player/hd/player_relic_body_atlas.png"
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
const MINIMUM_MELEE_PHASE_MASK_DIFFERENCE: int = 1200
const MINIMUM_ALIGNED_RECOVERY_MASK_DIFFERENCE: int = 600
const SUBSTANTIVE_ALPHA_CUTOFF: float = 0.5
const ALIGNMENT_SEARCH_RADIUS: int = 6

var _player: PlayerController
var _legacy_visual: PlayerVisual
var _presentation: PlayerHdPresentation


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_legacy_visual = _player.get_node("Body") as PlayerVisual
	_presentation = _player.get_node("HdPresentation") as PlayerHdPresentation


func after_each() -> void:
	for projectile: Node in get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP):
		projectile.free()
	# A real relic cast also creates the self-cleaning cast fork directly under
	# this test root. Tests assert immediate body state, not its visual lifetime.
	for child: Node in get_children():
		if child is AnimatedSprite2D:
			child.free()


func test_hd_presentation_hides_only_the_legacy_display_driver() -> void:
	assert_not_null(_presentation)
	assert_false(_legacy_visual.visible)
	assert_not_null(_legacy_visual.sprite_frames)
	var display: Sprite2D = _presentation.get_display_sprite()
	assert_not_null(display)
	assert_eq(display.texture, HD_ATLAS)
	assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_true(display.region_enabled, "Body must display one atlas cell, not the whole sheet.")
	assert_eq(display.region_rect.size, PlayerHdPresentation.ATLAS_CELL_SIZE)
	assert_almost_eq(
		display.scale.y * PlayerHdPresentation.ATLAS_CONTENT_HEIGHT_PX,
		PlayerHdPresentation.DISPLAY_HEIGHT_PX,
		0.01,
	)
	assert_gt(
		PlayerHdPresentation.DISPLAY_HEIGHT_PX, 34.0,
		"Issue #165 body should read materially larger than the retired 34px static body."
	)
	assert_not_null(_presentation.get_node("ContactShadow") as Polygon2D)


func test_atlas_is_a_documented_four_cell_directional_sheet() -> void:
	var file: FileAccess = FileAccess.open(ATLAS_PATH, FileAccess.READ)
	assert_not_null(file, "Missing HD player atlas: %s" % ATLAS_PATH)
	if file == null:
		return
	assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
	assert_eq(Vector2i(HD_ATLAS.get_width(), HD_ATLAS.get_height()), Vector2i(1024, 256))
	assert_eq(
		float(HD_ATLAS.get_width()),
		PlayerHdPresentation.ATLAS_CELL_SIZE.x * PlayerHdPresentation.DIRECTION_ATLAS_COLUMNS.size(),
	)
	var import_text: String = FileAccess.get_file_as_string(ATLAS_PATH + ".import")
	assert_string_contains(import_text, "compress/mode=0")
	assert_string_contains(import_text, "mipmaps/generate=false")
	assert_string_contains(import_text, "process/premult_alpha=false")
	assert_string_contains(import_text, "process/fix_alpha_border=true")


func test_atlas_region_follows_player_visual_facing_for_all_four_directions() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var cell: Vector2 = PlayerHdPresentation.ATLAS_CELL_SIZE
	# Atlas side art is authored west in column 1 and east in column 3. This
	# regression lock prevents left/right movement from selecting the opposite body.
	var direction_expectations: Array[Array] = [
		[Vector2.UP, 0], [Vector2.RIGHT, 3], [Vector2.DOWN, 2], [Vector2.LEFT, 1],
	]
	for expectation: Array in direction_expectations:
		_legacy_visual.set_facing_direction(expectation[0] as Vector2)
		_presentation._process(0.0)
		var column: int = expectation[1] as int
		assert_eq(
			display.region_rect,
			Rect2(Vector2(cell.x * float(column), 0.0), cell),
			"facing %s must select atlas column %d" % [expectation[0], column],
		)
		assert_false(
			display.flip_h,
			"West is authored atlas art, not a runtime mirror of the east cell."
		)


func test_melee_body_atlas_has_three_distinct_authored_poses_for_each_facing() -> void:
	var melee_atlas: Texture2D = load(MELEE_ATLAS_PATH) as Texture2D
	assert_not_null(melee_atlas, "Issue #189 requires a dedicated HD body melee atlas.")
	if melee_atlas == null:
		return
	var file: FileAccess = FileAccess.open(MELEE_ATLAS_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
	file.close()
	assert_eq(
		Vector2i(melee_atlas.get_width(), melee_atlas.get_height()),
		Vector2i(768, 1024),
		"The body attack sheet is three 256px phase columns by four directional rows.",
	)
	var image: Image = melee_atlas.get_image()
	for row: int in PlayerHdPresentation.MELEE_DIRECTION_ROWS.size():
		var windup_region := Rect2i(0, row * 256, 256, 256)
		var contact_region := Rect2i(256, row * 256, 256, 256)
		var recovery_region := Rect2i(512, row * 256, 256, 256)
		var windup: int = _opaque_pixel_count(image, windup_region)
		var contact: int = _opaque_pixel_count(image, contact_region)
		var recovery: int = _opaque_pixel_count(image, recovery_region)
		assert_gt(windup, 0, "Each facing needs an authored body/arm wind-up silhouette.")
		assert_gt(contact, 0, "Contact needs an authored committed-lunge silhouette.")
		assert_gt(recovery, 0, "Recovery must remain an authored pose, not a static-body pop.")
		assert_gt(
			_alpha_mask_difference(image, windup_region, contact_region),
			MINIMUM_MELEE_PHASE_MASK_DIFFERENCE,
			"Wind-up and contact must have materially different silhouettes.",
		)
		assert_gt(
			_alpha_mask_difference(image, contact_region, recovery_region),
			MINIMUM_MELEE_PHASE_MASK_DIFFERENCE,
			"Contact and recovery must have materially different silhouettes.",
		)
		assert_gt(
			_alpha_mask_difference(image, windup_region, recovery_region),
			MINIMUM_MELEE_PHASE_MASK_DIFFERENCE,
			"Recovery must not repeat the wind-up silhouette.",
		)
		assert_gt(
			_minimum_aligned_alpha_mask_difference(image, windup_region, recovery_region),
			MINIMUM_ALIGNED_RECOVERY_MASK_DIFFERENCE,
			"Recovery must change the body shape, not merely translate wind-up.",
		)
		var windup_bounds: Rect2i = _opaque_bounds(image, windup_region)
		var contact_bounds: Rect2i = _opaque_bounds(image, contact_region)
		match row:
			0:
				assert_lt(contact_bounds.position.y, windup_bounds.position.y - 8,
					"North contact must lunge visibly north of wind-up.")
			1:
				assert_lt(contact_bounds.position.x - 256, windup_bounds.position.x - 8,
					"West contact must lunge visibly west of wind-up.")
			2:
				assert_gt(contact_bounds.end.y, windup_bounds.end.y + 8,
					"South contact must lunge visibly south of wind-up.")
			3:
				assert_gt(contact_bounds.end.x - 256, windup_bounds.end.x + 8,
					"East contact must lunge visibly east of wind-up.")


func test_recovery_shape_check_rejects_a_translated_windup_copy() -> void:
	var atlas: Image = PlayerHdPresentation.MELEE_ATLAS_TEXTURE.get_image()
	var comparison := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	var windup_region := Rect2i(0, 0, 256, 256)
	var recovery_region := Rect2i(256, 0, 256, 256)
	comparison.blit_rect(atlas, windup_region, Vector2i.ZERO)
	comparison.blit_rect(atlas, windup_region, Vector2i(261, 0))
	comparison.fill_rect(Rect2i(266, 10, 11, 11), Color.WHITE)
	assert_gt(
		_alpha_mask_difference(comparison, windup_region, recovery_region),
		MINIMUM_MELEE_PHASE_MASK_DIFFERENCE,
		"The old unaligned comparison demonstrates the five-pixel translation loophole.",
	)
	assert_lt(
		_minimum_aligned_alpha_mask_difference(comparison, windup_region, recovery_region),
		MINIMUM_ALIGNED_RECOVERY_MASK_DIFFERENCE,
		"Translation search must reject a shifted copy with a small disconnected noise patch.",
	)


func test_melee_body_uses_windup_contact_recovery_and_returns_at_the_existing_window() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var directions: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for direction: Vector2 in directions:
		_legacy_visual.play_melee(direction)
		_presentation._process(0.0)
		assert_eq(display.texture, PlayerHdPresentation.MELEE_ATLAS_TEXTURE)
		assert_eq(display.region_rect, _presentation._melee_atlas_region_for(
			_legacy_visual.facing_label, PlayerHdPresentation.MELEE_WINDUP_COLUMN))
		_presentation._process(PlayerHdPresentation.MELEE_WINDUP_SECONDS)
		assert_eq(display.region_rect, _presentation._melee_atlas_region_for(
			_legacy_visual.facing_label, PlayerHdPresentation.MELEE_CONTACT_COLUMN))
		_presentation._process(PlayerHdPresentation.MELEE_CONTACT_SECONDS)
		assert_eq(display.region_rect, _presentation._melee_atlas_region_for(
			_legacy_visual.facing_label, PlayerHdPresentation.MELEE_RECOVERY_COLUMN))
		_presentation._process(PlayerHdPresentation.MELEE_RECOVERY_SECONDS)
		assert_eq(display.texture, HD_ATLAS,
			"The HD body must stop advertising the swing when the 0.12s gameplay window ends.")
		assert_eq(display.region_rect, _presentation._atlas_region_for(_legacy_visual.facing_label))
		_legacy_visual._on_clip_finished()


func test_melee_body_phases_exactly_partition_existing_melee_mechanics() -> void:
	assert_almost_eq(
		PlayerHdPresentation.MELEE_WINDUP_SECONDS
		+ PlayerHdPresentation.MELEE_CONTACT_SECONDS
		+ PlayerHdPresentation.MELEE_RECOVERY_SECONDS,
		_player.melee_duration,
		0.0001,
	)
	assert_eq(_player.melee_damage, 1)
	assert_eq(_player.melee_hitbox_offset, 14.0)


func test_real_player_melee_event_drives_the_body_pose_without_extending_combat() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	assert_true(_player.try_melee_attack())
	assert_eq(_legacy_visual.animation_name, PlayerVisual.MELEE_ANIMATION)
	_presentation._process(0.0)
	assert_eq(display.texture, PlayerHdPresentation.MELEE_ATLAS_TEXTURE)
	_presentation._process(_player.melee_duration)
	assert_eq(display.texture, HD_ATLAS)


func test_dash_body_atlas_has_four_distinct_upright_cardinal_phases() -> void:
	var dash_atlas: Texture2D = load(DASH_ATLAS_PATH) as Texture2D
	assert_not_null(dash_atlas, "Issue #195 requires a dedicated HD body dash atlas.")
	if dash_atlas == null:
		return
	assert_eq(Vector2i(dash_atlas.get_width(), dash_atlas.get_height()), Vector2i(1024, 1024))
	var image: Image = dash_atlas.get_image()
	for row: int in PlayerHdPresentation.DASH_DIRECTION_ROWS.size():
		var regions: Array[Rect2i] = []
		for column: int in 4:
			var region := Rect2i(column * 256, row * 256, 256, 256)
			regions.append(region)
			var bounds: Rect2i = _opaque_bounds(image, region)
			assert_gt(bounds.size.y, bounds.size.x,
				"Every dash phase must retain an upright top-down human silhouette.")
		for column: int in 3:
			assert_gt(
				_alpha_mask_difference(image, regions[column], regions[column + 1]),
				400,
				"Adjacent dash phases must remain visibly distinct.",
			)


func test_dash_body_uses_four_phases_and_returns_at_existing_dash_window() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var directions: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
	for direction: Vector2 in directions:
		_legacy_visual.play_dash(direction)
		_presentation._process(0.0)
		assert_eq(display.texture, PlayerHdPresentation.DASH_ATLAS_TEXTURE)
		for column: int in 4:
			assert_eq(display.region_rect, _presentation._dash_atlas_region_for(
				_legacy_visual.facing_label, column))
			_presentation._process(PlayerHdPresentation.DASH_PHASE_SECONDS)
		assert_eq(display.texture, HD_ATLAS,
			"Dash body must return at the existing 0.14-second movement boundary.")
		_legacy_visual._on_clip_finished()
	assert_almost_eq(PlayerHdPresentation.DASH_WINDOW_SECONDS, _player.dash_duration, 0.0001)


func test_real_player_dash_event_drives_body_pose_without_changing_movement_contract() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var dash_speed_before: float = _player.dash_speed
	var dash_duration_before: float = _player.dash_duration
	_player._movement.update(Vector2.RIGHT, true, 0.0)
	assert_eq(_legacy_visual.animation_name, PlayerVisual.DASH_ANIMATION)
	_presentation._process(0.0)
	assert_eq(display.texture, PlayerHdPresentation.DASH_ATLAS_TEXTURE)
	assert_eq(_player._movement.state, PlayerMovementStateMachine.State.DASH)
	assert_eq(_player.dash_speed, dash_speed_before)
	assert_eq(_player.dash_duration, dash_duration_before)


func test_relic_body_atlas_has_three_authored_cardinal_cast_poses() -> void:
	var relic_atlas: Texture2D = load(RELIC_ATLAS_PATH) as Texture2D
	assert_not_null(relic_atlas, "Issue #193 requires a dedicated HD body relic atlas.")
	if relic_atlas == null:
		return
	var file: FileAccess = FileAccess.open(RELIC_ATLAS_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
	file.close()
	assert_eq(Vector2i(relic_atlas.get_width(), relic_atlas.get_height()), Vector2i(768, 1024))
	var image: Image = relic_atlas.get_image()
	for row: int in PlayerHdPresentation.RELIC_DIRECTION_ROWS.size():
		var charge: int = _opaque_pixel_count(image, Rect2i(0, row * 256, 256, 256))
		var release: int = _opaque_pixel_count(image, Rect2i(256, row * 256, 256, 256))
		var recovery: int = _opaque_pixel_count(image, Rect2i(512, row * 256, 256, 256))
		assert_gt(charge, 0, "Each facing needs a charge pose.")
		assert_gt(release, 0, "Each facing needs a release pose.")
		assert_gt(recovery, 0, "Each facing needs a recovery pose.")
		assert_ne(charge, release, "Release must be a new silhouette, not a relabeled charge cell.")


func test_relic_body_uses_charge_release_recovery_and_returns_at_existing_clip_window() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var directions: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for direction: Vector2 in directions:
		_legacy_visual.play_relic(direction)
		_presentation._process(0.0)
		assert_eq(display.texture, PlayerHdPresentation.RELIC_ATLAS_TEXTURE)
		assert_eq(display.region_rect, _presentation._relic_atlas_region_for(
			_legacy_visual.facing_label, PlayerHdPresentation.RELIC_CHARGE_COLUMN))
		_presentation._process(PlayerHdPresentation.RELIC_CHARGE_SECONDS)
		assert_eq(display.region_rect, _presentation._relic_atlas_region_for(
			_legacy_visual.facing_label, PlayerHdPresentation.RELIC_RELEASE_COLUMN))
		_presentation._process(PlayerHdPresentation.RELIC_RELEASE_SECONDS)
		assert_eq(display.region_rect, _presentation._relic_atlas_region_for(
			_legacy_visual.facing_label, PlayerHdPresentation.RELIC_RECOVERY_COLUMN))
		_presentation._process(PlayerHdPresentation.RELIC_RECOVERY_SECONDS)
		assert_eq(display.texture, HD_ATLAS)
		_legacy_visual._on_clip_finished()


func test_real_player_relic_event_drives_body_pose_without_changing_bolt_contract() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var energy_before: float = _player.energy.current_energy
	assert_true(_player.try_relic_ability())
	assert_eq(_legacy_visual.animation_name, PlayerVisual.RELIC_ANIMATION)
	_presentation._process(0.0)
	assert_eq(display.texture, PlayerHdPresentation.RELIC_ATLAS_TEXTURE)
	_presentation._process(PlayerHdPresentation.RELIC_WINDOW_SECONDS)
	assert_eq(display.texture, HD_ATLAS)
	assert_eq(_player.energy.current_energy, energy_before - _player.energy_bolt_cost)
	assert_eq(_player.energy_bolt_damage, 1)


func _minimum_aligned_alpha_mask_difference(
	image: Image, first: Rect2i, second: Rect2i
) -> int:
	var first_points: Array[Vector2i] = _substantive_alpha_points(image, first)
	var second_points: Array[Vector2i] = _substantive_alpha_points(image, second)
	var first_center: Vector2 = _point_centroid(first_points)
	var second_center: Vector2 = _point_centroid(second_points)
	var estimated_shift := Vector2i(
		roundi(first_center.x - second_center.x),
		roundi(first_center.y - second_center.y),
	)
	var local_bounds := Rect2i(Vector2i.ZERO, first.size)
	var minimum_difference: int = first.size.x * first.size.y
	for search_y: int in range(-ALIGNMENT_SEARCH_RADIUS, ALIGNMENT_SEARCH_RADIUS + 1):
		for search_x: int in range(-ALIGNMENT_SEARCH_RADIUS, ALIGNMENT_SEARCH_RADIUS + 1):
			var shift: Vector2i = estimated_shift + Vector2i(search_x, search_y)
			var intersection: int = 0
			for point: Vector2i in first_points:
				var second_point: Vector2i = point - shift
				if local_bounds.has_point(second_point):
					if image.get_pixelv(second.position + second_point).a > SUBSTANTIVE_ALPHA_CUTOFF:
						intersection += 1
			var shifted_second_count: int = 0
			for point: Vector2i in second_points:
				if local_bounds.has_point(point + shift):
					shifted_second_count += 1
			var difference: int = first_points.size() + shifted_second_count - 2 * intersection
			minimum_difference = mini(minimum_difference, difference)
	return minimum_difference


func _substantive_alpha_points(image: Image, region: Rect2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for y: int in region.size.y:
		for x: int in region.size.x:
			if image.get_pixel(region.position.x + x, region.position.y + y).a > SUBSTANTIVE_ALPHA_CUTOFF:
				points.append(Vector2i(x, y))
	return points


func _point_centroid(points: Array[Vector2i]) -> Vector2:
	var total := Vector2.ZERO
	for point: Vector2i in points:
		total += Vector2(point)
	return total / float(points.size())


func _alpha_mask_difference(image: Image, first: Rect2i, second: Rect2i) -> int:
	var difference: int = 0
	for y: int in first.size.y:
		for x: int in first.size.x:
			var offset := Vector2i(x, y)
			var first_opaque: bool = image.get_pixelv(first.position + offset).a > 0.05
			var second_opaque: bool = image.get_pixelv(second.position + offset).a > 0.05
			if first_opaque != second_opaque:
				difference += 1
	return difference


func _opaque_bounds(image: Image, region: Rect2i) -> Rect2i:
	var minimum: Vector2i = region.end
	var maximum: Vector2i = region.position
	var found: bool = false
	for y: int in region.size.y:
		for x: int in region.size.x:
			var point: Vector2i = region.position + Vector2i(x, y)
			if image.get_pixelv(point).a <= 0.05:
				continue
			found = true
			minimum.x = mini(minimum.x, point.x)
			minimum.y = mini(minimum.y, point.y)
			maximum.x = maxi(maximum.x, point.x)
			maximum.y = maxi(maximum.y, point.y)
	if not found:
		return Rect2i(region.position, Vector2i.ZERO)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _opaque_pixel_count(image: Image, region: Rect2i) -> int:
	var count: int = 0
	for y: int in region.size.y:
		for x: int in region.size.x:
			if image.get_pixel(region.position.x + x, region.position.y + y).a > 0.0:
				count += 1
	return count


func test_hd_presentation_mirrors_move_state_with_presentation_only_gait() -> void:
	_legacy_visual.set_facing_direction(Vector2.LEFT)
	_legacy_visual.play_move()
	_presentation._process(0.2)

	var display: Sprite2D = _presentation.get_display_sprite()
	assert_eq(_legacy_visual.animation_name, PlayerVisual.MOVE_ANIMATION)
	assert_ne(display.position.y, PlayerHdPresentation.BODY_POSITION.y,
		"Move state adds presentation-only bob.")
	assert_ne(display.rotation, 0.0, "Move state adds a subtle presentation-only lean.")


func test_hd_presentation_has_unambiguous_state_driven_four_direction_feedback() -> void:
	var accent: Polygon2D = _presentation.get_node("FacingAccent") as Polygon2D
	var direction_expectations: Array[Array] = [
		[Vector2.UP, 0.0], [Vector2.RIGHT, PI * 0.5],
		[Vector2.DOWN, PI], [Vector2.LEFT, -PI * 0.5],
	]
	for expectation: Array in direction_expectations:
		_legacy_visual.set_facing_direction(expectation[0] as Vector2)
		_legacy_visual.play_move()
		_presentation._process(0.0)
		assert_almost_eq(accent.rotation, expectation[1] as float, 0.01)
	_legacy_visual.play_melee(Vector2.UP)
	_presentation._process(0.0)
	assert_eq(accent.color, PlayerHdPresentation.ACTION_FACING_ACCENT_COLOR)
	_legacy_visual._on_clip_finished()
	_legacy_visual.play_dash(Vector2.DOWN)
	_presentation._process(0.0)
	assert_eq(accent.color, PlayerHdPresentation.ACTION_FACING_ACCENT_COLOR)
	_legacy_visual.play_relic(Vector2.LEFT)
	_presentation._process(0.0)
	assert_eq(accent.color, PlayerHdPresentation.ACTION_FACING_ACCENT_COLOR)


func test_hd_presentation_changes_pose_without_changing_player_collision() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	var base_scale: Vector2 = display.scale
	var collision: CollisionShape2D = _player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D

	_legacy_visual.play_dash(Vector2.RIGHT)
	_presentation._process(0.0)
	assert_gt(display.scale.y, base_scale.y)
	assert_eq(capsule.radius, 7.0)
	assert_eq(capsule.height, 20.0)


func test_hd_presentation_hurt_and_death_follow_existing_health_driver() -> void:
	var display: Sprite2D = _presentation.get_display_sprite()
	_legacy_visual._on_health_damaged(1, Vector2.ZERO, 0)
	_presentation._process(0.0)
	assert_eq(display.self_modulate, PlayerHdPresentation.HURT_TINT)

	_legacy_visual.set_facing_direction(Vector2.LEFT)
	_legacy_visual._on_health_died()
	_presentation._process(0.0)
	assert_almost_eq(display.rotation, deg_to_rad(-90.0), 0.01)
	assert_eq(display.self_modulate, PlayerHdPresentation.DEAD_TINT)
