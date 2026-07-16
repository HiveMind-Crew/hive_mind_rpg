extends GutTest
## Coverage for the CameraLimits component (issue #65): the pure limit math,
## the Camera2D wiring, and the Zone 1 integration — limits derive from the
## zone's authored tile geometry, follow smoothing stays on, and respawn snaps
## the smoothed camera instead of panning it across the zone. Zone 1 holds
## persistent secret pickups, so zone tests redirect SaveManager at a scratch
## file like test_zone1_graybox.gd does.

const ZONE_SCENE: PackedScene = preload("res://scenes/world/zone1_graybox.tscn")
const TEST_SAVE_PATH: String = "user://test_camera_limits_savegame.json"


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()


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


func _add_zone() -> Zone1Graybox:
	var zone: Zone1Graybox = ZONE_SCENE.instantiate() as Zone1Graybox
	add_child_autofree(zone)
	return zone


## A bare Camera2D + CameraLimits rig, detached from any zone.
func _add_camera_rig() -> CameraLimits:
	var root: Node2D = Node2D.new()
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	root.add_child(camera)
	var limits: CameraLimits = CameraLimits.new()
	limits.camera_path = NodePath("../Camera2D")
	root.add_child(limits)
	add_child_autofree(root)
	return limits


func _camera_limit_rect(camera: Camera2D) -> Rect2:
	return Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	)


## Where the camera center can legally sit: limits inset by half the view.
func _clamp_center(camera: Camera2D, target: Vector2) -> Vector2:
	var half_view: Vector2 = camera.get_viewport_rect().size / camera.zoom / 2.0
	var limits: Rect2 = _camera_limit_rect(camera)
	return target.clamp(limits.position + half_view, limits.end - half_view)


func test_limits_for_bounds_keeps_bounds_that_cover_the_viewport() -> void:
	var bounds: Rect2 = Rect2(0.0, 0.0, 1728.0, 480.0)

	var limits: Rect2 = CameraLimits.limits_for_bounds(bounds, Vector2(640.0, 360.0))

	assert_eq(limits, bounds, "Bounds at least viewport-sized pass through untouched.")


func test_limits_for_bounds_centers_undersized_bounds_on_each_axis() -> void:
	var bounds: Rect2 = Rect2(100.0, 100.0, 320.0, 480.0)

	var limits: Rect2 = CameraLimits.limits_for_bounds(bounds, Vector2(640.0, 360.0))

	assert_eq(limits.size, Vector2(640.0, 480.0), "Only the narrow axis widens.")
	assert_eq(
		limits.get_center(), bounds.get_center(),
		"A room narrower than the view frames centered, not pinned to a corner."
	)


func test_apply_bounds_writes_camera_limits() -> void:
	var camera_limits: CameraLimits = _add_camera_rig()
	var bounds: Rect2 = Rect2(-64.0, -32.0, 4000.0, 2000.0)

	camera_limits.apply_bounds(bounds)

	assert_eq(_camera_limit_rect(camera_limits.get_camera()), bounds)


func test_apply_bounds_centers_a_room_smaller_than_the_view() -> void:
	var camera_limits: CameraLimits = _add_camera_rig()
	var camera: Camera2D = camera_limits.get_camera()
	var bounds: Rect2 = Rect2(200.0, 300.0, 16.0, 16.0)
	var visible_size: Vector2 = camera.get_viewport_rect().size / camera.zoom

	camera_limits.apply_bounds(bounds)

	var limits: Rect2 = _camera_limit_rect(camera)
	assert_eq(limits.size, visible_size)
	assert_almost_eq(limits.get_center(), bounds.get_center(), Vector2.ONE)


func test_zone_camera_limits_match_the_authored_tile_geometry() -> void:
	var zone: Zone1Graybox = _add_zone()
	var camera: Camera2D = zone.get_node("Player/Camera2D") as Camera2D

	var zone_bounds: Rect2 = zone.get_zone_bounds()
	assert_eq(
		zone_bounds.size,
		Vector2(Zone1Graybox.ZONE_SIZE_TILES * Zone1Graybox.TILE_SIZE),
		"Bounds derive from the painted tile constants, nothing hand-typed."
	)
	assert_eq(_camera_limit_rect(camera), zone_bounds)
	assert_true(
		camera.position_smoothing_enabled,
		"Bounding the camera must not disable smooth follow."
	)


func test_zone_covers_the_project_viewport_on_both_axes() -> void:
	var zone: Zone1Graybox = _add_zone()
	var camera: Camera2D = zone.get_node("Player/Camera2D") as Camera2D
	# The world camera is zoomed in (crisp full-res UI: the render surface is
	# larger than the visible world so menus/HUD get native-resolution space).
	# The zone only has to cover the *visible* world area, not the raw render
	# resolution, so divide the project viewport by the camera zoom.
	var visible_size: Vector2 = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	) / camera.zoom

	var zone_bounds: Rect2 = zone.get_zone_bounds()

	assert_gte(zone_bounds.size.x, visible_size.x, "No horizontal void beside the zone.")
	assert_gte(zone_bounds.size.y, visible_size.y, "No vertical void above/below the zone.")


func test_camera_never_frames_outside_the_zone_at_the_spawn_edge() -> void:
	var zone: Zone1Graybox = _add_zone()
	var camera: Camera2D = zone.get_node("Player/Camera2D") as Camera2D
	await wait_physics_frames(2)

	var half_view: Vector2 = camera.get_viewport_rect().size / camera.zoom / 2.0
	var center: Vector2 = camera.get_screen_center_position()
	var zone_bounds: Rect2 = zone.get_zone_bounds()

	assert_true(
		zone_bounds.encloses(Rect2(center - half_view, half_view * 2.0)),
		"Spawn sits near the west wall; the view must stay inside the zone."
	)


func test_respawn_snaps_the_camera_to_the_respawn_point() -> void:
	var zone: Zone1Graybox = _add_zone()
	var player: PlayerController = zone.get_node("Player") as PlayerController
	var camera: Camera2D = zone.get_node("Player/Camera2D") as Camera2D
	var respawn: RespawnController = zone.get_node("RespawnController") as RespawnController
	var spawn_position: Vector2 = player.global_position

	# Walk the smoothed camera away from the spawn: teleport far east and give
	# smoothing a few frames to drift after the player.
	player.global_position = Vector2(zone.get_node("BossArenaAnchor").global_position)
	await wait_physics_frames(5)
	respawn.respawn()
	await wait_physics_frames(1)

	assert_almost_eq(
		camera.get_screen_center_position(),
		_clamp_center(camera, spawn_position),
		Vector2.ONE,
		"Respawn must recenter immediately, not pan back across the zone."
	)
