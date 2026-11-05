extends "res://scripts/board_hud_triangle_batch.gd"

## Widget-local retained geometry. The owner compares scalar inputs before
## replay: no per-segment hashing, tessellation or submissions on a warm draw.
## Native text, textures, borders and AA lines are explicit flush boundaries.
var _retained: Dictionary = {}
var _separator_inputs: Array = []

func rect(bounds: Rect2, color: Color) -> void:
	var r: Rect2 = bounds.abs()
	_pending.append([
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([color]), PackedInt32Array([0, 1, 2, 0, 2, 3])
	])

func separators(bounds: Rect2, count: int, width: float, color: Color) -> void:
	for index: int in range(1, count):
		var x: float = bounds.position.x + bounds.size.x * float(index) / float(count)
		rect(Rect2(Vector2(x - width * 0.5, bounds.position.y), Vector2(width, bounds.size.y)), color)

func draw_separators(canvas: CanvasItem, bounds: Rect2, count: int, width: float, color: Color) -> void:
	var inputs: Array = [bounds, count, width, color]
	if inputs == _separator_inputs:
		replay(canvas)
		return
	_separator_inputs = inputs
	separators(bounds, count, width, color)
	flush(canvas)

func flush(canvas: CanvasItem) -> void:
	_retained = _build(_pending)
	_pending.clear()
	replay(canvas)

func replay(canvas: CanvasItem) -> void:
	if _retained.is_empty() or (_retained["indices"] as PackedInt32Array).is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), _retained["indices"], _retained["points"], _retained["colors"])

func _build(commands: Array[Array]) -> Dictionary:
	var result: Dictionary = {"points": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	for command: Array in commands:
		var indices: PackedInt32Array = command[2] if command.size() == 3 else Geometry2D.triangulate_polygon(command[0])
		_append(result, command[0], command[1], indices)
	return result

func sheen(bounds: Rect2, strength: float, cut: float) -> void:
	# Same faces, colour arithmetic and triangulation as GildedFrame.draw_sheen.
	var frame = preload("res://scripts/ui_gilded_frame.gd")
	var top_band := Rect2(bounds.position, Vector2(bounds.size.x, bounds.size.y * 0.5))
	var points: PackedVector2Array = frame.cut_corner_points(top_band, cut)
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var t: float = clampf((point.y - top_band.position.y) / maxf(1.0, top_band.size.y), 0.0, 1.0)
		colors.append(Color(1.0, 0.90, 0.70, 0.075 * strength * (1.0 - t)))
	polygon(points, colors)
	var bottom_band := Rect2(Vector2(bounds.position.x, bounds.position.y + bounds.size.y * 0.55), Vector2(bounds.size.x, bounds.size.y * 0.45))
	points = frame.cut_corner_points(bottom_band, cut)
	colors = PackedColorArray()
	for point: Vector2 in points:
		var t: float = clampf((point.y - bottom_band.position.y) / maxf(1.0, bottom_band.size.y), 0.0, 1.0)
		colors.append(Color(0.0, 0.0, 0.0, 0.20 * strength * t))
	polygon(points, colors)

func health_faces(bounds: Rect2, value: float, maximum: float, background: Color, fill: Color, highlight: Color) -> void:
	# Stable (no ghost/heal) subset of SegmentedHealthBar.draw_bar, in exactly
	# the same paint order and with the same authored arithmetic.
	var ratio: float = clamp(value / maxf(maximum, 1.0), 0.0, 1.0)
	_vertical_shade(bounds, background.darkened(0.24), background)
	if ratio <= 0.0: return
	var fill_rect := Rect2(bounds.position, Vector2(bounds.size.x * ratio, bounds.size.y))
	var shoulder: float = fill_rect.size.y * 0.35
	var lit: Color = fill.lerp(highlight, 0.56)
	_vertical_shade(Rect2(fill_rect.position, Vector2(fill_rect.size.x, shoulder)), fill, lit)
	_vertical_shade(Rect2(fill_rect.position + Vector2(0.0, shoulder), Vector2(fill_rect.size.x, fill_rect.size.y - shoulder)), lit, fill.darkened(0.32))
	rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, minf(fill_rect.size.y, 1.0))), highlight)
	if ratio < 1.0:
		var cap_width: float = minf(1.0, fill_rect.size.x)
		rect(Rect2(Vector2(fill_rect.end.x - cap_width, fill_rect.position.y), Vector2(cap_width, fill_rect.size.y)), highlight.lerp(fill, 0.38))

func _vertical_shade(bounds: Rect2, top: Color, bottom: Color) -> void:
	polygon(
		PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]),
		PackedColorArray([top, top, bottom, bottom])
	)
