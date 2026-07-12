class_name EnergyComponent
extends Node

signal energy_changed(current_energy: float, max_energy: float)

@export_range(0.01, 10000.0, 0.01) var max_energy: float = 100.0
@export_range(0.0, 10000.0, 0.01) var regeneration_per_second: float = 20.0

var current_energy: float:
	get:
		return _current_energy

var _current_energy: float = 0.0


func _ready() -> void:
	_current_energy = max_energy


func _physics_process(delta: float) -> void:
	regenerate(regeneration_per_second * maxf(delta, 0.0))


func set_max_energy(new_max_energy: float) -> void:
	# Runtime max-energy changes (skill unlocks/respec, issue #17). Growth
	# also grants the new energy immediately; shrinking clamps.
	new_max_energy = maxf(new_max_energy, 0.01)
	if is_equal_approx(new_max_energy, max_energy):
		return
	var gained_energy: float = new_max_energy - max_energy
	max_energy = new_max_energy
	if gained_energy > 0.0:
		_current_energy += gained_energy
	_current_energy = clampf(_current_energy, 0.0, max_energy)
	energy_changed.emit(_current_energy, max_energy)


func can_spend(amount: float) -> bool:
	return amount > 0.0 and _current_energy >= amount


func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	_set_current_energy(_current_energy - amount)
	return true


func regenerate(amount: float) -> bool:
	if amount <= 0.0 or _current_energy >= max_energy:
		return false
	_set_current_energy(minf(_current_energy + amount, max_energy))
	return true


func restore_full_energy() -> void:
	_set_current_energy(max_energy)


func _set_current_energy(value: float) -> void:
	var bounded_value: float = clampf(value, 0.0, max_energy)
	if is_equal_approx(_current_energy, bounded_value):
		return
	_current_energy = bounded_value
	energy_changed.emit(_current_energy, max_energy)
