class_name HiddenRoomReveal
extends Area2D
## Reveals a hidden room (issue #24): the cover CanvasItem — a wall/fog shape
## drawn over the room and whatever secret it holds — stays visible until a
## player-group body walks into this trigger, then hides. The reveal itself is
## per-session cosmetics; the pickups inside persist their own collection.

signal room_revealed()

const REVEAL_TEXTURE: Texture2D = preload(
	"res://assets/sprites/world/hd/interactables/secret_reveal.png"
)
const REVEAL_VISUAL_HEIGHT_PX: float = 48.0
const REVEAL_DURATION_SECONDS: float = 0.35
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR

@export var player_group: StringName = &"player"
## CanvasItem hidden on reveal. Defaults to a child named "Cover" so a level
## can drop the whole secret (trigger shape + cover art) in as one subtree.
@export var cover_path: NodePath = ^"Cover"

var _revealed: bool = false
var _reveal_feedback: Sprite2D
var _reveal_feedback_scale: Vector2

@onready var _cover: CanvasItem = get_node_or_null(cover_path) as CanvasItem


func _ready() -> void:
	# Actor bodies moved off the default physics layer onto PLAYER_BODY (issue
	# #128), so the inherited Area2D mask (WORLD) would never see the real
	# player (issue #136). The trigger is a pure sensor: it scans the player
	# body layer and occupies no layer itself.
	collision_layer = 0
	collision_mask = CollisionLayers.PLAYER_BODY
	_reveal_feedback = _build_reveal_feedback()
	add_child(_reveal_feedback)
	if _cover == null:
		push_warning(
			"HiddenRoomReveal '%s' found no cover CanvasItem at '%s'." % [name, cover_path]
		)
	body_entered.connect(_on_body_entered)


func is_revealed() -> bool:
	return _revealed


func get_reveal_feedback() -> Sprite2D:
	return _reveal_feedback


func _on_body_entered(body: Node2D) -> void:
	if _revealed or not body.is_in_group(player_group):
		return
	_revealed = true
	if _cover != null:
		_cover.hide()
	_play_reveal_feedback()
	room_revealed.emit()


func _build_reveal_feedback() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "RevealFeedback"
	sprite.texture = REVEAL_TEXTURE
	sprite.texture_filter = HD_TEXTURE_FILTER
	var visual_scale: float = REVEAL_VISUAL_HEIGHT_PX / float(REVEAL_TEXTURE.get_height())
	_reveal_feedback_scale = Vector2(visual_scale, visual_scale)
	sprite.scale = _reveal_feedback_scale
	sprite.hide()
	return sprite


func _play_reveal_feedback() -> void:
	_reveal_feedback.show()
	_reveal_feedback.scale = _reveal_feedback_scale * 0.65
	_reveal_feedback.self_modulate = Color.WHITE
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(
		_reveal_feedback, "scale", _reveal_feedback_scale, REVEAL_DURATION_SECONDS
	)
	tween.tween_property(
		_reveal_feedback, "self_modulate:a", 0.0, REVEAL_DURATION_SECONDS
	)
	tween.finished.connect(_reveal_feedback.hide)
