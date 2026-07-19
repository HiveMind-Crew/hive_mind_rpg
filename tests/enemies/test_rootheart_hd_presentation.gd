extends GutTest
## Production boss-presentation contract for issue #155. The Rootheart's
## illustrated phase bodies and attack cues mirror the existing BossBase and
## EnemyBase state; they never own damage, phase thresholds, or collision.

const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/rootheart_colossus.tscn")
const EXPECTED_ASSET_DIMENSIONS: Dictionary[String, Vector2i] = {
	"res://assets/sprites/enemies/hd/boss/rootheart_phase_one.png": Vector2i(256, 256),
	"res://assets/sprites/enemies/hd/boss/rootheart_phase_two.png": Vector2i(256, 256),
	"res://assets/sprites/enemies/hd/boss/rootheart_slam_tell.png": Vector2i(256, 256),
	"res://assets/sprites/enemies/hd/boss/rootheart_radial_burst.png": Vector2i(256, 256),
}
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

var _arena: Node2D
var _boss: RootheartColossus
var _presentation: RootheartHdPresentation


func before_each() -> void:
	GameState.reset_progress()
	_arena = Node2D.new()
	add_child_autofree(_arena)
	_boss = BOSS_SCENE.instantiate() as RootheartColossus
	_arena.add_child(_boss)
	_boss.health.invulnerability_duration = 0.0
	_presentation = _boss.get_node("HdPresentation") as RootheartHdPresentation


func after_each() -> void:
	GameState.reset_progress()


func _make_target(offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	target.global_position = _boss.global_position + offset
	return target


func test_assets_are_alpha_pngs_with_production_import_settings() -> void:
	for asset_path: String in EXPECTED_ASSET_DIMENSIONS:
		var file: FileAccess = FileAccess.open(asset_path, FileAccess.READ)
		assert_not_null(file, "Missing Rootheart HD asset: %s" % asset_path)
		if file == null:
			continue
		assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
		var texture: Texture2D = load(asset_path) as Texture2D
		assert_not_null(texture)
		assert_eq(
			Vector2i(texture.get_width(), texture.get_height()),
			EXPECTED_ASSET_DIMENSIONS[asset_path]
		)
		var image: Image = texture.get_image()
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE)
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		var import_text: String = FileAccess.get_file_as_string(asset_path + ".import")
		assert_string_contains(import_text, "compress/mode=0")
		assert_string_contains(import_text, "mipmaps/generate=false")
		assert_string_contains(import_text, "process/premult_alpha=false")
		assert_string_contains(import_text, "process/fix_alpha_border=true")


func test_scene_replaces_only_legacy_display_nodes() -> void:
	var legacy_body: Polygon2D = _boss.get_node("BodyVisual") as Polygon2D
	var legacy_tell: Polygon2D = _boss.get_node("TellVisual") as Polygon2D
	var collision: CollisionShape2D = _boss.get_node("CollisionShape2D") as CollisionShape2D
	var body_shape: CircleShape2D = collision.shape as CircleShape2D

	assert_false(legacy_body.visible)
	assert_false(legacy_tell.visible)
	assert_eq(_presentation.get_phase_one_body().texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(_presentation.get_phase_two_body().texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(_presentation.get_slam_tell().texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(_presentation.get_radial_cue().texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_almost_eq(
		_presentation.get_phase_one_body().scale.y
			* float(_presentation.get_phase_one_body().texture.get_height()),
		RootheartHdPresentation.BODY_DISPLAY_HEIGHT_PX,
		0.01
	)
	assert_almost_eq(body_shape.radius, 16.0, 0.001)
	assert_eq(_boss.stats.attack_range, 40.0)
	assert_eq(_boss.phase_health_thresholds, [0.5])


func test_live_phase_switches_body_and_plays_radial_cue() -> void:
	assert_true(_presentation.get_phase_one_body().visible)
	assert_false(_presentation.get_phase_two_body().visible)
	assert_false(_presentation.get_radial_cue().visible)

	_boss.health.take_damage(15)

	assert_eq(_boss.get_phase(), 1)
	assert_false(_presentation.get_phase_one_body().visible)
	assert_true(_presentation.get_phase_two_body().visible)
	assert_true(_presentation.get_radial_cue().visible)
	assert_eq(
		get_tree().get_nodes_in_group(EnemyBolt.PROJECTILE_GROUP).size(),
		_boss.burst_bolt_count,
		"Presentation must follow, not replace, the live radial burst."
	)


func test_live_windup_drives_slam_tell_and_attack_tint() -> void:
	_boss.set_target(_make_target(Vector2(30.0, 0.0)))
	_boss._physics_process(0.0)

	assert_eq(_boss.state, EnemyBase.State.WIND_UP)
	assert_true(_presentation.get_slam_tell().visible)
	assert_eq(_presentation.get_phase_one_body().modulate, EnemyBase.WIND_UP_COLOR)

	_boss._physics_process(_boss.stats.wind_up_duration)

	assert_eq(_boss.state, EnemyBase.State.ATTACK)
	assert_false(_presentation.get_slam_tell().visible)
	assert_eq(_presentation.get_phase_one_body().modulate, EnemyBase.ATTACK_COLOR)


func test_phase_two_slam_recovery_replays_radial_cue() -> void:
	_boss.health.take_damage(15)
	await wait_seconds(RootheartHdPresentation.RADIAL_PULSE_DURATION_SECONDS + 0.05)
	assert_false(_presentation.get_radial_cue().visible)
	_boss.set_target(_make_target(Vector2(30.0, 0.0)))
	_boss._physics_process(0.0)
	_boss._physics_process(_boss.stats.wind_up_duration)
	_boss._physics_process(_boss.stats.attack_duration)

	assert_eq(_boss.state, EnemyBase.State.RECOVERY)
	assert_true(_presentation.get_radial_cue().visible)


func test_defeat_tints_the_live_body_and_removes_grounding() -> void:
	_boss.health.take_damage(15)
	assert_true(_presentation.get_radial_cue().visible)
	_boss.health.take_damage(99999)

	assert_eq(_boss.state, EnemyBase.State.DEAD)
	assert_eq(_presentation.get_phase_two_body().modulate, EnemyBase.DEAD_COLOR)
	assert_false(_presentation.get_contact_shadow().visible)
	assert_false(_presentation.get_slam_tell().visible)
	assert_false(_presentation.get_radial_cue().visible)
