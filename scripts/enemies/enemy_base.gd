class_name EnemyBase
extends CharacterBody2D

signal state_changed(previous_state: State, current_state: State)
signal enemy_died()

enum State {
	IDLE,
	CHASE,
	WIND_UP,
	ATTACK,
	RECOVERY,
	STAGGER,
	DEAD,
}

const ENEMY_GROUP: StringName = &"enemies"
const IDLE_COLOR: Color = Color(0.58, 0.25, 0.68, 1.0)
const WIND_UP_COLOR: Color = Color(1.0, 0.78, 0.18, 1.0)
const ATTACK_COLOR: Color = Color(1.0, 0.2, 0.25, 1.0)
const STAGGER_COLOR: Color = Color(0.72, 0.86, 1.0, 1.0)
const DEAD_COLOR: Color = Color(0.22, 0.22, 0.26, 1.0)

@export var stats: EnemyStats

@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var attack_hitbox: Hitbox = %AttackHitbox
@onready var _body_visual: CanvasItem = %BodyVisual
@onready var _tell_visual: CanvasItem = get_node_or_null("%TellVisual") as CanvasItem

var state: State = State.IDLE
var target: Node2D
var _state_time_remaining: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN
var _attack_target_ids: Dictionary[int, bool] = {}
var _spawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(ENEMY_GROUP)
	_spawn_position = global_position
	if stats == null:
		push_error("EnemyBase requires an EnemyStats resource.")
		set_physics_process(false)
		return
	health.max_health = stats.max_health
	health.restore_full_health()
	attack_hitbox.damage = stats.attack_damage
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_apply_state_visuals()


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	match state:
		State.IDLE:
			_update_idle()
		State.CHASE:
			_update_chase()
		State.WIND_UP, State.ATTACK, State.RECOVERY, State.STAGGER:
			_update_timed_state(safe_delta)
		State.DEAD:
			velocity = Vector2.ZERO
	move_and_slide()


func set_target(new_target: Node2D) -> void:
	target = new_target
	if state == State.IDLE and is_instance_valid(target):
		_transition_to(State.CHASE)


func reset_to_spawn() -> void:
	# RespawnController's "resettable" group hook: enemies in the area reset
	# when the player dies (DESIGN.md §5). Revives and rearms a dead enemy,
	# so the state is restored directly — _transition_to treats DEAD as
	# terminal on purpose.
	global_position = _spawn_position
	velocity = Vector2.ZERO
	health.restore_full_health()
	hurtbox.set_enabled(true)
	attack_hitbox.set_deferred("monitoring", false)
	var previous_state: State = state
	state = State.IDLE
	_state_time_remaining = 0.0
	_apply_state_visuals()
	if previous_state != State.IDLE:
		state_changed.emit(previous_state, state)


func _update_idle() -> void:
	velocity = Vector2.ZERO
	if is_instance_valid(target):
		_transition_to(State.CHASE)


func _update_chase() -> void:
	if not is_instance_valid(target):
		_transition_to(State.IDLE)
		return
	var distance_to_target: float = global_position.distance_to(target.global_position)
	if distance_to_target > stats.aggro_range:
		velocity = Vector2.ZERO
		return
	_attack_direction = global_position.direction_to(target.global_position)
	if distance_to_target <= stats.attack_range:
		velocity = Vector2.ZERO
		_transition_to(State.WIND_UP)
		return
	velocity = _attack_direction * stats.move_speed


