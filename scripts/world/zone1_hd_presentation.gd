class_name Zone1HdPresentation
extends Node2D
## Zone 1 HD 2D presentation prototype (issue #141). Lays a painted background
## plate over the entrance → encounter-room-A route and swaps the player, the
## room-A melee chaser, and the entrance shrine to static HD illustrations —
## presentation only. Collision, combat, Area2D contracts, spawns, camera, and
## save flow are untouched: the legacy display nodes stay in the tree (hidden)
## as the mechanical state source, and this node mirrors their live signals
## (facing flips, CombatFeedback self_modulate flashes, enemy state, shrine
## lit state) onto the HD sprites so gameplay readability survives static art.
##
## Sits between FloorWalls and Props in the zone tree so the plate draws over
## the legacy tiles but under props, actors, and interactables.
##
## The plate depicts environment only — no shrine, gate, pickup, character, or
## other gameplay affordance is baked into it (independent-review requirement:
## painted landmarks must never suggest interactions that do not exist). Every
## interactable keeps its own live node + visual. Legacy scenery that would
## double up with the painted plate (display-only prop sprites and the
## exit-gate marker polygon) is hidden inside the covered route; the ExitZone
## Area2D, its prompt, and everything east of the seam are untouched.

## Copied production-prototype sources; provenance (LemonadeAI /
## Flux-2-Klein-9B-GGUF, non-commercial, prototype-only) is recorded in
## assets/sprites/LICENSES.md. The background is the recomposed v2
## no-affordance plate (assets/reference/.../encounter_room_background_v2.png).
const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/sprites/hd_prototype/encounter_room_background.png")
const PLAYER_TEXTURE: Texture2D = preload("res://assets/sprites/hd_prototype/player_wanderer.png")
const CHASER_TEXTURE: Texture2D = preload("res://assets/sprites/hd_prototype/relic_hound.png")
const SHRINE_TEXTURE: Texture2D = preload("res://assets/sprites/hd_prototype/checkpoint_shrine.png")

## Filtering is a per-node decision for the prototype; the project-wide
## default and every legacy nearest-filtered node stay as they are.
const HD_TEXTURE_FILTER: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR

## Entrance room + west corridor + encounter room A (incl. its alcove column)
## + middle corridor: tiles x 0..39 at 16 px, full 480 px zone height. The
## east edge lands exactly on encounter room B's doorway wall so the
## HD-vs-legacy seam reads as a room boundary, not a random cut.
const COVERED_ROUTE_RECT: Rect2 = Rect2(0, 0, 624, 480)
const BACKGROUND_SOURCE_SIZE: Vector2 = Vector2(1024, 576)

## On-screen actor sizes chosen against the existing 2× camera so HD bodies
## keep the legacy 32 px-frame footprint and never overstate their collision
## shapes (player capsule 14×24, chaser circle r10, checkpoint pad 24×24).
const PLAYER_VISUAL_HEIGHT_PX: float = 34.0
const PLAYER_VISUAL_OFFSET: Vector2 = Vector2(0, 2)
const CHASER_VISUAL_HEIGHT_PX: float = 30.0
const SHRINE_VISUAL_HEIGHT_PX: float = 44.0
const SHRINE_VISUAL_OFFSET: Vector2 = Vector2(0, -8)

## Dormant shrines sit dimmed so Checkpoint.checkpoint_reached visibly lights
## the illustration (restoration green stays baked into the source art).
const SHRINE_DORMANT_MODULATE: Color = Color(0.62, 0.66, 0.68, 1.0)
const SHRINE_LIT_MODULATE: Color = Color.WHITE

## Zone-local HUD skin: a mossy dark panel with a contained cyan energy
## accent. Applied as theme overrides only, so shared HUD behavior/layout in
## player_hud.gd and player_hud.tscn stay intact.
const HUD_PANEL_BG_COLOR: Color = Color(0.09, 0.11, 0.1, 0.92)
const HUD_PANEL_BORDER_COLOR: Color = Color(0.3, 0.95, 1.0, 0.55)
const HUD_PANEL_CONTENT_MARGIN_PX: float = 4.0

@export var props_root_path: NodePath
@export var exit_gate_visual_path: NodePath
@export var player_path: NodePath
@export var player_visual_path: NodePath
@export var chaser_path: NodePath
@export var chaser_visual_path: NodePath
@export var checkpoint_path: NodePath
@export var checkpoint_visual_path: NodePath
@export var hud_panel_path: NodePath

