extends GutTest
## Startup-scene gameplay smoke test (issue #61): guards the project against
## silently regressing to a non-playable pixel-test entry point. Unlike
## test_game_manager.gd, which preloads main.tscn directly, this suite reads
## `application/run/main_scene` from ProjectSettings — the same value a normal
## F5 run and the desktop/Web exports boot — so it follows whatever the project
## is actually configured to launch and fails if that entry point stops being
## functional gameplay. Save hygiene mirrors test_game_manager: worlds persist
## runs through SaveManager, so it is redirected at a scratch file and
## progression is reset around every test.

const MAIN_SCENE_SETTING: String = "application/run/main_scene"
const TEST_SAVE_PATH: String = "user://test_main_scene_savegame.json"

## Autoload registry contract (AGENTS.md §9): startup gameplay requires all
## four singletons configured for auto-instantiation and alive under /root.
const REQUIRED_AUTOLOADS: Array[StringName] = [
	&"GameState", &"TimeScaleManager", &"SaveManager", &"AudioManager",
]

## Homes of visual/test-only content. The configured entry point drifting into
## one of these (e.g. back to the visual reference sheet) is exactly the
## regression this suite exists to catch, so name it directly instead of only
## failing on the missing-player symptom.
const NON_GAMEPLAY_PATH_PREFIXES: Array[String] = [
	"res://tests/",
	"res://scenes/reference/",
	"res://assets/",
]


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()


func after_each() -> void:
	get_tree().paused = false
	TimeScaleManager.reset()
	_delete_test_save()
	_forget_run_state()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	GameState.reset_progress()


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _forget_run_state() -> void:
	SaveManager.checkpoint_scene_path = ""
	SaveManager.checkpoint_position = Vector2.ZERO
	SaveManager.collected_secret_ids.clear()
	SaveManager.completed_milestone_ids.clear()


func _configured_scene_path() -> String:
	return String(ProjectSettings.get_setting(MAIN_SCENE_SETTING, ""))


func _load_startup_scene() -> PackedScene:
	var path: String = _configured_scene_path()
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return ResourceLoader.load(path) as PackedScene


## Instantiates the configured startup scene exactly as the engine would on
## boot and hands it to the tree so _ready-driven world setup runs.
func _boot_startup_scene() -> Node:
	var scene: PackedScene = _load_startup_scene()
	assert_not_null(scene, "The configured startup scene must load as a PackedScene.")
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	assert_not_null(root, "The configured startup scene must instantiate.")
	if root == null:
		return null
	add_child_autofree(root)
	return root


## Resolves the live player the way a startup scene is allowed to provide one:
## through a game-flow controller's typed accessor (GameManager.get_player) or,
## for a startup scene that is itself a world, the scene-assigned player group.
func _resolve_player(root: Node) -> PlayerController:
	if root.has_method(&"get_player"):
		return root.call(&"get_player") as PlayerController
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players.front() as PlayerController


func test_project_configures_a_loadable_startup_scene() -> void:
	var path: String = _configured_scene_path()
	assert_false(path.is_empty(), "The project must configure %s." % MAIN_SCENE_SETTING)
	var scene: PackedScene = _load_startup_scene()
	assert_not_null(scene, "run/main_scene ('%s') must load as a PackedScene." % path)
	if scene == null:
		return
	assert_true(scene.can_instantiate(), "The startup scene must be instantiable.")
	# resource_path resolves uid:// forms of the setting to the real location.
	for prefix: String in NON_GAMEPLAY_PATH_PREFIXES:
		assert_false(
			scene.resource_path.begins_with(prefix),
			"The startup scene must be functional gameplay, not test/reference "
			+ "content under '%s' (got '%s')." % [prefix, scene.resource_path]
		)


func test_required_autoloads_are_configured_and_alive() -> void:
	for autoload_name: StringName in REQUIRED_AUTOLOADS:
		var setting: String = "autoload/%s" % autoload_name
		assert_true(
			ProjectSettings.has_setting(setting),
			"Autoload %s must stay registered in project.godot." % autoload_name
		)
		var value: String = String(ProjectSettings.get_setting(setting, ""))
		assert_true(
			value.begins_with("*"),
			"Autoload %s must auto-instantiate (leading '*')." % autoload_name
		)
		assert_not_null(
			get_tree().root.get_node_or_null(String(autoload_name)),
			"Autoload %s must be alive under /root at startup." % autoload_name
		)


func test_startup_scene_provides_a_game_flow_controller_or_player() -> void:
	var root: Node = _boot_startup_scene()
	if root == null:
		return

	var is_game_flow_controller: bool = (
		root.has_method(&"get_player") and root.has_method(&"get_current_world")
	)
	var has_player_in_tree: bool = not get_tree().get_nodes_in_group(&"player").is_empty()
	assert_true(
		is_game_flow_controller or has_player_in_tree,
		"The startup scene must instantiate a game-flow controller or a player; "
		+ "a standalone visual test asset provides neither."
	)


func test_startup_scene_boots_into_functional_gameplay() -> void:
	var root: Node = _boot_startup_scene()
	if root == null:
		return

	assert_false(
		root is VisualReferenceSheet,
		"The startup scene must never regress to the visual reference sheet."
	)
	var player: PlayerController = _resolve_player(root)
	assert_not_null(player, "Startup must route to a world that owns a player.")
	if player == null:
		return
	assert_true(player.is_inside_tree(), "The startup player is live in the tree.")
	assert_true(
		player.is_control_enabled(),
		"Startup hands the player live input — gameplay, not a picture of it."
	)
	assert_eq(
		get_tree().get_nodes_in_group(&"player").size(), 1,
		"Startup produces exactly one player."
	)
	if root.has_method(&"get_current_world"):
		var world: Node2D = root.call(&"get_current_world") as Node2D
		assert_not_null(world, "The game-flow controller has an active world at boot.")
		if world != null:
			assert_true(
				world.is_ancestor_of(player),
				"The active world owns the live player."
			)
