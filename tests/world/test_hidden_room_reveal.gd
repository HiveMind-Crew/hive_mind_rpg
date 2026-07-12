extends GutTest
## Coverage for HiddenRoomReveal (issue #24): only a player-group body hides
## the cover, the reveal is a one-shot, and a missing cover degrades to a
## warning instead of a crash.

const REVEAL_SCRIPT := preload("res://scripts/world/hidden_room_reveal.gd")


func _build_reveal(with_cover: bool = true) -> HiddenRoomReveal:
	var reveal: HiddenRoomReveal = REVEAL_SCRIPT.new()
	if with_cover:
		var cover: Polygon2D = Polygon2D.new()
		cover.name = "Cover"
		reveal.add_child(cover)
	add_child_autofree(reveal)
	return reveal


func _player_body() -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"player")
	add_child_autofree(body)
	return body


func test_player_entry_hides_cover_and_signals() -> void:
	var reveal: HiddenRoomReveal = _build_reveal()
	watch_signals(reveal)

	reveal.body_entered.emit(_player_body())

	assert_true(reveal.is_revealed())
	assert_false((reveal.get_node("Cover") as CanvasItem).visible)
	assert_signal_emit_count(reveal, "room_revealed", 1)


func test_non_player_body_keeps_room_hidden() -> void:
	var reveal: HiddenRoomReveal = _build_reveal()
	watch_signals(reveal)
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(body)

	reveal.body_entered.emit(body)

	assert_false(reveal.is_revealed())
	assert_true((reveal.get_node("Cover") as CanvasItem).visible)
	assert_signal_emit_count(reveal, "room_revealed", 0)


func test_reveal_is_a_one_shot() -> void:
	var reveal: HiddenRoomReveal = _build_reveal()
	watch_signals(reveal)
	var body: CharacterBody2D = _player_body()

	reveal.body_entered.emit(body)
	reveal.body_entered.emit(body)

	assert_signal_emit_count(reveal, "room_revealed", 1)


func test_missing_cover_warns_but_still_reveals() -> void:
	var reveal: HiddenRoomReveal = _build_reveal(false)
	watch_signals(reveal)

	reveal.body_entered.emit(_player_body())

	assert_push_warning("found no cover")
	assert_true(reveal.is_revealed())
	assert_signal_emit_count(reveal, "room_revealed", 1)
