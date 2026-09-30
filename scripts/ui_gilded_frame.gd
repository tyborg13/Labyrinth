extends RefCounted

# Code-drawn "gilded glass" frame shared by dialogs, HUD plates and choice
# panels: warm ink glass, a fine double gold hairline and small diamond corner
# studs. Everything is vector-drawn so it stays crisp at every UI scale and
# never competes with the pixel-art board for attention.

const Palette = preload("res://scripts/ui_palette.gd")

# Soft, offset drop shadow built from stacked translucent rounded rects.
static func draw_shadow(canvas: CanvasItem, rect: Rect2, spread: float = 14.0, alpha: float = 0.55, offset: Vector2 = Vector2(0.0, 8.0), radius: float = 6.0) -> void:
	var steps: int = 7
	for index: int in range(steps):
		var t: float = float(index + 1) / float(steps)
		var grow: float = spread * t
		var layer_alpha: float = alpha * (1.0 - t) * (1.0 - t) * 0.42
		_draw_rounded_rect(canvas, rect.grow(grow - spread * 0.25).grow_individual(0, 0, 0, 0), radius + grow, Color(0.0, 0.0, 0.0, layer_alpha), offset)

# Vertical gradient fill (top -> bottom) with softly cut corners.
static func draw_fill(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, cut: float = 4.0) -> void:
	var points: PackedVector2Array = cut_corner_points(rect, cut)
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var t: float = clampf((point.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	canvas.draw_polygon(points, colors)

# Warm top light and cool bottom falloff over an existing surface.
static func draw_sheen(canvas: CanvasItem, rect: Rect2, strength: float = 1.0, cut: float = 4.0) -> void:
	var top_band := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5))
	var points: PackedVector2Array = cut_corner_points(top_band, cut)
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var t: float = clampf((point.y - top_band.position.y) / maxf(1.0, top_band.size.y), 0.0, 1.0)
		colors.append(Color(1.0, 0.90, 0.70, 0.075 * strength * (1.0 - t)))
	canvas.draw_polygon(points, colors)
	var bottom_band := Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y * 0.55), Vector2(rect.size.x, rect.size.y * 0.45))
	points = cut_corner_points(bottom_band, cut)
	colors = PackedColorArray()
	for point: Vector2 in points:
		var t: float = clampf((point.y - bottom_band.position.y) / maxf(1.0, bottom_band.size.y), 0.0, 1.0)
		colors.append(Color(0.0, 0.0, 0.0, 0.20 * strength * t))
	canvas.draw_polygon(points, colors)

# Fine double hairline with diamond corner studs and short filigree ticks.
static func draw_gilding(canvas: CanvasItem, rect: Rect2, gold: Color = Palette.GOLD, strength: float = 1.0, inner_inset: float = 4.0, cut: float = 4.0, corner_studs: bool = true) -> void:
	var outer: Color = Color(gold, 0.62 * strength)
	var inner: Color = Color(gold, 0.20 * strength)
	var outer_rect: Rect2 = rect.grow(-0.5)
	canvas.draw_polyline(_closed(cut_corner_points(outer_rect, cut)), outer, 1.0, true)
	if inner_inset > 0.0 and rect.size.x > inner_inset * 4.0 and rect.size.y > inner_inset * 4.0:
		var inner_rect: Rect2 = outer_rect.grow(-inner_inset)
		canvas.draw_polyline(_closed(cut_corner_points(inner_rect, maxf(1.0, cut - 1.5))), inner, 1.0, true)
	# A single warm catch-light along the top edge reads as polished metal.
	var catch_light := Color(1.0, 0.93, 0.76, 0.34 * strength)
	var span: float = minf(outer_rect.size.x * 0.34, 180.0)
	var center_x: float = outer_rect.position.x + outer_rect.size.x * 0.5
	_draw_fading_line(canvas, Vector2(center_x - span, outer_rect.position.y), Vector2(center_x + span, outer_rect.position.y), catch_light)
	if not corner_studs:
		return
	var stud: float = clampf(minf(rect.size.x, rect.size.y) * 0.045, 3.0, 5.5)
	var tick: float = clampf(minf(rect.size.x, rect.size.y) * 0.10, 8.0, 22.0)
	var tick_color := Color(gold, 0.85 * strength)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var point: Vector2 = outer_rect.position + outer_rect.size * corner
		var inward: Vector2 = Vector2.ONE - corner * 2.0
		var inset_point: Vector2 = point + inward * inner_inset
		canvas.draw_line(inset_point, inset_point + Vector2(inward.x * tick, 0.0), tick_color, 1.0, true)
		canvas.draw_line(inset_point, inset_point + Vector2(0.0, inward.y * tick), tick_color, 1.0, true)
		draw_diamond(canvas, point + inward * 1.5, stud, gold, strength)

