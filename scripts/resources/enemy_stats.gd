class_name EnemyStats
extends Resource

@export_range(1, 100000, 1) var max_health: int = 4
@export_range(1.0, 1000.0, 1.0) var move_speed: float = 70.0
@export_range(1, 1000, 1) var attack_damage: int = 1
@export_range(1.0, 512.0, 1.0) var aggro_range: float = 240.0
@export_range(1.0, 128.0, 1.0) var attack_range: float = 30.0
@export_range(1.0, 128.0, 1.0) var attack_offset: float = 18.0
@export_range(0.01, 5.0, 0.01) var wind_up_duration: float = 0.45
@export_range(0.01, 1.0, 0.01) var attack_duration: float = 0.1
@export_range(0.01, 5.0, 0.01) var recovery_duration: float = 0.5
@export_range(0.01, 5.0, 0.01) var stagger_duration: float = 0.2
