extends GutTest

const HITBOX_SCENE: PackedScene = preload("res://scenes/combat/hitbox.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

var _hitbox: Hitbox
var _hurtbox: Hurtbox


func before_each() -> void:
	_hitbox = HITBOX_SCENE.instantiate() as Hitbox
	_hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	_hitbox.damage = 3
	_hitbox.knockback_strength = 12.0
	_hitbox.global_position = Vector2.ZERO
	_hurtbox.global_position = Vector2.RIGHT
	add_child_autofree(_hitbox)
	add_child_autofree(_hurtbox)
	watch_signals(_hurtbox)


func test_disabled_hurtbox_rejects_hits_until_reenabled() -> void:
	_hurtbox.set_enabled(false)

	assert_false(_hurtbox.enabled)
	_hurtbox.receive_hit(_hitbox)
	assert_signal_not_emitted(_hurtbox, "hit_received")

	_hurtbox.set_enabled(true)

	assert_true(_hurtbox.enabled)
	_hurtbox.receive_hit(_hitbox)
	assert_signal_emitted_with_parameters(
		_hurtbox,
		"hit_received",
		[3, Vector2(12.0, 0.0)]
	)
