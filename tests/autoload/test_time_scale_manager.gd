extends GutTest


func before_each() -> void:
	TimeScaleManager.reset()


func after_each() -> void:
	TimeScaleManager.reset()


func test_modifier_slows_the_base_time_scale_until_released() -> void:
	TimeScaleManager.set_base_time_scale(0.75)
	var token: int = TimeScaleManager.acquire_modifier(0.5)

	assert_eq(Engine.time_scale, 0.5)
	assert_eq(TimeScaleManager.get_modifier_count(), 1)

	assert_true(TimeScaleManager.release_modifier(token))
	assert_eq(Engine.time_scale, 0.75)
	assert_eq(TimeScaleManager.get_modifier_count(), 0)


func test_base_change_to_same_scale_survives_modifier_release() -> void:
	var token: int = TimeScaleManager.acquire_modifier(0.5)

	TimeScaleManager.set_base_time_scale(0.5)
	assert_eq(Engine.time_scale, 0.5)

	TimeScaleManager.release_modifier(token)
	assert_eq(Engine.time_scale, 0.5)


func test_multiple_modifiers_use_the_strongest_slowdown() -> void:
	var first_token: int = TimeScaleManager.acquire_modifier(0.5)
	var second_token: int = TimeScaleManager.acquire_modifier(0.1)

	assert_eq(Engine.time_scale, 0.1)

	TimeScaleManager.release_modifier(second_token)
	assert_eq(Engine.time_scale, 0.5)

	TimeScaleManager.release_modifier(first_token)
	assert_eq(Engine.time_scale, 1.0)


func test_unknown_modifier_token_is_rejected_without_changing_scale() -> void:
	TimeScaleManager.set_base_time_scale(0.75)

	assert_false(TimeScaleManager.release_modifier(TimeScaleManager.INVALID_TOKEN))
	assert_eq(Engine.time_scale, 0.75)
