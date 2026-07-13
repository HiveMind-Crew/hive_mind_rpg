extends GutTest
## Coverage for the reusable EncounterRoom (issue #66): enemies stay dormant
## until the player enters, entry seals the configured exits, clearing every
## assigned enemy reopens them and completes exactly once per attempt, and
## reset_to_spawn() re-arms the whole encounter after a death.

const ROOM_SCENE: PackedScene = preload("res://scenes/world/encounter_room.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")


class StubEnemy:
	extends Node2D
	## Minimal duck-typed enemy: the controller only needs set_target() and an
	## enemy_died signal, never a concrete enemy class.

	signal enemy_died()

	var target: Node2D


	func set_target(new_target: Node2D) -> void:
		target = new_target


	func die() -> void:
		enemy_died.emit()


class StubDoor:
	extends Node
	## Exit that manages its own presentation through seal()/open().

	var seal_count: int = 0
	var open_count: int = 0


	func seal() -> void:
		seal_count += 1


	func open() -> void:
		open_count += 1


var _room: EncounterRoom
var _player: Node2D
var _barrier: StaticBody2D
var _barrier_shape: CollisionShape2D
var _stub_door: StubDoor


func before_each() -> void:
	_player = Node2D.new()
	_player.add_to_group(&"player")
	add_child_autofree(_player)


func _build_room(enemy_count: int = 2) -> void:
	_room = ROOM_SCENE.instantiate() as EncounterRoom
	var enemies_root: Node2D = _room.get_node("Enemies") as Node2D
	for index: int in enemy_count:
		var enemy: StubEnemy = StubEnemy.new()
		enemy.name = "StubEnemy%d" % index
		enemies_root.add_child(enemy)
	_barrier = StaticBody2D.new()
	_barrier.name = "Barrier"
	_barrier_shape = CollisionShape2D.new()
	_barrier_shape.shape = RectangleShape2D.new()
	_barrier.add_child(_barrier_shape)
	_room.add_child(_barrier)
	_stub_door = StubDoor.new()
	_stub_door.name = "StubDoor"
	_room.add_child(_stub_door)
	var paths: Array[NodePath] = [^"Barrier", ^"StubDoor"]
	_room.exit_paths = paths
	add_child_autofree(_room)
	watch_signals(_room)


func _stub_enemies() -> Array[StubEnemy]:
	var stubs: Array[StubEnemy] = []
	for node: Node in _room.get_assigned_enemies():
		stubs.append(node as StubEnemy)
	return stubs


func test_room_joins_encounter_and_resettable_groups() -> void:
	_build_room()
	assert_true(_room.is_in_group(EncounterRoom.ENCOUNTER_ROOM_GROUP))
	assert_true(
		_room.is_in_group(RespawnController.RESETTABLE_GROUP),
		"Death respawns must be able to reset the room."
	)


func test_enemies_stay_dormant_until_the_player_enters() -> void:
	_build_room()
	await wait_physics_frames(1)

	assert_eq(_room.state, EncounterRoom.State.DORMANT)
	assert_false(_room.are_exits_sealed())
	assert_false(_barrier.visible, "Dormant rooms keep barrier exits open.")
	assert_true(_barrier_shape.disabled)
	for stub_enemy: StubEnemy in _stub_enemies():
		assert_null(stub_enemy.target, "%s must stay dormant before entry." % stub_enemy.name)

	_room._on_body_entered(_player)

	assert_eq(_room.state, EncounterRoom.State.ACTIVE)
	for stub_enemy: StubEnemy in _stub_enemies():
		assert_eq(stub_enemy.target, _player)
	assert_signal_emit_count(_room, "encounter_started", 1)


func test_non_player_bodies_do_not_activate_the_room() -> void:
	_build_room()
	var bystander: Node2D = Node2D.new()
	add_child_autofree(bystander)

	_room._on_body_entered(bystander)

	assert_eq(_room.state, EncounterRoom.State.DORMANT)
	assert_signal_emit_count(_room, "encounter_started", 0)


func test_entering_seals_every_configured_exit() -> void:
	_build_room()
	await wait_physics_frames(1)

	_room._on_body_entered(_player)
	await wait_physics_frames(1)

	assert_true(_room.are_exits_sealed())
	assert_true(_barrier.visible, "Barrier exits become visible walls during combat.")
	assert_false(_barrier_shape.disabled, "Barrier exits collide during combat.")
	assert_eq(_stub_door.seal_count, 1, "Custom doors are asked to seal themselves.")


