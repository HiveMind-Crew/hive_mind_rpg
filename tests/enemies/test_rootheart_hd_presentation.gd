extends GutTest
## Production boss-presentation contract for issues #155/#205. The Rootheart's
## illustrated phase bodies and attack cues mirror the existing BossBase and
## EnemyBase state; they never own damage, phase thresholds, or collision.

const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/rootheart_colossus.tscn")
const EXPECTED_ASSET_DIMENSIONS: Dictionary[String, Vector2i] = {
	"res://assets/sprites/enemies/hd/boss/rootheart_phase_one_poses.png": Vector2i(768, 2048),
	"res://assets/sprites/enemies/hd/boss/rootheart_phase_two_poses.png": Vector2i(768, 2048),
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


func test_pose_cells_keep_transform_margins_and_read_as_distinct_slam_phases() -> void:
	for asset_path: String in EXPECTED_ASSET_DIMENSIONS:
		var texture: Texture2D = load(asset_path) as Texture2D
		assert_not_null(texture)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		for row: int in RootheartHdPresentation.PoseRow.size():
			for frame: int in RootheartHdPresentation.POSE_FRAME_COUNT:
				var cell: Image = image.get_region(Rect2i(
					frame * int(RootheartHdPresentation.POSE_CELL_SIZE.x),
					row * int(RootheartHdPresentation.POSE_CELL_SIZE.y),
					int(RootheartHdPresentation.POSE_CELL_SIZE.x),
					int(RootheartHdPresentation.POSE_CELL_SIZE.y),
				))
				var used: Rect2i = cell.get_used_rect()
				assert_gt(used.position.x, 0, "%s row %d frame %d clips left" % [asset_path, row, frame])
				assert_gt(used.position.y, 0, "%s row %d frame %d clips top" % [asset_path, row, frame])
				assert_lt(used.end.x, int(RootheartHdPresentation.POSE_CELL_SIZE.x), "%s row %d frame %d clips right" % [asset_path, row, frame])
				assert_lt(used.end.y, int(RootheartHdPresentation.POSE_CELL_SIZE.y), "%s row %d frame %d clips bottom" % [asset_path, row, frame])
		var windup: Rect2i = image.get_region(Rect2i(0, int(RootheartHdPresentation.PoseRow.WINDUP) * 256, 256, 256)).get_used_rect()
		var contact: Rect2i = image.get_region(Rect2i(256, int(RootheartHdPresentation.PoseRow.CONTACT) * 256, 256, 256)).get_used_rect()
		var recovery: Rect2i = image.get_region(Rect2i(0, int(RootheartHdPresentation.PoseRow.RECOVERY) * 256, 256, 256)).get_used_rect()
		assert_gt(windup.size.y, contact.size.y, "Wind-up must read taller than the committed slam.")
		assert_gt(contact.size.x, windup.size.x, "Committed slam must read broader than wind-up.")
		assert_ne(recovery, windup, "Recovery must be a follow-through, not a wind-up replay.")


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
	assert_true(_presentation.get_phase_one_body().region_enabled)
	assert_true(_presentation.get_phase_two_body().region_enabled)
	assert_eq(
		_presentation.get_phase_one_body().region_rect,
		RootheartHdPresentation.pose_region_for(RootheartHdPresentation.PoseRow.DORMANT, 0)
	)
	assert_almost_eq(
		_presentation.get_phase_one_body().scale.y
			* RootheartHdPresentation.POSE_CONTENT_HEIGHT_PX,
		RootheartHdPresentation.BODY_DISPLAY_HEIGHT_PX,
		0.01
	)
	assert_almost_eq(
		_presentation.get_slam_tell().scale.y * float(_presentation.get_slam_tell().texture.get_height()),
		RootheartHdPresentation.SLAM_TELL_DIAMETER_PX,
		0.01
	)
	assert_almost_eq(
		_presentation.get_radial_cue().scale.y * float(_presentation.get_radial_cue().texture.get_height()),
		RootheartHdPresentation.RADIAL_CUE_DIAMETER_PX,
		0.01
	)
	assert_almost_eq(body_shape.radius, 16.0, 0.001)
	assert_eq(_boss.stats.attack_range, 40.0)
	assert_eq(_boss.phase_health_thresholds, [0.5])


func test_live_phase_switches_body_and_plays_radial_cue() -> void:
	assert_true(_presentation.get_phase_one_body().visible)
	assert_false(_presentation.get_phase_two_body().visible)
	assert_false(_presentation.get_radial_cue().visible)
	# Prove phase-channel priority after the deferred real-hit subscription is live.
	await get_tree().process_frame
	_boss.health.take_damage(15)

	assert_eq(_boss.get_phase(), 1)
	assert_false(_presentation.get_phase_one_body().visible)
	assert_true(_presentation.get_phase_two_body().visible)
	assert_true(_presentation.get_radial_cue().visible)
	assert_eq(
		_presentation.get_phase_two_body().region_rect,
		RootheartHdPresentation.pose_region_for(RootheartHdPresentation.PoseRow.BURST, 0)
	)
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
	assert_eq(
		_presentation.get_phase_one_body().region_rect,
		RootheartHdPresentation.pose_region_for(RootheartHdPresentation.PoseRow.WINDUP, 0)
	)

	_boss._physics_process(_boss.stats.wind_up_duration)

	assert_eq(_boss.state, EnemyBase.State.ATTACK)
	assert_false(_presentation.get_slam_tell().visible)
	assert_eq(_presentation.get_phase_one_body().modulate, EnemyBase.ATTACK_COLOR)
	assert_eq(
		_presentation.get_phase_one_body().region_rect,
		RootheartHdPresentation.pose_region_for(RootheartHdPresentation.PoseRow.CONTACT, 0)
	)


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
	assert_eq(
		_presentation.get_phase_two_body().region_rect,
		RootheartHdPresentation.pose_region_for(RootheartHdPresentation.PoseRow.BURST, 0)
	)


func test_defeat_tints_the_live_body_and_removes_grounding() -> void:
	_boss.health.take_damage(15)
	assert_true(_presentation.get_radial_cue().visible)
	_boss.health.take_damage(99999)

	assert_eq(_boss.state, EnemyBase.State.DEAD)
	assert_eq(_presentation.get_phase_two_body().modulate, EnemyBase.DEAD_COLOR)
	assert_eq(
		_presentation.get_phase_two_body().region_rect,
		RootheartHdPresentation.pose_region_for(
			RootheartHdPresentation.PoseRow.DEFEAT,
			RootheartHdPresentation.POSE_FRAME_COUNT - 1,
		)
	)
	assert_false(_presentation.get_contact_shadow().visible)
	assert_false(_presentation.get_slam_tell().visible)
	assert_false(_presentation.get_radial_cue().visible)


func test_pose_row_mapping_covers_all_live_enemy_states_without_mechanics_ownership() -> void:
	var expectations: Array[Array] = [
		[EnemyBase.State.IDLE, RootheartHdPresentation.PoseRow.DORMANT],
		[EnemyBase.State.CHASE, RootheartHdPresentation.PoseRow.AWAKENING],
		[EnemyBase.State.WIND_UP, RootheartHdPresentation.PoseRow.WINDUP],
		[EnemyBase.State.ATTACK, RootheartHdPresentation.PoseRow.CONTACT],
		[EnemyBase.State.RECOVERY, RootheartHdPresentation.PoseRow.RECOVERY],
		[EnemyBase.State.STAGGER, RootheartHdPresentation.PoseRow.HIT],
		[EnemyBase.State.DEAD, RootheartHdPresentation.PoseRow.DEFEAT],
	]
	for expectation: Array in expectations:
		assert_eq(
			RootheartHdPresentation.pose_row_for(expectation[0] as EnemyBase.State, false),
			expectation[1] as RootheartHdPresentation.PoseRow,
		)
	assert_eq(
		RootheartHdPresentation.pose_row_for(EnemyBase.State.RECOVERY, true),
		RootheartHdPresentation.PoseRow.BURST,
		"The existing phase/burst signal may temporarily override only the illustrated pose."
	)
	# Rootheart's shipped poise remains enabled: an accepted hit must drive its
	# presentation without entering STAGGER or interrupting the live pattern.
	await get_tree().process_frame
	assert_true(_boss.immune_to_stagger)
	_boss._on_hit_received(1, Vector2.ZERO, Hitbox.ImpactType.GENERIC)
	assert_ne(_boss.state, EnemyBase.State.STAGGER)
	assert_eq(
		_presentation.get_phase_one_body().region_rect,
		RootheartHdPresentation.pose_region_for(RootheartHdPresentation.PoseRow.HIT, 0)
	)
