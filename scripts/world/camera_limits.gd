class_name CameraLimits
extends Node
## Reusable camera-bounds component (issue #65). A zone drops this node into
## its scene, points camera_path at the player's Camera2D, and calls
## apply_bounds() with its authored world rect; the component translates that
## rect into Camera2D limit_* values so the view never exposes space outside
## the zone. Zones stay the owners of their geometry — this node never guesses
## bounds on its own, and there is deliberately no global camera manager.

@export var camera_path: NodePath

var _camera: Camera2D


func _ready() -> void:
	_camera = get_node(camera_path) as Camera2D


func get_camera() -> Camera2D:
	return _camera


## Clamp the camera to a world-space rect. Bounds smaller than the visible
## area are widened around their center first (see limits_for_bounds), so a
## room narrower than the viewport frames centered instead of pinning the
## camera to its top-left corner.
func apply_bounds(bounds: Rect2) -> void:
	var visible_size: Vector2 = _camera.get_viewport_rect().size / _camera.zoom
	var limits: Rect2 = limits_for_bounds(bounds, visible_size)
	_camera.limit_left = int(limits.position.x)
	_camera.limit_top = int(limits.position.y)
	_camera.limit_right = int(limits.end.x)
	_camera.limit_bottom = int(limits.end.y)
	# New limits must not animate in: the camera starts framed, not panning.
	snap_to_target()


## Discard smoothed history so the camera lands on its target immediately.
## Wire this to teleports (respawn) — otherwise position smoothing pans the
## view across the whole zone from the death location.
func snap_to_target() -> void:
	_camera.reset_smoothing()


## Pure limit math, static for direct unit testing: returns the rect the
## camera center may roam scaled up to what Camera2D limit_* values enclose.
## An axis where bounds are smaller than the viewport is expanded symmetrically
## around the bounds center, keeping undersized rooms centered on screen.
static func limits_for_bounds(bounds: Rect2, viewport_size: Vector2) -> Rect2:
	var size: Vector2 = bounds.size.max(viewport_size)
	return Rect2(bounds.get_center() - size / 2.0, size)
