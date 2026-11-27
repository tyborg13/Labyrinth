extends RefCounted
## CPU coverage at viewport pixel centres. Shapes retain alpha, so two partial
## coats of ink can make a pixel opaque together.

const VIEWPORT := Rect2(0, 0, 1920, 1080)
const OPAQUE := 254.5 / 255.0

var _textures: Dictionary = {}
var _glyphs: Dictionary = {}
var _lines: Dictionary = {}
var _text_server := TextServerManager.get_primary_interface()

func compose(row: Dictionary, canvas: CanvasItem, clip: Rect2, modulate: float) -> Dictionary:
	var shapes: Array[Dictionary]
	var full := Rect2()
	var readable := Rect2()
	var text_bounds := Rect2()
	var ink_band: int = 0
	var transform: Transform2D = canvas.get_global_transform_with_canvas()
	for command: Array in row["ink"]:
		var alpha: float = float(command[2]) * modulate
		if alpha <= 0.0: continue
		var primitive: Array = command[0]
		var xf: Transform2D = transform * (command[1] as Transform2D)
		var pieces: Array = _text(primitive) if primitive[0] == "text" else [primitive]
		for piece: Array in pieces:
			var shape: Dictionary = _shape(piece, xf, clip, alpha)
			if shape.is_empty(): continue
			var bounds: Rect2 = shape["bounds"]
			var band: int = int(command[4]) if command.size() > 4 else 0
			shape["band"] = band
			if command[3]: ink_band = maxi(ink_band, band)
			full = union_rect(full, bounds)
			if command[3]:
				readable = union_rect(readable, bounds)
				if primitive[0] == "text": text_bounds = union_rect(text_bounds, bounds)
			shapes.append(shape)
	if not full.has_area(): return {}
	return {"kind": row["kind"], "owner": row["owner"], "detail": row["detail"], "text": row["text"],
		"rect": full, "glyph_rect": readable, "text_rect": text_bounds, "band": ink_band, "shapes": shapes, "popup": row["popup"]}

static func union_rect(a: Rect2, b: Rect2) -> Rect2:
	if not a.has_area(): return b
	if not b.has_area(): return a
	return a.merge(b)

func _shape(piece: Array, xf: Transform2D, clip: Rect2, alpha: float) -> Dictionary:
	var kind: String = piece[0]
	var local: Rect2
	var image: Image
	var src := Rect2()
	var points := PackedVector2Array()
	var width: float = 0.0
	var style: StyleBoxFlat
	match kind:
		"texture", "bitmap":
			local = piece[1]
			if kind == "texture":
				image = _image(piece[2])
				if image == null: return {}
				src = piece[3]
				if not src.has_area(): src = Rect2(Vector2.ZERO, image.get_size())
			else:
				image = piece[2]
				src = Rect2(Vector2.ZERO, image.get_size())
			if not local.has_area(): return {}
			var used := Rect2(image.get_used_rect()).intersection(src)
			if not used.has_area(): return {}
			var fitted := Rect2(local.position + ((used.position - src.position) / src.size) * local.size, used.size / src.size * local.size)
			var bounds: Rect2 = (xf * fitted).intersection(clip)
			if not bounds.has_area(): return {}
			return {"kind": kind, "bounds": bounds, "local": local, "inverse": xf.affine_inverse(),
				"alpha": alpha, "image": image, "source": src}
		"line", "polygon":
			points = piece[1]
			if points.is_empty(): return {}
			local = Rect2(points[0], Vector2.ZERO)
			for point: Vector2 in points: local = local.expand(point)
			if kind == "line":
				width = float(piece[2])
				local = local.grow(width * 0.5)
			elif piece[2] != null:
				image = _image(piece[2])
				if image != null: src = Rect2(Vector2.ZERO, image.get_size())
		"style":
			local = piece[1]
			style = piece[2]
		"rect", "circle":
			local = piece[1]
			width = float(piece[2])
		_:
			return {}
	var bounds: Rect2 = (xf * local).intersection(clip)
	if not bounds.has_area(): return {}
	return {"kind": kind, "bounds": bounds, "local": local, "inverse": xf.affine_inverse(), "alpha": alpha,
		"points": points, "width": width, "style": style, "image": image, "source": src}

func _image(texture: Texture2D) -> Image:
	if texture == null: return null
	var id: int = texture.get_instance_id()
	if not _textures.has(id):
		var image: Image = texture.get_image()
		if image != null and image.is_compressed(): image.decompress()
		_textures[id] = [texture, image]
	return _textures[id][1]

func _text(command: Array) -> Array:
	var font: Font = command[1]
	var baseline: Vector2 = command[2]
	var value: String = command[3]
	var align: int = command[4]
	var width: float = command[5]
	var size: int = command[6]
	var outline: int = command[7]
	var key := "%d|%d|%d|%s" % [font.get_instance_id(), size, outline, value]
	if not _lines.has(key):
		var line := TextLine.new()
		line.add_string(value, font, size)
		var bitmaps: Array = []
		var x: float = 0.0
		for glyph: Dictionary in _text_server.shaped_text_get_glyphs(line.get_rid()):
			var ink: Array = _glyph(glyph["font_rid"], glyph["font_size"], glyph["index"], outline)
			for _repeat: int in range(int(glyph["repeat"])):
				if not ink.is_empty():
					var rect: Rect2 = ink[0]
					rect.position += Vector2(x, 0.0) + (glyph["offset"] as Vector2)
					bitmaps.append([rect, ink[1]])
				x += float(glyph["advance"])
		_lines[key] = [bitmaps, x]
	var cached: Array = _lines[key]
	var padding: float = maxf(0.0, width - float(cached[1]))
	if align == HORIZONTAL_ALIGNMENT_CENTER: baseline.x += padding * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT: baseline.x += padding
	var out: Array = []
	for bitmap: Array in cached[0]:
		var rect: Rect2 = bitmap[0]
		rect.position += baseline
		out.append(["bitmap", rect, bitmap[1]])
	return out

