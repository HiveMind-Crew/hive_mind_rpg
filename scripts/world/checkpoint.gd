class_name Checkpoint
extends Area2D
## A shrine/beacon checkpoint (issue #18). When a body in the player group
## touches it, the shrine lights up and announces its respawn position. It
## only reports being reached — healing and respawn bookkeeping belong to the
## RespawnController, so this node never reaches up to the player or manager
## (signals up, calls down).

signal checkpoint_reached(respawn_position: Vector2)

const CHECKPOINT_GROUP: StringName = &"checkpoints"
const HD_TEXTURE: Texture2D = preload(
	"res://assets/sprites/world/hd/interactables/checkpoint.png"
)
const HD_VISUAL_HEIGHT_PX: float = 44.0
const HD_VISUAL_OFFSET: Vector2 = Vector2(0, -8)
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR

@export var player_group: StringName = &"player"
@export var dormant_color: Color = Color(0.62, 0.66, 0.68, 1.0)
@export var lit_color: Color = Color.WHITE

@onready var _legacy_visual: Polygon2D = %Visual
@onready var _respawn_point: Marker2D = %RespawnPoint

var _lit: bool = false
var _hd_visual: Sprite2D


func _ready() -> void:
	# Actor bodies moved off the default physics layer onto PLAYER_BODY (issue
	# #128), so the inherited Area2D mask (WORLD) would never see the real
	# player (issue #136). The shrine is a pure sensor: it scans the player
	# body layer and occupies no layer itself.
	collision_layer = 0
	collision_mask = CollisionLayers.PLAYER_BODY
	add_to_group(CHECKPOINT_GROUP)
	_legacy_visual.hide()
	_hd_visual = _build_hd_visual()
	add_child(_hd_visual)
	_hd_visual.modulate = dormant_color
	body_entered.connect(_on_body_entered)


func get_respawn_position() -> Vector2:
	return _respawn_point.global_position


func is_lit() -> bool:
	return _lit


func get_hd_visual() -> Sprite2D:
	return _hd_visual


func _on_body_entered(body: Node2D) -> void:
	# Re-touching re-heals and re-arms the respawn point; body_entered only
	# fires on entry, so this stays a per-visit event, not a per-frame one.
	if not body.is_in_group(player_group):
		return
	_lit = true
	_hd_visual.modulate = lit_color
	checkpoint_reached.emit(get_respawn_position())


func _build_hd_visual() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "HdVisual"
	sprite.texture = HD_TEXTURE
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.position = HD_VISUAL_OFFSET
	var visual_scale: float = HD_VISUAL_HEIGHT_PX / float(HD_TEXTURE.get_height())
	sprite.scale = Vector2(visual_scale, visual_scale)
	return sprite
