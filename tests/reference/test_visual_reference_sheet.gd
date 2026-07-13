extends GutTest
## Scene-load verification for the visual reference sheet (issue #82): the
## sheet must instantiate cleanly and its palette groups must stay non-empty
## with distinct swatches, since docs/visual_bible.md cites them as canonical.

const SHEET_SCENE: PackedScene = preload(
	"res://scenes/reference/visual_reference_sheet.tscn"
)


func _add_sheet() -> VisualReferenceSheet:
	var sheet: VisualReferenceSheet = (
		SHEET_SCENE.instantiate() as VisualReferenceSheet
	)
	add_child_autofree(sheet)
	return sheet


func test_scene_instantiates_and_builds_swatches() -> void:
	var sheet: VisualReferenceSheet = _add_sheet()
	assert_not_null(sheet)
	# Background + title + one rect and one label per swatch, at minimum.
	assert_gt(
		sheet.get_child_count(),
		sheet.swatch_color_count(),
		"Sheet should build nodes for every palette swatch."
	)


func test_palette_groups_cover_all_separation_roles() -> void:
	var group_names: Array = VisualReferenceSheet.PALETTE_GROUPS.keys()
	assert_gte(group_names.size(), 4, "Need world/corruption/player/enemy/UI groups.")
	for group_name: String in group_names:
		var swatches: Array = VisualReferenceSheet.PALETTE_GROUPS[group_name]
		assert_gt(swatches.size(), 0, "Group '%s' should not be empty." % group_name)
		var seen: Dictionary = {}
		for swatch: Color in swatches:
			var hex: String = swatch.to_html(false)
			assert_false(
				seen.has(hex),
				"Group '%s' repeats swatch #%s." % [group_name, hex]
			)
			seen[hex] = true


func test_player_enemy_world_identity_colors_are_distinct() -> void:
	var identity_colors: Array[Color] = [
		VisualReferenceSheet.STRIP_PLAYER,
		VisualReferenceSheet.STRIP_ENEMY,
		VisualReferenceSheet.STRIP_FLOOR,
		VisualReferenceSheet.STRIP_WALL,
		VisualReferenceSheet.STRIP_UI_PANEL,
	]
	var seen: Dictionary = {}
	for identity_color: Color in identity_colors:
		var hex: String = identity_color.to_html(false)
		assert_false(seen.has(hex), "Identity color #%s duplicated." % hex)
		seen[hex] = true


func test_pickup_uses_the_canonical_relic_cyan() -> void:
	assert_eq(VisualReferenceSheet.STRIP_PICKUP, VisualReferenceSheet.STRIP_BOLT)
	assert_eq(VisualReferenceSheet.STRIP_PICKUP.to_html(false), "4de5ff")


func test_readability_strip_contains_wall_and_floor_silhouettes() -> void:
	var sheet: VisualReferenceSheet = _add_sheet()
	var strip: Node2D = sheet.get_node("ReadabilityStrip") as Node2D
	var wall_silhouettes: Node2D = strip.get_node("WallSilhouettes") as Node2D
	var floor_silhouettes: Node2D = strip.get_node("FloorSilhouettes") as Node2D

	assert_not_null(wall_silhouettes)
	assert_not_null(floor_silhouettes)
	assert_gte(wall_silhouettes.get_child_count(), 3)
	assert_gte(floor_silhouettes.get_child_count(), 3)
