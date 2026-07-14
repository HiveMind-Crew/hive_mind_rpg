extends GutTest
## Static check for the Godot metadata policy (issue #81, AGENTS.md section
## "Godot Metadata Policy"): every script ships with its .gd.uid sidecar and
## every imported asset ships with its .import file, with no orphaned sidecars
## and no duplicate UIDs. Uses only res:// file access so it cannot depend on
## git being available or on user cache locations. The authoritative
## clean-worktree check (headless import + `git status --porcelain`) is
## documented in AGENTS.md.

## File extensions Godot's importer turns into .import-managed resources.
## Extend this list when a new imported asset type enters the repo.
const IMPORTED_ASSET_EXTENSIONS: Array[String] = [
	"bmp", "fnt", "jpeg", "jpg", "mp3", "ogg", "otf", "png", "svg", "ttf", "wav", "webp",
]

var _files: Array[String] = []


func before_all() -> void:
	_collect_files("res://", _files)
	assert_true(_files.size() > 0, "res:// scan should find project files")


func test_every_script_has_a_uid_sidecar() -> void:
	for path: String in _files:
		if path.get_extension() != "gd":
			continue
		assert_true(
			FileAccess.file_exists(path + ".uid"),
			(
				"%s is missing its .gd.uid sidecar; import the project with"
				+ " supported Godot 4.7 and commit the generated file"
			) % path
		)


func test_every_uid_sidecar_has_an_owner() -> void:
	for path: String in _files:
		if path.get_extension() != "uid":
			continue
		var sidecar_owner: String = path.trim_suffix(".uid")
		assert_true(
			FileAccess.file_exists(sidecar_owner),
			"%s is an orphaned sidecar; delete it alongside its removed owner" % path
		)


func test_every_imported_asset_has_an_import_file() -> void:
	for path: String in _files:
		if not IMPORTED_ASSET_EXTENSIONS.has(path.get_extension()):
			continue
		assert_true(
			FileAccess.file_exists(path + ".import"),
			(
				"%s is missing its .import file; import the project with"
				+ " supported Godot 4.7 and commit the generated file"
			) % path
		)


func test_every_import_file_has_an_asset() -> void:
	for path: String in _files:
		if path.get_extension() != "import":
			continue
		var sidecar_owner: String = path.trim_suffix(".import")
		assert_true(
			FileAccess.file_exists(sidecar_owner),
			"%s is an orphaned .import file; delete it alongside its removed asset" % path
		)


func test_uid_sidecars_are_valid_and_unique() -> void:
	var seen: Dictionary[String, String] = {}
	for path: String in _files:
		if path.get_extension() != "uid":
			continue
		var uid: String = FileAccess.get_file_as_string(path).strip_edges()
		assert_true(
			uid.begins_with("uid://") and uid.length() > "uid://".length(),
			"%s should contain a single uid:// identifier, got %s" % [path, uid]
		)
		assert_false(
			seen.has(uid),
			"duplicate UID %s in %s and %s" % [uid, path, seen.get(uid, "")]
		)
		seen[uid] = path


## Recursively lists files under dir_path. DirAccess skips hidden entries by
## default, which keeps the editor cache (.godot/) and VCS internals out.
func _collect_files(dir_path: String, files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		fail_test("could not open %s: %s" % [dir_path, error_string(DirAccess.get_open_error())])
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var entry_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_files(entry_path, files)
		else:
			files.append(entry_path)
		entry = dir.get_next()
	dir.list_dir_end()
