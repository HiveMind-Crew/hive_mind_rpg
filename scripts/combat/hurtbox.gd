class_name Hurtbox
extends Area2D

signal hit_received(damage: int, knockback: Vector2)

var enabled: bool:
	get:
		return _enabled

var _enabled: bool = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_enabled(value: bool) -> void:
	if _enabled == value:
		return
	_enabled = value
	# Physics properties cannot safely change while an overlap query is flushing.
	set_deferred("monitoring", value)
	set_deferred("monitorable", value)


func receive_hit(hitbox: Hitbox) -> void:
	if not _enabled or not is_instance_valid(hitbox):
		return
	hit_received.emit(hitbox.damage, hitbox.get_knockback(global_position))


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		receive_hit(area as Hitbox)
