extends GutTest
## Coverage for the AudioManager autoload (issue #25): the placeholder SFX
## registry, unknown-id handling, and ambient loop state control. Actual
## audible output is not assertable headless, so these tests pin the API
## contract: known ids are accepted, unknown ids warn and are rejected.

const REQUIRED_SFX_IDS: Array[StringName] = [
	&"melee_swing", &"relic_cast", &"dash", &"hit", &"death",
]


func after_each() -> void:
	# Leave the autoload the way gameplay expects it: default drone running.
	AudioManager.play_ambient()


func test_registry_covers_the_combat_placeholder_set() -> void:
	for sfx_id: StringName in REQUIRED_SFX_IDS:
		assert_true(
			AudioManager.SFX_STREAM_PATHS.has(sfx_id),
			"Missing required placeholder SFX '%s'." % sfx_id
		)


func test_known_sfx_ids_are_accepted() -> void:
	for sfx_id: StringName in AudioManager.SFX_STREAM_PATHS:
		assert_true(AudioManager.play_sfx(sfx_id), "SFX '%s' should be playable." % sfx_id)


func test_unknown_sfx_id_warns_and_is_rejected() -> void:
	assert_false(AudioManager.play_sfx(&"kazoo_solo"))
	assert_push_warning("no SFX named")


func test_unknown_ambient_id_warns_and_keeps_the_current_loop() -> void:
	var previous_ambient_id: StringName = AudioManager.get_current_ambient_id()

	assert_false(AudioManager.play_ambient(&"elevator_jazz"))

	assert_push_warning("no ambient loop named")
	assert_eq(AudioManager.get_current_ambient_id(), previous_ambient_id)


func test_ambient_loop_stops_and_restarts() -> void:
	AudioManager.stop_ambient()
	assert_false(AudioManager.is_ambient_playing())
	assert_eq(AudioManager.get_current_ambient_id(), StringName())

	assert_true(AudioManager.play_ambient())
	assert_true(AudioManager.is_ambient_playing())
	assert_eq(AudioManager.get_current_ambient_id(), AudioManager.DEFAULT_AMBIENT)
