extends GutTest
## Coverage for the BossBase phase framework (issue #23), driven through the
## Zone 1 colossus scene: one-way HP-threshold phases, engage-once boss-bar
## hook, defeat reward + persisted milestone (paid exactly once per run and
## never re-paid once the milestone is in the save), and stagger poise.

const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/rootheart_colossus.tscn")
const HURTBOX_SCENE: PackedScene = preload("res://scenes/combat/hurtbox.tscn")
const TEST_SAVE_PATH: String = "user://test_boss_savegame.json"
const MILESTONE_ID: StringName = &"test_boss_milestone"

var _arena: Node2D
var _boss: BossBase


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()
	# The arena stands in for the level scene that owns the boss, so phase
	# bursts (parented to the boss's parent) are hard-freed with it between
	# tests instead of leaking into other suites' projectile group counts.
	_arena = Node2D.new()
	add_child_autofree(_arena)
	_boss = _spawn_boss(MILESTONE_ID)


func after_each() -> void:
	_delete_test_save()
	_forget_run_state()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	GameState.reset_progress()


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _forget_run_state() -> void:
	SaveManager.checkpoint_scene_path = ""
	SaveManager.checkpoint_position = Vector2.ZERO
	SaveManager.collected_secret_ids.clear()
	SaveManager.completed_milestone_ids.clear()


func _spawn_boss(milestone_id: StringName) -> BossBase:
	var boss: BossBase = BOSS_SCENE.instantiate() as BossBase
	boss.defeat_milestone_id = milestone_id
	_arena.add_child(boss)
	boss.health.invulnerability_duration = 0.0
	return boss


func _make_target(offset: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	var hurtbox: Hurtbox = HURTBOX_SCENE.instantiate() as Hurtbox
	hurtbox.name = "Hurtbox"
	target.add_child(hurtbox)
	add_child_autofree(target)
	target.global_position = _boss.global_position + offset
	return target


func test_starts_unengaged_in_phase_zero() -> void:
	assert_eq(_boss.get_phase(), 0)
	assert_eq(_boss.get_phase_count(), 2, "The authored colossus has two phases.")
	assert_false(_boss.is_engaged())


func test_crossing_the_health_threshold_advances_the_phase_exactly_once() -> void:
	watch_signals(_boss)

	_boss.health.take_damage(14)
	assert_eq(_boss.get_phase(), 0, "16/30 HP is still above the half threshold.")

	_boss.health.take_damage(1)
	assert_eq(_boss.get_phase(), 1, "15/30 HP crosses the 0.5 threshold.")

	_boss.health.take_damage(5)
	assert_eq(_boss.get_phase(), 1)
	assert_signal_emit_count(_boss, "phase_changed", 1)
	assert_signal_emitted_with_parameters(_boss, "phase_changed", [0, 1])


func test_healing_never_regresses_the_phase() -> void:
	_boss.health.take_damage(15)
	assert_eq(_boss.get_phase(), 1)
	watch_signals(_boss)

	_boss.health.heal(10)

	assert_eq(_boss.get_phase(), 1, "A phase advance is one-way.")
	assert_signal_emit_count(_boss, "phase_changed", 0)


func test_engages_once_when_the_target_enters_aggro_range() -> void:
	watch_signals(_boss)
	var target: Node2D = _make_target(Vector2(400.0, 0.0))
	_boss.set_target(target)

	_boss._physics_process(0.016)
	assert_false(_boss.is_engaged(), "400px is outside the 300px aggro range.")
	assert_signal_emit_count(_boss, "boss_engaged", 0)

	target.global_position = _boss.global_position + Vector2(200.0, 0.0)
	_boss._physics_process(0.016)
	_boss._physics_process(0.016)

	assert_true(_boss.is_engaged())
	assert_signal_emit_count(_boss, "boss_engaged", 1, "The boss bar hook fires once.")


func test_defeat_pays_the_reward_and_records_the_milestone_once() -> void:
	watch_signals(_boss)

	_boss.health.take_damage(99999)

	assert_eq(_boss.state, EnemyBase.State.DEAD)
	assert_signal_emit_count(_boss, "boss_defeated", 1)
	assert_eq(GameState.get_skill_points(), _boss.reward_skill_points)
	assert_true(SaveManager.is_milestone_completed(MILESTONE_ID))
	assert_true(SaveManager.has_save(), "The slice flag persists immediately.")

	# The die-back-to-checkpoint loop revives the boss; re-killing it must
	# never pay twice.
	_boss.reset_to_spawn()
	assert_eq(_boss.get_phase(), 0)
	assert_false(_boss.is_engaged())
	_boss.health.take_damage(99999)

	assert_signal_emit_count(_boss, "boss_defeated", 2)
	assert_eq(GameState.get_skill_points(), _boss.reward_skill_points)


func test_boss_with_an_already_recorded_milestone_never_repays() -> void:
	SaveManager.record_milestone_completed(&"prepaid_milestone")
	var repeat_boss: BossBase = _spawn_boss(&"prepaid_milestone")

	repeat_boss.health.take_damage(99999)

	assert_eq(GameState.get_skill_points(), 0, "A recorded milestone was already paid.")


func test_poise_takes_damage_without_stagger_or_displacement() -> void:
	var position_before: Vector2 = _boss.global_position

	_boss._on_hit_received(2, Vector2(10.0, 0.0), Hitbox.ImpactType.GENERIC)

	assert_eq(_boss.health.current_health, _boss.health.max_health - 2)
	assert_ne(_boss.state, EnemyBase.State.STAGGER, "Bosses never stunlock.")
	assert_eq(_boss.global_position, position_before)
