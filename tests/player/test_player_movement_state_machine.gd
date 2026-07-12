extends GutTest

const MOVE_SPEED: float = 100.0
const ACCELERATION: float = 500.0
const FRICTION: float = 1000.0
const DASH_SPEED: float = 300.0
const DASH_DURATION: float = 0.2
const DASH_COOLDOWN: float = 0.5

var _movement: PlayerMovementStateMachine


func before_each() -> void:
	_movement = PlayerMovementStateMachine.new(
		MOVE_SPEED,
		ACCELERATION,
		FRICTION,
		DASH_SPEED,
		DASH_DURATION,
		DASH_COOLDOWN
	)
	watch_signals(_movement)


func test_accelerates_into_free_angle_movement_and_friction_stops() -> void:
	var direction: Vector2 = Vector2(1.0, 1.0).normalized()
	_movement.update(direction, false, 0.1)

	assert_eq(_movement.state, PlayerMovementStateMachine.State.MOVE)
	assert_almost_eq(_movement.velocity.length(), 50.0, 0.001)
	assert_almost_eq(_movement.velocity.normalized().distance_to(direction), 0.0, 0.001)

	_movement.update(Vector2.ZERO, false, 0.1)

	assert_eq(_movement.state, PlayerMovementStateMachine.State.IDLE)
	assert_eq(_movement.velocity, Vector2.ZERO)


func test_dash_uses_fixed_speed_and_duration_then_ends() -> void:
	_movement.update(Vector2.RIGHT, true, 0.01)

	assert_eq(_movement.state, PlayerMovementStateMachine.State.DASH)
	assert_eq(_movement.velocity, Vector2.RIGHT * DASH_SPEED)
	assert_signal_emitted(_movement, "dash_started")

	_movement.update(Vector2.RIGHT, false, DASH_DURATION)
	_movement.finish_frame(Vector2.RIGHT)

	assert_eq(_movement.state, PlayerMovementStateMachine.State.MOVE)
	assert_eq(_movement.velocity, Vector2.RIGHT * MOVE_SPEED)
	assert_signal_emitted(_movement, "dash_ended")


func test_dash_cooldown_rejects_spam_until_elapsed() -> void:
	_movement.update(Vector2.RIGHT, true, 0.0)
	_movement.update(Vector2.RIGHT, false, DASH_DURATION)
	_movement.finish_frame(Vector2.RIGHT)
	_movement.update(Vector2.RIGHT, true, 0.0)

	assert_eq(_movement.state, PlayerMovementStateMachine.State.MOVE)
	assert_signal_emit_count(_movement, "dash_started", 1)

	_movement.update(Vector2.RIGHT, false, DASH_COOLDOWN - DASH_DURATION)
	_movement.update(Vector2.RIGHT, true, 0.0)

	assert_eq(_movement.state, PlayerMovementStateMachine.State.DASH)
	assert_signal_emit_count(_movement, "dash_started", 2)


func test_stationary_dash_uses_last_movement_direction() -> void:
	_movement.update(Vector2.LEFT, false, 1.0)
	_movement.update(Vector2.ZERO, false, 1.0)
	_movement.update(Vector2.ZERO, true, 0.0)

	assert_eq(_movement.velocity, Vector2.LEFT * DASH_SPEED)


func test_dash_distance_is_independent_of_physics_delta() -> void:
	var coarse_movement: PlayerMovementStateMachine = PlayerMovementStateMachine.new(
		MOVE_SPEED,
		ACCELERATION,
		FRICTION,
		DASH_SPEED,
		DASH_DURATION,
		DASH_COOLDOWN
	)
	var coarse_delta: float = DASH_DURATION * 2.0
	coarse_movement.update(Vector2.RIGHT, true, coarse_delta)
	var coarse_distance: float = coarse_movement.velocity.x * coarse_delta

	var fine_movement: PlayerMovementStateMachine = PlayerMovementStateMachine.new(
		MOVE_SPEED,
		ACCELERATION,
		FRICTION,
		DASH_SPEED,
		DASH_DURATION,
		DASH_COOLDOWN
	)
	var fine_delta: float = DASH_DURATION / 4.0
	var fine_distance: float = 0.0
	for frame: int in range(4):
		fine_movement.update(Vector2.RIGHT, frame == 0, fine_delta)
		fine_distance += fine_movement.velocity.x * fine_delta

	var expected_distance: float = DASH_SPEED * DASH_DURATION
	assert_almost_eq(coarse_distance, expected_distance, 0.001)
	assert_almost_eq(fine_distance, expected_distance, 0.001)


func test_cancel_dash_emits_end_and_stops_motion() -> void:
	_movement.update(Vector2.RIGHT, true, 0.0)
	_movement.cancel_dash()

	assert_eq(_movement.state, PlayerMovementStateMachine.State.IDLE)
	assert_eq(_movement.velocity, Vector2.ZERO)
	assert_signal_emitted(_movement, "dash_ended")
