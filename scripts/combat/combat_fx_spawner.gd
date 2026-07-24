class_name CombatFxSpawner
extends RefCounted
## Visual-only, self-cleaning combat bursts. Gameplay callers keep all timing,
## collision, damage, and time-scale ownership; this helper only displays art.

const COMBAT_TEXTURE: Texture2D = preload("res://assets/sprites/fx/combat_fx_hd.png")
const RELIC_ORB_TEXTURE: Texture2D = preload("res://assets/sprites/fx/relic_orb_fx.png")
const SLASH: StringName = &"slash"
const SPARK: StringName = &"spark"
const DASH: StringName = &"dash"
const DISSOLVE: StringName = &"dissolve"
const RELIC_CAST: StringName = &"relic_cast"
const RELIC_FLIGHT: StringName = &"relic_flight"
const RELIC_IMPACT: StringName = &"relic_impact"
const COMBAT_FPS: float = 12.0
const RELIC_CAST_FPS: float = 24.0
const RELIC_FLIGHT_FPS: float = 14.0
const RELIC_IMPACT_FPS: float = 20.0
const QUARTER_TURN: float = PI / 2.0

# Stylized-HD relic sheet layout (assets/sprites/generate_relic_orb_fx.py):
# cast 6×96×96 at y=0, flight 4×128×64 at y=96 (orb core on the exact cell
# center so the display never overstates the collision position, trail toward
# -x), impact 6×128×128 at y=160. Frames are authored facing +x and rotated to
# the true launch direction at runtime.
const RELIC_CAST_CELL: Vector2i = Vector2i(96, 96)
const RELIC_CAST_FRAMES: int = 6
const RELIC_FLIGHT_CELL: Vector2i = Vector2i(128, 64)
const RELIC_FLIGHT_FRAMES: int = 4
const RELIC_FLIGHT_ROW_Y: int = 96
const RELIC_IMPACT_CELL: Vector2i = Vector2i(128, 128)
const RELIC_IMPACT_FRAMES: int = 6
const RELIC_IMPACT_ROW_Y: int = 160
# Display contracts at the shipped 2× camera: ≈29 px peak cast flare, ≈11 px
# orb core with a ≈21 px trail, ≈36 px peak impact burst.
const RELIC_CAST_SCALE: float = 0.35
const RELIC_FLIGHT_SCALE: float = 0.36
const RELIC_IMPACT_SCALE: float = 0.3
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR

# Stylized-HD combat sheet layout (assets/sprites/generate_combat_fx_hd.py):
# uniform 64×64 cells in four rows — slash 4 (y=0), spark 4 (y=64), dash 3
# (y=128), dissolve 6 (y=192). Slash/dash are authored facing +x and rotated to
# the true action direction at runtime. Per-effect display scales keep the HD
# frames at their previous on-screen footprint at the shipped 2× camera.
const COMBAT_CELL: int = 64
const SLASH_ROW_Y: int = 0
const SPARK_ROW_Y: int = 64
const DASH_ROW_Y: int = 128
const DISSOLVE_ROW_Y: int = 192
const SLASH_SCALE: float = 0.62
const SPARK_SCALE: float = 0.5
const DASH_SCALE: float = 0.55
const DISSOLVE_SCALE: float = 0.6


static func spawn_slash(parent: Node, position: Vector2, direction: Vector2) -> void:
	_spawn(
		parent, position, _combat_frames(SLASH), SLASH, _cardinal_rotation(direction),
		HD_TEXTURE_FILTER, SLASH_SCALE
	)


static func spawn_spark(parent: Node, position: Vector2) -> void:
	_spawn(parent, position, _combat_frames(SPARK), SPARK, 0.0, HD_TEXTURE_FILTER, SPARK_SCALE)


static func spawn_dash_trail(parent: Node, position: Vector2, direction: Vector2) -> void:
	_spawn(
		parent, position, _combat_frames(DASH), DASH, _cardinal_rotation(direction),
		HD_TEXTURE_FILTER, DASH_SCALE
	)


static func spawn_dissolve(parent: Node, position: Vector2) -> void:
	_spawn(parent, position, _combat_frames(DISSOLVE), DISSOLVE, 0.0, HD_TEXTURE_FILTER, DISSOLVE_SCALE)


