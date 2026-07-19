class_name HubHdPresentation
extends Node2D
## Presentation-only painted Hub plate for issue #151. The legacy TileMapLayer
## remains in the tree for collision and bounds; live shrine, station, and gate
## nodes remain separate so the background never invents interactions.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/sprites/hd_hub/hub_settlement_background.png")
const CHECKPOINT_TEXTURE: Texture2D = preload("res://assets/sprites/hd_prototype/checkpoint_shrine.png")
const SOURCE_REGION: Rect2 = Rect2(128.0, 67.0, 768.0, 442.0)
const HUB_DISPLAY_SIZE: Vector2 = Vector2(640.0, 368.0)

@export var legacy_floor_path: NodePath
@export var checkpoint_path: NodePath
@export var station_path: NodePath
@export var gate_visual_path: NodePath

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
	_background.scale = HUB_DISPLAY_SIZE / SOURCE_REGION.size
	add_child(_background)
	_replace_live_prop_visuals()


func _replace_live_prop_visuals() -> void:
	var checkpoint: Checkpoint = get_node_or_null(checkpoint_path) as Checkpoint
	var station: Node2D = get_node_or_null(station_path) as Node2D
	var legacy_gate: Polygon2D = get_node_or_null(gate_visual_path) as Polygon2D
	if checkpoint != null:
		_install_checkpoint_visual(checkpoint)
	if station != null:
		_install_station_visual(station)
	if legacy_gate != null:
		_install_gate_visual(legacy_gate)


func _install_checkpoint_visual(checkpoint: Checkpoint) -> void:
	var legacy_visual: Polygon2D = checkpoint.get_node("Visual") as Polygon2D
	legacy_visual.visible = false
	var shrine: Sprite2D = Sprite2D.new()
	shrine.name = "HdShrine"
	shrine.texture = CHECKPOINT_TEXTURE
	shrine.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shrine.scale = Vector2.ONE * (44.0 / float(CHECKPOINT_TEXTURE.get_height()))
	shrine.position = checkpoint.position + Vector2(0.0, -9.0)
	add_child(shrine)
	checkpoint.checkpoint_reached.connect(func(_respawn_position: Vector2) -> void: shrine.modulate = Color(0.72, 1.0, 0.82, 1.0))


func _install_station_visual(station: Node2D) -> void:
	(station.get_node("StationVisual") as Polygon2D).visible = false
	var glyph: Polygon2D = Polygon2D.new()
	glyph.name = "HdStationGlyph"
	glyph.polygon = PackedVector2Array([Vector2(0, -22), Vector2(17, 0), Vector2(0, 22), Vector2(-17, 0)])
	glyph.color = Color(0.18, 0.72, 0.72, 1.0)
	glyph.position = station.position
	add_child(glyph)


func _install_gate_visual(legacy_gate: Polygon2D) -> void:
	legacy_gate.visible = false
	var gate: Polygon2D = Polygon2D.new()
	gate.name = "HdGateArch"
	gate.polygon = PackedVector2Array([Vector2(-15, 26), Vector2(-15, -24), Vector2(0, -38), Vector2(15, -24), Vector2(15, 26), Vector2(8, 26), Vector2(8, -20), Vector2(0, -29), Vector2(-8, -20), Vector2(-8, 26)])
	gate.color = Color(0.56, 0.22, 0.68, 1.0)
	gate.position = legacy_gate.position
	add_child(gate)


func get_background() -> Sprite2D:
	return _background
