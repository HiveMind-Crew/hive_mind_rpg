extends GutTest

const SWING_DURATION: float = 0.2

var _melee: PlayerMeleeAttack


func before_each() -> void:
	_melee = PlayerMeleeAttack.new(SWING_DURATION)
	watch_signals(_melee)


func test_swing_starts_with_normalized_direction() -> void:
	assert_true(_melee.try_start_swing(Vector2(2.0, 0.0)))

	assert_true(_melee.is_swinging)
	assert_eq(_melee.swing_direction, Vector2.RIGHT)
	assert_signal_emitted_with_parameters(_melee, "swing_started", [Vector2.RIGHT])


func test_zero_direction_falls_back_to_previous_facing() -> void:
	_melee.try_start_swing(Vector2.ZERO)

	assert_eq(_melee.swing_direction, Vector2.DOWN)


func test_rejects_new_swing_while_swinging() -> void:
	_melee.try_start_swing(Vector2.RIGHT)

	assert_false(_melee.try_start_swing(Vector2.LEFT))
	assert_eq(_melee.swing_direction, Vector2.RIGHT)
	assert_signal_emit_count(_melee, "swing_started", 1)


func test_swing_ends_only_after_full_duration() -> void:
	_melee.try_start_swing(Vector2.RIGHT)
	_melee.update(SWING_DURATION / 2.0)

	assert_true(_melee.is_swinging)
	assert_signal_not_emitted(_melee, "swing_ended")

	_melee.update(SWING_DURATION / 2.0)

	assert_false(_melee.is_swinging)
	assert_signal_emitted(_melee, "swing_ended")


func test_each_target_registers_at_most_one_hit_per_swing() -> void:
	_melee.try_start_swing(Vector2.RIGHT)

	assert_true(_melee.register_hit(1))
	assert_false(_melee.register_hit(1))
	assert_true(_melee.register_hit(2))


func test_new_swing_resets_hit_tracking() -> void:
	_melee.try_start_swing(Vector2.RIGHT)
	_melee.register_hit(1)
	_melee.update(SWING_DURATION)
	_melee.try_start_swing(Vector2.RIGHT)

	assert_true(_melee.register_hit(1))


func test_register_hit_rejected_outside_swing() -> void:
	assert_false(_melee.register_hit(1))

	_melee.try_start_swing(Vector2.RIGHT)
	_melee.update(SWING_DURATION)

	assert_false(_melee.register_hit(1))


func test_cancel_swing_ends_immediately_and_is_idempotent() -> void:
	_melee.try_start_swing(Vector2.RIGHT)
	_melee.cancel_swing()

	assert_false(_melee.is_swinging)
	assert_signal_emitted(_melee, "swing_ended")

	_melee.cancel_swing()

	assert_signal_emit_count(_melee, "swing_ended", 1)


func test_update_outside_swing_does_not_emit_end() -> void:
	_melee.update(SWING_DURATION)

	assert_signal_not_emitted(_melee, "swing_ended")
