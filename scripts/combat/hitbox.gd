class_name Hitbox
extends Area2D

enum ImpactType {
	GENERIC,
	MELEE,
	RELIC,
	ENEMY,
}

# Impact type is presentation metadata: combat math stays shared while
# replaceable feedback can distinguish steel, relic, and enemy attacks.
@export_range(1, 1000, 1) var damage: int = 1
@export_range(0.0, 2000.0, 1.0) var knockback_strength: float = 0.0
@export var fallback_knockback_direction: Vector2 = Vector2.RIGHT
@export var impact_type: ImpactType = ImpactType.GENERIC


func get_knockback(target_position: Vector2) -> Vector2:
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = fallback_knockback_direction.normalized()
	return direction * knockback_strength
