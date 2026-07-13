extends GutTest
## Coverage for the pause menu (issue #69): the pause action toggles the menu,
## time stops through TimeScaleManager (never Engine.time_scale directly),
## pause composes with combat hitstop, the UI stays interactive while time is
## stopped, and controller focus navigation works.

const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")


class PhysicsProbe:
	extends Node
	## Stand-in for gameplay/enemy AI: counts physics ticks, which must stop
	## while the game is paused.
	var ticks: int = 0

	func _physics_process(_delta: float) -> void:
		ticks += 1


var _menu: PauseMenu
var _input_sender: GutInputSender


func before_each() -> void:
	TimeScaleManager.reset()
	_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child_autofree(_menu)
	_input_sender = GutInputSender.new(Input)
	await wait_process_frames(1)


func after_each() -> void:
	_input_sender.release_all()
	_input_sender.clear()
	get_tree().paused = false
	TimeScaleManager.reset()


func _press_pause() -> void:
	_input_sender.action_down("pause")
	await wait_process_frames(2)
	_input_sender.action_up("pause")
	await wait_process_frames(2)


func test_starts_hidden_without_touching_time_scale() -> void:
	assert_false(_menu.visible)
	assert_false(_menu.is_open())
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(TimeScaleManager.get_modifier_count(), 0)


func test_pause_action_opens_the_menu_and_stops_time() -> void:
	watch_signals(_menu)

	await _press_pause()

	assert_true(_menu.is_open())
	assert_true(_menu.visible)
	assert_true(get_tree().paused)
	assert_eq(Engine.time_scale, 0.0)
	assert_eq(TimeScaleManager.get_modifier_count(), 1)
	assert_signal_emitted(_menu, "menu_opened")


func test_pause_action_toggles_closed_and_restores_time() -> void:
	watch_signals(_menu)

	await _press_pause()
	await _press_pause()

	assert_false(_menu.is_open())
	assert_false(_menu.visible)
	assert_false(get_tree().paused)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(TimeScaleManager.get_modifier_count(), 0)
	assert_signal_emitted(_menu, "menu_closed")


func test_open_and_close_are_idempotent() -> void:
	_menu.open()
	_menu.open()

	assert_eq(TimeScaleManager.get_modifier_count(), 1)

	_menu.close()
	_menu.close()

	assert_eq(TimeScaleManager.get_modifier_count(), 0)
	assert_eq(Engine.time_scale, 1.0)


func test_gameplay_physics_stops_while_paused_and_ui_stays_interactive() -> void:
	var probe: PhysicsProbe = PhysicsProbe.new()
	add_child_autofree(probe)
	await wait_physics_frames(2)
	assert_gt(probe.ticks, 0)

	_menu.open()
	await wait_process_frames(2)
	var ticks_at_pause: int = probe.ticks

	await wait_process_frames(5)

	assert_eq(probe.ticks, ticks_at_pause, "physics must not tick while paused")

	# The menu itself stays interactive with time stopped: the focused resume
	# button accepts ui_accept and resumes the game.
	_input_sender.action_down("ui_accept")
	await wait_process_frames(2)
	_input_sender.action_up("ui_accept")
	await wait_process_frames(2)

	assert_false(_menu.is_open())
	assert_eq(Engine.time_scale, 1.0)


func test_resume_button_closes_the_menu_and_restores_time() -> void:
	_menu.open()
	assert_eq(Engine.time_scale, 0.0)

	var resume_button: Button = _menu.get_node("%ResumeButton") as Button
	resume_button.pressed.emit()

	assert_false(_menu.is_open())
	assert_false(_menu.visible)
	assert_eq(Engine.time_scale, 1.0)


func test_pause_composes_with_combat_hitstop() -> void:
	# Hitstop is already active when the player pauses.
	var hitstop_token: int = TimeScaleManager.acquire_modifier(0.5)
	_menu.open()

	assert_eq(Engine.time_scale, 0.0)

	# Hitstop ends (its timer runs in real time) while still paused.
	TimeScaleManager.release_modifier(hitstop_token)

	assert_eq(Engine.time_scale, 0.0)

	_menu.close()

	assert_eq(Engine.time_scale, 1.0)


func test_unpausing_during_hitstop_returns_to_the_hitstop_scale() -> void:
	var hitstop_token: int = TimeScaleManager.acquire_modifier(0.5)
	_menu.open()
	_menu.close()

	assert_eq(Engine.time_scale, 0.5)

	TimeScaleManager.release_modifier(hitstop_token)

	assert_eq(Engine.time_scale, 1.0)


func test_return_to_hub_emits_signal_and_unpauses_first() -> void:
	watch_signals(_menu)
	_menu.open()

	var return_button: Button = _menu.get_node("%ReturnToHubButton") as Button
	return_button.pressed.emit()

	# The menu must release its time-scale modifier before any scene change,
	# otherwise the next scene starts frozen.
	assert_eq(Engine.time_scale, 1.0)
	assert_false(_menu.is_open())
	assert_signal_emitted(_menu, "return_to_hub_requested")


func test_opening_focuses_resume_and_controller_navigation_moves_focus() -> void:
	_menu.open()
	await wait_process_frames(2)

	var resume_button: Button = _menu.get_node("%ResumeButton") as Button
	var return_button: Button = _menu.get_node("%ReturnToHubButton") as Button
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), resume_button)

	# ui_down is bound to the d-pad by default, so this is the controller path.
	_input_sender.action_down("ui_down")
	await wait_process_frames(2)
	_input_sender.action_up("ui_down")
	await wait_process_frames(2)

	assert_eq(_menu.get_viewport().gui_get_focus_owner(), return_button)


func test_freeing_an_open_menu_releases_its_pause() -> void:
	var other_menu: PauseMenu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child(other_menu)
	other_menu.open()
	assert_eq(Engine.time_scale, 0.0)

	other_menu.free()

	assert_false(get_tree().paused)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(TimeScaleManager.get_modifier_count(), 0)
