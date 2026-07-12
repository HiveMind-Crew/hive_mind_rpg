extends GutTest
## Coverage for the Checkpoint shrine: only player-group bodies light it and
## trigger its respawn-position report.

const CHECKPOINT_SCENE := preload("res://scenes/world/checkpoint.tscn")

var _checkpoint: Checkpoint


func before_each() -> void:
	_checkpoint = CHECKPOINT_SCENE.instantiate()
	add_child_autofree(_checkpoint)
	await wait_physics_frames(1)


func test_registers_in_the_checkpoint_group() -> void:
	assert_true(_checkpoint.is_in_group(Checkpoint.CHECKPOINT_GROUP))


func test_player_touch_lights_shrine_and_reports_respawn_position() -> void:
	watch_signals(_checkpoint)
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(_checkpoint.player_group)
	add_child_autofree(body)

	_checkpoint.body_entered.emit(body)

	assert_true(_checkpoint.is_lit())
	assert_signal_emit_count(_checkpoint, "checkpoint_reached", 1)
	assert_signal_emitted_with_parameters(
		_checkpoint, "checkpoint_reached", [_checkpoint.get_respawn_position()]
	)


func test_non_player_body_is_ignored() -> void:
	watch_signals(_checkpoint)
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(body)

	_checkpoint.body_entered.emit(body)

	assert_false(_checkpoint.is_lit())
	assert_signal_emit_count(_checkpoint, "checkpoint_reached", 0)