var _props_root: Node2D
var _exit_gate_visual: Polygon2D
var _player: CharacterBody2D
var _player_legacy_visual: AnimatedSprite2D
var _chaser: EnemyBase
var _chaser_legacy_visual: AnimatedSprite2D
var _checkpoint: Checkpoint
var _checkpoint_legacy_visual: Polygon2D
var _hud_panel: PanelContainer

var _hidden_legacy_scenery: Array[CanvasItem] = []

var _background_sprite: Sprite2D
var _player_sprite: Sprite2D
var _chaser_sprite: Sprite2D
var _uses_prototype_chaser_fallback: bool = false
var _shrine_sprite: Sprite2D


func _ready() -> void:
	_props_root = get_node_or_null(props_root_path) as Node2D
	_exit_gate_visual = get_node_or_null(exit_gate_visual_path) as Polygon2D
	_player = get_node_or_null(player_path) as CharacterBody2D
	_player_legacy_visual = get_node_or_null(player_visual_path) as AnimatedSprite2D
	_chaser = get_node_or_null(chaser_path) as EnemyBase
	_chaser_legacy_visual = get_node_or_null(chaser_visual_path) as AnimatedSprite2D
	_checkpoint = get_node_or_null(checkpoint_path) as Checkpoint
	_checkpoint_legacy_visual = get_node_or_null(checkpoint_visual_path) as Polygon2D
	_hud_panel = get_node_or_null(hud_panel_path) as PanelContainer
	if (
		_props_root == null or _exit_gate_visual == null
		or _player == null or _player_legacy_visual == null
		or _chaser == null or _chaser_legacy_visual == null
		or _checkpoint == null or _checkpoint_legacy_visual == null
		or _hud_panel == null
	):
		push_error("Zone1HdPresentation requires valid actor/visual/HUD paths.")
		set_process(false)
		return

	_background_sprite = _build_background_sprite()
	add_child(_background_sprite)
	_hide_covered_legacy_scenery()
	var player_hd_presentation: PlayerHdPresentation = (
		_player.get_node_or_null("HdPresentation") as PlayerHdPresentation
	)
	if player_hd_presentation != null:
		# Issue #150 owns the player-wide display node. Reuse it so Zone 1 does
		# not add a duplicate HD body over the actor it already renders.
		_player_sprite = player_hd_presentation.get_display_sprite()
	else:
		_player_sprite = _install_actor_sprite(
			_player, _player_legacy_visual, PLAYER_TEXTURE,
			PLAYER_VISUAL_HEIGHT_PX, PLAYER_VISUAL_OFFSET
		)
	# The production regular-enemy pass owns the roster body. Retain the old
	# prototype hound only as a compatibility fallback for stripped fixtures.
	var roster_presentation: EnemyHdPresentation = (
		_chaser.get_node_or_null("HdPresentation") as EnemyHdPresentation
	)
	if roster_presentation != null:
		_chaser_sprite = roster_presentation.get_body_sprite()
	else:
		_uses_prototype_chaser_fallback = true
		_chaser_sprite = _install_actor_sprite(
			_chaser, _chaser_legacy_visual, CHASER_TEXTURE,
			CHASER_VISUAL_HEIGHT_PX, Vector2.ZERO
		)
	_shrine_sprite = _install_actor_sprite(
		_checkpoint, _checkpoint_legacy_visual, SHRINE_TEXTURE,
		SHRINE_VISUAL_HEIGHT_PX, SHRINE_VISUAL_OFFSET
	)
	_shrine_sprite.modulate = SHRINE_DORMANT_MODULATE
	_checkpoint.checkpoint_reached.connect(_on_checkpoint_reached)
	_apply_hud_treatment()


func _process(_delta: float) -> void:
	# The hidden legacy visuals stay driven by PlayerVisual, EnemyBase, and
	# CombatFeedback; mirroring each frame keeps facing and hit/invuln/death
	# feedback honest on the static HD art without touching those systems.
	_player_sprite.flip_h = _player_legacy_visual.flip_h
	_player_sprite.self_modulate = _player_legacy_visual.self_modulate
	if _uses_prototype_chaser_fallback:
		_chaser_sprite.flip_h = _chaser_legacy_visual.flip_h
		_chaser_sprite.self_modulate = _chaser_legacy_visual.self_modulate
		_chaser_sprite.modulate = state_tint_for(_chaser.state)


