class_name PlayerVisual
extends Sprite2D

## Selects authored directional frames; the player never rotates as a substitute
## for facing animation.
signal animation_changed(animation_name: StringName)

enum Direction { SOUTH, NORTH, EAST, WEST }

const IDLE_ANIMATION: StringName = &"idle"
const MOVE_ANIMATION: StringName = &"move"
const DASH_ANIMATION: StringName = &"dash"
const MELEE_ANIMATION: StringName = &"melee"
const RELIC_ANIMATION: StringName = &"relic"

@export var front_idle: Texture2D
@export var front_move: Texture2D
@export var front_attack: Texture2D
@export var back_idle: Texture2D
@export var back_move: Texture2D
@export var back_attack: Texture2D
@export var side_idle: Texture2D
@export var side_move: Texture2D
@export var side_attack: Texture2D
@export var walk_south_0: Texture2D
@export var walk_south_1: Texture2D
@export var walk_south_2: Texture2D
@export var walk_south_3: Texture2D
@export var walk_north_0: Texture2D
@export var walk_north_1: Texture2D
@export var walk_north_2: Texture2D
@export var walk_north_3: Texture2D
@export var walk_east_0: Texture2D
@export var walk_east_1: Texture2D
@export var walk_east_2: Texture2D
@export var walk_east_3: Texture2D
@export var walk_west_0: Texture2D
@export var walk_west_1: Texture2D
@export var walk_west_2: Texture2D
@export var walk_west_3: Texture2D
@export_range(0.1, 20.0, 0.1) var idle_bob_speed: float = 2.4
@export_range(0.0, 8.0, 0.1) var idle_bob_distance: float = 0.45
@export_range(0.1, 20.0, 0.1) var move_bob_speed: float = 9.0
@export_range(0.0, 8.0, 0.1) var move_bob_distance: float = 1.0
@export_range(1.0, 20.0, 0.1) var walk_frame_rate: float = 8.0
@export_range(0.01, 1.0, 0.01) var melee_animation_duration: float = 0.12
@export_range(0.01, 1.0, 0.01) var relic_animation_duration: float = 0.16

var animation_name: StringName:
	get:
		return _animation_name

var facing_label: StringName:
	get:
		match _direction:
			Direction.NORTH:
				return &"north"
			Direction.EAST:
				return &"east"
			Direction.WEST:
				return &"west"
			_:
				return &"south"

var _animation_name: StringName = IDLE_ANIMATION
var _direction: Direction = Direction.SOUTH
var _facing_direction: Vector2 = Vector2.DOWN
var _elapsed: float = 0.0
var _action_time_remaining: float = 0.0
var _base_position: Vector2
var _base_scale: Vector2


func _ready() -> void:
	_base_position = position
	_base_scale = scale


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _action_time_remaining > 0.0:
		_action_time_remaining = maxf(_action_time_remaining - maxf(delta, 0.0), 0.0)
		if _action_time_remaining <= 0.0:
			_set_animation(IDLE_ANIMATION)
	_render_animation()


func play_idle() -> void:
	if _action_time_remaining <= 0.0:
		_set_animation(IDLE_ANIMATION)


func play_move() -> void:
	if _action_time_remaining <= 0.0:
		_set_animation(MOVE_ANIMATION)


func play_dash(direction: Vector2) -> void:
	set_facing_direction(direction)
	_action_time_remaining = 0.0
	_set_animation(DASH_ANIMATION)


func play_melee(direction: Vector2) -> void:
	set_facing_direction(direction)
	_action_time_remaining = melee_animation_duration
	_set_animation(MELEE_ANIMATION)


func play_relic(direction: Vector2) -> void:
	set_facing_direction(direction)
	_action_time_remaining = relic_animation_duration
	_set_animation(RELIC_ANIMATION)


func set_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_facing_direction = direction.normalized()
	if absf(_facing_direction.x) > absf(_facing_direction.y):
		_direction = Direction.EAST if _facing_direction.x > 0.0 else Direction.WEST
	elif _facing_direction.y < 0.0:
		_direction = Direction.NORTH
	else:
		_direction = Direction.SOUTH


func _set_animation(next_animation: StringName) -> void:
	if _animation_name == next_animation:
		return
	_animation_name = next_animation
	animation_changed.emit(_animation_name)


func _render_animation() -> void:
	position = _base_position
	scale = _base_scale
	rotation = 0.0
	flip_h = false
	texture = _texture_for_animation()
	match _animation_name:
		IDLE_ANIMATION:
			position.y += sin(_elapsed * idle_bob_speed) * idle_bob_distance
		MOVE_ANIMATION:
			position.y += absf(sin(_elapsed * move_bob_speed)) * move_bob_distance
		DASH_ANIMATION:
			position -= _facing_direction * 2.5
			scale *= Vector2(1.12, 0.9)
		MELEE_ANIMATION, RELIC_ANIMATION:
			var action_duration: float = (
				melee_animation_duration if _animation_name == MELEE_ANIMATION else relic_animation_duration
			)
			var action_progress: float = 1.0 - _action_time_remaining / action_duration
			position += _facing_direction * sin(action_progress * PI) * 2.5


func _texture_for_animation() -> Texture2D:
	match _animation_name:
		MOVE_ANIMATION, DASH_ANIMATION:
			return _walk_cycle_texture()
		MELEE_ANIMATION, RELIC_ANIMATION:
			return _attack_texture()
		_:
			return _idle_texture()


func _walk_cycle_texture() -> Texture2D:
	var frame_index: int = posmod(floori(_elapsed * walk_frame_rate), 4)
	match _direction:
		Direction.NORTH:
			return _frame_from([walk_north_0, walk_north_1, walk_north_2, walk_north_3], frame_index)
		Direction.EAST:
			return _frame_from([walk_east_0, walk_east_1, walk_east_2, walk_east_3], frame_index)
		Direction.WEST:
			return _frame_from([walk_west_0, walk_west_1, walk_west_2, walk_west_3], frame_index)
		_:
			return _frame_from([walk_south_0, walk_south_1, walk_south_2, walk_south_3], frame_index)


func _idle_texture() -> Texture2D:
	match _direction:
		Direction.NORTH:
			return back_idle
		Direction.EAST:
			return side_idle
		Direction.WEST:
			# West is independently drawn; never mirror the east-facing relic.
			return walk_west_0
		_:
			return front_idle


func _attack_texture() -> Texture2D:
	match _direction:
		Direction.NORTH:
			# The relic remains occluded from the rear, including during attacks.
			return walk_north_0
		Direction.EAST:
			return side_attack
		Direction.WEST:
			return walk_west_0
		_:
			return front_attack


func _frame_from(frames: Array[Texture2D], frame_index: int) -> Texture2D:
	return frames[clampi(frame_index, 0, frames.size() - 1)]
