extends GutTest

const COMBAT_TEXTURE: Texture2D = preload("res://assets/sprites/fx/combat_fx.png")
const BOLT_TEXTURE: Texture2D = preload("res://assets/sprites/fx/energy_bolt.png")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func test_generated_fx_sheets_have_manifest_dimensions() -> void:
	assert_eq(COMBAT_TEXTURE.get_size(), Vector2(264.0, 64.0))
	assert_eq(BOLT_TEXTURE.get_size(), Vector2(80.0, 24.0))


func test_combat_effects_have_authored_frame_counts_and_do_not_loop() -> void:
	_assert_effect(CombatFxSpawner.SLASH, 4)
	_assert_effect(CombatFxSpawner.SPARK, 4)
	_assert_effect(CombatFxSpawner.DASH, 3)
	_assert_effect(CombatFxSpawner.DISSOLVE, 6)


func test_bolt_flight_loops_and_impact_finishes() -> void:
	var flight: SpriteFrames = CombatFxSpawner.bolt_flight_frames()
	assert_eq(flight.get_frame_count(CombatFxSpawner.BOLT_FLIGHT), 4)
	assert_true(flight.get_animation_loop(CombatFxSpawner.BOLT_FLIGHT))

	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	CombatFxSpawner.spawn_bolt_impact(parent, Vector2.ZERO)
	var impact: AnimatedSprite2D = parent.get_child(0) as AnimatedSprite2D
	assert_not_null(impact)
	assert_eq(impact.sprite_frames.get_frame_count(CombatFxSpawner.BOLT_IMPACT), 5)
	assert_false(impact.sprite_frames.get_animation_loop(CombatFxSpawner.BOLT_IMPACT))


func test_player_actions_spawn_visual_only_effects() -> void:
	var parent: Node2D = Node2D.new()
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(parent)
	parent.add_child(player)

	player._movement.update(Vector2.RIGHT, true, 0.0)
	assert_eq(_animated_fx_count(parent), 1)

	assert_true(player.try_melee_attack())
	assert_eq(_animated_fx_count(parent), 2)


func _assert_effect(animation_name: StringName, expected_frames: int) -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	match animation_name:
		CombatFxSpawner.SLASH:
			CombatFxSpawner.spawn_slash(parent, Vector2.ZERO, Vector2.RIGHT)
		CombatFxSpawner.SPARK:
			CombatFxSpawner.spawn_spark(parent, Vector2.ZERO)
		CombatFxSpawner.DASH:
			CombatFxSpawner.spawn_dash_trail(parent, Vector2.ZERO, Vector2.RIGHT)
		CombatFxSpawner.DISSOLVE:
			CombatFxSpawner.spawn_dissolve(parent, Vector2.ZERO)
	var effect: AnimatedSprite2D = parent.get_child(0) as AnimatedSprite2D
	assert_not_null(effect)
	assert_eq(effect.sprite_frames.get_frame_count(animation_name), expected_frames)
	assert_false(effect.sprite_frames.get_animation_loop(animation_name))
	assert_eq(effect.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func _animated_fx_count(parent: Node2D) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is AnimatedSprite2D:
			count += 1
	return count
