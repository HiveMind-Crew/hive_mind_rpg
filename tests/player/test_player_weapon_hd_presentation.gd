extends GutTest
## Contract coverage for the authoritative presentation-only HD steel weapon
## (issues #168/#175). PlayerVisual stays the logical state/facing owner; the
## single weapon sprite mirrors it, and gameplay (controller, melee hitbox,
## timing, collision) remains unchanged.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ATLAS_PATH: String = "res://assets/sprites/player/hd/steel_weapon_atlas.png"
const WEAPON_ATLAS: Texture2D = preload("res://assets/sprites/player/hd/steel_weapon_atlas.png")
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
## facing vector -> [facing_label, facing angle] (matches PlayerVisual mapping).
const FACING_EXPECTATIONS: Array[Array] = [
	[Vector2.UP, &"north", -PI * 0.5],
	[Vector2.RIGHT, &"east", 0.0],
	[Vector2.DOWN, &"south", PI * 0.5],
	[Vector2.LEFT, &"west", PI],
]

var _player: PlayerController
var _legacy_visual: PlayerVisual
var _presentation: PlayerHdPresentation
var _weapon: PlayerWeaponHdPresentation


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_legacy_visual = _player.get_node("Body") as PlayerVisual
	_presentation = _player.get_node("HdPresentation") as PlayerHdPresentation
	_weapon = _presentation.get_weapon_sprite()


