extends GutTest
## End-to-end coverage for issue #17: unlocking a skill changes the player's
## gameplay values immediately, and respec reverts them — one effect per
## branch (Steel attack, Relic bolt damage, Body max HP).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

const STEEL_ATTACK: StringName = &"steel_tempered_edge"
const BODY_HP: StringName = &"body_scar_tissue"
const RELIC_BOLT: StringName = &"relic_resonant_spark"

const BASE_MELEE_DAMAGE: int = 10
const BASE_BOLT_DAMAGE: int = 20

var _player: PlayerController
var _health: HealthComponent
var _energy: EnergyComponent


func before_each() -> void:
	GameState.reset_progress()
	TimeScaleManager.reset()
	_player = PLAYER_SCENE.instantiate() as PlayerController
	# Baselines large enough that the multipliers round to visible changes.
	_player.melee_damage = BASE_MELEE_DAMAGE
	_player.energy_bolt_damage = BASE_BOLT_DAMAGE
	add_child_autofree(_player)
	_health = _player.get_node("HealthComponent") as HealthComponent
	_energy = _player.get_node("EnergyComponent") as EnergyComponent


func after_each() -> void:
	GameState.reset_progress()
	for projectile: Node in get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP):
		projectile.free()


func test_steel_unlock_raises_melee_damage_immediately() -> void:
	assert_eq(_player.get_effective_melee_damage(), BASE_MELEE_DAMAGE)

	GameState.award_skill_points(1)
	GameState.spend_points(STEEL_ATTACK)

	assert_eq(_player.get_effective_melee_damage(), 11)


func test_body_unlock_raises_max_and_current_hp() -> void:
	var base_max: int = _health.max_health

	GameState.award_skill_points(1)
	GameState.spend_points(BODY_HP)

	assert_eq(_health.max_health, base_max + 10)
	assert_eq(_health.current_health, base_max + 10)


func test_relic_unlock_raises_spawned_bolt_damage() -> void:
	GameState.award_skill_points(1)
	GameState.spend_points(RELIC_BOLT)

	assert_true(_player.try_relic_ability())
	var bolts: Array[Node] = get_tree().get_nodes_in_group(EnergyBolt.PROJECTILE_GROUP)
	assert_eq(bolts.size(), 1)
	assert_eq((bolts[0] as EnergyBolt).damage, 23)


func test_respec_reverts_every_effect() -> void:
	GameState.award_skill_points(3)
	GameState.spend_points(STEEL_ATTACK)
	GameState.spend_points(BODY_HP)
	GameState.spend_points(RELIC_BOLT)
	var base_max: int = _health.max_health - 10

	GameState.respec_skills()

	assert_eq(_player.get_effective_melee_damage(), BASE_MELEE_DAMAGE)
	assert_eq(_player.get_effective_bolt_damage(), BASE_BOLT_DAMAGE)
	assert_eq(_health.max_health, base_max)
	assert_true(_health.current_health <= _health.max_health)


func test_damaged_player_keeps_missing_health_through_hp_unlock() -> void:
	_health.take_damage(3)
	var damaged_health: int = _health.current_health

	GameState.award_skill_points(1)
	GameState.spend_points(BODY_HP)

	# The +10 max also grants +10 current, but missing health stays missing.
	assert_eq(_health.current_health, damaged_health + 10)
