extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const ESCAPE_DISTANCE: float = 24.0
const WALL_DISTANCE: float = 30.0
const WALL_THICKNESS: float = 8.0

var _player: PlayerController
var _enemy: EnemyBase


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_enemy = CHASER_SCENE.instantiate() as EnemyBase
	add_child_autofree(_player)
	add_child_autofree(_enemy)
	_player.global_position = Vector2.ZERO
	_enemy.global_position = Vector2.ZERO
	await wait_physics_frames(2)


func test_actor_bodies_only_query_world_geometry() -> void:
	assert_eq(_player.collision_layer, CollisionLayers.PLAYER_BODY)
	assert_eq(_player.collision_mask, CollisionLayers.WORLD)
	assert_eq(_enemy.collision_layer, CollisionLayers.ENEMY_BODY)
	assert_eq(_enemy.collision_mask, CollisionLayers.WORLD)


func test_overlapping_enemy_body_does_not_block_player_escape_in_cardinal_directions() -> void:
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_player.global_position = Vector2.ZERO
		_enemy.global_position = Vector2.ZERO
		await wait_physics_frames(1)

		var collision: KinematicCollision2D = _player.move_and_collide(direction * ESCAPE_DISTANCE)

		assert_null(collision, "Enemy body must not collide while moving %s." % direction)
		assert_almost_eq(
			_player.global_position.dot(direction),
			ESCAPE_DISTANCE,
			0.01,
			"Player must escape the overlapping enemy body toward %s." % direction
		)


func test_player_body_still_stops_at_authored_world_collision() -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = CollisionLayers.WORLD
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(WALL_THICKNESS, 64.0)
	wall_shape.shape = shape
	wall.add_child(wall_shape)
	add_child_autofree(wall)
	wall.global_position = Vector2(WALL_DISTANCE, 0.0)
	_enemy.global_position = Vector2(-WALL_DISTANCE, 0.0)
	_player.global_position = Vector2.ZERO
	await wait_physics_frames(2)

	var collision: KinematicCollision2D = _player.move_and_collide(Vector2.RIGHT * ESCAPE_DISTANCE * 2.0)

	assert_not_null(collision, "Player must continue to collide with authored world geometry.")
	assert_lt(_player.global_position.x, WALL_DISTANCE - WALL_THICKNESS * 0.5)


func test_body_change_does_not_change_hitbox_hurtbox_contract() -> void:
	var player_hurtbox: Hurtbox = _player.get_node("Hurtbox") as Hurtbox
	var player_hitbox: Hitbox = _player.get_node("MeleeHitbox") as Hitbox

	assert_eq(player_hurtbox.collision_layer, CollisionLayers.COMBAT_HURTBOX)
	assert_eq(player_hurtbox.collision_mask, CollisionLayers.COMBAT_HITBOX)
	assert_eq(player_hitbox.collision_layer, CollisionLayers.COMBAT_HITBOX)
	assert_eq(player_hitbox.collision_mask, CollisionLayers.COMBAT_HURTBOX)
	assert_eq(_enemy.hurtbox.collision_layer, CollisionLayers.COMBAT_HURTBOX)
	assert_eq(_enemy.hurtbox.collision_mask, CollisionLayers.COMBAT_HITBOX)
	assert_eq(_enemy.attack_hitbox.collision_layer, CollisionLayers.COMBAT_HITBOX)
	assert_eq(_enemy.attack_hitbox.collision_mask, CollisionLayers.COMBAT_HURTBOX)
