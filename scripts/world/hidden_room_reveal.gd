class_name HiddenRoomReveal
extends Area2D
## Reveals a hidden room (issue #24): the cover CanvasItem — a wall/fog shape
## drawn over the room and whatever secret it holds — stays visible until a
## player-group body walks into this trigger, then hides. The reveal itself is
## per-session cosmetics; the pickups inside persist their own collection.

signal room_revealed()

@export var player_group: StringName = &"player"
## CanvasItem hidden on reveal. Defaults to a child named "Cover" so a level
## can drop the whole secret (trigger shape + cover art) in as one subtree.
@export var cover_path: NodePath = ^"Cover"

var _revealed: bool = false

@onready var _cover: CanvasItem = get_node_or_null(cover_path) as CanvasItem


func _ready() -> void:
	if _cover == null:
		push_warning(
			"HiddenRoomReveal '%s' found no cover CanvasItem at '%s'." % [name, cover_path]
		)
	body_entered.connect(_on_body_entered)


func is_revealed() -> bool:
	return _revealed


func _on_body_entered(body: Node2D) -> void:
	if _revealed or not body.is_in_group(player_group):
		return
	_revealed = true
	if _cover != null:
		_cover.hide()
	room_revealed.emit()
