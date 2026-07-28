extends GutTest
## Production HD roster contract for issues #154 and #204. Static illustrated
## bodies are presentation-only: the legacy SpriteFrames and live EnemyBase/
## archetype state remain loaded and drive facing, tells, hit feedback, shield
## direction, death tint, and pass-through behavior. Issue #204 adds per-
## archetype 6-row × 4-column pose atlases; EnemyHdPresentation selects the
## correct row/column from live state and _state_elapsed.

const ROSTER_SCENES: Dictionary[String, PackedScene] = {
	"melee_chaser": preload("res://scenes/enemies/melee_chaser.tscn"),
	"fast_flanker": preload("res://scenes/enemies/fast_flanker.tscn"),
	"ranged_harasser": preload("res://scenes/enemies/ranged_harasser.tscn"),
	"shielded_brute": preload("res://scenes/enemies/shielded_brute.tscn"),
}
const EXPECTED_DIMENSIONS: Dictionary[String, Vector2i] = {
	"melee_chaser": Vector2i(316, 384),
	"fast_flanker": Vector2i(239, 384),
	"ranged_harasser": Vector2i(179, 384),
	"shielded_brute": Vector2i(379, 384),
}
const EXPECTED_ATLAS_DIMENSIONS: Dictionary[String, Vector2i] = {
	"melee_chaser": Vector2i(1264, 2304),
	"fast_flanker": Vector2i(956, 2304),
	"ranged_harasser": Vector2i(716, 2304),
	"shielded_brute": Vector2i(1516, 2304),
}


func test_roster_uses_distinct_alpha_pngs_and_linear_hd_nodes() -> void:
	var textures_seen: Dictionary[String, bool] = {}
	for enemy_name: String in ROSTER_SCENES:
		var texture_path: String = "res://assets/sprites/enemies/hd/%s.png" % enemy_name
		var texture: Texture2D = load(texture_path) as Texture2D
		assert_not_null(texture, "%s must import as a texture." % texture_path)
		assert_eq(
			Vector2i(texture.get_width(), texture.get_height()),
			EXPECTED_DIMENSIONS[enemy_name]
		)
		assert_false(textures_seen.has(texture_path), "Each archetype needs distinct art.")
		textures_seen[texture_path] = true
		var image: Image = texture.get_image()
		assert_ne(
			image.detect_alpha(), Image.ALPHA_NONE,
			"%s must preserve transparent bounds." % enemy_name
		)
		assert_eq(image.get_pixel(0, 0).a, 0.0, "%s needs a transparent corner." % enemy_name)

		var enemy: EnemyBase = ROSTER_SCENES[enemy_name].instantiate() as EnemyBase
		add_child_autofree(enemy)
		var legacy: AnimatedSprite2D = enemy.get_node("BodyVisual") as AnimatedSprite2D
		var presentation: EnemyHdPresentation = (
			enemy.get_node("HdPresentation") as EnemyHdPresentation
		)
		assert_false(legacy.visible, "Legacy body must not double-draw for %s." % enemy_name)
		assert_not_null(legacy.sprite_frames, "Legacy state driver must remain loaded.")
		assert_eq(legacy.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(
			presentation.get_body_sprite().texture_filter,
			CanvasItem.TEXTURE_FILTER_LINEAR
		)
		# Display-height contract: scale × source cell height == display_height_px.
		# Cell height matches the single-portrait height so the contract holds for both
		# the legacy body_texture path and the atlas-region path.
		assert_almost_eq(
			presentation.get_body_sprite().scale.y * float(texture.get_height()),
			presentation.display_height_px,
			0.01
		)


func test_roster_scenes_assign_distinct_pose_atlases() -> void:
	var atlas_ids_seen: Dictionary[int, bool] = {}
	for enemy_name: String in ROSTER_SCENES:
		var enemy: EnemyBase = ROSTER_SCENES[enemy_name].instantiate() as EnemyBase
		add_child_autofree(enemy)
		var presentation: EnemyHdPresentation = (
			enemy.get_node("HdPresentation") as EnemyHdPresentation
		)
		assert_not_null(
			presentation.pose_atlas,
			"Scene must assign pose_atlas for %s." % enemy_name
		)
		if presentation.pose_atlas == null:
			continue

		var body: Sprite2D = presentation.get_body_sprite()
		assert_true(
			body.region_enabled,
			"pose_atlas path enables region on the body Sprite2D for %s." % enemy_name
		)
		assert_eq(
			Vector2i(presentation.pose_atlas.get_width(), presentation.pose_atlas.get_height()),
			EXPECTED_ATLAS_DIMENSIONS[enemy_name],
			"Atlas dimensions match the 6-row × 4-column generator contract for %s." % enemy_name
		)

		var atlas_id: int = presentation.pose_atlas.get_instance_id()
		assert_false(
			atlas_ids_seen.has(atlas_id),
			"Each archetype must use a distinct pose atlas."
		)
		atlas_ids_seen[atlas_id] = true


func test_state_to_atlas_row_maps_all_states() -> void:
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.IDLE), EnemyHdPresentation.ATLAS_ROW_IDLE)
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.CHASE), EnemyHdPresentation.ATLAS_ROW_CHASE)
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.WIND_UP), EnemyHdPresentation.ATLAS_ROW_WINDUP)
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.ATTACK), EnemyHdPresentation.ATLAS_ROW_ATTACK)
	# RECOVERY maps to idle row — safe idle visual, no dedicated row in the atlas.
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.RECOVERY), EnemyHdPresentation.ATLAS_ROW_IDLE)
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.STAGGER), EnemyHdPresentation.ATLAS_ROW_STAGGER)
	assert_eq(EnemyHdPresentation.state_to_atlas_row(EnemyBase.State.DEAD), EnemyHdPresentation.ATLAS_ROW_DEATH)


