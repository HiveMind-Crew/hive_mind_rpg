extends GutTest
## Production presentation contract for issue #153: every v1 interactable owns
## a distinct linear-filtered HD visual on the live gameplay node, while the
## legacy polygons remain hidden and all state changes still originate from
## the existing checkpoint/proximity/collection/reveal/door mechanics.

const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/world/checkpoint.tscn")
const INTERACTABLE_ZONE_SCENE: PackedScene = preload(
	"res://scenes/world/interactable_zone.tscn"
)
const PICKUP_SCENE: PackedScene = preload("res://scenes/world/skill_point_pickup.tscn")
const STATION_SCENE: PackedScene = preload("res://scenes/world/skill_tree_station.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")
const REVEAL_SCRIPT: Script = preload("res://scripts/world/hidden_room_reveal.gd")

const TEST_SAVE_PATH: String = "user://test_hd_interactable_presentation.json"
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

const EXPECTED_ASSET_DIMENSIONS: Dictionary[String, Vector2i] = {
	"res://assets/sprites/world/hd/interactables/checkpoint.png": Vector2i(384, 384),
	"res://assets/sprites/world/hd/interactables/travel_gate.png": Vector2i(256, 384),
	"res://assets/sprites/world/hd/interactables/skill_point_pickup.png": Vector2i(256, 256),
	"res://assets/sprites/world/hd/interactables/skill_tree_station.png": Vector2i(256, 384),
	"res://assets/sprites/world/hd/interactables/boss_door.png": Vector2i(256, 384),
	"res://assets/sprites/world/hd/interactables/secret_reveal.png": Vector2i(256, 256),
}


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.collected_secret_ids.clear()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func after_each() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	SaveManager.collected_secret_ids.clear()
	GameState.reset_progress()


func _player_body() -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"player")
	add_child_autofree(body)
	return body


func test_assets_are_real_pngs_with_production_import_settings() -> void:
	for asset_path: String in EXPECTED_ASSET_DIMENSIONS:
		var file: FileAccess = FileAccess.open(asset_path, FileAccess.READ)
		assert_not_null(file, "Missing HD interactable asset: %s" % asset_path)
		if file == null:
			continue
		assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
		var texture: Texture2D = load(asset_path) as Texture2D
		assert_not_null(texture)
		assert_eq(
			Vector2i(texture.get_width(), texture.get_height()),
			EXPECTED_ASSET_DIMENSIONS[asset_path]
		)
		var import_text: String = FileAccess.get_file_as_string(asset_path + ".import")
		assert_string_contains(import_text, "compress/mode=0")
		assert_string_contains(import_text, "mipmaps/generate=false")
		assert_string_contains(import_text, "process/premult_alpha=false")
		assert_string_contains(import_text, "process/fix_alpha_border=true")


func test_checkpoint_visual_follows_the_live_lit_state() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	add_child_autofree(checkpoint)
	var sprite: Sprite2D = checkpoint.get_hd_visual()

	assert_false((checkpoint.get_node("Visual") as Polygon2D).visible)
	assert_eq(sprite.get_parent(), checkpoint)
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_almost_eq(
		float(sprite.texture.get_height()) * sprite.scale.y,
		Checkpoint.HD_VISUAL_HEIGHT_PX,
		0.01
	)
	assert_eq(sprite.modulate, checkpoint.dormant_color)

	checkpoint.body_entered.emit(_player_body())
	assert_true(checkpoint.is_lit())
	assert_eq(sprite.modulate, checkpoint.lit_color)


func test_gate_visual_follows_proximity_without_changing_the_sensor() -> void:
	var zone: InteractableZone = INTERACTABLE_ZONE_SCENE.instantiate() as InteractableZone
	add_child_autofree(zone)
	var sprite: Sprite2D = zone.get_hd_visual()
	var original_shape: Shape2D = (zone.get_node("CollisionShape2D") as CollisionShape2D).shape

	assert_not_null(sprite)
	assert_eq(sprite.get_parent(), zone)
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(sprite.modulate, Color.WHITE)

	zone.body_entered.emit(_player_body())
	assert_true(zone.is_player_nearby())
	assert_eq(sprite.modulate, InteractableZone.NEARBY_MODULATE)
	assert_eq((zone.get_node("CollisionShape2D") as CollisionShape2D).shape, original_shape)


func test_station_owns_its_visual_and_suppresses_the_generic_gate_body() -> void:
	var rig: Node2D = Node2D.new()
	add_child_autofree(rig)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	rig.add_child(player)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ScreenLayer"
	rig.add_child(layer)
	var station: SkillTreeStation = STATION_SCENE.instantiate() as SkillTreeStation
	station.player_path = NodePath("../Player")
	station.screen_layer_path = NodePath("../ScreenLayer")
	rig.add_child(station)

	var station_sprite: Sprite2D = station.get_hd_visual()
	var interaction_zone: InteractableZone = station.get_node("InteractionZone") as InteractableZone
	assert_false((station.get_node("StationVisual") as Polygon2D).visible)
	assert_not_null(station_sprite)
	assert_eq(station_sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_false(interaction_zone.show_gate_visual)
	assert_null(interaction_zone.get_hd_visual())


func test_pickup_and_secret_reveal_use_distinct_live_feedback() -> void:
	var pickup: SkillPointPickup = PICKUP_SCENE.instantiate() as SkillPointPickup
	pickup.secret_id = &"hd_presentation_pickup"
	add_child_autofree(pickup)
	assert_false((pickup.get_node("Visual") as Polygon2D).visible)
	assert_eq(pickup.get_hd_visual().texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)

	var reveal: HiddenRoomReveal = REVEAL_SCRIPT.new() as HiddenRoomReveal
	var cover: Polygon2D = Polygon2D.new()
	cover.name = "Cover"
	reveal.add_child(cover)
	add_child_autofree(reveal)
	var feedback: Sprite2D = reveal.get_reveal_feedback()
	assert_false(feedback.visible)
	assert_ne(feedback.texture.resource_path, pickup.get_hd_visual().texture.resource_path)

	reveal.body_entered.emit(_player_body())
	assert_true(reveal.is_revealed())
	assert_false(cover.visible)
	assert_true(feedback.visible)
	await wait_seconds(HiddenRoomReveal.REVEAL_DURATION_SECONDS + 0.05)
	assert_false(feedback.visible)


func test_boss_door_visual_is_owned_by_the_real_blocking_body() -> void:
	var zone: Zone1Graybox = ZONE_SCENE.instantiate() as Zone1Graybox
	add_child_autofree(zone)
	var door: StaticBody2D = zone.get_node("BossDoor") as StaticBody2D
	var sprite: Sprite2D = door.get_node("DoorHdVisual") as Sprite2D
	var shape: CollisionShape2D = door.get_node("CollisionShape2D") as CollisionShape2D

	assert_false((door.get_node("DoorVisual") as Polygon2D).visible)
	assert_eq(sprite.get_parent(), door)
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_false(shape.disabled)

	zone.open_boss_door()
	await wait_physics_frames(1)
	assert_false(door.visible)
	assert_true(shape.disabled)
