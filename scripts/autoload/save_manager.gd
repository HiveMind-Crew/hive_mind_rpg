extends Node
## SaveManager autoload (issue #19): persists a run to versioned JSON in
## user:// via FileAccess (DESIGN.md §9) and restores it on launch.
##
## Persisted: GameState progression (skill points + unlocked ids), the last
## checkpoint (scene path + position), and collected secret ids (written for
## the secrets work in #24; empty until then). Anything invalid — missing
## file, unparseable JSON, wrong shapes, unknown skill ids — degrades to a
## new game with a warning, never a crash.

signal game_saved()
signal game_loaded()

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://savegame.json"

## Tests point this at a scratch file; gameplay never changes it.
var save_path: String = DEFAULT_SAVE_PATH

var checkpoint_scene_path: String = ""
var checkpoint_position: Vector2 = Vector2.ZERO
var collected_secret_ids: Array[StringName] = []


func _ready() -> void:
	# Relaunch restores state: autoloads ready before any scene, so gameplay
	# nodes that read GameState in their own _ready see the loaded values.
	load_game()


func _notification(what: int) -> void:
	# "Save on checkpoint + quit": checkpoints save via record_checkpoint;
	# this covers the quit half.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func has_checkpoint() -> bool:
	return not checkpoint_scene_path.is_empty()


func record_checkpoint(scene_path: String, position: Vector2) -> void:
	checkpoint_scene_path = scene_path
	checkpoint_position = position
	save_game()


func save_game() -> bool:
	var unlocked_ids: Array[String] = []
	for skill_id: StringName in GameState.get_unlocked_skill_ids():
		unlocked_ids.append(str(skill_id))
	var secret_ids: Array[String] = []
	for secret_id: StringName in collected_secret_ids:
		secret_ids.append(str(secret_id))
	var save_data: Dictionary[String, Variant] = {
		"version": SAVE_VERSION,
		"skill_points": GameState.get_skill_points(),
		"unlocked_skill_ids": unlocked_ids,
		"checkpoint": {
			"scene_path": checkpoint_scene_path,
			"x": checkpoint_position.x,
			"y": checkpoint_position.y,
		},
		"collected_secret_ids": secret_ids,
	}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning(
			"SaveManager could not open '%s' for writing (%s)."
			% [save_path, error_string(FileAccess.get_open_error())]
		)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	game_saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning(
			"SaveManager could not open '%s' for reading (%s)."
			% [save_path, error_string(FileAccess.get_open_error())]
		)
		return false
	var raw_text: String = file.get_as_text()
	file.close()

	# A JSON instance reports malformed text as a return code instead of an
	# engine error, keeping corrupt saves a quiet new-game fallback.
	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK or not _is_valid_save_data(json.data):
		push_warning("SaveManager found an invalid save at '%s'; starting a new game." % save_path)
		return false
	var save_data: Dictionary = json.data

	var unlocked_ids: Array[StringName] = []
	for raw_id: Variant in (save_data["unlocked_skill_ids"] as Array):
		unlocked_ids.append(StringName(raw_id))
	if not GameState.restore_progress(int(save_data["skill_points"]), unlocked_ids):
		push_warning(
			"SaveManager could not restore progression from '%s'; starting a new game."
			% save_path
		)
		return false

	var checkpoint: Dictionary = save_data["checkpoint"]
	checkpoint_scene_path = checkpoint["scene_path"]
	checkpoint_position = Vector2(float(checkpoint["x"]), float(checkpoint["y"]))
	collected_secret_ids.clear()
	for raw_id: Variant in (save_data["collected_secret_ids"] as Array):
		collected_secret_ids.append(StringName(raw_id))
	game_loaded.emit()
	return true


func clear_save() -> void:
	# New game: forget the file and all in-memory run state.
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	checkpoint_scene_path = ""
	checkpoint_position = Vector2.ZERO
	collected_secret_ids.clear()
	GameState.reset_progress()


func _is_valid_save_data(parsed: Variant) -> bool:
	if not parsed is Dictionary:
		return false
	var save_data: Dictionary = parsed
	if not save_data.get("version") is float and not save_data.get("version") is int:
		return false
	if not save_data.get("skill_points") is float and not save_data.get("skill_points") is int:
		return false
	if not save_data.get("unlocked_skill_ids") is Array:
		return false
	for raw_id: Variant in (save_data["unlocked_skill_ids"] as Array):
		if not raw_id is String:
			return false
	if not save_data.get("checkpoint") is Dictionary:
		return false
	var checkpoint: Dictionary = save_data["checkpoint"]
	if not checkpoint.get("scene_path") is String:
		return false
	if not checkpoint.get("x") is float and not checkpoint.get("x") is int:
		return false
	if not checkpoint.get("y") is float and not checkpoint.get("y") is int:
		return false
	if not save_data.get("collected_secret_ids") is Array:
		return false
	for raw_id: Variant in (save_data["collected_secret_ids"] as Array):
		if not raw_id is String:
			return false
	return true
