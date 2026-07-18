extends GutTest
## Structural and state-mirroring coverage for issue #150's presentation-only HD
## player layer. PlayerVisual remains the logical animation/state owner.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HD_TEXTURE: Texture2D = preload("res://assets/sprites/hd_prototype/player_wanderer.png")

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
	assert_eq(display.texture, HD_TEXTURE)
	assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_almost_eq(display.get_rect().size.y * display.scale.y, 34.0, 0.01)
	assert_not_null(_presentation.get_node("ContactShadow") as Polygon2D)


func test_hd_presentation_mirrors_facing_and_move_state() -> void:
	_legacy_visual.set_facing_direction(Vector2.LEFT)
	_legacy_visual.play_move()
	_presentation._process(0.2)

	var display: Sprite2D = _presentation.get_display_sprite()
	assert_true(display.flip_h)
	assert_ne(display.position.y, 2.0, "Move state adds presentation-only bob.")


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


func test_hd_presentation_death_pose_follows_existing_health_driver() -> void:
	_legacy_visual._on_health_died()
	_presentation._process(0.0)

	var display: Sprite2D = _presentation.get_display_sprite()
	assert_almost_eq(absf(display.rotation), deg_to_rad(90.0), 0.01)
	assert_eq(display.self_modulate, PlayerHdPresentation.DEAD_TINT)
