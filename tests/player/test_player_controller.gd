extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: PlayerController
var _hurtbox: Hurtbox


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_hurtbox = _player.get_node("Hurtbox") as Hurtbox


func test_dash_toggles_hurtbox_for_iframe_window() -> void:
	_player._movement.update(Vector2.RIGHT, true, 0.0)

	assert_false(_hurtbox.enabled)

	_player._movement.update(Vector2.RIGHT, false, _player.dash_duration)
	_player._movement.finish_frame(Vector2.RIGHT)

	assert_true(_hurtbox.enabled)


func test_cancel_dash_restores_hurtbox() -> void:
	_player._movement.update(Vector2.RIGHT, true, 0.0)
	_player.cancel_dash()

	assert_true(_hurtbox.enabled)
