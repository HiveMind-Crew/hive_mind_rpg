extends GutTest
## Coverage for NpcBarkSet (issue #26): validation rules and the authored
## hub NPC resources.

const BARK_SET_SCRIPT := preload("res://scripts/resources/npc_bark_set.gd")
const AUTHORED_PATHS: Array[String] = [
	"res://data/npcs/warden_maylis.tres",
	"res://data/npcs/tinker_bosk.tres",
	"res://data/npcs/old_petra.tres",
]


func _build_set(npc_name: String, barks: Array[String]) -> NpcBarkSet:
	var bark_set: NpcBarkSet = BARK_SET_SCRIPT.new()
	bark_set.npc_name = npc_name
	bark_set.barks = barks
	return bark_set


func test_valid_set_passes_validation() -> void:
	var barks: Array[String] = ["Hello.", "Go away."]
	var bark_set: NpcBarkSet = _build_set("Warden", barks)

	assert_true(bark_set.is_valid())
	assert_eq(bark_set.validate().size(), 0)


func test_empty_name_and_empty_barks_each_fail_validation() -> void:
	var no_barks: Array[String] = []
	var bark_set: NpcBarkSet = _build_set("", no_barks)

	var errors: PackedStringArray = bark_set.validate()

	assert_false(bark_set.is_valid())
	assert_eq(errors.size(), 2)


func test_blank_bark_line_fails_validation() -> void:
	var barks: Array[String] = ["A fine day.", "   "]
	var bark_set: NpcBarkSet = _build_set("Warden", barks)

	assert_false(bark_set.is_valid())


func test_authored_hub_npcs_are_valid_and_distinct() -> void:
	var seen_names: Array[String] = []
	for path: String in AUTHORED_PATHS:
		var bark_set: NpcBarkSet = load(path) as NpcBarkSet
		assert_not_null(bark_set, "%s should load as an NpcBarkSet." % path)
		if bark_set == null:
			continue
		assert_true(bark_set.is_valid(), "%s should validate." % path)
		assert_false(seen_names.has(bark_set.npc_name), "%s reuses an NPC name." % path)
		seen_names.append(bark_set.npc_name)
