extends GutTest
## Regression contract for the display stretch + Web canvas configuration
## (issue #125). In the Web export, `stretch/scale_mode="integer"` floored the
## window scale: a 1920x1080 browser window rendered the game 1x (1280x720
## centered in black), and windows smaller than the 1280x720 base cropped the
## HUD off-screen instead of shrinking. Fractional scaling with aspect "keep"
## fills or letterbox-centers every window size; the 2x-zoomed world camera
## keeps world texels crisp at exact 720p (2x) and 1080p (3x). A change back
## to integer scaling, a different base resolution, or a Web preset canvas
## policy change must fail here instead of shipping.

const EXPECTED_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

## Godot omits settings that match engine defaults when the editor saves
## project.godot, so every read supplies the engine default as fallback.
const DEFAULT_STRETCH_MODE: String = "disabled"
const DEFAULT_STRETCH_ASPECT: String = "ignore"
const DEFAULT_SCALE_MODE: String = "fractional"

const WEB_EXPORT_PRESETS_PATH: String = "res://export_presets.cfg"
## html/canvas_resize_policy=2 is "Adaptive": the shell tracks the browser
## window (including devicePixelRatio) every frame.
const CANVAS_RESIZE_POLICY_ADAPTIVE: int = 2


func test_base_viewport_is_720p() -> void:
	var size: Vector2i = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	)
	assert_eq(size, EXPECTED_VIEWPORT_SIZE, "base viewport must stay 1280x720 (issue #124)")


func test_stretch_scales_canvas_items_fractionally_keeping_aspect() -> void:
	assert_eq(
		ProjectSettings.get_setting("display/window/stretch/mode", DEFAULT_STRETCH_MODE),
		"canvas_items",
		"stretch mode must render UI at window resolution (issue #124)"
	)
	assert_eq(
		ProjectSettings.get_setting("display/window/stretch/aspect", DEFAULT_STRETCH_ASPECT),
		"keep",
		"aspect must letterbox, not distort or reframe the 640x360 visible world"
	)
	assert_eq(
		ProjectSettings.get_setting("display/window/stretch/scale_mode", DEFAULT_SCALE_MODE),
		"fractional",
		"integer scale mode crops sub-720p windows and shrinks 1080p to 1x (issue #125)"
	)


func test_pixel_snapping_stays_enabled() -> void:
	# Fractional window scaling relies on 2D pixel snap to keep the pixel art
	# stable; disabling snap reintroduces shimmer at non-integer scales.
	assert_true(
		ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false),
		"2D transform pixel snap must stay enabled"
	)
	assert_true(
		ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false),
		"2D vertex pixel snap must stay enabled"
	)


func test_web_preset_resizes_canvas_adaptively_with_default_shell() -> void:
	var presets: ConfigFile = ConfigFile.new()
	var error: Error = presets.load(WEB_EXPORT_PRESETS_PATH)
	if error != OK:
		# The Web preset excludes tests/* from the exported pack, so this test
		# only ever runs in the dev project where export_presets.cfg exists.
		fail_test("failed to load %s (error %d)" % [WEB_EXPORT_PRESETS_PATH, error])
		return
	assert_eq(
		presets.get_value("preset.0", "name", ""), "Web", "preset.0 must stay the Web preset"
	)
	assert_eq(
		presets.get_value("preset.0.options", "html/canvas_resize_policy", -1),
		CANVAS_RESIZE_POLICY_ADAPTIVE,
		"Web canvas must track the browser window adaptively (issue #125)"
	)
	assert_eq(
		presets.get_value("preset.0.options", "html/custom_html_shell", "unset"),
		"",
		"Web export must use the stock Godot shell; sizing is handled by project settings"
	)
