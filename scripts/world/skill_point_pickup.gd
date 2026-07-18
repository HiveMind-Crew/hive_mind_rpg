class_name SkillPointPickup
extends Area2D
## A hidden skill-point pickup (issue #24). Touching it awards its points
## through GameState and records the collection through SaveManager, which
## writes the save immediately so the reward can never be re-farmed by
## quitting before the next checkpoint. An instance whose secret_id is
## already in the loaded save frees itself before the player can see it.

signal collected(secret_id: StringName, points: int)

const PICKUP_GROUP: StringName = &"skill_point_pickups"
const HD_TEXTURE: Texture2D = preload(
	"res://assets/sprites/world/hd/interactables/skill_point_pickup.png"
)
const HD_VISUAL_HEIGHT_PX: float = 24.0
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR

## Unique per placed pickup. An empty id still grants points but cannot be
## persisted, so the pickup would respawn on every visit.
@export var secret_id: StringName = &""
@export_range(1, 10) var points: int = 1
@export var player_group: StringName = &"player"

var _collected: bool = false
var _hd_visual: Sprite2D


func _ready() -> void:
	# Actor bodies moved off the default physics layer onto PLAYER_BODY (issue
	# #128), so the inherited Area2D mask (WORLD) would never see the real
	# player (issue #136). The pickup is a pure sensor: it scans the player
	# body layer and occupies no layer itself.
	collision_layer = 0
	collision_mask = CollisionLayers.PLAYER_BODY
	add_to_group(PICKUP_GROUP)
	var legacy_visual: Polygon2D = get_node("Visual") as Polygon2D
	legacy_visual.hide()
	_hd_visual = _build_hd_visual()
	add_child(_hd_visual)
	if secret_id == StringName():
		push_warning(
			"SkillPointPickup '%s' has no secret_id; it will respawn on every visit." % name
		)
	elif SaveManager.is_secret_collected(secret_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func is_collected() -> bool:
	return _collected


func get_hd_visual() -> Sprite2D:
	return _hd_visual


func _on_body_entered(body: Node2D) -> void:
	# body_entered can re-fire while queue_free is still pending, so the flag
	# keeps the payout a one-shot.
	if _collected or not body.is_in_group(player_group):
		return
	_collected = true
	GameState.award_skill_points(points)
	if secret_id != StringName():
		SaveManager.record_secret_collected(secret_id)
	collected.emit(secret_id, points)
	queue_free()


func _build_hd_visual() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "HdVisual"
	sprite.texture = HD_TEXTURE
	sprite.texture_filter = HD_TEXTURE_FILTER
	var visual_scale: float = HD_VISUAL_HEIGHT_PX / float(HD_TEXTURE.get_height())
	sprite.scale = Vector2(visual_scale, visual_scale)
	return sprite