func test_atlas_frame_resets_to_zero_on_state_changed() -> void:
	var enemy: EnemyBase = ROSTER_SCENES["melee_chaser"].instantiate() as EnemyBase
	add_child_autofree(enemy)
	var presentation: EnemyHdPresentation = (
		enemy.get_node("HdPresentation") as EnemyHdPresentation
	)
	var body: Sprite2D = presentation.get_body_sprite()

	# Advance time to a non-zero frame.
	presentation._process(EnemyHdPresentation.POSE_FRAME_SECONDS + 0.01)
	assert_gt(body.region_rect.position.x, 0.0, "Frame advances beyond zero with elapsed time.")

	# Emit state_changed to reset _state_elapsed to 0.
	enemy.state_changed.emit(EnemyBase.State.IDLE, EnemyBase.State.CHASE)
	enemy.state = EnemyBase.State.CHASE
	presentation._process(0.0)
	assert_eq(body.region_rect.position.x, 0.0, "State change resets the atlas column to frame 0.")


func test_atlas_frame_advances_with_state_elapsed() -> void:
	var enemy: EnemyBase = ROSTER_SCENES["fast_flanker"].instantiate() as EnemyBase
	add_child_autofree(enemy)
	var presentation: EnemyHdPresentation = (
		enemy.get_node("HdPresentation") as EnemyHdPresentation
	)
	var body: Sprite2D = presentation.get_body_sprite()
	var cell_w: float = body.region_rect.size.x

	# Fresh state — frame 0.
	presentation._process(0.0)
	assert_eq(body.region_rect.position.x, 0.0, "Frame 0 at zero elapsed time.")

	# Advance past one frame boundary.
	enemy.state_changed.emit(EnemyBase.State.IDLE, EnemyBase.State.CHASE)
	enemy.state = EnemyBase.State.CHASE
	presentation._process(EnemyHdPresentation.POSE_FRAME_SECONDS + 0.001)
	var col_one: int = int(round(body.region_rect.position.x / cell_w))
	assert_eq(col_one, 1, "Frame advances to column 1 after one POSE_FRAME_SECONDS.")

	# Advance two more frame boundaries.
	presentation._process(EnemyHdPresentation.POSE_FRAME_SECONDS * 2.0)
	var col_three: int = int(round(body.region_rect.position.x / cell_w))
	assert_eq(col_three, 3, "Frame reaches column 3 after three POSE_FRAME_SECONDS.")


func test_dead_state_uses_death_row_and_terminal_frame() -> void:
	var enemy: EnemyBase = ROSTER_SCENES["melee_chaser"].instantiate() as EnemyBase
	add_child_autofree(enemy)
	var presentation: EnemyHdPresentation = (
		enemy.get_node("HdPresentation") as EnemyHdPresentation
	)
	var body: Sprite2D = presentation.get_body_sprite()
	var cell_h: float = body.region_rect.size.y
	var cell_w: float = body.region_rect.size.x

	# Transition to DEAD and reset state elapsed.
	enemy.state = EnemyBase.State.DEAD
	enemy.state_changed.emit(EnemyBase.State.CHASE, EnemyBase.State.DEAD)
	presentation._process(0.0)

	var row: int = int(round(body.region_rect.position.y / cell_h))
	assert_eq(row, EnemyHdPresentation.ATLAS_ROW_DEATH, "Dead state selects the death atlas row.")

	# Advance far past the last frame — must clamp, not wrap.
	presentation._process(EnemyHdPresentation.POSE_FRAME_SECONDS * 100.0)
	var col: int = int(round(body.region_rect.position.x / cell_w))
	assert_eq(
		col,
		EnemyHdPresentation.ATLAS_COLUMNS - 1,
		"Dead frame clamps at the last column and does not wrap."
	)
	assert_eq(enemy.state, EnemyBase.State.DEAD, "Presentation time does not extend gameplay state.")
	assert_false(presentation.get_facing_accent().visible, "Facing accent hidden on death.")


