class_name PlayerController
extends CharacterBody2D

signal movement_state_changed(
	previous_state: PlayerMovementStateMachine.State,
	current_state: PlayerMovementStateMachine.State
)
signal dash_started()
signal dash_ended()
signal melee_swing_started(direction: Vector2)
signal melee_swing_ended()
signal relic_ability_fired(direction: Vector2)
signal relic_ability_blocked()
signal skill_effects_refreshed()
signal control_enabled_changed(enabled: bool)

## Ability id the starter bolt's ABILITY_MODIFIER skill nodes target.
const RELIC_BOLT_ABILITY_ID: StringName = &"starter_relic_bolt"
const ATTACK_STAT: StringName = &"attack"
const BOLT_DAMAGE_STAT: StringName = &"damage"
const MAX_HP_STAT: StringName = &"max_hp"
const MAX_ENERGY_STAT: StringName = &"max_energy"

@export_range(1.0, 1000.0, 1.0) var move_speed: float = 120.0
@export_range(1.0, 10000.0, 1.0) var acceleration: float = 1400.0
@export_range(1.0, 10000.0, 1.0) var friction: float = 1800.0
@export_range(1.0, 2000.0, 1.0) var dash_speed: float = 320.0
@export_range(0.01, 2.0, 0.01) var dash_duration: float = 0.14
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.45
@export_range(1, 1000, 1) var melee_damage: int = 1
@export_range(0.01, 2.0, 0.01) var melee_duration: float = 0.12
@export_range(1.0, 64.0, 1.0) var melee_hitbox_offset: float = 14.0
@export_range(0.0, 1.0, 0.01) var melee_hitstop_duration: float = 0.05
@export_range(0.01, 1.0, 0.01) var melee_hitstop_time_scale: float = 0.05
@export var energy_bolt_scene: PackedScene
@export_range(0.01, 1000.0, 0.01) var energy_bolt_cost: float = 25.0
@export_range(1, 1000, 1) var energy_bolt_damage: int = 1
@export_range(1.0, 128.0, 1.0) var energy_bolt_spawn_offset: float = 24.0

@onready var _hurtbox: Hurtbox = %Hurtbox
@onready var _melee_hitbox: Hitbox = %MeleeHitbox
@onready var energy: EnergyComponent = %EnergyComponent
@onready var health: HealthComponent = %HealthComponent
@onready var _hud: PlayerHud = %PlayerHud
@onready var _body_visual: PlayerVisual = %Body

var movement_state: PlayerMovementStateMachine.State:
	get:
		return _movement.state

var _movement: PlayerMovementStateMachine
var _melee: PlayerMeleeAttack
# Gates every input path (movement, dash, melee, relic). Systems that take
# control away from the player (e.g. respawn transitions, issue #79) toggle
# this instead of reaching into the state machines.
var _control_enabled: bool = true
# Pre-skill baselines captured in _ready; skill effects derive from these so
# unlock → respec always round-trips back to the authored values (issue #17).
var _base_max_health: int = 0
var _base_max_energy: float = 0.0
var _effective_bolt_damage: int = 1
var _hitstop_token: int = TimeScaleManager.INVALID_TOKEN
# SceneTreeTimers outlive this node leaving/re-entering the tree; a timeout
# only ends the hitstop whose generation it captured.
var _hitstop_generation: int = 0


