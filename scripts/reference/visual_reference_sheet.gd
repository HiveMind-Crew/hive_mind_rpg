class_name VisualReferenceSheet
extends Node2D
## F6-runnable proof sheet for docs/visual_bible.md (issue #82): renders the
## canonical corrupted-forest palette groups plus a native 640x360 readability
## strip using only built-in nodes (no textures). PALETTE_GROUPS mirrors the
## bible's hex tables; change them only together, in the same PR.

const VIEW_SIZE: Vector2 = Vector2(640, 360)
const FONT_SIZE: int = 8
const SWATCH_SIZE: Vector2 = Vector2(38, 20)
const SWATCH_GAP: float = 4.0
const ROW_HEIGHT: float = 34.0
const LABEL_COLUMN_WIDTH: float = 148.0
const ROWS_TOP: float = 26.0
const STRIP_TOP: float = 244.0

const COLOR_BACKGROUND: Color = Color("#100D16")
const COLOR_TEXT: Color = Color("#F2E9CE")
const COLOR_TEXT_DIM: Color = Color("#B8A98C")

## Group name -> ordered swatches; one row each, in bible section order.
const PALETTE_GROUPS: Dictionary = {
	"World: canopy / soil / bark": [
		Color("#100D16"), Color("#1C1826"), Color("#2A2438"),
		Color("#2E211B"), Color("#4A3628"), Color("#6B4E33"), Color("#8F6D46"),
	],
	"World: moss / stone / parchment": [
		Color("#1E2B1D"), Color("#33472A"), Color("#4F6B38"), Color("#7A934F"),
		Color("#2B2B33"), Color("#45454F"), Color("#63636E"),
		Color("#B8A98C"), Color("#D9CBA8"), Color("#F2E9CE"),
	],
	"Corruption: relic cyan / magenta": [
		Color("#0F4A52"), Color("#1FA0A8"), Color("#4DE5FF"), Color("#C8F8FF"),
		Color("#5C1E52"), Color("#9E2966"), Color("#F259B8"), Color("#FFC8EC"),
	],
	"Player (teal + accent)": [
		Color("#0E5F58"), Color("#1FD1C2"), Color("#A8FFF2"), Color("#F259B8"),
	],
	"Enemies (violet + tells)": [
		Color("#3A1445"), Color("#9440AD"), Color("#D98FF0"),
		Color("#FFC72E"), Color("#FF3340"),
	],
	"UI & signals": [
		Color("#171721"), Color("#F2E9CE"), Color("#8CE5FF"),
		Color("#FFB8B8"), Color("#80F2B8"), Color("#666B80"), Color("#383842"),
	],
}

## Readability-strip actor colors (bible anchors already used in gameplay).
const STRIP_FLOOR: Color = Color("#33472A")
const STRIP_FLOOR_PATCH: Color = Color("#4A3628")
const STRIP_WALL: Color = Color("#2B2B33")
const STRIP_WALL_RIM: Color = Color("#63636E")
const STRIP_PLAYER: Color = Color("#1FD1C2")
const STRIP_PLAYER_ACCENT: Color = Color("#F259B8")
const STRIP_ENEMY: Color = Color("#9440AD")
const STRIP_BOLT: Color = Color("#4DE5FF")
const STRIP_PICKUP: Color = Color("#4DE5FF")
const STRIP_CHECKPOINT_LIT: Color = Color("#80F2B8")
const STRIP_CORRUPTION: Color = Color("#9E2966")
const STRIP_UI_PANEL: Color = Color("#171721")
const STRIP_UI_HEALTH: Color = Color("#FFB8B8")
const STRIP_UI_ENERGY: Color = Color("#8CE5FF")


func _ready() -> void:
	_add_rect(Vector2.ZERO, VIEW_SIZE, COLOR_BACKGROUND, self)
	_add_label(
		"VISUAL BIBLE v1 — corrupted forest palette (docs/visual_bible.md)",
		Vector2(8, 6),
		COLOR_TEXT
	)
	_build_swatch_rows()
	_build_readability_strip()


func swatch_color_count() -> int:
	var total: int = 0
	for group_name: String in PALETTE_GROUPS:
		var swatches: Array = PALETTE_GROUPS[group_name]
		total += swatches.size()
	return total


func _build_swatch_rows() -> void:
	var row_index: int = 0
	for group_name: String in PALETTE_GROUPS:
		var row_top: float = ROWS_TOP + row_index * ROW_HEIGHT
		_add_label(group_name, Vector2(8, row_top + 5), COLOR_TEXT_DIM)
		var swatches: Array = PALETTE_GROUPS[group_name]
		for swatch_index: int in swatches.size():
			var swatch_color: Color = swatches[swatch_index]
			var swatch_left: float = (
				LABEL_COLUMN_WIDTH + swatch_index * (SWATCH_SIZE.x + SWATCH_GAP)
			)
			_add_rect(
				Vector2(swatch_left, row_top), SWATCH_SIZE, swatch_color, self
			)
			var hex_color: Color = (
				COLOR_TEXT if swatch_color.get_luminance() < 0.45
				else COLOR_BACKGROUND
			)
			_add_label(
				"#" + swatch_color.to_html(false).to_upper(),
				Vector2(swatch_left + 1, row_top + 5),
				hex_color
			)
		row_index += 1