func test_live_facing_and_combat_states_drive_the_static_body() -> void:
	var enemy: EnemyBase = ROSTER_SCENES["melee_chaser"].instantiate() as EnemyBase
	var target: Node2D = Node2D.new()
	add_child_autofree(enemy)
	add_child_autofree(target)
	target.global_position = enemy.global_position + Vector2.LEFT * 64.0
	enemy.set_target(target)
	enemy.state = EnemyBase.State.WIND_UP
	enemy._apply_state_visuals()
	var legacy: AnimatedSprite2D = enemy.get_node("BodyVisual") as AnimatedSprite2D
	var presentation: EnemyHdPresentation = (
		enemy.get_node("HdPresentation") as EnemyHdPresentation
	)
	legacy.self_modulate = Color(1.0, 0.5, 0.5, 1.0)
	presentation._process(0.0)

	assert_true(presentation.get_body_sprite().flip_h)
	assert_eq(presentation.get_body_sprite().modulate, EnemyBase.WIND_UP_COLOR)
	assert_eq(presentation.get_body_sprite().self_modulate, legacy.self_modulate)
	assert_eq(presentation.get_facing_direction(), Vector2.LEFT)
	assert_true(presentation.get_facing_accent().visible)
	assert_lt(presentation.get_facing_accent().position.x, 0.0)

	enemy.state = EnemyBase.State.DEAD
	presentation._process(0.0)
	assert_eq(presentation.get_body_sprite().modulate, EnemyBase.DEAD_COLOR)
	assert_false(presentation.get_facing_accent().visible)


func test_hd_body_uses_live_state_poses_without_changing_enemy_state() -> void:
	var enemy: EnemyBase = ROSTER_SCENES["fast_flanker"].instantiate() as EnemyBase
	var target: Node2D = Node2D.new()
	add_child_autofree(enemy)
	add_child_autofree(target)
	target.global_position = enemy.global_position + Vector2.RIGHT * 64.0
	enemy.set_target(target)
	var presentation: EnemyHdPresentation = enemy.get_node("HdPresentation") as EnemyHdPresentation
	var body: Sprite2D = presentation.get_body_sprite()
	var cell_h: float = body.region_rect.size.y

	# Wind-up: atlas selects the windup row; the atlas bakes the anticipation
	# pose so no additional position offset or non-uniform scale is applied.
	enemy.state = EnemyBase.State.WIND_UP
	presentation._process(0.0)
	var windup_row: int = int(round(body.region_rect.position.y / cell_h))
	assert_eq(windup_row, EnemyHdPresentation.ATLAS_ROW_WINDUP, "Wind-up selects the windup atlas row.")
	assert_almost_eq(
		body.position.x, presentation.body_offset.x, 0.01,
		"Atlas owns the windup pose; no extra position offset from the transform bridge."
	)
	assert_almost_eq(body.scale.x, body.scale.y, 0.001, "Atlas path uses uniform scale.")

	# Attack: atlas selects the attack row.
	enemy.state = EnemyBase.State.ATTACK
	presentation._process(0.0)
	var attack_row: int = int(round(body.region_rect.position.y / cell_h))
	assert_eq(attack_row, EnemyHdPresentation.ATLAS_ROW_ATTACK, "Attack selects the attack atlas row.")

	# Dead: atlas selects the death row; facing accent is hidden.
	enemy.state = EnemyBase.State.DEAD
	presentation._process(0.0)
	var dead_row: int = int(round(body.region_rect.position.y / cell_h))
	assert_eq(dead_row, EnemyHdPresentation.ATLAS_ROW_DEATH, "Dead selects the death atlas row.")
	assert_false(presentation.get_facing_accent().visible, "Facing accent hidden on death.")
	# No gameplay state was changed by the presentation layer.
	assert_eq(enemy.state, EnemyBase.State.DEAD)


func test_brute_facing_accent_uses_the_live_shield_direction() -> void:
	var brute: ShieldedBrute = ROSTER_SCENES["shielded_brute"].instantiate() as ShieldedBrute
	var target: Node2D = Node2D.new()
	add_child_autofree(brute)
	add_child_autofree(target)
	target.global_position = brute.global_position + Vector2.RIGHT * 64.0
	brute.set_target(target)
	brute._physics_process(1.0)
	var presentation: EnemyHdPresentation = (
		brute.get_node("HdPresentation") as EnemyHdPresentation
	)
	presentation._process(0.0)

	assert_gt(brute.get_facing().x, 0.99)
	assert_gt(presentation.get_facing_accent().position.x, 0.0)
	assert_almost_eq(
		presentation.get_facing_accent().rotation,
		brute.get_facing().angle(),
		0.001
	)
