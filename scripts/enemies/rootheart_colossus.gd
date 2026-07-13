class_name RootheartColossus
extends BossBase
## Zone 1 boss (issue #23): a rootbound titan of the corrupted forest.
## Phase 1 fights as a slow, heavy slammer on the shared melee loop. At half
## health it wakes — movement quickens, and the wake itself plus the end of
## every slam detonates a radial burst of relic bolts. Phase 2 is new
## behavior, not just more HP: the arena fills with dodge pressure and the
## punish window after each slam now has to be taken through a bullet ring.

@export var bolt_scene: PackedScene
@export_range(2, 24, 1) var burst_bolt_count: int = 8
@export_range(1.0, 5.0, 0.1) var phase_two_speed_multiplier: float = 1.6
@export_range(1.0, 128.0, 1.0) var burst_spawn_offset: float = 24.0


func _update_chase() -> void:
	super()
	# Wake speed: scale the chase velocity instead of writing the shared
	# stats resource, which other instances read.
	if state == State.CHASE and get_phase() >= 1:
		velocity *= phase_two_speed_multiplier


func _transition_to(new_state: State) -> void:
	super(new_state)
	if new_state == State.RECOVERY and state == State.RECOVERY and get_phase() >= 1:
		_fire_radial_burst()


func _on_phase_entered(phase: int) -> void:
	if phase >= 1:
		_fire_radial_burst()


func _fire_radial_burst() -> void:
	if bolt_scene == null:
		push_warning("RootheartColossus '%s' has no bolt scene; the burst fizzles." % name)
		return
	for index: int in burst_bolt_count:
		var bolt: EnemyBolt = bolt_scene.instantiate() as EnemyBolt
		if bolt == null:
			push_warning("RootheartColossus '%s' bolt scene is not an EnemyBolt." % name)
			return
		var direction: Vector2 = Vector2.RIGHT.rotated(
			TAU * float(index) / float(burst_bolt_count)
		)
		bolt.direction = direction
		bolt.damage = stats.attack_damage
		bolt.ignored_hurtbox = hurtbox
		# Same parenting the other shooters use, so bolts outlive the boss.
		var projectile_parent: Node = get_parent()
		projectile_parent.add_child(bolt)
		bolt.global_position = global_position + direction * burst_spawn_offset
