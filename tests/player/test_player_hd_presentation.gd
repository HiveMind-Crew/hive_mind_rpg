extends GutTest
## Structural and state-mirroring coverage for the presentation-only HD player
## layer (issues #150/#165). PlayerVisual remains the logical animation/state
## owner; the HD body is a four-cell directional atlas selected by facing_label.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ATLAS_PATH: String = "res://assets/sprites/player/hd/player_directional_atlas.png"
const HD_ATLAS: Texture2D = preload("res://assets/sprites/player/hd/player_directional_atlas.png")
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
	var direction_expectations: Array[Array] = [
		[Vector2.UP, 0], [Vector2.RIGHT, 1], [Vector2.DOWN, 2], [Vector2.LEFT, 3],
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
