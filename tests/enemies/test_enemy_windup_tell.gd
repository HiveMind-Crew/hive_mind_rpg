extends GutTest
## Coverage for the stylized-HD combat FX pass (issue #157): the regular-enemy
## wind-up telegraph is now an HD sprite driven by the existing EnemyBase
## WIND_UP state, not a flat Polygon2D, and the shared HD sheets are documented
## imported assets. No gameplay, timing, hitbox, or AI behavior changes here.

const TELL_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/hd/enemy_windup_tell.png")
const TELL_PATH: String = "res://assets/sprites/enemies/hd/enemy_windup_tell.png"
const COMBAT_FX_PATH: String = "res://assets/sprites/fx/combat_fx_hd.png"
const COMBAT_FX_TEXTURE: Texture2D = preload("res://assets/sprites/fx/combat_fx_hd.png")
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

const ENEMY_SCENES: Array[String] = [
	"res://scenes/enemies/fast_flanker.tscn",
	"res://scenes/enemies/ranged_harasser.tscn",
	"res://scenes/enemies/shielded_brute.tscn",
]


func test_regular_enemy_tell_is_a_linear_filtered_hd_sprite_behind_the_actor() -> void:
	for scene_path: String in ENEMY_SCENES:
		var scene: PackedScene = load(scene_path)
		var enemy: EnemyBase = scene.instantiate() as EnemyBase
		add_child_autofree(enemy)
		var tell: Sprite2D = enemy.get_node("%TellVisual") as Sprite2D
		assert_not_null(tell, "%s tell must be an HD Sprite2D, not a flat Polygon2D." % scene_path)
		if tell == null:
			continue
		assert_eq(tell.texture, TELL_TEXTURE)
		assert_eq(tell.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
		assert_true(tell.show_behind_parent, "The tell haloes behind the actor.")
		assert_false(tell.visible, "The tell is hidden until the enemy winds up.")


func test_tell_visibility_still_tracks_the_wind_up_state() -> void:
	var enemy: FastFlanker = load(ENEMY_SCENES[0]).instantiate() as FastFlanker
	add_child_autofree(enemy)
	var tell: Sprite2D = enemy.get_node("%TellVisual") as Sprite2D
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	target.global_position = enemy.global_position + Vector2(90.0, 0.0)
	enemy.set_target(target)

	enemy._physics_process(0.0)
	assert_eq(enemy.state, EnemyBase.State.WIND_UP)
	assert_true(tell.visible, "Wind-up reveals the HD telegraph.")

	enemy._physics_process(enemy.stats.wind_up_duration)
	assert_eq(enemy.state, EnemyBase.State.ATTACK)
	assert_false(tell.visible, "The telegraph clears once the attack commits.")


func test_hd_fx_sheets_are_documented_imported_pngs() -> void:
	assert_eq(
		Vector2i(COMBAT_FX_TEXTURE.get_width(), COMBAT_FX_TEXTURE.get_height()), Vector2i(384, 256)
	)
	assert_eq(Vector2i(TELL_TEXTURE.get_width(), TELL_TEXTURE.get_height()), Vector2i(96, 96))
	for path: String in [COMBAT_FX_PATH, TELL_PATH]:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "Missing HD asset: %s" % path)
		if file == null:
			continue
		assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE, "%s is a real PNG." % path)
		var import_text: String = FileAccess.get_file_as_string(path + ".import")
		assert_string_contains(import_text, "compress/mode=0")
		assert_string_contains(import_text, "mipmaps/generate=false")
		assert_string_contains(import_text, "process/premult_alpha=false")
		assert_string_contains(import_text, "process/fix_alpha_border=true")
