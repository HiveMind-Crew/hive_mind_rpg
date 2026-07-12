extends GutTest

const ENERGY_COMPONENT_SCENE: PackedScene = preload(
	"res://scenes/combat/energy_component.tscn"
)

var _energy: EnergyComponent


func before_each() -> void:
	_energy = ENERGY_COMPONENT_SCENE.instantiate() as EnergyComponent
	_energy.max_energy = 100.0
	_energy.regeneration_per_second = 20.0
	add_child_autofree(_energy)


func test_starts_full() -> void:
	assert_eq(_energy.current_energy, 100.0)


func test_spend_deducts_energy_and_rejects_insufficient_balance() -> void:
	assert_true(_energy.spend(75.0))
	assert_eq(_energy.current_energy, 25.0)
	assert_false(_energy.spend(25.01))
	assert_eq(_energy.current_energy, 25.0)


func test_spend_rejects_non_positive_costs() -> void:
	assert_false(_energy.spend(0.0))
	assert_false(_energy.spend(-1.0))
	assert_eq(_energy.current_energy, 100.0)


func test_regeneration_is_passive_and_bounded_at_maximum() -> void:
	_energy.spend(30.0)
	_energy._physics_process(1.0)
	assert_eq(_energy.current_energy, 90.0)
	_energy._physics_process(1.0)
	assert_eq(_energy.current_energy, 100.0)


func test_changes_emit_current_and_maximum_energy() -> void:
	watch_signals(_energy)
	_energy.spend(25.0)
	assert_signal_emitted_with_parameters(_energy, "energy_changed", [75.0, 100.0])