func _ready() -> void:
	_movement = PlayerMovementStateMachine.new(
		move_speed,
		acceleration,
		friction,
		dash_speed,
		dash_duration,
		dash_cooldown
	)
	_movement.state_changed.connect(_on_movement_state_changed)
	_movement.dash_started.connect(_on_dash_started)
	_movement.dash_ended.connect(_on_dash_ended)
	_melee = PlayerMeleeAttack.new(melee_duration)
	_melee.swing_started.connect(_on_melee_swing_started)
	_melee.swing_ended.connect(_on_melee_swing_ended)
	_melee_hitbox.damage = melee_damage
	_melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)
	_hurtbox.hit_received.connect(health.apply_hit)
	_hud.bind(health, energy)
	_base_max_health = health.max_health
	_base_max_energy = energy.max_energy
	# Signal arities differ (StringName / int / none); unbind normalizes them
	# onto the same zero-argument refresh.
	GameState.skill_unlocked.connect(_refresh_skill_effects.unbind(1))
	GameState.skills_respecced.connect(_refresh_skill_effects.unbind(1))
	GameState.progress_reset.connect(_refresh_skill_effects)
	_refresh_skill_effects()


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Vector2.ZERO
	var dash_requested: bool = false
	if _control_enabled:
		input_direction = Input.get_vector(
			&"move_left",
			&"move_right",
			&"move_up",
			&"move_down"
		)
		dash_requested = Input.is_action_just_pressed(&"dash")
	_movement.update(input_direction, dash_requested, delta)
	velocity = _movement.velocity
	move_and_slide()
	_movement.finish_frame(input_direction)
	_body_visual.set_facing_direction(_movement.last_move_direction)
	if _movement.state == PlayerMovementStateMachine.State.IDLE:
		_body_visual.play_idle()
	elif _movement.state == PlayerMovementStateMachine.State.MOVE:
		_body_visual.play_move()
	if _control_enabled and Input.is_action_just_pressed(&"attack_melee"):
		try_melee_attack()
	if _control_enabled and Input.is_action_just_pressed(&"ability_relic"):
		try_relic_ability()
	_melee.update(delta)


func cancel_dash() -> void:
	_movement.cancel_dash()


func is_control_enabled() -> bool:
	return _control_enabled


## Turns player input on/off. Disabling stops movement immediately and cancels
## any in-flight dash or melee swing (closing its hitbox), so no gameplay
## action can leak out while an external system (respawn, cutscene) owns the
## player. Idempotent; emits control_enabled_changed only on real changes.
func set_control_enabled(enabled: bool) -> void:
	if _control_enabled == enabled:
		return
	_control_enabled = enabled
	if not enabled:
		_movement.cancel_dash()
		_melee.cancel_swing()
		_movement.velocity = Vector2.ZERO
		velocity = Vector2.ZERO
	control_enabled_changed.emit(enabled)


func try_melee_attack() -> bool:
	if not _control_enabled:
		return false
	return _melee.try_start_swing(_movement.last_move_direction)


func try_relic_ability() -> bool:
	if not _control_enabled:
		return false
	if energy_bolt_scene == null or not energy.spend(energy_bolt_cost):
		relic_ability_blocked.emit()
		return false
	var bolt: EnergyBolt = energy_bolt_scene.instantiate() as EnergyBolt
	if bolt == null:
		energy.regenerate(energy_bolt_cost)
		relic_ability_blocked.emit()
		return false
	var aim_direction: Vector2 = snap_to_eight_directions(_movement.last_move_direction)
	bolt.direction = aim_direction
	bolt.damage = _effective_bolt_damage
	var projectile_parent: Node = get_parent()
	projectile_parent.add_child(bolt)
	bolt.global_position = global_position + aim_direction * energy_bolt_spawn_offset
	AudioManager.play_sfx(&"relic_cast")
	_body_visual.play_relic(aim_direction)
	relic_ability_fired.emit(aim_direction)
	return true


func get_effective_melee_damage() -> int:
	return _melee_hitbox.damage


func get_effective_bolt_damage() -> int:
	return _effective_bolt_damage


