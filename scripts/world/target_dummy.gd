class_name TargetDummy
extends StaticBody2D

## Stationary practice target for the graybox arena. Composes the shared
## Hurtbox and HealthComponent scenes so it reacts to any Hitbox (melee #9,
## relic #10) without knowing who attacked it. Shows remaining HP above the
## body and stays defeated until the scene is re-run.

const TARGET_DUMMY_GROUP: StringName = &"target_dummies"
const DEFEATED_TINT: Color = Color(0.32, 0.34, 0.38, 1.0)
const DEFEATED_LABEL_TEXT: String = "KO"

@onready var _health: HealthComponent = %HealthComponent
@onready var _hurtbox: Hurtbox = %Hurtbox
@onready var _body_visual: Polygon2D = %BodyVisual
@onready var _hp_label: Label = %HpLabel


func _ready() -> void:
	add_to_group(TARGET_DUMMY_GROUP)
	_hurtbox.hit_received.connect(_health.apply_hit)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_on_health_changed(_health.current_health, _health.max_health)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_hp_label.text = "%d/%d" % [current_health, maximum_health]


func _on_died() -> void:
	# A dead dummy should not keep eating hits or flashing its HP.
	_hurtbox.set_enabled(false)
	_body_visual.color = DEFEATED_TINT
	_hp_label.text = DEFEATED_LABEL_TEXT
