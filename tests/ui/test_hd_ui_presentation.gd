extends GutTest
## Structural contract for issue #156. These checks protect presentation and
## responsive readability without snapshot-testing Godot's raster output.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/player_hud.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const SKILL_TREE_SCENE: PackedScene = preload("res://scenes/ui/skill_tree_screen.tscn")
const INTERACTION_SCENE: PackedScene = preload("res://scenes/world/interactable_zone.tscn")


func test_hud_uses_hd_icons_and_readable_resource_bars() -> void:
	var hud: CanvasLayer = HUD_SCENE.instantiate() as CanvasLayer
	add_child_autofree(hud)
	var health_icon: TextureRect = hud.get_node(
		"MarginContainer/PanelContainer/PanelMargin/Bars/HealthIcon"
	) as TextureRect
	var energy_icon: TextureRect = hud.get_node(
		"MarginContainer/PanelContainer/PanelMargin/Bars/EnergyIcon"
	) as TextureRect
	assert_not_null(health_icon.texture)
	assert_not_null(energy_icon.texture)
	assert_gte((hud.get_node("%HealthLabel") as Label).get_theme_font_size("font_size"), 14)
	assert_gte((hud.get_node("%HealthBar") as ProgressBar).custom_minimum_size.y, 14.0)


func test_pause_menu_keeps_focus_controls_inside_material_panel() -> void:
	var menu: CanvasLayer = PAUSE_SCENE.instantiate() as CanvasLayer
	add_child_autofree(menu)
	var panel: PanelContainer = menu.get_node("CenterContainer/Panel") as PanelContainer
	var icon: TextureRect = panel.get_node("MarginContainer/VBoxContainer/PauseIcon") as TextureRect
	var title: Label = panel.get_node("MarginContainer/VBoxContainer/TitleLabel") as Label
	assert_gte(panel.custom_minimum_size.x, 360.0)
	assert_not_null(icon.texture)
	assert_gte(title.get_theme_font_size("font_size"), 28)
	assert_eq((menu.get_node("%ResumeButton") as Button).focus_mode, Control.FOCUS_ALL)


func test_skill_tree_branches_have_distinct_emblems_and_fit_hd_canvas() -> void:
	var screen: Control = SKILL_TREE_SCENE.instantiate() as Control
	add_child_autofree(screen)
	await wait_process_frames(2)
	for path: String in [
		"Margin/Layout/Columns/SteelBranch/SteelIcon",
		"Margin/Layout/Columns/RelicBranch/RelicIcon",
		"Margin/Layout/Columns/BodyBranch/BodyIcon",
	]:
		assert_not_null((screen.get_node(path) as TextureRect).texture)
	var columns: Control = screen.get_node("Margin/Layout/Columns") as Control
	assert_lte(columns.global_position.x + columns.size.x, 1280.5)
	assert_gte((screen.get_node("Margin/Layout/Header/TitleLabel") as Label).get_theme_font_size("font_size"), 28)


func test_touch_actions_keep_labels_and_gain_hd_icons() -> void:
	var controls: MobileVirtualControls = MobileVirtualControls.new()
	controls.force_touch_controls = true
	add_child_autofree(controls)
	controls.set_forced_viewport_size(Vector2(1280, 720))
	for action_name: String in ["AttackMelee", "AbilityRelic", "Dash", "Interact"]:
		var button: Panel = controls.get_node("TouchOverlay/%sButton" % action_name) as Panel
		assert_not_null((button.get_node("Icon") as TextureRect).texture)
		assert_false((button.get_node("Label") as Label).text.is_empty())


func test_reusable_interaction_prompt_uses_hd_readability_contract() -> void:
	var interaction: Area2D = INTERACTION_SCENE.instantiate() as Area2D
	add_child_autofree(interaction)
	var prompt: Label = interaction.get_node("%PromptLabel") as Label
	assert_gte(prompt.get_theme_font_size("font_size"), 12)
	assert_gte(prompt.get_theme_constant("outline_size"), 2)
