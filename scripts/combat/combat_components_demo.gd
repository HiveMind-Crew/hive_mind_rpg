class_name CombatComponentsDemo
extends Node2D

const ATTACK_FLASH_DURATION: float = 0.12

@onready var hitbox: Hitbox = $DemoHitbox
@onready var hurtbox: Hurtbox = $Dummy/Hurtbox
@onready var health: HealthComponent = $Dummy/HealthComponent
@onready var health_label: Label = $UI/MarginContainer/VBoxContainer/HealthLabel
@onready var status_label: Label = $UI/MarginContainer/VBoxContainer/StatusLabel
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_flash_timer: Timer = $AttackFlashTimer
@onready var attack_visual: Polygon2D = $AttackVisual


func _ready() -> void:
	hurtbox.hit_received.connect(health.apply_hit)
	hurtbox.hit_received.connect(_on_hit_received)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	attack_timer.timeout.connect(_attack_dummy)
	attack_flash_timer.timeout.connect(_hide_attack_flash)
	# No manual resync needed: HealthComponent defers its initial
	# health_changed broadcast, so the connection above catches it (#35).


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_melee"):
		_attack_dummy()


func _attack_dummy() -> void:
	if health.is_dead:
		return
	attack_visual.visible = true
	attack_flash_timer.start(ATTACK_FLASH_DURATION)
	hurtbox.receive_hit(hitbox)


func _hide_attack_flash() -> void:
	attack_visual.visible = false


func _on_hit_received(_damage: int, knockback: Vector2) -> void:
	status_label.text = "Hit received — knockback %s" % knockback


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	health_label.text = "Dummy HP: %d / %d" % [current_health, maximum_health]


func _on_died() -> void:
	status_label.text = "Dummy defeated. Re-run the scene to reset."