# Bold L-shaped corner brackets with a stepped inner return, for major dialogs.
static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, gold: Color = Palette.GOLD, length: float = 30.0, width: float = 2.0, inset: float = 1.0, strength: float = 1.0) -> void:
	var color := Color(gold.lerp(Palette.GOLD_BRIGHT, 0.2), 0.95 * strength)
	var shadow := Color(0.0, 0.0, 0.0, 0.55 * strength)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var inward: Vector2 = Vector2.ONE - corner * 2.0
		var origin: Vector2 = rect.position + rect.size * corner + inward * inset
		var h_end: Vector2 = origin + Vector2(inward.x * length, 0.0)
		var v_end: Vector2 = origin + Vector2(0.0, inward.y * length)
		canvas.draw_line(origin + Vector2(0.0, 1.0), h_end + Vector2(0.0, 1.0), shadow, width, true)
		canvas.draw_line(origin, h_end, color, width, true)
		canvas.draw_line(origin, v_end, color, width, true)
		# Stepped return: a short parallel line tucked inside the bracket.
		var step: float = 5.0
		var inner_origin: Vector2 = origin + inward * step
		canvas.draw_line(inner_origin, inner_origin + Vector2(inward.x * length * 0.45, 0.0), Color(color, color.a * 0.55), 1.0, true)
		canvas.draw_line(inner_origin, inner_origin + Vector2(0.0, inward.y * length * 0.45), Color(color, color.a * 0.55), 1.0, true)
		draw_diamond(canvas, origin + Vector2(inward.x * (length + 5.0), 0.0), 2.6, gold, strength)
		draw_diamond(canvas, origin + Vector2(0.0, inward.y * (length + 5.0)), 2.6, gold, strength)

static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, gold: Color = Palette.GOLD, strength: float = 1.0) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius), center + Vector2(-radius, 0.0)
	])
	canvas.draw_colored_polygon(points, Color(Palette.INK_0, 0.9 * strength))
	var inner := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.72), center + Vector2(radius * 0.72, 0.0),
		center + Vector2(0.0, radius * 0.72), center + Vector2(-radius * 0.72, 0.0)
	])
	canvas.draw_colored_polygon(inner, Color(gold.lerp(Palette.GOLD_BRIGHT, 0.35), strength))
	canvas.draw_line(center + Vector2(-radius * 0.35, -radius * 0.2), center + Vector2(0.0, -radius * 0.55), Color(1.0, 0.96, 0.84, 0.75 * strength), 1.0, true)

# Horizontal ornamental rule: line - diamond - line, fading at both ends.
static func draw_rule(canvas: CanvasItem, from: Vector2, to: Vector2, gold: Color = Palette.GOLD, strength: float = 1.0, center_diamond: bool = true) -> void:
	var middle: Vector2 = (from + to) * 0.5
	var gap: float = 9.0 if center_diamond else 0.0
	_draw_fading_line(canvas, middle - Vector2(gap, 0.0), from, Color(gold, 0.55 * strength), true)
	_draw_fading_line(canvas, middle + Vector2(gap, 0.0), to, Color(gold, 0.55 * strength), true)
	if center_diamond:
		draw_diamond(canvas, middle, 4.0, gold, strength)

# Complete panel: shadow, gradient glass, sheen and gilding in one call.
static func draw_panel(canvas: CanvasItem, rect: Rect2, options: Dictionary = {}) -> void:
	var cut: float = float(options.get("cut", 5.0))
	var gold: Color = options.get("gold", Palette.GOLD)
	var strength: float = float(options.get("strength", 1.0))
	if bool(options.get("shadow", true)):
		draw_shadow(canvas, rect, float(options.get("shadow_spread", 16.0)), float(options.get("shadow_alpha", 0.6)))
	var glow: Color = options.get("glow", Color.TRANSPARENT)
	if glow.a > 0.0:
		draw_glow(canvas, rect, glow, float(options.get("glow_spread", 12.0)), cut)
	draw_fill(canvas, rect, options.get("top", Palette.INK_2), options.get("bottom", Palette.INK_1), cut)
	draw_sheen(canvas, rect, float(options.get("sheen", 1.0)), cut)
	draw_gilding(canvas, rect, gold, strength, float(options.get("inner_inset", 4.0)), cut, bool(options.get("corner_studs", true)))

static func draw_glow(canvas: CanvasItem, rect: Rect2, glow: Color, spread: float = 12.0, cut: float = 5.0) -> void:
	var steps: int = 6
	for index: int in range(steps):
		var t: float = float(index + 1) / float(steps)
		var layer := Color(glow, glow.a * (1.0 - t) * 0.5)
		canvas.draw_polyline(_closed(cut_corner_points(rect.grow(spread * t * 0.8), cut + spread * t * 0.5)), layer, spread / float(steps) + 1.0, true)

static func cut_corner_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var c: float = clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	if c <= 0.01:
		return PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
	return PackedVector2Array([
		Vector2(left + c, top), Vector2(right - c, top), Vector2(right, top + c), Vector2(right, bottom - c),
		Vector2(right - c, bottom), Vector2(left + c, bottom), Vector2(left, bottom - c), Vector2(left, top + c),
	])

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result

static func _draw_rounded_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, offset: Vector2) -> void:
	var r: Rect2 = Rect2(rect.position + offset, rect.size)
	canvas.draw_colored_polygon(cut_corner_points(r, radius * 0.6), color)

# Line whose alpha fades from full at `from` to zero at `to` (or both ends).
static func _draw_fading_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, one_sided: bool = false) -> void:
	var segments: int = 12
	for index: int in range(segments):
		var a: float = float(index) / float(segments)
		var b: float = float(index + 1) / float(segments)
		var mid: float = (a + b) * 0.5
		var fade: float = (1.0 - mid) if one_sided else (1.0 - absf(mid - 0.5) * 2.0)
		canvas.draw_line(from.lerp(to, a), from.lerp(to, b), Color(color, color.a * fade), 1.0, true)