## Cast-origin flare for the starter relic orb. Callers spawn it only after
## the real EnergyBolt exists, so a blocked cast never shows a fake effect.
static func spawn_relic_cast(parent: Node, position: Vector2, direction: Vector2) -> void:
	_spawn(
		parent,
		position,
		_relic_cast_frames(),
		RELIC_CAST,
		_true_rotation(direction),
		HD_TEXTURE_FILTER,
		RELIC_CAST_SCALE
	)


static func spawn_relic_impact(parent: Node, position: Vector2) -> void:
	_spawn(
		parent, position, _relic_impact_frames(), RELIC_IMPACT, 0.0, HD_TEXTURE_FILTER, RELIC_IMPACT_SCALE
	)


## Builds the configured (unparented) flight visual; the owning EnergyBolt
## adds it as a child and keeps every gameplay property to itself.
static func create_relic_flight_visual(direction: Vector2) -> AnimatedSprite2D:
	var visual: AnimatedSprite2D = AnimatedSprite2D.new()
	visual.name = "FlightVisual"
	visual.sprite_frames = _relic_flight_frames()
	visual.animation = RELIC_FLIGHT
	visual.texture_filter = HD_TEXTURE_FILTER
	visual.scale = Vector2.ONE * RELIC_FLIGHT_SCALE
	visual.rotation = _true_rotation(direction)
	return visual


static func _spawn(
	parent: Node,
	position: Vector2,
	frames: SpriteFrames,
	animation: StringName,
	rotation_value: float,
	texture_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST,
	display_scale: float = 1.0
) -> void:
	if parent == null:
		return
	var visual: AnimatedSprite2D = AnimatedSprite2D.new()
	visual.sprite_frames = frames
	visual.animation = animation
	visual.texture_filter = texture_filter
	visual.scale = Vector2.ONE * display_scale
	visual.global_position = position
	visual.rotation = rotation_value
	visual.z_index = 2
	parent.add_child(visual)
	visual.animation_finished.connect(visual.queue_free)
	visual.play()


static func _combat_frames(animation_name: StringName) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, false)
	frames.set_animation_speed(animation_name, COMBAT_FPS)
	# Every HD combat effect is a row of uniform 64×64 cells; only the row origin
	# and frame count differ.
	var row_y: int = SLASH_ROW_Y
	var frame_count: int = 4
	match animation_name:
		SPARK:
			row_y = SPARK_ROW_Y
		DASH:
			row_y = DASH_ROW_Y
			frame_count = 3
		DISSOLVE:
			row_y = DISSOLVE_ROW_Y
			frame_count = 6
	for frame_index: int in frame_count:
		frames.add_frame(
			animation_name,
			_atlas(COMBAT_TEXTURE, Rect2i(Vector2i(COMBAT_CELL * frame_index, row_y), Vector2i(COMBAT_CELL, COMBAT_CELL)))
		)
	return frames


static func _relic_cast_frames() -> SpriteFrames:
	return _relic_frames(
		RELIC_CAST, RELIC_CAST_FRAMES, RELIC_CAST_CELL, 0, false, RELIC_CAST_FPS
	)


static func _relic_flight_frames() -> SpriteFrames:
	return _relic_frames(
		RELIC_FLIGHT, RELIC_FLIGHT_FRAMES, RELIC_FLIGHT_CELL, RELIC_FLIGHT_ROW_Y, true, RELIC_FLIGHT_FPS
	)


static func _relic_impact_frames() -> SpriteFrames:
	return _relic_frames(
		RELIC_IMPACT, RELIC_IMPACT_FRAMES, RELIC_IMPACT_CELL, RELIC_IMPACT_ROW_Y, false, RELIC_IMPACT_FPS
	)


static func _relic_frames(
	animation_name: StringName, frame_count: int, cell: Vector2i, row_y: int, loop: bool, fps: float
) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for frame_index: int in frame_count:
		frames.add_frame(
			animation_name, _atlas(RELIC_ORB_TEXTURE, Rect2i(Vector2i(frame_index * cell.x, row_y), cell))
		)
	return frames


static func _atlas(texture: Texture2D, region: Rect2i) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region.position, region.size)
	return atlas


static func _cardinal_rotation(direction: Vector2) -> float:
	if direction.is_zero_approx():
		return 0.0
	return snappedf(direction.angle(), QUARTER_TURN)


## Exact aim rotation for +x-authored relic art, truthful for all eight
## normalized launch directions (and any other normalized vector).
static func _true_rotation(direction: Vector2) -> float:
	if direction.is_zero_approx():
		return 0.0
	return direction.angle()
