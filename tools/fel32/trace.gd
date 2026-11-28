extends RefCounted
## Headless diagnostic pack hooks at the production CanvasItem draw calls.

const Palette = preload("res://scripts/ui_palette.gd")
const ROWS := &"fel32_draw_rows"
const BORDER := &"fel32_border_drawn"


static func begin(canvas: CanvasItem) -> void:
	if canvas.has_meta(ROWS): canvas.remove_meta(ROWS)


static func operation(canvas: CanvasItem, method: String, args: Array) -> void:
	if method != "draw_polyline" and method != "draw_colored_polygon": return
	var polygon: PackedVector2Array = args[0]
	if polygon.size() < 4 or polygon.size() > 6: return
	var color: Color = args[1]
	var rgb := Color(color, 1.0)
	if method == "draw_polyline":
		if polygon[0] != polygon[-1] or rgb not in [Palette.DANGER_BRIGHT, Color(Palette.PREVIEW_INK, 1.0)]: return
		_record(canvas, polygon, color, float(args[2]), bool(args[3]))
	elif rgb == Palette.DANGER:
		_record(canvas, polygon, color, 0.0, false)


static func _record(canvas: CanvasItem, polygon: PackedVector2Array, color: Color, width: float, aa: bool) -> void:
	var rows: Array = canvas.get_meta(ROWS, [])
	rows.append({"polygon": polygon, "color": color, "width": width, "antialias": aa})
	canvas.set_meta(ROWS, rows)


static func snapshot(board: Control) -> Dictionary:
	var rows: Dictionary
	_collect(board, board, rows)
	return rows


static func _collect(node: Node, board: Control, tiles: Dictionary) -> void:
	var canvas := node as CanvasItem
	if canvas == null or not canvas.is_visible_in_tree() or canvas.is_queued_for_deletion(): return
	if canvas.has_meta(ROWS):
		var to_screen: Transform2D = canvas.get_global_transform_with_canvas()
		for record: Dictionary in canvas.get_meta(ROWS):
			var polygon: PackedVector2Array = record["polygon"]
			var tile: Vector2i = board.tile_at_global_position(to_screen * ((polygon[0] + polygon[2]) * 0.5))
			var row: Dictionary = tiles.get_or_add(tile, {"strokes": []})
			var color: Color = record["color"]
			var rgba: Array = [color.r, color.g, color.b, color.a]
			if record["width"] == 0.0:
				row["fill"] = rgba
				continue
			var points: Array = []
			for point: Vector2 in to_screen * polygon: points.append([point.x, point.y])
			row["strokes"].append({"points": points, "rgba": rgba, "width": record["width"],
				"antialias": record["antialias"], "canvas": str(canvas.name)})
	for child: Node in node.get_children(): _collect(child, board, tiles)
