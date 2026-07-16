class_name CombatFeedback
extends Node

signal hit_feedback_started(impact_type: int)
signal death_feedback_started()

@export var health_path: NodePath
@export var visual_path: NodePath
@export_range(0.01, 1.0, 0.01) var flash_duration: float = 0.1
@export_range(0.01, 1.0, 0.01) var invulnerability_pulse_interval: float = 0.06
@export_range(0.05, 1.0, 0.05) var invulnerability_alpha: float = 0.35
@export var generic_hit_tint: Color = Color(1.0, 0.45, 0.45, 1.0)
@export var melee_hit_tint: Color = Color(1.0, 0.92, 0.45, 1.0)
@export var relic_hit_tint: Color = Color(0.3, 0.95, 1.0, 1.0)
@export var enemy_hit_tint: Color = Color(1.0, 0.35, 0.28, 1.0)
@export var death_tint: Color = Color(0.28, 0.28, 0.34, 1.0)

var _health: HealthComponent
var _visual: CanvasItem
var _base_self_modulate: Color = Color.WHITE
var _active_hit_tint: Color = Color.WHITE
var _flash_ends_at_msec: int = 0
var _invulnerable: bool = false
var _dead: bool = false


func _ready() -> void:
	# Feedback must finish during hitstop or pause without owning global time.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_health = get_node_or_null(health_path) as HealthComponent
	_visual = get_node_or_null(visual_path) as CanvasItem
	if _health == null or _visual == null:
		push_error("CombatFeedback requires valid health_path and visual_path targets.")
		set_process(false)
		return
	_base_self_modulate = _visual.self_modulate
	# self_modulate layers feedback over actor-authored state colors instead of
	# competing with EnemyBase wind-up, attack, stagger, and death colors.
	_health.damaged.connect(_on_damaged)
	_health.invulnerability_changed.connect(_on_invulnerability_changed)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	set_process(false)


func _process(_delta: float) -> void:
	# Wall-clock time keeps short flashes readable and independent of hitstop.
	_render_feedback(Time.get_ticks_msec())


func _on_damaged(_amount: int, _knockback: Vector2, impact_type: int) -> void:
	if _dead:
		return
	_active_hit_tint = _tint_for_impact(impact_type)
	_flash_ends_at_msec = Time.get_ticks_msec() + roundi(flash_duration * 1000.0)
	set_process(true)
	_render_feedback(Time.get_ticks_msec())
	CombatFxSpawner.spawn_spark(get_parent(), _visual.global_position)
	hit_feedback_started.emit(impact_type)


func _on_invulnerability_changed(value: bool) -> void:
	_invulnerable = value
	set_process(value or Time.get_ticks_msec() < _flash_ends_at_msec)
	_render_feedback(Time.get_ticks_msec())


func _on_health_changed(current_health: int, _maximum_health: int) -> void:
	if not _dead or current_health <= 0:
		return
	_dead = false
	_invulnerable = false
	_flash_ends_at_msec = 0
	_visual.self_modulate = _base_self_modulate
	set_process(false)


func _on_died() -> void:
	_dead = true
	_invulnerable = false
	_flash_ends_at_msec = 0
	_visual.self_modulate = death_tint
	CombatFxSpawner.spawn_dissolve(get_parent(), _visual.global_position)
	set_process(false)
	death_feedback_started.emit()


func _render_feedback(now_msec: int) -> void:
	if _visual == null or _dead:
		return
	var tint: Color = _base_self_modulate
	if now_msec < _flash_ends_at_msec:
		tint = _active_hit_tint
	if _invulnerable:
		var interval_msec: int = maxi(roundi(invulnerability_pulse_interval * 1000.0), 1)
		var pulse_index: int = floori(float(now_msec) / float(interval_msec))
		if pulse_index % 2 == 1:
			tint.a *= invulnerability_alpha
	_visual.self_modulate = tint
	var feedback_active: bool = _invulnerable or now_msec < _flash_ends_at_msec
	if not feedback_active:
		set_process(false)


func _tint_for_impact(impact_type: int) -> Color:
	match impact_type:
		Hitbox.ImpactType.MELEE:
			return melee_hit_tint
		Hitbox.ImpactType.RELIC:
			return relic_hit_tint
		Hitbox.ImpactType.ENEMY:
			return enemy_hit_tint
		_:
			return generic_hit_tint