func _refresh_skill_effects() -> void:
	# Effect layer (issue #17): re-derive every skill-affected stat from the
	# authored baselines + currently unlocked nodes. Runs on unlock, respec,
	# and reset, so gameplay changes immediately and respec fully reverts.
	var tree: SkillTree = GameState.skill_tree
	var unlocked_ids: Array[StringName] = GameState.get_unlocked_skill_ids()

	var attack_multiplier: float = PlayerStatCalculator.get_stat_multiplier(
		tree, unlocked_ids, ATTACK_STAT
	)
	_melee_hitbox.damage = maxi(1, roundi(melee_damage * attack_multiplier))

	var bolt_multiplier: float = PlayerStatCalculator.get_ability_multiplier(
		tree, unlocked_ids, RELIC_BOLT_ABILITY_ID, BOLT_DAMAGE_STAT
	)
	_effective_bolt_damage = maxi(1, roundi(energy_bolt_damage * bolt_multiplier))

	var max_hp_bonus: float = PlayerStatCalculator.get_stat_bonus(
		tree, unlocked_ids, MAX_HP_STAT
	)
	health.set_max_health(_base_max_health + roundi(max_hp_bonus))

	var max_energy_bonus: float = PlayerStatCalculator.get_stat_bonus(
		tree, unlocked_ids, MAX_ENERGY_STAT
	)
	energy.set_max_energy(_base_max_energy + max_energy_bonus)

	skill_effects_refreshed.emit()


static func snap_to_eight_directions(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.DOWN
	var octant: int = roundi(direction.angle() / (PI / 4.0))
	return Vector2.from_angle(float(octant) * PI / 4.0).normalized()


func _exit_tree() -> void:
	if is_instance_valid(_movement):
		_movement.cancel_dash()
	if is_instance_valid(_melee):
		_melee.cancel_swing()
	_end_hitstop()


func _on_movement_state_changed(
	previous_state: PlayerMovementStateMachine.State,
	current_state: PlayerMovementStateMachine.State
) -> void:
	movement_state_changed.emit(previous_state, current_state)


func _on_dash_started() -> void:
	_hurtbox.set_enabled(false)
	_body_visual.play_dash(_movement.last_move_direction)
	AudioManager.play_sfx(&"dash")
	dash_started.emit()


func _on_dash_ended() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.set_enabled(true)
	dash_ended.emit()


func _on_melee_swing_started(direction: Vector2) -> void:
	_melee_hitbox.position = direction * melee_hitbox_offset
	_body_visual.play_melee(direction)
	# Deferred: physics properties cannot safely change while an overlap query is flushing.
	_melee_hitbox.set_deferred("monitoring", true)
	AudioManager.play_sfx(&"melee_swing")
	melee_swing_started.emit(direction)


func _on_melee_swing_ended() -> void:
	if is_instance_valid(_melee_hitbox):
		_melee_hitbox.set_deferred("monitoring", false)
	_body_visual.play_idle()
	melee_swing_ended.emit()


func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	var target_hurtbox: Hurtbox = area as Hurtbox
	if target_hurtbox == null or target_hurtbox == _hurtbox:
		return
	if not _melee.register_hit(target_hurtbox.get_instance_id()):
		return
	target_hurtbox.receive_hit(_melee_hitbox)
	_start_hitstop()


func _start_hitstop() -> void:
	if melee_hitstop_duration <= 0.0 or _hitstop_token != TimeScaleManager.INVALID_TOKEN:
		return
	_hitstop_generation += 1
	_hitstop_token = TimeScaleManager.acquire_modifier(melee_hitstop_time_scale)
	var timer: SceneTreeTimer = get_tree().create_timer(
		melee_hitstop_duration, true, false, true
	)
	timer.timeout.connect(_on_hitstop_timer_timeout.bind(_hitstop_generation))


func _on_hitstop_timer_timeout(generation: int) -> void:
	if generation != _hitstop_generation:
		return
	_end_hitstop()


func _end_hitstop() -> void:
	if _hitstop_token == TimeScaleManager.INVALID_TOKEN:
		return
	# Invalidate any pending timer so it cannot end a future hitstop.
	_hitstop_generation += 1
	TimeScaleManager.release_modifier(_hitstop_token)
	_hitstop_token = TimeScaleManager.INVALID_TOKEN
