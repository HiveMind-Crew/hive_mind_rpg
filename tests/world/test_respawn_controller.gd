extends GutTest
## Coverage for the RespawnController: checkpoints move the respawn point and
## heal, and death (or a direct respawn) returns the player to that point at
## full health while resetting enemies and preserving skill progress.

const HEALTH_SCRIPT := preload("res://scripts/combat/health_component.gd")
const START_POSITION := Vector2(100, 100)


class StubEnemy:
	extends Node
	var was_reset: bool = false

	func reset_to_spawn() -> void:
		was_reset = true


var _controller: RespawnController
var _player: Node2D
var _health: HealthComponent


func before_each() -> void:
	GameState.reset_progress()
	_controller = RespawnController.new()
	_player = Node2D.new()
	_player.position = START_POSITION
	_health = HEALTH_SCRIPT.new()
	_health.max_health = 3
	_controller.add_child(_player)
	_controller.add_child(_health)
	_controller.player_path = _controller.get_path_to(_player)
	_controller.health_component_path = _controller.get_path_to(_health)
	add_child_autofree(_controller)
	await wait_physics_frames(1)


func after_each() -> void:
	GameState.reset_progress()


func test_initial_respawn_is_the_player_start_position() -> void:
	assert_eq(_controller.get_respawn_position(), START_POSITION)


func test_reaching_a_checkpoint_updates_respawn_and_heals() -> void:
	_health.take_damage(2)
	assert_eq(_health.current_health, 1)

	_controller._on_checkpoint_reached(Vector2(300, 50))

	assert_eq(_controller.get_respawn_position(), Vector2(300, 50))
	assert_eq(_health.current_health, 3)


func test_respawn_moves_player_heals_and_resets_enemies() -> void:
	var enemy: StubEnemy = StubEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group(RespawnController.RESETTABLE_GROUP)
	_health.take_damage(2)
	_player.global_position = Vector2(500, 500)

	_controller.respawn()

	assert_eq(_player.global_position, START_POSITION)
	assert_eq(_health.current_health, 3)
	assert_true(enemy.was_reset)


func test_death_respawns_at_last_checkpoint_at_full_health() -> void:
	_controller._on_checkpoint_reached(Vector2(200, 200))
	_player.global_position = Vector2(500, 500)

	_health.take_damage(3)
	await wait_physics_frames(1)

	assert_eq(_player.global_position, Vector2(200, 200))
	assert_eq(_health.current_health, 3)
	assert_false(_health.is_dead)
	assert_false(_controller.is_respawning())


func test_dying_does_not_reset_skill_progress() -> void:
	GameState.award_skill_points(4)
	GameState.spend_points(&"steel_tempered_edge")

	_health.take_damage(3)
	await wait_physics_frames(1)

	assert_eq(GameState.get_skill_points(), 3)
	assert_true(GameState.is_skill_unlocked(&"steel_tempered_edge"))
