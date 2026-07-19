extends GutTest
## Focused issue #169 coverage: the stylized-HD relic orb presentation must be
## driven by the real EnergyBolt/PlayerController pathways only — truthful
## launch rotation, cast strictly after a real spawn, one impact per bolt, and
## no mechanics drift on the scene-authored projectile contract.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")

const EIGHT_DIRECTIONS: Array[Vector2] = [
	Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
	Vector2(0.7071068, 0.7071068), Vector2(-0.7071068, 0.7071068),
	Vector2(-0.7071068, -0.7071068), Vector2(0.7071068, -0.7071068),
]

var _player: PlayerController
var _energy: EnergyComponent


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_energy = _player.get_node("EnergyComponent") as EnergyComponent


func after_each() -> void:
	for projectile: Node in get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP):
		projectile.free()
	# One-shot FX free themselves on animation_finished; sweep the ones still
	# mid-animation so counts never leak between tests.
	for child: Node in get_children():
		if child is AnimatedSprite2D:
			child.free()


func test_successful_cast_spawns_one_bolt_and_one_cast_flare_at_the_muzzle() -> void:
	_player._movement.update(Vector2.RIGHT, false, 0.016)

	assert_true(_player.try_relic_ability())

	assert_eq(get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP).size(), 1)
	var bolt: EnergyBolt = _player.get_parent().get_node("EnergyBolt") as EnergyBolt
	assert_not_null(bolt)
	var casts: Array[AnimatedSprite2D] = _find_fx(CombatFxSpawner.RELIC_CAST)
	assert_eq(casts.size(), 1)
	assert_eq(casts[0].global_position, bolt.global_position)
	assert_almost_eq(casts[0].rotation, Vector2.RIGHT.angle(), 0.0001)
	# The flare is a display-only AnimatedSprite2D, never a projectile owner.
	assert_false(casts[0].is_in_group(EnergyBolt.PROJECTILE_GROUP))


func test_blocked_cast_spawns_no_bolt_and_no_fake_presentation() -> void:
	assert_true(_energy.spend(_energy.max_energy))

	assert_false(_player.try_relic_ability())

	assert_eq(get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP).size(), 0)
	assert_eq(_find_fx(CombatFxSpawner.RELIC_CAST).size(), 0)
	assert_eq(_find_fx(CombatFxSpawner.RELIC_IMPACT).size(), 0)


func test_flight_visual_rotation_is_truthful_for_all_eight_launch_directions() -> void:
	for direction: Vector2 in EIGHT_DIRECTIONS:
		_energy.regenerate(_energy.max_energy)
		_player._movement.update(direction, false, 0.016)

		assert_true(_player.try_relic_ability(), "cast toward %s must succeed" % direction)

		var bolts: Array[Node] = get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP)
		assert_eq(bolts.size(), 1)
		var bolt: EnergyBolt = bolts[0] as EnergyBolt
		var expected: Vector2 = PlayerController.snap_to_eight_directions(direction)
		assert_almost_eq(bolt.direction.distance_to(expected), 0.0, 0.001)
		var flight: AnimatedSprite2D = bolt.get_node("FlightVisual") as AnimatedSprite2D
		assert_not_null(flight)
		assert_eq(flight.animation, CombatFxSpawner.RELIC_FLIGHT)
		assert_true(flight.is_playing())
		assert_almost_eq(flight.rotation, expected.angle(), 0.0001)
		assert_eq(flight.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
		bolt.free()


func test_ending_a_bolt_spawns_exactly_one_impact_burst() -> void:
	_player._movement.update(Vector2.RIGHT, false, 0.016)
	assert_true(_player.try_relic_ability())
	var bolt: EnergyBolt = _player.get_parent().get_node("EnergyBolt") as EnergyBolt

	bolt._end()
	bolt._end()

	assert_eq(_find_fx(CombatFxSpawner.RELIC_IMPACT).size(), 1)
	var impact: AnimatedSprite2D = _find_fx(CombatFxSpawner.RELIC_IMPACT)[0]
	assert_eq(impact.global_position, bolt.global_position)
	assert_false(impact.sprite_frames.get_animation_loop(CombatFxSpawner.RELIC_IMPACT))


func test_bolt_gameplay_contract_is_unchanged_by_the_hd_presentation() -> void:
	_player._movement.update(Vector2.RIGHT, false, 0.016)
	var energy_before: float = _energy.current_energy

	assert_true(_player.try_relic_ability())

	var bolt: EnergyBolt = _player.get_parent().get_node("EnergyBolt") as EnergyBolt
	assert_eq(bolt.speed, 360.0)
	assert_eq(bolt.lifetime, 1.5)
	assert_eq(bolt.collision_layer, 2)
	assert_eq(bolt.collision_mask, 5)
	assert_false(bolt.monitorable)
	assert_eq(bolt.impact_type, Hitbox.ImpactType.RELIC)
	var shape: CircleShape2D = (
		(bolt.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	)
	assert_eq(shape.radius, 4.0)
	assert_eq(_player.energy_bolt_cost, 25.0)
	assert_eq(_player.energy_bolt_spawn_offset, 24.0)
	assert_eq(_energy.current_energy, energy_before - _player.energy_bolt_cost)
	assert_eq(
		bolt.global_position,
		_player.global_position + Vector2.RIGHT * _player.energy_bolt_spawn_offset
	)
	# The scene placeholder stays hidden; the HD flight visual is display-only.
	var placeholder: CanvasItem = bolt.get_node("Visual") as CanvasItem
	assert_false(placeholder.visible)


func _find_fx(animation_name: StringName) -> Array[AnimatedSprite2D]:
	var found: Array[AnimatedSprite2D] = []
	for child: Node in _player.get_parent().get_children():
		var sprite: AnimatedSprite2D = child as AnimatedSprite2D
		if sprite != null and sprite.animation == animation_name:
			found.append(sprite)
	return found
