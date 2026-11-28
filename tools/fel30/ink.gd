extends RefCounted
## Record draw submissions without adding a rendering command or CanvasItem.

const ROWS := &"fel30_ink"
const STACK := &"fel30_scope"
const MATRIX := &"fel30_matrix"
const LANE := 8.0 # Checked against CombatArtTreatment.UV_LANE by prepare.py.

class Scope extends RefCounted:
	var canvas: CanvasItem

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and is_instance_valid(canvas):
			var stack: Array = canvas.get_meta(STACK)
			stack.pop_back()


static func begin(canvas: CanvasItem) -> void:
	canvas.set_meta(ROWS, [])
	canvas.set_meta(MATRIX, Transform2D.IDENTITY)


static func owner(view: Object) -> CanvasItem:
	return view as CanvasItem if view is CanvasItem else view.get("view") as CanvasItem


static func scope(view: Object, kind: String, name: String, tile: Vector2i = Vector2i(-1, -1), actor: String = "") -> RefCounted:
	var canvas: CanvasItem = owner(view)
	var marker := Scope.new()
	if not is_instance_valid(canvas): return marker
	marker.canvas = canvas
	if not canvas.has_meta(STACK): canvas.set_meta(STACK, [])
	var stack: Array = canvas.get_meta(STACK)
	if actor.is_empty() and not stack.is_empty(): actor = stack.back()["actor"]
	stack.append({"kind": kind, "what": name, "tile": tile, "actor": actor})
	return marker


static func row(view: Object, shape: Dictionary, alpha: float, z: int = 0, kind: String = "", name: String = "") -> void:
	var canvas: CanvasItem = owner(view)
	if not is_instance_valid(canvas) or not canvas.has_meta(ROWS) or alpha <= 0.0: return
	var stack: Array = canvas.get_meta(STACK, [])
	if stack.is_empty(): return
	var record: Dictionary = stack.back().duplicate()
	if not kind.is_empty(): record["kind"] = kind
	if not name.is_empty(): record["text"] = name
	record.merge(shape)
	record["alpha"] = alpha
	record["z"] = z
	record["matrix"] = canvas.get_meta(MATRIX, Transform2D.IDENTITY)
	var rows: Array = canvas.get_meta(ROWS)
	rows.append(record)


static func shape(view: Object, rect: Rect2, alpha: float = 1.0, z: int = 0) -> void:
	if rect.has_area(): row(view, {"rect": rect}, alpha, z)


static func texture(view: Object, tex: Texture2D, rect: Rect2, alpha: float, region: Rect2 = Rect2(), transpose: bool = false) -> void:
	if tex != null and absf(rect.get_area()) > 0.0:
		row(view, {"texture": tex, "rect": rect, "region": region, "transpose": transpose}, alpha)


static func text(view: Object, font: Font, at: Vector2, line: String, align: int, width: float, size: int, color: Color, z: int = 0) -> void:
	if font == null or line.is_empty(): return
	var measured: Vector2 = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var start: Vector2 = at - Vector2(0, font.get_ascent(size))
	if width >= 0.0 and measured.x < width:
		if align == HORIZONTAL_ALIGNMENT_CENTER: start.x += (width - measured.x) * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT: start.x += width - measured.x
	if width >= 0.0: measured.x = minf(measured.x, width)
	if measured.x > 0.0: row(view, {"rect": Rect2(start, measured)}, color.a, z, "", line)


static func draw_texture_rect(view: Object, tex: Texture2D, rect: Rect2, tile: bool, color: Color = Color.WHITE, transpose: bool = false) -> void:
	texture(view, tex, rect, color.a, Rect2(), transpose)
	view.draw_texture_rect(tex, rect, tile, color, transpose)


static func draw_texture_rect_region(view: Object, tex: Texture2D, rect: Rect2, region: Rect2, color: Color = Color.WHITE, transpose: bool = false, clip: bool = true) -> void:
	texture(view, tex, rect, color.a, region, transpose)
	if view is CanvasItem: view.draw_texture_rect_region(tex, rect, region, color, transpose, clip)
	else: view.draw_texture_rect_region(tex, rect, region, color)


