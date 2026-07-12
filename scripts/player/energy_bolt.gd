class_name EnergyBolt
extends Hitbox

const PROJECTILE_GROUP: StringName = &"player_projectiles"

@export_range(1.0, 2000.0, 1.0) var speed: float = 360.0
@export_range(0.01, 10.0, 0.01) var lifetime: float = 1.5

var direction: Vector2 = Vector2.DOWN
var _remaining_lifetime: float = 0.0


func _ready() -> void:
	add_to_group(PROJECTILE_GROUP)
	direction = direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	_remaining_lifetime = lifetime
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	position += direction * speed * safe_delta
	_remaining_lifetime -= safe_delta
	if _remaining_lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox == null:
		return
	hurtbox.receive_hit(self)
	# Physics objects cannot safely be removed while overlap callbacks flush.
	queue_free.call_deferred()


func _on_body_entered(_body: Node2D) -> void:
	queue_free.call_deferred()