func test_defeating_every_enemy_reopens_exits_and_completes_once() -> void:
	_build_room()
	_room._on_body_entered(_player)
	var stubs: Array[StubEnemy] = _stub_enemies()

	stubs[0].die()
	assert_true(_room.are_exits_sealed(), "Exits stay sealed until the last enemy falls.")
	assert_false(_room.is_completed())

	stubs[1].die()
	await wait_physics_frames(1)

	assert_true(_room.is_completed())
	assert_false(_room.are_exits_sealed())
	assert_false(_barrier.visible)
	assert_true(_barrier_shape.disabled)
	assert_eq(_stub_door.open_count, 2, "Opened once at the ready baseline, once on clear.")

	# Duplicate death reports and re-entry must not re-fire either signal.
	stubs[0].die()
	_room._on_body_entered(_player)
	assert_signal_emit_count(_room, "encounter_completed", 1)
	assert_signal_emit_count(_room, "encounter_started", 1)


func test_room_with_no_enemies_completes_without_sealing() -> void:
	_build_room(0)

	_room._on_body_entered(_player)

	assert_true(_room.is_completed())
	assert_eq(_stub_door.seal_count, 0, "Never trap the player in an empty room.")
	assert_signal_emit_count(_room, "encounter_completed", 1)


func test_enemies_defeated_while_dormant_complete_on_entry() -> void:
	_build_room()
	for stub_enemy: StubEnemy in _stub_enemies():
		stub_enemy.die()

	_room._on_body_entered(_player)

	assert_true(_room.is_completed())
	assert_eq(_stub_door.seal_count, 0, "Never trap the player in an already-cleared room.")
	assert_signal_emit_count(_room, "encounter_completed", 1)


func test_reset_restores_a_mid_fight_room_to_its_dormant_state() -> void:
	_build_room()
	_room._on_body_entered(_player)
	_stub_enemies()[0].die()

	_room.reset_to_spawn()
	await wait_physics_frames(1)

	assert_eq(_room.state, EncounterRoom.State.DORMANT)
	assert_false(_room.are_exits_sealed())
	var stubs: Array[StubEnemy] = _stub_enemies()
	assert_eq(stubs.size(), 2, "Defeated enemies come back after a reset.")
	for stub_enemy: StubEnemy in stubs:
		assert_null(stub_enemy.target, "Rebuilt enemies must be dormant, not re-targeted.")
	assert_eq(_room.get_node("Enemies").get_child_count(), 2, "Old bodies are freed.")


func test_reset_room_can_be_fought_and_completed_again() -> void:
	_build_room()
	_room._on_body_entered(_player)
	for stub_enemy: StubEnemy in _stub_enemies():
		stub_enemy.die()
	assert_signal_emit_count(_room, "encounter_completed", 1)

	_room.reset_to_spawn()
	await wait_physics_frames(1)
	_room._on_body_entered(_player)
	assert_true(_room.is_active(), "A completed room re-arms after reset (die-back loop).")
	assert_true(_room.are_exits_sealed())
	for stub_enemy: StubEnemy in _stub_enemies():
		stub_enemy.die()

	assert_true(_room.is_completed())
	# Completion stays one-shot per attempt: the second clear is a fresh
	# attempt after the reset, not a repeat of the first emission.
	assert_signal_emit_count(_room, "encounter_completed", 2)
	assert_signal_emit_count(_room, "encounter_started", 2)


func test_player_body_physically_entering_activates_real_enemies() -> void:
	var room: EncounterRoom = ROOM_SCENE.instantiate() as EncounterRoom
	var chaser: EnemyBase = CHASER_SCENE.instantiate() as EnemyBase
	room.get_node("Enemies").add_child(chaser)
	add_child_autofree(room)
	watch_signals(room)
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"player")
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	body.add_child(body_shape)
	add_child_autofree(body)
	body.global_position = room.global_position
	await wait_physics_frames(3)

	assert_true(room.is_active(), "A player body inside the trigger starts the encounter.")
	assert_eq(chaser.target, body, "Real EnemyBase enemies receive the player as target.")

	chaser.health.take_damage(99999)

	assert_true(room.is_completed())
	assert_signal_emit_count(room, "encounter_completed", 1)
