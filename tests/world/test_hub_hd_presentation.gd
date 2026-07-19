extends GutTest
## Structural coverage for issue #151's presentation-only illustrated Hub layer.

const HUB_SCENE: PackedScene = preload("res://scenes/world/hub.tscn")
const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/sprites/hd_hub/hub_settlement_background.png")


func test_hub_uses_the_illustrated_plate_without_changing_legacy_collision() -> void:
	var hub: Hub = HUB_SCENE.instantiate() as Hub
	add_child_autofree(hub)

	var presentation: HubHdPresentation = hub.get_node("HubHdPresentation") as HubHdPresentation
	var floor: TileMapLayer = hub.get_node("FloorWalls") as TileMapLayer
	var background: Sprite2D = presentation.get_background()

	assert_not_null(presentation)
	assert_not_null(background)
	assert_eq(background.texture, BACKGROUND_TEXTURE)
	assert_eq(background.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(background.region_rect, HubHdPresentation.SOURCE_REGION)
	assert_eq(background.position, HubHdPresentation.HUB_DISPLAY_SIZE * 0.5)
	assert_false(floor.visible, "The collision TileMapLayer remains present but its legacy art is covered.")
	assert_eq(floor.get_used_cells().size(), Hub.HUB_SIZE_TILES.x * Hub.HUB_SIZE_TILES.y)


func test_hd_background_does_not_replace_live_hub_affordance_nodes() -> void:
	var hub: Hub = HUB_SCENE.instantiate() as Hub
	add_child_autofree(hub)

	assert_not_null(hub.get_node("Checkpoint") as Checkpoint)
	assert_not_null(hub.get_node("SkillTreeStation") as SkillTreeStation)
	assert_not_null(hub.get_node("GateZone") as InteractableZone)
	assert_not_null(hub.get_node("GateVisual") as Polygon2D)
