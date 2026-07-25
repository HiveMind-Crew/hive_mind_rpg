extends GutTest
## Structural and state-mirroring coverage for the presentation-only HD player
## layer (issues #150/#165). PlayerVisual remains the logical animation/state
## owner; the HD body is a four-cell directional atlas selected by facing_label.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ATLAS_PATH: String = "res://assets/sprites/player/hd/player_directional_atlas.png"
const HD_ATLAS: Texture2D = preload("res://assets/sprites/player/hd/player_directional_atlas.png")
const MELEE_ATLAS_PATH: String = "res://assets/sprites/player/hd/player_melee_body_atlas.png"
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

var _player: PlayerController
var _legacy_visual: PlayerVisual
var _presentation: PlayerHdPresentation


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_legacy_visual = _player.get_node("Body") as PlayerVisual
	_presentation = _player.get_node("HdPresentation") as PlayerHdPresentation


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
		var windup: int = _opaque_pixel_count(image, Rect2i(0, row * 256, 256, 256))
		var contact: int = _opaque_pixel_count(image, Rect2i(256, row * 256, 256, 256))
		var recovery: int = _opaque_pixel_count(image, Rect2i(512, row * 256, 256, 256))
		assert_gt(windup, 0, "Each facing needs an authored body/arm wind-up silhouette.")
		assert_gt(contact, windup, "Contact must visibly extend the body/arms into the strike.")
		assert_gt(recovery, 0, "Recovery must remain an authored pose, not a static-body pop.")


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
