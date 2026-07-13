class_name EnemyBolt
extends Hitbox
## Slow, readable enemy projectile (issue #22), mirror of the player's
## EnergyBolt: flies straight, pops on the first hurtbox or wall it meets,
## and expires after its lifetime. Deliberately slower than a dash so it is
## always dodgeable.

const PROJECTILE_GROUP: StringName = &"enemy_projectiles"

@export_range(1.0, 2000.0, 1.0) var speed: float = 150.0
@export_range(0.01, 10.0, 0.01) var lifetime: float = 2.5

var direction: Vector2 = Vector2.DOWN
## The shooter's hurtbox, so a bolt never pops on its own lobber.
var ignored_hurtbox: Hurtbox

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
	if hurtbox == null or hurtbox == ignored_hurtbox:
		return
	hurtbox.receive_hit(self)
	# Physics objects cannot safely be removed while overlap callbacks flush.
	queue_free.call_deferred()


func _on_body_entered(_body: Node2D) -> void:
	queue_free.call_deferred()