func _glyph(rid: RID, size: int, index: int, outline: int) -> Array:
	if not rid.is_valid(): return []
	var key := "%s|%d|%d|%d" % [rid, size, index, outline]
	if _glyphs.has(key): return _glyphs[key]
	var cache := Vector2i(size, outline)
	_text_server.font_render_glyph(rid, cache, index)
	var result: Array = []
	var uv := Rect2i(_text_server.font_get_glyph_uv_rect(rid, cache, index))
	if uv.has_area():
		var page: int = _text_server.font_get_glyph_texture_idx(rid, cache, index)
		var atlas: Image = _text_server.font_get_texture_image(rid, cache, page)
		if atlas != null and not atlas.is_empty():
			var offset: Vector2 = _text_server.font_get_glyph_offset(rid, cache, index)
			var extent: Vector2 = _text_server.font_get_glyph_size(rid, cache, index)
			result = [Rect2(offset, extent), atlas.get_region(uv)]
	_glyphs[key] = result
	return result

static func opaque_pixels(shapes: Array, rect: Rect2) -> int:
	var relevant: Array[Dictionary]
	for shape: Dictionary in shapes:
		if (shape["bounds"] as Rect2).intersects(rect): relevant.append(shape)
	if relevant.is_empty(): return 0
	var covered: int = 0
	for y: int in range(ceili(rect.position.y - 0.5), ceili(rect.end.y - 0.5)):
		for x: int in range(ceili(rect.position.x - 0.5), ceili(rect.end.x - 0.5)):
			var point := Vector2(x + 0.5, y + 0.5)
			var transmission: float = 1.0
			for shape: Dictionary in relevant:
				if not (shape["bounds"] as Rect2).has_point(point): continue
				transmission *= 1.0 - _alpha_at(shape, point)
				if 1.0 - transmission >= OPAQUE:
					covered += 1
					break
	return covered

static func pixel_count(rect: Rect2) -> int:
	return maxi(0, ceili(rect.end.x - 0.5) - ceili(rect.position.x - 0.5)) * maxi(0, ceili(rect.end.y - 0.5) - ceili(rect.position.y - 0.5))

static func _alpha_at(shape: Dictionary, screen: Vector2) -> float:
	var local: Rect2 = shape["local"]
	var point: Vector2 = (shape["inverse"] as Transform2D) * screen
	var alpha: float = shape["alpha"]
	var width: float = shape["width"] if shape.has("width") else 0.0
	match str(shape["kind"]):
		"bitmap", "texture":
			return alpha * _sample_texture(shape, (point - local.position) / local.size)
		"circle":
			var radius: float = local.size.x * 0.5
			var distance: float = point.distance_to(local.get_center())
			return alpha if distance <= radius and (width <= 0.0 or distance >= radius - width) else 0.0
		"rect":
			return alpha if local.has_point(point) and (width <= 0.0 or not local.grow(-width).has_point(point)) else 0.0
		"polygon":
			if not Geometry2D.is_point_in_polygon(point, shape["points"]): return 0.0
			return alpha if shape["image"] == null else alpha * _sample_texture(shape, (point - local.position) / local.size)
		"line":
			var points: PackedVector2Array = shape["points"]
			for i: int in range(1, points.size()):
				if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, points[i - 1], points[i])) <= width * width * 0.25:
					return alpha
			return 0.0
		"style":
			return alpha * _style_alpha(shape["style"], local, point)
	return 0.0

static func _style_alpha(style: StyleBoxFlat, rect: Rect2, point: Vector2) -> float:
	var p: Vector2 = point - rect.position
	var corner: int = CORNER_TOP_LEFT if p.x < rect.size.x * 0.5 else CORNER_TOP_RIGHT
	if p.y >= rect.size.y * 0.5: corner = CORNER_BOTTOM_LEFT if corner == CORNER_TOP_LEFT else CORNER_BOTTOM_RIGHT
	var radius: float = minf(style.get_corner_radius(corner), minf(rect.size.x, rect.size.y) * 0.5)
	var margin := Vector2(minf(p.x, rect.size.x - p.x), minf(p.y, rect.size.y - p.y))
	if margin.x < radius and margin.y < radius and margin.distance_squared_to(Vector2.ONE * radius) > radius * radius:
		return 0.0
	var inner: Rect2 = rect.grow_individual(-style.border_width_left, -style.border_width_top, -style.border_width_right, -style.border_width_bottom)
	if not inner.has_point(point): return style.border_color.a
	return style.bg_color.a if style.draw_center else 0.0

static func _sample_texture(shape: Dictionary, uv: Vector2) -> float:
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0: return 0.0
	var src: Rect2 = shape["source"]
	var image: Image = shape["image"]
	var p: Vector2 = src.position + uv * src.size - Vector2.ONE * 0.5
	var low := Vector2i(p.floor())
	var hi := low + Vector2i.ONE
	var weight: Vector2 = p - Vector2(low)
	var bound := Vector2i(image.get_size()) - Vector2i.ONE
	low = low.clamp(Vector2i.ZERO, bound)
	hi = hi.clamp(Vector2i.ZERO, bound)
	return lerpf(lerpf(image.get_pixel(low.x, low.y).a, image.get_pixel(hi.x, low.y).a, weight.x),
		lerpf(image.get_pixel(low.x, hi.y).a, image.get_pixel(hi.x, hi.y).a, weight.x), weight.y)
