extends Node2D

## atk-09 (director 2026-11-14): the tile the player points at shows its red.
## When the targeted tile (a hovered destination or card-target tile) is in the
## red threat set, its red outline is drawn here, directly above the targeted-tile
## border, with the same paint and width as every other red tile; its red fill is
## lifted above the move-range and hover highlights but stays under the border,
## so the border's white core keeps its colour (board_layer_slices.gd).
## Input-transparent; the board keeps this node in the sibling slot right after
## the border (combat_board_view.gd).
const Slices = preload("res://scripts/board_layer_slices.gd")
const Threats = preload("res://scripts/threat_tiles.gd")
const Palette = preload("res://scripts/ui_palette.gd")

var tile := Vector2i(-1, -1)
var _paint: Dictionary = {}

func _init() -> void:
	name = "TargetedTileThreat"
	visible = false

# shown: the targeted-tile border is on this tile.
func present(board: Control, next_tile: Vector2i, shown: bool) -> void:
	var paint: Dictionary = Slices.threat_paint(board, next_tile, {}) if shown and next_tile.x >= 0 else {}
	var changed: bool = paint != _paint or next_tile != tile
	tile = next_tile
	_paint = paint
	visible = not paint.is_empty()
	if changed: queue_redraw()

func _draw() -> void:
	if _paint.is_empty(): return
	var inner: PackedVector2Array = _paint["inner"]
	var outline: PackedVector2Array = inner.duplicate()
	outline.append(inner[0])
	draw_polyline(outline, Color(Palette.DANGER, Threats.OUTLINE_ALPHA * float(_paint["alpha"])), Threats.OUTLINE_WIDTH, true)
