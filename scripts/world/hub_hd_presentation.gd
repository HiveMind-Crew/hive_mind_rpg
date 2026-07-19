class_name HubHdPresentation
extends Node2D
## Presentation-only painted Hub environment for issue #151. The existing
## TileMapLayer stays in the tree for collision/bounds and each live
## checkpoint/station/gate owns its own HD visual and interaction feedback.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/sprites/hd_hub/hub_settlement_background.png")
const SOURCE_REGION: Rect2 = Rect2(128.0, 64.0, 768.0, 442.0)
const HUB_DISPLAY_SIZE: Vector2 = Vector2(640.0, 368.0)
const UNIFORM_SCALE: float = HUB_DISPLAY_SIZE.x / SOURCE_REGION.size.x

@export var legacy_floor_path: NodePath

var _legacy_floor: TileMapLayer
var _background: Sprite2D


func _ready() -> void:
	_legacy_floor = get_node_or_null(legacy_floor_path) as TileMapLayer
	if _legacy_floor == null:
		push_error("HubHdPresentation requires the legacy FloorWalls TileMapLayer.")
		set_process(false)
		return
	_legacy_floor.visible = false
	_background = Sprite2D.new()
	_background.name = "PaintedSettlement"
	_background.texture = BACKGROUND_TEXTURE
	_background.region_enabled = true
	_background.region_rect = SOURCE_REGION
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_background.centered = true
	_background.position = HUB_DISPLAY_SIZE * 0.5
	_background.scale = Vector2.ONE * UNIFORM_SCALE
	add_child(_background)


func get_background() -> Sprite2D:
	return _background
