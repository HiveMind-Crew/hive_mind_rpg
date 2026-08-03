extends GutTest

const HUD_SCENE: PackedScene = preload("res://scenes/ui/player_hud.tscn")

var _hud: PlayerHud
var _health: HealthComponent
var _energy: EnergyComponent


func before_each() -> void:
	_hud = HUD_SCENE.instantiate() as PlayerHud
	_health = HealthComponent.new()
	_health.max_health = 12
	_health.invulnerability_duration = 0.0
	_energy = EnergyComponent.new()
	_energy.max_energy = 80.0
	_energy.regeneration_per_second = 0.0
	add_child_autofree(_health)
	add_child_autofree(_energy)
	add_child_autofree(_hud)
	_hud.bind(_health, _energy)


func test_bind_immediately_displays_current_values() -> void:
	assert_eq(_hud.health_value, 12.0)
	assert_eq(_hud.energy_value, 80.0)
	assert_eq((_hud.get_node("%HealthLabel") as Label).text, "HP 12/12")
	assert_eq((_hud.get_node("%EnergyLabel") as Label).text, "Energy 80/80")


func test_desktop_combat_legend_exposes_live_input_map_bindings() -> void:
	assert_eq((_hud.get_node("%MeleeKeybind") as Label).text, "[J] Attack")
	assert_eq((_hud.get_node("%RelicKeybind") as Label).text, "[K] Relic")
	assert_eq((_hud.get_node("%DashKeybind") as Label).text, "[Space] Dash")
	assert_eq((_hud.get_node("%UseKeybind") as Label).text, "[E] Use")
	assert_true((_hud.get_node("DesktopControlLegend") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE)


func test_health_bar_updates_from_signal() -> void:
	assert_true(_health.take_damage(3))

	assert_eq(_hud.health_value, 9.0)
	assert_eq((_hud.get_node("%HealthLabel") as Label).text, "HP 9/12")


func test_energy_bar_updates_from_signal() -> void:
	assert_true(_energy.spend(25.0))

	assert_eq(_hud.energy_value, 55.0)
	assert_eq((_hud.get_node("%EnergyLabel") as Label).text, "Energy 55/80")


func test_rebinding_disconnects_previous_components() -> void:
	var replacement_health := HealthComponent.new()
	replacement_health.max_health = 20
	var replacement_energy := EnergyComponent.new()
	replacement_energy.max_energy = 50.0
	add_child_autofree(replacement_health)
	add_child_autofree(replacement_energy)
	_hud.bind(replacement_health, replacement_energy)

	_health.take_damage(1)
	_energy.spend(1.0)

	assert_eq(_hud.health_value, 20.0)
	assert_eq(_hud.energy_value, 50.0)
