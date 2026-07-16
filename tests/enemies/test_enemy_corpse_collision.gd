extends GutTest
## Regression coverage for issue #130: a defeated enemy's remains must never
## participate in physical collisions, so a corpse can never block or trap the
## player — even in a narrow doorway — while living enemies keep their world
## collision and reset_to_spawn() re-arms the body for the respawn loop.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")

## The chaser body is a 10 px-radius circle and the player capsule is 20 px
## tall (offset +2): a 28 px gap fits the player with a few pixels to spare,
## while the corpse still plugs the middle so there is no way around it.
const DOORWAY_GAP: float = 28.0
const DOORWAY_X: float = 40.0
const WALL_SIZE: Vector2 = Vector2(8.0, 64.0)
const TRAVERSAL_DISTANCE: float = 80.0

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


func test_defeated_enemy_leaves_the_enemy_body_layer() -> void:
	await _kill_enemy()

	assert_eq(_enemy.state, EnemyBase.State.DEAD)
	assert_eq(_enemy.collision_layer, 0, "A corpse must not advertise a solid body.")
	assert_eq(
		_query_bodies_at(_enemy.global_position, CollisionLayers.ENEMY_BODY).size(),
		0,
		"No ENEMY_BODY collision may remain at the death location."
	)


func test_living_enemy_still_occupies_the_enemy_body_layer() -> void:
	assert_eq(_enemy.collision_layer, CollisionLayers.ENEMY_BODY)
	assert_eq(
		_query_bodies_at(_enemy.global_position, CollisionLayers.ENEMY_BODY).size(),
		1,
		"A living enemy body stays physically present."
	)


func test_player_walks_through_corpse_plugging_a_narrow_doorway() -> void:
	_build_doorway(DOORWAY_X)
	_enemy.global_position = Vector2(DOORWAY_X, 0.0)
	await _kill_enemy()

	var collision: KinematicCollision2D = _player.move_and_collide(
		Vector2.RIGHT * TRAVERSAL_DISTANCE
	)

	assert_null(collision, "The corpse in the doorway must not block traversal.")
	assert_almost_eq(_player.global_position.x, TRAVERSAL_DISTANCE, 0.01)

	# The route stays open in both directions (killed on either side of you).
	var return_collision: KinematicCollision2D = _player.move_and_collide(
		Vector2.LEFT * TRAVERSAL_DISTANCE
	)

	assert_null(return_collision, "Walking back through the corpse must also work.")
	assert_almost_eq(_player.global_position.x, 0.0, 0.01)


func test_living_enemy_still_stops_at_authored_world_collision() -> void:
	_build_doorway(DOORWAY_X)
	_enemy.global_position = Vector2(0.0, DOORWAY_GAP)

	var collision: KinematicCollision2D = _enemy.move_and_collide(
		Vector2.RIGHT * TRAVERSAL_DISTANCE
	)

	assert_not_null(collision, "A living enemy keeps colliding with world geometry.")
	assert_lt(_enemy.global_position.x, DOORWAY_X - WALL_SIZE.x * 0.5)


func test_reset_to_spawn_restores_the_body_layer_after_death() -> void:
	await _kill_enemy()
	assert_eq(_enemy.collision_layer, 0)

	_enemy.reset_to_spawn()
	# The layer restore is deferred alongside the other physics toggles.
	await wait_physics_frames(2)

	assert_eq(_enemy.state, EnemyBase.State.IDLE)
	assert_eq(_enemy.collision_layer, CollisionLayers.ENEMY_BODY)
	assert_true(_enemy.hurtbox.enabled)
	assert_eq(
		_query_bodies_at(_enemy.global_position, CollisionLayers.ENEMY_BODY).size(),
		1,
		"A revived enemy is physically present again."
	)


func _kill_enemy() -> void:
	_enemy.health.invulnerability_duration = 0.0
	_enemy._on_hit_received(99999, Vector2.ZERO, Hitbox.ImpactType.MELEE)
	# The corpse layer change defers out of the combat overlap flush.
	await wait_physics_frames(2)


func _build_doorway(doorway_x: float) -> void:
	# Two WORLD walls leaving a DOORWAY_GAP-tall opening centered on y = 0.
	for side: float in [-1.0, 1.0]:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.collision_layer = CollisionLayers.WORLD
		var wall_shape: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = WALL_SIZE
		wall_shape.shape = shape
		wall.add_child(wall_shape)
		# Position before entering the tree: a body added at the origin and
		# moved afterwards depenetrates anything overlapping its spawn spot.
		wall.position = Vector2(
			doorway_x,
			side * (DOORWAY_GAP + WALL_SIZE.y) * 0.5
		)
		add_child_autofree(wall)


func _query_bodies_at(point: Vector2, mask: int) -> Array[Dictionary]:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return _player.get_world_2d().direct_space_state.intersect_point(query)