## Semantic state color for a static enemy body, mirroring the Polygon2D-enemy
## convention in EnemyBase._set_body_visual: the hound art is already violet,
## so only non-neutral states tint it.
static func state_tint_for(state: EnemyBase.State) -> Color:
	match state:
		EnemyBase.State.WIND_UP:
			return EnemyBase.WIND_UP_COLOR
		EnemyBase.State.ATTACK:
			return EnemyBase.ATTACK_COLOR
		EnemyBase.State.STAGGER:
			return EnemyBase.STAGGER_COLOR
		EnemyBase.State.DEAD:
			return EnemyBase.DEAD_COLOR
		_:
			return Color.WHITE


func get_background_sprite() -> Sprite2D:
	return _background_sprite


func get_player_sprite() -> Sprite2D:
	return _player_sprite


func get_chaser_sprite() -> Sprite2D:
	# HdPresentation is ordered before Enemies in the zone scene, so the
	# roster adapter can exist while its dynamically built Body is not ready
	# yet. Resolve lazily after the scene's full ready cascade.
	if _chaser_sprite == null and is_instance_valid(_chaser):
		var roster_presentation: EnemyHdPresentation = (
			_chaser.get_node_or_null("HdPresentation") as EnemyHdPresentation
		)
		if roster_presentation != null:
			_chaser_sprite = roster_presentation.get_body_sprite()
	return _chaser_sprite


func get_shrine_sprite() -> Sprite2D:
	return _shrine_sprite


func get_hd_sprites() -> Array[Sprite2D]:
	return [_background_sprite, _player_sprite, get_chaser_sprite(), _shrine_sprite]


## Display-only legacy scenery hidden because it sits under the painted
## plate, for tests proving the covered route carries no doubled-up visuals.
func get_hidden_legacy_scenery() -> Array[CanvasItem]:
	return _hidden_legacy_scenery


## Where the plate actually draws in zone-local pixels, for tests proving the
## entrance route is covered without leaking past the room B doorway.
func get_background_world_rect() -> Rect2:
	var drawn_size: Vector2 = _background_sprite.region_rect.size * _background_sprite.scale
	return Rect2(_background_sprite.position, drawn_size)


func _build_background_sprite() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "HdBackground"
	sprite.texture = BACKGROUND_TEXTURE
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.centered = false
	sprite.position = COVERED_ROUTE_RECT.position
	# Uniform scale fits the 576 px-tall plate to the 480 px zone height; the
	# region crops the source width so the drawn rect ends exactly on the
	# route boundary instead of stretching the art.
	var plate_scale: float = COVERED_ROUTE_RECT.size.y / BACKGROUND_SOURCE_SIZE.y
	sprite.scale = Vector2(plate_scale, plate_scale)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		0, 0, COVERED_ROUTE_RECT.size.x / plate_scale, BACKGROUND_SOURCE_SIZE.y
	)
	return sprite


## Hides the display-only legacy scenery the plate paints over: the prop
## sprites whose position falls inside the covered route, and the exit-gate
## marker Polygon2D at the entrance. Visibility only — no node is removed or
## reparented, and nothing mechanical is touched: props carry no collision or
## script, and the exit interaction lives on the separate ExitZone Area2D
## (kept monitoring, with its prompt). Props east of the room B seam and the
## secret-alcove reveal covers (mechanical, drawn above the plate) stay as
## they are.
func _hide_covered_legacy_scenery() -> void:
	_exit_gate_visual.visible = false
	_hidden_legacy_scenery = [_exit_gate_visual]
	for child: Node in _props_root.get_children():
		var prop: Node2D = child as Node2D
		if prop != null and COVERED_ROUTE_RECT.has_point(prop.position):
			prop.visible = false
			_hidden_legacy_scenery.append(prop)


## Hides only the legacy display node and parents a static HD illustration on
## the same actor, scaled to the given on-screen height. The legacy node keeps
## its script, frames, and signal wiring as the live state source.
func _install_actor_sprite(
	actor: Node2D,
	legacy_visual: CanvasItem,
	texture: Texture2D,
	target_height_px: float,
	offset: Vector2,
) -> Sprite2D:
	legacy_visual.visible = false
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "HdVisual"
	sprite.texture = texture
	sprite.texture_filter = HD_TEXTURE_FILTER
	sprite.position = offset
	var visual_scale: float = target_height_px / float(texture.get_height())
	sprite.scale = Vector2(visual_scale, visual_scale)
	actor.add_child(sprite)
	return sprite


func _on_checkpoint_reached(_respawn_position: Vector2) -> void:
	_shrine_sprite.modulate = SHRINE_LIT_MODULATE


func _apply_hud_treatment() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HUD_PANEL_BG_COLOR
	style.border_color = HUD_PANEL_BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(HUD_PANEL_CONTENT_MARGIN_PX)
	_hud_panel.add_theme_stylebox_override("panel", style)
