extends SceneTree

# Typeset director text with the approved game font's CPU glyph atlas. This is
# text rendering, not generated artwork; it works without a window server and
# avoids an extra Pillow/libfreetype dependency in the Python encoder.
const Typography = preload("res://scripts/ui_typography.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var font: FontFile = Typography.ui_font() as FontFile
	var server: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var image := Image.create(int(spec["width"]), int(spec["height"]), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var jobs: Array[Dictionary]
	for line: Dictionary in spec["lines"]:
		var size_value: int = int(line["size"])
		var text_value: String = line["text"]
		var shaped: RID = server.create_shaped_text()
		var rids: Array[RID]
		rids.assign([rid])
		server.shaped_text_add_string(shaped, text_value, rids, size_value)
		server.shaped_text_shape(shaped)
		var glyphs: Array[Dictionary] = server.shaped_text_get_glyphs(shaped)
		var baseline: Vector2 = Vector2(float(line["x"]), float(line["y"]) + font.get_ascent(size_value))
		for glyph: Dictionary in glyphs:
			var glyph_index: int = int(glyph["index"])
			var cache_size := Vector2i(size_value, 0)
			server.font_render_glyph(rid, cache_size, glyph_index)
			var texture_index: int = server.font_get_glyph_texture_idx(rid, cache_size, glyph_index)
			var atlas: Image = server.font_get_texture_image(rid, cache_size, texture_index) if texture_index >= 0 else null
			if atlas != null:
				var rect: Rect2 = server.font_get_glyph_uv_rect(rid, cache_size, glyph_index)
				var glyph_image: Image = atlas.get_region(Rect2i(rect))
				var single_channel: bool = atlas.get_format() in [Image.FORMAT_L8, Image.FORMAT_R8]
				glyph_image.convert(Image.FORMAT_RGBA8)
				var position: Vector2 = baseline + server.font_get_glyph_offset(rid, cache_size, glyph_index) + (glyph["offset"] as Vector2)
				jobs.append({"mask": glyph_image, "position": Vector2i(position.round()), "single_channel": single_channel})
			baseline.x += float(glyph["advance"]) * int(glyph["repeat"])
		server.free_rid(shaped)
	# All shadow glyphs precede all foreground glyphs, so kerning cannot paint
	# a later glyph's shadow over the preceding letter.
	for job: Dictionary in jobs:
		var shadow := Color(Color(spec["shadow_color"]), float(spec["shadow_alpha"]))
		_blend_mask(image, job["mask"], job["position"] + Vector2i.ONE * int(spec["shadow_px"]), shadow, job["single_channel"])
	for job: Dictionary in jobs:
		_blend_mask(image, job["mask"], job["position"], Color(spec["color"]), job["single_channel"])
	var result: Error = image.save_png(args[1])
	print("DEMO CAPTION RASTER: ", "PASS" if result == OK else "FAIL")
	quit(0 if result == OK else 1)

func _blend_mask(target: Image, mask: Image, position: Vector2i, color: Color, single_channel: bool) -> void:
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var point := position + Vector2i(x, y)
			if point.x < 0 or point.y < 0 or point.x >= target.get_width() or point.y >= target.get_height(): continue
			var sample: Color = mask.get_pixel(x, y)
			var tint := Color(color, color.a * (sample.r if single_channel else sample.a))
			target.set_pixelv(point, target.get_pixelv(point).blend(tint))