static func draw_texture(view: Object, tex: Texture2D, at: Vector2, color: Color = Color.WHITE) -> void:
	if tex != null: texture(view, tex, Rect2(at, tex.get_size()), color.a)
	view.draw_texture(tex, at, color)


static func draw_polygon(view: Object, poly: PackedVector2Array, colors: PackedColorArray, uv: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	polygon(view, poly, colors, uv, tex)
	view.draw_polygon(poly, colors, uv, tex)


static func polygon(view: Object, poly: PackedVector2Array, colors: PackedColorArray, uv: PackedVector2Array, tex: Texture2D, lane: float = 0.0) -> void:
	var canvas: CanvasItem = owner(view)
	if not is_instance_valid(canvas) or not canvas.has_meta(STACK) or (canvas.get_meta(STACK) as Array).is_empty(): return
	var coords: PackedVector2Array = uv
	if tex != null and uv.size() == poly.size():
		coords = uv.duplicate()
		for index: int in coords.size():
			var x: float = coords[index].x
			if lane > 0.0: x -= lane
			coords[index] = Vector2(x, coords[index].y) * tex.get_size()
	row(view, {"polygon": poly, "uv": coords, "texture": tex, "colors": colors}, colors[0].a if colors.size() == 1 else 1.0)


static func draw_colored_polygon(view: Object, poly: PackedVector2Array, color: Color, uv: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	polygon(view, poly, PackedColorArray([color]), uv, tex)
	view.draw_colored_polygon(poly, color, uv, tex)


static func draw_rect(view: Object, rect: Rect2, color: Color, fill: bool = true, width: float = -1.0, smooth: bool = false) -> void:
	if fill: shape(view, rect, color.a)
	view.draw_rect(rect, color, fill, width, smooth)


static func draw_style_box(view: Object, style: StyleBox, rect: Rect2) -> void:
	if not style is StyleBoxEmpty:
		shape(view, rect, style.bg_color.a if style is StyleBoxFlat else 1.0)
	view.draw_style_box(style, rect)


static func draw_string(view: Object, font: Font, at: Vector2, line: String, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, size: int = 16, color: Color = Color.WHITE, justification: int = 3, direction: int = 0, orientation: int = 0) -> void:
	text(view, font, at, line, align, width, size, color)
	if view is CanvasItem: view.draw_string(font, at, line, align, width, size, color, justification, direction, orientation)
	else: view.draw_string(font, at, line, align, width, size, color)


static func draw_set_transform(view: Object, at: Vector2, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	draw_set_transform_matrix(view, Transform2D(rotation, scale, 0.0, at))


static func draw_set_transform_matrix(view: Object, matrix: Transform2D) -> void:
	var canvas: CanvasItem = owner(view)
	if is_instance_valid(canvas): canvas.set_meta(MATRIX, matrix)
	view.draw_set_transform_matrix(matrix)


static func art_polygon(view: Object, poly: PackedVector2Array, colors: PackedColorArray, uv: PackedVector2Array, tex: Texture2D) -> void:
	var lane: float = floorf(uv[0].x / LANE) * LANE if not uv.is_empty() else 0.0
	polygon(view, poly, colors, uv, tex, lane)


static func diamond(view: Object, poly: PackedVector2Array) -> void:
	row(view, {"polygon": poly, "diamond": true}, 1.0)


static func popup(view: Object, font: Font, at: Vector2, local: Vector2, line: String, align: int, width: float, size: int, scale: float, color: Color) -> void:
	var canvas: CanvasItem = owner(view)
	canvas.set_meta(MATRIX, Transform2D(0.0, Vector2.ONE * scale, 0.0, at))
	text(view, font, local, line, align, width, size, color, 13)
	canvas.set_meta(MATRIX, Transform2D.IDENTITY)


static func image_texture(image: Image) -> ImageTexture:
	var result: ImageTexture = ImageTexture.create_from_image(image)
	result.set_meta("fel30_image", image)
	return result


static func note_flip(flipped: Texture2D, original: Texture2D) -> Texture2D:
	if flipped != null and flipped != original: flipped.set_meta("fel30_flip_source", original)
	return flipped
