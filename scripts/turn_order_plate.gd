extends Control

# Initiative tile, drawn in the shared gilded-glass language. The "fill" layer
# sits beneath the sprite portrait; the "rim" layer sits above it so the team
# hairline and the next-actor gilding are never hidden by the sprite.

const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const Palette = preload("res://scripts/ui_palette.gd")

const LAYER_FILL: String = "fill"
const LAYER_RIM: String = "rim"
const CUT: float = 4.0

var layer: String = LAYER_FILL
var team: String = "enemy"
var active: bool = false
var projected: bool = false

func configure(layer_name: String, team_name: String, is_active: bool, is_projected: bool) -> void:
	layer = layer_name
	team = team_name
	active = is_active
	projected = is_projected
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func team_color() -> Color:
	return Palette.ALLY if team == "player" else Palette.DANGER

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	if layer == LAYER_FILL:
		_draw_fill(rect)
	else:
		_draw_rim(rect)

func _draw_fill(rect: Rect2) -> void:
	if active:
		GildedFrame.draw_glow(self, rect, Color(Palette.EMBER, 0.42), 9.0, CUT)
	else:
		GildedFrame.draw_shadow(self, rect, 7.0, 0.5, Vector2(0.0, 3.0), CUT)
	var tint: Color = team_color()
	var top := Color(Palette.INK_2.lerp(tint, 0.05), 0.80 if active else 0.70)
	var bottom := Color(Palette.INK_0.lerp(tint, 0.06), 0.94)
	GildedFrame.draw_fill(self, rect, top, bottom, CUT)
	GildedFrame.draw_sheen(self, rect, 0.8, CUT)

func _draw_rim(rect: Rect2) -> void:
	var tint: Color = team_color()
	if active:
		GildedFrame.draw_gilding(self, rect, Palette.GOLD_BRIGHT, 1.0, 3.0, CUT, true)
		return
	var alpha: float = 0.70 if projected else 0.50
	draw_polyline(_closed(GildedFrame.cut_corner_points(rect.grow(-0.5), CUT)), Color(tint.lerp(Palette.GOLD_DIM, 0.55), alpha), 1.0, true)
	# A short team-coloured base line anchors the health bar to its owner.
	draw_line(Vector2(rect.position.x + CUT, rect.end.y - 1.0), Vector2(rect.end.x - CUT, rect.end.y - 1.0), Color(tint, 0.75), 1.5, true)

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
