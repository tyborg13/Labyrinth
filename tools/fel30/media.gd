extends SceneTree
## Build crops and a contact sheet from owner-captured native frames.

const SOURCE_SIZE := Vector2i(1920, 1080)
const CROP_SCALE := 2
const CROP_MARGIN := 18
const COLUMNS := 4
const CELL := Vector2i(440, 292)
const IMAGE_AREA := Vector2i(424, 234)
const SHEET_BACKGROUND := Color("#19171d")
const OUTLINES := {"text": Color("#ffe374"), "tile_content": Color("#67d9fb"),
	"unit": Color("#ff7f91"), "unit_ui": Color("#e5a1ff"), "clip": Color("#baf486")}
const FONT_PATH := "res://fonts/LabyrinthCrumble-UI.ttf"
const FONT_SIZE := 17


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("FEL30 media: expected census output and native frame directory")
		quit(1)
		return
	quit(0 if _build(args[0], args[1]) else 1)


func _build(output: String, frames: String) -> bool:
	var selection: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("selection.json")))
	if not selection is Array or selection.is_empty(): return false
	var font: FontFile = load(FONT_PATH)
	if font == null: return false
	var top: String = output.path_join("top")
	if DirAccess.make_dir_recursive_absolute(top) != OK: return false
	var height: int = ceili(float(selection.size()) / COLUMNS) * CELL.y
	var sheet := Image.create_empty(COLUMNS * CELL.x, height, false, Image.FORMAT_RGB8)
	sheet.fill(SHEET_BACKGROUND)
	for entry: Dictionary in selection:
		var rank: int = int(entry["rank"])
		var stem: String = "%02d-%s" % [rank, entry["key"]]
		var source_path: String = frames.path_join(stem + ".png")
		var source := Image.load_from_file(source_path)
		if source == null or source.get_size() != SOURCE_SIZE:
			push_error("FEL30 media: missing exact-size frame " + source_path)
			return false
		if DirAccess.copy_absolute(source_path, top.path_join(stem + ".png")) != OK: return false
		source.convert(Image.FORMAT_RGB8)
		var flags: Array = entry["flags"]
		var geometry: String = frames.path_join(stem + ".json")
		var native_flags: Variant = JSON.parse_string(FileAccess.get_file_as_string(geometry)) if FileAccess.file_exists(geometry) else null
		if native_flags is Array: flags = native_flags
		var crop: Image = _crop(source, flags)
		if crop.save_png(top.path_join(stem + "-crop.png")) != OK: return false
		var scale: float = minf(float(IMAGE_AREA.x) / crop.get_width(), float(IMAGE_AREA.y) / crop.get_height())
		crop.resize(maxi(1, roundi(crop.get_width() * scale)), maxi(1, roundi(crop.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		var index: int = rank - 1
		var origin := Vector2i(index % COLUMNS, index / COLUMNS) * CELL + Vector2i(8, 8)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), origin + (IMAGE_AREA - crop.get_size()) / 2)
		var label: String = "#%02d  Seed %d  Combat %d  Turn %d" % [rank, entry["seed"], entry["combat"], entry["turn"]]
		var headless: Array = entry["flags"]
		var leading: String = "%s: %s" % [headless[0]["category"], headless[0]["what"]] if not headless.is_empty() else "Clear"
		_caption(sheet, font, origin + Vector2i(0, IMAGE_AREA.y + 20), label)
		_caption(sheet, font, origin + Vector2i(0, IMAGE_AREA.y + 42), leading)
	if sheet.save_png(output.path_join("sheet.png")) != OK: return false
	print("FEL30 MEDIA frames=%d crops=%d sheet=%s" % [selection.size(), selection.size(), output.path_join("sheet.png")])
	return true


func _crop(source: Image, flags: Array) -> Image:
	var extent := Rect2i(Vector2i.ZERO, source.get_size())
	var area := Rect2i()
	var rects: Array[Rect2i]
	for flag: Dictionary in flags:
		var data: Array = flag["rect"]
		var point := Vector2i(floori(data[0]), floori(data[1]))
		var end := Vector2i(ceili(data[0] + data[2]), ceili(data[1] + data[3]))
		var rect := Rect2i(point, end - point)
		rects.append(rect)
		# A fully clipped subject still anchors the proof to the nearest edge.
		var anchor: Vector2i = point.clamp(extent.position, extent.end - Vector2i.ONE)
		var visible: Rect2i = rect.intersection(extent)
		if not visible.has_area(): visible = Rect2i(anchor, Vector2i.ONE)
		area = area.merge(visible) if area.has_area() else visible
	area = area.grow(CROP_MARGIN).intersection(extent) if area.has_area() else extent
	var crop: Image = source.get_region(area)
	crop.resize(crop.get_width() * CROP_SCALE, crop.get_height() * CROP_SCALE, Image.INTERPOLATE_NEAREST)
	for index: int in rects.size():
		var rect: Rect2i = rects[index]
		var label: Dictionary = flags[index]
		var outlined := Rect2i((rect.position - area.position) * CROP_SCALE, rect.size * CROP_SCALE)
		if not rect.intersects(extent):
			var pin: Vector2i = outlined.position.clamp(Vector2i.ZERO, crop.get_size() - Vector2i.ONE)
			outlined = Rect2i(pin - Vector2i(4, 4), Vector2i(9, 9))
		_outline(crop, outlined, OUTLINES[label["category"]])
	return crop


func _outline(image: Image, rect: Rect2i, color: Color) -> void:
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var width: int = 2 * CROP_SCALE
	var bands: Array[Rect2i] = [
		Rect2i(rect.position, Vector2i(rect.size.x, width)),
		Rect2i(rect.position.x, rect.end.y - width, rect.size.x, width),
		Rect2i(rect.position, Vector2i(width, rect.size.y)),
		Rect2i(rect.end.x - width, rect.position.y, width, rect.size.y),
	]
	for band: Rect2i in bands:
		var visible: Rect2i = band.intersection(bounds)
		if visible.has_area(): image.fill_rect(visible, color)


func _caption(image: Image, font: FontFile, baseline: Vector2i, text: String) -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var rendered_size := Vector2i(FONT_SIZE, 0)
	var pen: float = float(baseline.x)
	var end: int = baseline.x + IMAGE_AREA.x
	for index: int in text.length():
		var glyph: int = server.font_get_glyph_index(rid, FONT_SIZE, text.unicode_at(index), 0)
		server.font_render_glyph(rid, rendered_size, glyph)
		var slot: int = server.font_get_glyph_texture_idx(rid, rendered_size, glyph)
		if slot >= 0:
			var glyph_rect := Rect2i(server.font_get_glyph_uv_rect(rid, rendered_size, glyph))
			var offset := Vector2i(server.font_get_glyph_offset(rid, rendered_size, glyph))
			var page: Image = server.font_get_texture_image(rid, rendered_size, slot)
			var at := Vector2i(roundi(pen), baseline.y)
			if at.x + offset.x + glyph_rect.size.x >= end: break
			for y: int in glyph_rect.size.y:
				for x: int in glyph_rect.size.x:
					var delta := Vector2i(x, y)
					var alpha: float = page.get_pixelv(glyph_rect.position + delta).a
					if alpha > 0.0:
						var point: Vector2i = at + offset + delta
						image.set_pixelv(point, SHEET_BACKGROUND.lerp(Color.WHITE, alpha))
		pen += server.font_get_glyph_advance(rid, FONT_SIZE, glyph).x
