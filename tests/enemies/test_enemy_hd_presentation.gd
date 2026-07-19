extends GutTest
## Production HD roster contract for issue #154. Static illustrated bodies are
## presentation-only: the legacy SpriteFrames and live EnemyBase/archetype
## state remain loaded and drive facing, tells, hit feedback, shield direction,
## death tint, and pass-through behavior.

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
		assert_almost_eq(
			presentation.get_body_sprite().scale.y * float(texture.get_height()),
			presentation.display_height_px,
			0.01
		)


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