## Mocks a native-resolution slice of Zone 1: floor + wall bands with
## actor/interactable/UI silhouettes, proving color separation at 1:1 scale.
func _build_readability_strip() -> void:
	var strip: Node2D = Node2D.new()
	strip.name = "ReadabilityStrip"
	add_child(strip)

	var strip_height: float = VIEW_SIZE.y - STRIP_TOP
	_add_label(
		"Readability strip — native 640x360, 1 texel = 1 px. Actors must read"
		+ " in silhouette on floor and wall.",
		Vector2(8, STRIP_TOP - 14),
		COLOR_TEXT_DIM
	)
	# Wall band (top) with rim light, then walkable floor with soil patches.
	_add_rect(Vector2(0, STRIP_TOP), Vector2(VIEW_SIZE.x, 32), STRIP_WALL, strip)
	_add_rect(
		Vector2(0, STRIP_TOP + 30), Vector2(VIEW_SIZE.x, 2), STRIP_WALL_RIM, strip
	)
	_add_rect(
		Vector2(0, STRIP_TOP + 32),
		Vector2(VIEW_SIZE.x, strip_height - 32),
		STRIP_FLOOR,
		strip
	)
	for patch_index: int in 8:
		_add_rect(
			Vector2(24 + patch_index * 80, STRIP_TOP + 48 + (patch_index % 3) * 14),
			Vector2(32, 10),
			STRIP_FLOOR_PATCH,
			strip
		)

	var wall_silhouettes: Node2D = Node2D.new()
	wall_silhouettes.name = "WallSilhouettes"
	strip.add_child(wall_silhouettes)
	# Player/enemy silhouettes against wall-dark prove the required second
	# readability context; labels sit below the wall band.
	_add_rect(Vector2(60, STRIP_TOP + 5), Vector2(14, 20), STRIP_PLAYER, wall_silhouettes)
	_add_rect(
		Vector2(65, STRIP_TOP + 21), Vector2(4, 4), STRIP_PLAYER_ACCENT, wall_silhouettes
	)
	_add_label("player / wall", Vector2(42, STRIP_TOP + 33), COLOR_TEXT_DIM)
	_add_rect(Vector2(150, STRIP_TOP + 5), Vector2(20, 20), STRIP_ENEMY, wall_silhouettes)
	_add_label("enemy / wall", Vector2(134, STRIP_TOP + 33), COLOR_TEXT_DIM)

	var floor_silhouettes: Node2D = Node2D.new()
	floor_silhouettes.name = "FloorSilhouettes"
	strip.add_child(floor_silhouettes)
	var actor_row: float = STRIP_TOP + 52
	# Player/enemy silhouettes on floor-mid prove the primary gameplay context.
	_add_rect(Vector2(60, actor_row), Vector2(14, 20), STRIP_PLAYER, floor_silhouettes)
	_add_rect(
		Vector2(65, actor_row + 16), Vector2(4, 4), STRIP_PLAYER_ACCENT, floor_silhouettes
	)
	_add_label("player / floor", Vector2(40, actor_row + 24), COLOR_TEXT_DIM)
	_add_rect(Vector2(150, actor_row), Vector2(20, 20), STRIP_ENEMY, floor_silhouettes)
	_add_label("enemy / floor", Vector2(132, actor_row + 24), COLOR_TEXT_DIM)
	# Energy bolt and skill-point pickup: relic cyan, 8x8.
	_add_rect(Vector2(244, actor_row + 6), Vector2(8, 8), STRIP_BOLT, strip)
	_add_label("bolt", Vector2(230, actor_row + 24), COLOR_TEXT_DIM)
	_add_rect(Vector2(316, actor_row + 6), Vector2(8, 8), STRIP_PICKUP, strip)
	_add_label("pickup", Vector2(298, actor_row + 24), COLOR_TEXT_DIM)
	# Checkpoint (lit) and a corruption vein against the wall band.
	_add_rect(Vector2(388, actor_row - 4), Vector2(16, 24), STRIP_CHECKPOINT_LIT, strip)
	_add_label("checkpoint", Vector2(368, actor_row + 24), COLOR_TEXT_DIM)
	_add_rect(Vector2(470, STRIP_TOP + 4), Vector2(4, strip_height - 8), STRIP_CORRUPTION, strip)
	_add_label("corruption", Vector2(452, actor_row + 24), COLOR_TEXT_DIM)
	# HUD mock: panel with health/energy text colors over the world colors.
	_add_rect(Vector2(536, actor_row - 6), Vector2(92, 34), STRIP_UI_PANEL, strip)
	_add_label("HP 12/12", Vector2(541, actor_row - 2), STRIP_UI_HEALTH)
	_add_label("Energy 30/30", Vector2(541, actor_row + 12), STRIP_UI_ENERGY)


func _add_rect(
	top_left: Vector2, size: Vector2, color: Color, parent: Node
) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.position = top_left
	rect.size = size
	rect.color = color
	parent.add_child(rect)
	return rect


func _add_label(text: String, top_left: Vector2, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = top_left
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(label)
	return label
