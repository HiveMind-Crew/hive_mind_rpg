extends GutTest
## Coverage for the reusable skill-tree station prop (issue #67): interaction
## opens the screen and suspends gameplay input, closing restores control, an
## unlock made from the station's screen updates the live player immediately,
## and respec works through the screen's real button. The station is exercised
## in a minimal rig (player + screen layer + station) so the contract holds
## anywhere it is placed, not just in the hub.

const STATION_SCENE_PATH: String = "res://scenes/world/skill_tree_station.tscn"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

## Root body node (cost 1, +10 max HP) — a stat the live player must reflect.
const HP_SKILL_ID: StringName = &"body_scar_tissue"
const HP_SKILL_BONUS: int = 10


func before_each() -> void:
	GameState.reset_progress()


func after_each() -> void:
	GameState.reset_progress()


func _add_rig() -> Node2D:
	var rig: Node2D = Node2D.new()
	add_child_autofree(rig)

	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	player.add_to_group(&"player")
	rig.add_child(player)

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ScreenLayer"
	rig.add_child(layer)

	var station: Node2D = (load(STATION_SCENE_PATH) as PackedScene).instantiate() as Node2D
	station.name = "Station"
	station.set("player_path", NodePath("../Player"))
	station.set("screen_layer_path", NodePath("../ScreenLayer"))
	rig.add_child(station)
	return rig


func _station_of(rig: Node2D) -> Node2D:
	return rig.get_node("Station") as Node2D

func _player_of(rig: Node2D) -> PlayerController:
	return rig.get_node("Player") as PlayerController

func _layer_of(rig: Node2D) -> CanvasLayer:
	return rig.get_node("ScreenLayer") as CanvasLayer

func _zone_of(rig: Node2D) -> InteractableZone:
	return rig.get_node("Station/InteractionZone") as InteractableZone

func _screen_of(rig: Node2D) -> SkillTreeScreen:
	if _layer_of(rig).get_child_count() == 0:
		return null
	return _layer_of(rig).get_child(0) as SkillTreeScreen


func test_station_scene_exists_and_exposes_its_interaction_zone() -> void:
	assert_true(
		ResourceLoader.exists(STATION_SCENE_PATH),
		"The reusable station scene exists (#67)."
	)
	if not ResourceLoader.exists(STATION_SCENE_PATH):
		return
	var rig: Node2D = _add_rig()
	assert_not_null(_zone_of(rig), "The station owns an InteractableZone child.")


func test_interact_opens_the_screen_and_suspends_player_input() -> void:
	var rig: Node2D = _add_rig()

	_zone_of(rig).interact()

	assert_true(_station_of(rig).call("is_screen_open") as bool)
	assert_false(_player_of(rig).is_control_enabled(), "Input suspends behind the menu.")
	assert_not_null(_screen_of(rig), "The screen instances into the provided layer.")


func test_interact_again_closes_the_screen_and_restores_input() -> void:
	var rig: Node2D = _add_rig()

	_zone_of(rig).interact()
	_zone_of(rig).interact()
	await wait_process_frames(2)

	assert_false(_station_of(rig).call("is_screen_open") as bool)
	assert_true(_player_of(rig).is_control_enabled())
	assert_eq(_layer_of(rig).get_child_count(), 0, "The closed screen frees itself.")


func test_unlock_while_screen_is_open_updates_the_live_player_immediately() -> void:
	var rig: Node2D = _add_rig()
	var baseline_max_health: int = _player_of(rig).health.max_health
	_zone_of(rig).interact()

	GameState.award_skill_points(1)
	assert_true(GameState.spend_points(HP_SKILL_ID), "Precondition: the unlock succeeds.")

	assert_eq(
		_player_of(rig).health.max_health,
		baseline_max_health + HP_SKILL_BONUS,
		"The live player reflects the unlock before the screen even closes."
	)


func test_respec_through_the_screens_real_button_reverts_the_player() -> void:
	var rig: Node2D = _add_rig()
	var baseline_max_health: int = _player_of(rig).health.max_health
	GameState.award_skill_points(1)
	GameState.spend_points(HP_SKILL_ID)
	_zone_of(rig).interact()
	await wait_process_frames(2)

	var screen: SkillTreeScreen = _screen_of(rig)
	assert_not_null(screen, "Precondition: the station opened the screen.")
	if screen == null:
		return
	(screen.get_node("%RespecButton") as Button).pressed.emit()

	assert_eq(GameState.get_unlocked_skill_ids().size(), 0, "Respec refunds every unlock.")
	assert_eq(
		_player_of(rig).health.max_health,
		baseline_max_health,
		"The live player reverts to baseline stats on respec."
	)


func test_station_emits_screen_lifecycle_signals() -> void:
	var rig: Node2D = _add_rig()
	var station: Node2D = _station_of(rig)
	watch_signals(station)

	_zone_of(rig).interact()
	assert_signal_emitted(station, "screen_opened")

	_zone_of(rig).interact()
	assert_signal_emitted(station, "screen_closed")
