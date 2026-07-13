extends GutTest

const FRONT_IDLE: Texture2D = preload("res://assets/sprites/player/wanderer_front_idle.png")
const FRONT_MOVE: Texture2D = preload("res://assets/sprites/player/wanderer_front_move.png")
const FRONT_ATTACK: Texture2D = preload("res://assets/sprites/player/wanderer_front_attack.png")
const BACK_IDLE: Texture2D = preload("res://assets/sprites/player/wanderer_back_idle.png")
const BACK_MOVE: Texture2D = preload("res://assets/sprites/player/wanderer_back_move.png")
const BACK_ATTACK: Texture2D = preload("res://assets/sprites/player/wanderer_back_attack.png")
const SIDE_IDLE: Texture2D = preload("res://assets/sprites/player/wanderer_side_idle.png")
const SIDE_MOVE: Texture2D = preload("res://assets/sprites/player/wanderer_side_move.png")
const SIDE_ATTACK: Texture2D = preload("res://assets/sprites/player/wanderer_side_attack.png")
const WALK_NORTH_0: Texture2D = preload("res://assets/sprites/player/wanderer_walk_north_0.png")
const WALK_NORTH_3: Texture2D = preload("res://assets/sprites/player/wanderer_walk_north_3.png")
const WALK_EAST_0: Texture2D = preload("res://assets/sprites/player/wanderer_walk_east_0.png")
const WALK_WEST_0: Texture2D = preload("res://assets/sprites/player/wanderer_walk_west_0.png")

var _visual: PlayerVisual


func before_each() -> void:
	_visual = PlayerVisual.new()
	_visual.scale = Vector2(0.09, 0.09)
	_visual.front_idle = FRONT_IDLE
	_visual.front_move = FRONT_MOVE
	_visual.front_attack = FRONT_ATTACK
	_visual.back_idle = BACK_IDLE
	_visual.back_move = BACK_MOVE
	_visual.back_attack = BACK_ATTACK
	_visual.side_idle = SIDE_IDLE
	_visual.side_move = SIDE_MOVE
	_visual.side_attack = SIDE_ATTACK
	_visual.walk_north_0 = WALK_NORTH_0
	_visual.walk_north_1 = WALK_NORTH_0
	_visual.walk_north_2 = WALK_NORTH_0
	_visual.walk_north_3 = WALK_NORTH_3
	_visual.walk_east_0 = WALK_EAST_0
	_visual.walk_east_1 = WALK_EAST_0
	_visual.walk_east_2 = WALK_EAST_0
	_visual.walk_east_3 = WALK_EAST_0
	_visual.walk_west_0 = WALK_WEST_0
	_visual.walk_west_1 = WALK_WEST_0
	_visual.walk_west_2 = WALK_WEST_0
	_visual.walk_west_3 = WALK_WEST_0
	add_child_autofree(_visual)


func test_melee_animation_keeps_the_character_upright() -> void:
	_visual.play_melee(Vector2.RIGHT)
	_visual._process(0.0)

	assert_eq(_visual.animation_name, PlayerVisual.MELEE_ANIMATION)
	assert_almost_eq(_visual.rotation, 0.0, 0.001)
	assert_eq(_visual.facing_label, &"east")
	assert_eq(_visual.texture, SIDE_ATTACK)


func test_relic_animation_returns_to_idle_after_its_duration() -> void:
	_visual.play_relic(Vector2.DOWN)
	_visual._process(_visual.relic_animation_duration)

	assert_eq(_visual.animation_name, PlayerVisual.IDLE_ANIMATION)


func test_back_movement_selects_the_back_walk_frame() -> void:
	_visual.set_facing_direction(Vector2.UP)
	_visual.play_move()
	_visual._process(0.4)

	assert_eq(_visual.animation_name, PlayerVisual.MOVE_ANIMATION)
	assert_eq(_visual.facing_label, &"north")
	assert_eq(_visual.texture, WALK_NORTH_3)


func test_west_facing_uses_its_own_unmirrored_walk_frame() -> void:
	_visual.set_facing_direction(Vector2.LEFT)
	_visual._process(0.0)

	assert_eq(_visual.facing_label, &"west")
	assert_false(_visual.flip_h)
	assert_eq(_visual.texture, WALK_WEST_0)


func test_front_relic_cast_selects_the_front_attack_frame() -> void:
	_visual.play_relic(Vector2.DOWN)
	_visual._process(0.0)

	assert_eq(_visual.facing_label, &"south")
	assert_eq(_visual.texture, FRONT_ATTACK)
