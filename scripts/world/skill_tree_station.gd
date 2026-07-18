class_name SkillTreeStation
extends Node2D
## Reusable skill-tree station prop (issue #67), extracted from the hub's
## inline wiring (#20): an interactable terminal whose zone toggles the skill
## tree screen (#16). The station owns the whole screen lifecycle — instancing
## into the exported screen layer, suspending the exported player's gameplay
## input while open, restoring it on close — so any scene that places one only
## points the two paths and listens to the lifecycle signals it cares about
## (the hub keeps its zone gate inert while the screen is open).
##
## Live-player updates need no station involvement: PlayerController already
## re-derives its stats from GameState's skill_unlocked / skills_respecced
## signals, so unlocks made on the open screen apply immediately (#17).

signal screen_opened()
signal screen_closed()

const SKILL_TREE_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/skill_tree_screen.tscn")
const HD_TEXTURE: Texture2D = preload(
	"res://assets/sprites/world/hd/interactables/skill_tree_station.png"
)
const HD_VISUAL_HEIGHT_PX: float = 52.0
const HD_VISUAL_OFFSET: Vector2 = Vector2(0, -8)
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR
const ACTIVE_MODULATE: Color = Color(0.72, 1.0, 1.0, 1.0)

## Player whose gameplay input suspends while the screen is open.
@export var player_path: NodePath
## CanvasLayer the screen instances into; must render above world content.
@export var screen_layer_path: NodePath

var _screen: SkillTreeScreen
var _hd_visual: Sprite2D

@onready var _player: PlayerController = get_node(player_path) as PlayerController
@onready var _screen_layer: CanvasLayer = get_node(screen_layer_path) as CanvasLayer
@onready var _zone: InteractableZone = %InteractionZone


func _ready() -> void:
	var legacy_visual: Polygon2D = get_node("StationVisual") as Polygon2D
	legacy_visual.hide()
	_hd_visual = _build_hd_visual()
	add_child(_hd_visual)
	move_child(_hd_visual, 0)
	_zone.interacted.connect(_on_zone_interacted)
	_zone.player_nearby_changed.connect(_on_player_nearby_changed)


func is_screen_open() -> bool:
	return _screen != null


func get_hd_visual() -> Sprite2D:
	return _hd_visual


func open_screen() -> void:
	if is_screen_open():
		return
	# Suspend gameplay input first so the opening press can never double as an
	# attack or dash behind the menu.
	_player.set_control_enabled(false)
	_screen = SKILL_TREE_SCREEN_SCENE.instantiate() as SkillTreeScreen
	_screen_layer.add_child(_screen)
	_hd_visual.modulate = ACTIVE_MODULATE
	screen_opened.emit()


func close_screen() -> void:
	if not is_screen_open():
		return
	_screen.queue_free()
	_screen = null
	_player.set_control_enabled(true)
	_hd_visual.modulate = ACTIVE_MODULATE if _zone.is_player_nearby() else Color.WHITE
	screen_closed.emit()


func _on_zone_interacted() -> void:
	if is_screen_open():
		close_screen()
	else:
		open_screen()


func _on_player_nearby_changed(nearby: bool) -> void:
	if is_screen_open():
		return
	_hd_visual.modulate = ACTIVE_MODULATE if nearby else Color.WHITE


func _build_hd_visual() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "HdVisual"
	sprite.texture = HD_TEXTURE
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.position = HD_VISUAL_OFFSET
	var visual_scale: float = HD_VISUAL_HEIGHT_PX / float(HD_TEXTURE.get_height())
	sprite.scale = Vector2(visual_scale, visual_scale)
	return sprite
