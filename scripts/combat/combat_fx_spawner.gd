class_name CombatFxSpawner
extends RefCounted
## Visual-only, self-cleaning combat bursts. Gameplay callers keep all timing,
## collision, damage, and time-scale ownership; this helper only displays art.

const COMBAT_TEXTURE: Texture2D = preload("res://assets/sprites/fx/combat_fx.png")
const BOLT_TEXTURE: Texture2D = preload("res://assets/sprites/fx/energy_bolt.png")
const SLASH: StringName = &"slash"
const SPARK: StringName = &"spark"
const DASH: StringName = &"dash"
const DISSOLVE: StringName = &"dissolve"
const BOLT_IMPACT: StringName = &"bolt_impact"
const BOLT_FLIGHT: StringName = &"bolt_flight"
const COMBAT_FPS: float = 12.0
const BOLT_FPS: float = 14.0
const QUARTER_TURN: float = PI / 2.0


static func spawn_slash(parent: Node, position: Vector2, direction: Vector2) -> void:
	_spawn(parent, position, _combat_frames(SLASH), SLASH, _cardinal_rotation(direction))


static func spawn_spark(parent: Node, position: Vector2) -> void:
	_spawn(parent, position, _combat_frames(SPARK), SPARK, 0.0)


static func spawn_dash_trail(parent: Node, position: Vector2, direction: Vector2) -> void:
	_spawn(parent, position, _combat_frames(DASH), DASH, _cardinal_rotation(direction))


static func spawn_dissolve(parent: Node, position: Vector2) -> void:
	_spawn(parent, position, _combat_frames(DISSOLVE), DISSOLVE, 0.0)


static func spawn_bolt_impact(parent: Node, position: Vector2) -> void:
	_spawn(parent, position, _bolt_frames(), BOLT_IMPACT, 0.0)


static func _spawn(
	parent: Node, position: Vector2, frames: SpriteFrames, animation: StringName, rotation_value: float
) -> void:
	if parent == null:
		return
	var visual: AnimatedSprite2D = AnimatedSprite2D.new()
	visual.sprite_frames = frames
	visual.animation = animation
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var region_size: Vector2i = Vector2i(32, 32)
	var origin: Vector2i = Vector2i.ZERO
	var frame_count: int = 4
	match animation_name:
		SPARK:
			region_size = Vector2i(16, 16)
			origin = Vector2i(128, 0)
		DASH:
			region_size = Vector2i(24, 24)
			origin = Vector2i(192, 0)
			frame_count = 3
		DISSOLVE:
			region_size = Vector2i(24, 24)
			origin = Vector2i(0, 32)
			frame_count = 6
	for frame_index: int in frame_count:
		frames.add_frame(animation_name, _atlas(COMBAT_TEXTURE, Rect2i(origin + Vector2i(region_size.x * frame_index, 0), region_size)))
	return frames


static func bolt_flight_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(BOLT_FLIGHT)
	frames.set_animation_loop(BOLT_FLIGHT, true)
	frames.set_animation_speed(BOLT_FLIGHT, BOLT_FPS)
	for frame_index: int in 4:
		frames.add_frame(BOLT_FLIGHT, _atlas(BOLT_TEXTURE, Rect2i(frame_index * 8, 0, 8, 8)))
	return frames


static func _bolt_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(BOLT_IMPACT)
	frames.set_animation_loop(BOLT_IMPACT, false)
	frames.set_animation_speed(BOLT_IMPACT, BOLT_FPS)
	for frame_index: int in 5:
		frames.add_frame(BOLT_IMPACT, _atlas(BOLT_TEXTURE, Rect2i(frame_index * 16, 8, 16, 16)))
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