func test_weapon_exists_as_presentation_owned_display_only_sprite() -> void:
	assert_not_null(_weapon)
	assert_eq(_weapon.get_parent(), _presentation, "HdPresentation owns the weapon display.")
	assert_eq(_weapon.texture, WEAPON_ATLAS)
	assert_eq(_weapon.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_true(_weapon.region_enabled, "Weapon shows one authored cell, never the whole sheet.")
	assert_eq(_weapon.region_rect.size, PlayerWeaponHdPresentation.CELL_SIZE)
	assert_eq(_weapon.get_child_count(), 0, "Display-only: no collision or gameplay children.")
	assert_almost_eq(
		_weapon.scale.x * PlayerWeaponHdPresentation.CONTENT_LENGTH_PX,
		PlayerWeaponHdPresentation.DISPLAY_LENGTH_PX,
		0.01,
	)
	assert_eq(
		_weapon.offset,
		Vector2(
			PlayerWeaponHdPresentation.CELL_SIZE.x * 0.5
			- PlayerWeaponHdPresentation.HILT_PIVOT_X_PX,
			0.0,
		),
		"Rotation must pivot on the authored grip center.",
	)


func test_player_has_exactly_one_weapon_display_owned_by_hd_presentation() -> void:
	assert_null(
		_player.get_node_or_null("WeaponPresentation"),
		"The retired parallel weapon owner must not remain in the player scene.",
	)
	assert_eq(
	_weapon_display_count(_player),
		1,
		"Exactly one PlayerWeaponHdPresentation may be active at runtime.",
	)
	assert_eq(
		_weapon.get_parent(),
		_presentation,
		"HdPresentation is the sole weapon-display owner.",
	)


func test_weapon_atlas_is_a_documented_png_with_hd_import_rules() -> void:
	var file: FileAccess = FileAccess.open(ATLAS_PATH, FileAccess.READ)
	assert_not_null(file, "Missing HD weapon atlas: %s" % ATLAS_PATH)
	if file == null:
		return
	assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
	file.close()
	assert_eq(Vector2i(WEAPON_ATLAS.get_width(), WEAPON_ATLAS.get_height()), Vector2i(512, 128))
	var import_text: String = FileAccess.get_file_as_string(ATLAS_PATH + ".import")
	assert_string_contains(import_text, "compress/mode=0")
	assert_string_contains(import_text, "mipmaps/generate=false")
	assert_string_contains(import_text, "process/premult_alpha=false")
	assert_string_contains(import_text, "process/fix_alpha_border=true")


func test_swing_cell_is_authored_art_distinct_from_the_held_cell() -> void:
	var image: Image = WEAPON_ATLAS.get_image()
	var cell: Vector2i = Vector2i(PlayerWeaponHdPresentation.CELL_SIZE)
	var held_pixels: int = _opaque_pixel_count(image, Rect2i(Vector2i.ZERO, cell))
	var swing_pixels: int = _opaque_pixel_count(image, Rect2i(Vector2i(cell.x, 0), cell))
	assert_gt(held_pixels, 0, "Held cell must contain authored pixels.")
	assert_gt(swing_pixels, held_pixels,
		"Swing cell adds authored smear/edge pixels, so it can never be a copy of the held cell.")


func test_idle_and_move_hold_the_weapon_while_melee_swings_it() -> void:
	_legacy_visual.set_facing_direction(Vector2.RIGHT)
	_presentation._process(0.0)
	assert_eq(_weapon.region_rect, PlayerWeaponHdPresentation.HELD_REGION)
	var rest_rotation: float = _weapon.rotation

	_legacy_visual.play_move()
	_presentation._process(0.05)
	assert_eq(_weapon.region_rect, PlayerWeaponHdPresentation.HELD_REGION,
		"Move keeps the carried silhouette; only melee switches to the swing cell.")

	_legacy_visual.play_melee(Vector2.RIGHT)
	_presentation._process(0.0)
	assert_eq(_weapon.region_rect, PlayerWeaponHdPresentation.SWING_REGION)
	assert_ne(_weapon.rotation, rest_rotation,
		"Melee pose must differ from the idle/move rest pose.")


func test_rest_pose_follows_facing_for_all_four_directions() -> void:
	for expectation: Array in FACING_EXPECTATIONS:
		_legacy_visual.set_facing_direction(expectation[0] as Vector2)
		_presentation._process(0.0)
		var facing: StringName = expectation[1] as StringName
		var facing_angle: float = expectation[2] as float
		var tilt_sign: float = PlayerWeaponHdPresentation.FACING_TILT_SIGNS[facing]
		assert_almost_eq(
			_weapon.rotation,
			facing_angle + tilt_sign * deg_to_rad(PlayerWeaponHdPresentation.REST_ANGLE_DEGREES),
			0.001,
			"%s rest pose must tilt down-forward off the facing axis" % facing,
		)
		assert_eq(_weapon.position, PlayerWeaponHdPresentation.HAND_ANCHORS[facing])
		assert_false(_weapon.flip_h, "Facing comes from rotation, never a horizontal mirror.")
		assert_false(_weapon.flip_v, "Held pose never flips; only mirrored sweeps may.")
		if facing == &"north":
			assert_eq(_weapon.z_index, PlayerWeaponHdPresentation.WEAPON_Z_BEHIND,
				"North-facing weapon reads behind the body.")
		else:
			assert_eq(_weapon.z_index, PlayerWeaponHdPresentation.WEAPON_Z_FRONT)


func test_melee_sweep_is_directionally_truthful_for_all_four_facings() -> void:
	var half_arc: float = deg_to_rad(PlayerWeaponHdPresentation.SWING_ARC_DEGREES) * 0.5
	var half_sweep: float = PlayerWeaponHdPresentation.SWING_SWEEP_SECONDS * 0.5
	for expectation: Array in FACING_EXPECTATIONS:
		var facing: StringName = expectation[1] as StringName
		var facing_angle: float = expectation[2] as float
		var tilt_sign: float = PlayerWeaponHdPresentation.FACING_TILT_SIGNS[facing]
		_legacy_visual.play_melee(expectation[0] as Vector2)
		_presentation._process(0.0)
		assert_eq(_weapon.region_rect, PlayerWeaponHdPresentation.SWING_REGION)
		assert_eq(_weapon.flip_v, tilt_sign < 0.0,
			"Mirrored sweeps flip the authored leading edge onto the leading side.")
		assert_almost_eq(_weapon.rotation, facing_angle - tilt_sign * half_arc, 0.001,
			"%s swing must start on the wind-up side of the facing" % facing)
		_presentation._process(half_sweep)
		assert_almost_eq(_weapon.rotation, facing_angle, 0.001,
			"%s mid-swing must cross the exact play_melee facing angle" % facing)
		_presentation._process(half_sweep)
		assert_almost_eq(_weapon.rotation, facing_angle + tilt_sign * half_arc, 0.001,
			"%s swing must finish on the follow-through side and clamp there" % facing)
		_presentation._process(1.0)
		assert_almost_eq(_weapon.rotation, facing_angle + tilt_sign * half_arc, 0.001)
		# Return to idle the same way the real clip does before the next facing.
		_legacy_visual._on_clip_finished()


func test_weapon_follows_hurt_death_and_revive_presentation() -> void:
	_legacy_visual._on_health_damaged(1, Vector2.ZERO, 0)
	_presentation._process(0.0)
	assert_eq(_weapon.self_modulate, PlayerHdPresentation.HURT_TINT)

	_legacy_visual._on_health_died()
	_presentation._process(0.0)
	assert_false(_weapon.visible, "A defeated wanderer does not float a held sword.")

	_legacy_visual._on_health_changed(3, 3)
	_presentation._process(0.0)
	assert_true(_weapon.visible)
	assert_eq(_weapon.self_modulate, Color.WHITE)


func test_melee_keeps_a_single_slash_fx_owner() -> void:
	# CombatFxSpawner remains the one slash spawner; the weapon layer must not
	# add a second slash effect on top of it.
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	parent.add_child(player)
	assert_true(player.try_melee_attack())
	var fx_count: int = 0
	for child: Node in parent.get_children():
		if child is AnimatedSprite2D:
			fx_count += 1
	assert_eq(fx_count, 1, "Exactly one spawned slash effect per swing.")


func test_weapon_layer_leaves_melee_mechanics_and_collision_unchanged() -> void:
	assert_eq(_player.melee_damage, 1)
	assert_eq(_player.melee_duration, 0.12)
	assert_eq(_player.melee_hitbox_offset, 14.0)
	var hitbox: Hitbox = _player.get_node("MeleeHitbox") as Hitbox
	var hitbox_shape: RectangleShape2D = (
		hitbox.get_node("CollisionShape2D") as CollisionShape2D
	).shape as RectangleShape2D
	assert_eq(hitbox_shape.size, Vector2(24.0, 24.0))

	assert_true(_player.try_melee_attack())
	assert_eq(hitbox.position, Vector2.DOWN * 14.0,
		"Hitbox placement still comes from the swing direction and authored offset.")
	_player._melee.update(0.12)
	assert_false(_player._melee.is_swinging, "Authored swing duration is unchanged.")

	var capsule: CapsuleShape2D = (
		_player.get_node("CollisionShape2D") as CollisionShape2D
	).shape as CapsuleShape2D
	assert_eq(capsule.radius, 7.0)
	assert_eq(capsule.height, 20.0)


func _opaque_pixel_count(image: Image, region: Rect2i) -> int:
	var count: int = 0
	for y: int in region.size.y:
		for x: int in region.size.x:
			if image.get_pixel(region.position.x + x, region.position.y + y).a > 0.0:
				count += 1
	return count


func _weapon_display_count(node: Node) -> int:
	var count: int = 1 if node is PlayerWeaponHdPresentation else 0
	for child: Node in node.get_children():
		count += _weapon_display_count(child)
	return count