func _update_timed_state(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_time_remaining = maxf(_state_time_remaining - delta, 0.0)
	if _state_time_remaining > 0.0:
		return
	match state:
		State.WIND_UP:
			_transition_to(State.ATTACK)
		State.ATTACK:
			_transition_to(State.RECOVERY)
		State.RECOVERY, State.STAGGER:
			_transition_to(State.CHASE)


func _transition_to(new_state: State) -> void:
	if state == new_state or state == State.DEAD:
		return
	var previous_state: State = state
	state = new_state
	match state:
		State.WIND_UP:
			_state_time_remaining = stats.wind_up_duration
			_attack_direction = global_position.direction_to(target.global_position)
			if _attack_direction.is_zero_approx():
				_attack_direction = Vector2.DOWN
		State.ATTACK:
			_state_time_remaining = stats.attack_duration
			_attack_target_ids.clear()
			attack_hitbox.position = _attack_direction * stats.attack_offset
			attack_hitbox.set_deferred("monitoring", true)
		State.RECOVERY:
			_state_time_remaining = stats.recovery_duration
			attack_hitbox.set_deferred("monitoring", false)
		State.STAGGER:
			_state_time_remaining = stats.stagger_duration
			attack_hitbox.set_deferred("monitoring", false)
		State.DEAD:
			velocity = Vector2.ZERO
			attack_hitbox.set_deferred("monitoring", false)
			hurtbox.set_enabled(false)
	_apply_state_visuals()
	state_changed.emit(previous_state, state)


func _on_hit_received(damage: int, knockback: Vector2, impact_type: int) -> void:
	if not health.apply_hit(damage, knockback, impact_type) or health.is_dead:
		return
	global_position += knockback
	_transition_to(State.STAGGER)


func _on_attack_area_entered(area: Area2D) -> void:
	var target_hurtbox: Hurtbox = area as Hurtbox
	if target_hurtbox == null or target_hurtbox == hurtbox:
		return
	var target_id: int = target_hurtbox.get_instance_id()
	if _attack_target_ids.has(target_id):
		return
	_attack_target_ids[target_id] = true
	target_hurtbox.receive_hit(attack_hitbox)


func _on_died() -> void:
	_transition_to(State.DEAD)
	enemy_died.emit()


func _apply_state_visuals() -> void:
	if _tell_visual != null:
		_tell_visual.visible = state == State.WIND_UP
	match state:
		State.WIND_UP:
			_set_body_visual(WIND_UP_COLOR, &"windup")
		State.ATTACK:
			_set_body_visual(ATTACK_COLOR, &"attack_melee")
		State.STAGGER:
			_set_body_visual(STAGGER_COLOR, &"hurt")
		State.DEAD:
			_set_body_visual(DEAD_COLOR, &"death")
		State.CHASE:
			_set_body_visual(IDLE_COLOR, _get_directional_animation(&"walk"))
		_:
			_set_body_visual(IDLE_COLOR, _get_directional_animation(&"idle"))


func _get_directional_animation(prefix: StringName) -> StringName:
	var direction: Vector2 = _get_visual_facing_direction()
	if absf(direction.x) > absf(direction.y):
		return StringName("%s_side" % prefix)
	if direction.y < 0.0:
		return StringName("%s_up" % prefix)
	return StringName("%s_down" % prefix)


func _get_visual_facing_direction() -> Vector2:
	if target == null:
		return Vector2.DOWN
	var direction: Vector2 = target.global_position - global_position
	if direction.is_zero_approx():
		return Vector2.DOWN
	return direction.normalized()


## Polygon graybox enemies retain their authored `color`; animated production
## visuals use `modulate` and select their matching authored state clip.
func _set_body_visual(tint: Color, animation_name: StringName) -> void:
	var polygon_visual: Polygon2D = _body_visual as Polygon2D
	if polygon_visual != null:
		polygon_visual.color = tint
		return
	var animated_visual: AnimatedSprite2D = _body_visual as AnimatedSprite2D
	if animated_visual != null:
		# Animated production frames carry their own state colors; tinting them
		# again would muddy the canonical violet, yellow, and attack-red ramps.
		animated_visual.modulate = Color.WHITE
		if animation_name.ends_with("_side"):
			animated_visual.flip_h = _get_visual_facing_direction().x < 0.0
		if animated_visual.sprite_frames.has_animation(animation_name):
			animated_visual.play(animation_name)
