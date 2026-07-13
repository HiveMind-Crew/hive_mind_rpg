class_name BossBase
extends EnemyBase
## Reusable boss phase framework (issue #23). Descending HP-fraction
## thresholds drive one-way phase advances: crossing one calls the
## _on_phase_entered() hook and emits phase_changed. boss_engaged fires once
## when the target first comes inside aggro range and boss_defeated fires on
## death — together with HealthComponent.health_changed these are the
## boss-bar hooks: a bar UI subscribes without the boss knowing it exists.
##
## Defeat pays an authored skill-point reward once per run and records a
## persisted milestone through SaveManager (the Zone 1 slice-complete flag),
## so the payout can never be farmed across resets or reloads. Bosses default
## to stagger immunity (poise): the base staggers on every hit, which would
## stunlock a long fight.

signal boss_engaged()
signal phase_changed(previous_phase: int, current_phase: int)
signal boss_defeated()

## Descending health fractions; crossing one advances one phase. The default
## [0.5] yields two phases: 0 above half health, 1 at or below.
@export var phase_health_thresholds: Array[float] = [0.5]
@export_range(0, 100, 1) var reward_skill_points: int = 5
## Persisted milestone id recorded on defeat; empty skips recording. A boss
## whose milestone is already in the save never pays again on later runs.
@export var defeat_milestone_id: StringName = &""
@export var immune_to_stagger: bool = true

var _current_phase: int = 0
var _engaged: bool = false
var _reward_paid: bool = false
var _sorted_thresholds: Array[float] = []


func _ready() -> void:
	super()
	# Authoring order shouldn't matter; phases advance down the sorted list.
	_sorted_thresholds = phase_health_thresholds.duplicate()
	_sorted_thresholds.sort()
	_sorted_thresholds.reverse()
	if defeat_milestone_id != StringName():
		_reward_paid = SaveManager.is_milestone_completed(defeat_milestone_id)
	health.health_changed.connect(_on_boss_health_changed)


func get_phase() -> int:
	return _current_phase


func get_phase_count() -> int:
	return _sorted_thresholds.size() + 1


func is_engaged() -> bool:
	return _engaged


func reset_to_spawn() -> void:
	super()
	# _reward_paid survives resets on purpose: the payout is once per
	# run/milestone even when the die-back-to-checkpoint loop revives the boss.
	_current_phase = 0
	_engaged = false


func _update_chase() -> void:
	super()
	if _engaged or not is_instance_valid(target) or state == State.DEAD:
		return
	if global_position.distance_to(target.global_position) <= stats.aggro_range:
		_engaged = true
		boss_engaged.emit()


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	# Death is boss_defeated's moment, not a phase advance.
	if max_health <= 0 or current_health <= 0:
		return
	var health_fraction: float = float(current_health) / float(max_health)
	var target_phase: int = 0
	for threshold: float in _sorted_thresholds:
		if health_fraction <= threshold:
			target_phase += 1
	# Phases never regress: healing mid-fight keeps the current aggression.
	if target_phase <= _current_phase:
		return
	var previous_phase: int = _current_phase
	_current_phase = target_phase
	_on_phase_entered(_current_phase)
	phase_changed.emit(previous_phase, _current_phase)


## Per-boss hook: react to entering a phase (new attacks, speed, visuals).
func _on_phase_entered(_phase: int) -> void:
	pass


func _on_hit_received(damage: int, knockback: Vector2, impact_type: int) -> void:
	if immune_to_stagger:
		# Poise: damage lands (phases and death still flow through the health
		# signals) but hits never displace the boss or interrupt its pattern.
		health.apply_hit(damage, knockback, impact_type)
		return
	super(damage, knockback, impact_type)


func _on_died() -> void:
	super()
	_pay_defeat_reward()
	boss_defeated.emit()


func _pay_defeat_reward() -> void:
	if _reward_paid:
		return
	_reward_paid = true
	if reward_skill_points > 0:
		GameState.award_skill_points(reward_skill_points)
	if defeat_milestone_id != StringName():
		SaveManager.record_milestone_completed(defeat_milestone_id)
