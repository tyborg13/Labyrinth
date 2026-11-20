extends RefCounted
## Diagnostic layout estimates and native per-pixel silhouettes from the live scene.

static func layout(control: Control, safe: Rect2) -> Dictionary:
	if control == null or not control.is_visible_in_tree(): return {"visible": false}
	var bounds: Rect2 = control.get_global_rect()
	var result: Dictionary = {"visible": true, "control": str(bounds), "control_in_safe_area": safe.encloses(bounds)}
	if control is Label:
		var font: Font = control.get_theme_font("font")
		var font_size: int = control.get_theme_font_size("font_size")
		var line: Vector2 = font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var left: float = (control.size.x - line.x) * 0.5 if control.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0
		var top: float = (control.size.y - line.y) * 0.5 if control.vertical_alignment == VERTICAL_ALIGNMENT_CENTER else 0.0
		result["line_box"] = str(control.get_global_transform() * Rect2(Vector2(left, top), line))
	if control is RichTextLabel:
		var rich := control as RichTextLabel
		var line_box := Rect2(Vector2((rich.size.x - rich.get_content_width()) * 0.5, 0.0),
			Vector2(rich.get_content_width(), rich.get_content_height()))
		if rich.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
			line_box.position.y = (rich.size.y - line_box.size.y) * 0.5
		line_box = rich.get_global_transform() * line_box
		result.merge({"line_box": str(line_box), "line_box_in_safe_area": safe.encloses(line_box),
			"text": rich.get_parsed_text(), "lines": rich.get_line_count()})
	var ornament: Node2D = control.get_node_or_null("ThemedInsetOrnament") as Node2D
	if ornament != null and ornament.has_method("visual_bounds"):
		var envelope: Rect2 = ornament.get_global_transform() * ornament.visual_bounds()
		result["panel_paint_envelope"] = str(envelope)
		result["panel_paint_in_safe_area"] = safe.encloses(envelope)
	for node_name: String in ["PassForecastFrameArtHost", "DetailsRailBrush"]:
		var art: TextureRect = control.get_node_or_null(node_name) as TextureRect
		if art == null or art.texture == null: continue
		var texture: Image = art.texture.get_image()
		if texture == null: continue
		var source_size: Vector2 = art.texture.get_size()
		var factor: Vector2 = art.size / source_size
		if art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			factor = Vector2.ONE * minf(factor.x, factor.y)
		var used := Rect2(texture.get_used_rect())
		var inset: Vector2 = (art.size - source_size * factor) * 0.5
		var envelope: Rect2 = art.get_global_transform() * Rect2(inset + used.position * factor, used.size * factor)
		result["art_alpha_envelope"] = str(envelope)
		result["art_alpha_in_safe_area"] = safe.encloses(envelope)
	return result

static func capture(viewport: Window, targets: Dictionary, pairs: Array, safe: Rect2, size: Vector2i, path: String) -> Dictionary:
	# Submit multiple draws of one scene pose. No process/physics frame elapses
	# between the full frame and the isolated paints, and no focus is changed.
	var image: Image = _draw(viewport)
	if image == null or image.get_size() != size or image.save_png(path) != OK: return {}
	var originals: Dictionary = {}
	_collect(viewport, originals)
	var old_clear: Color = RenderingServer.get_default_clear_color()
	var safe_pixels: Rect2 = viewport.get_stretch_transform() * safe
	var masks: Dictionary = {}
	var bounds_by_key: Dictionary = {}
	var results: Dictionary = {"capture": path, "safe_pixels": str(safe_pixels), "paints": {}, "intersections": {}}
	for item: CanvasItem in originals:
		var tint: Color = originals[item]
		tint.a = 0.0
		item.self_modulate = tint
	var blank: Array[PackedByteArray] = _read_backings(viewport)
	var forecast: Control = targets.get("pass_forecast")
	for key: String in targets:
		var control: Control = targets[key]
		if control == null or not control.is_visible_in_tree():
			results.paints[key] = {"visible": false}
			continue
		for item: CanvasItem in originals:
			var tint: Color = originals[item]
			var belongs: bool = item == control or control.is_ancestor_of(item)
			if key == "pass_button" and forecast != null and (item == forecast or forecast.is_ancestor_of(item)):
				belongs = false
			if not belongs: tint.a = 0.0
			item.self_modulate = tint
		var silhouette: Dictionary = _silhouette(viewport, size, blank)
		var mask: BitMap = silhouette.mask
		masks[key] = mask
		var bounds: Rect2i = silhouette.bounds
		bounds_by_key[key] = bounds
		results.paints[key] = {"bounds": str(bounds), "pixels": mask.get_true_bit_count(),
			"touches_frame_edge": bounds.has_area() and not Rect2i(Vector2i.ONE, size - Vector2i.ONE * 2).encloses(bounds),
			"in_safe_area": not bounds.has_area() or safe_pixels.encloses(Rect2(bounds))}
	for pair: Array in pairs:
		var first: BitMap = masks.get(pair[0])
		var second: BitMap = masks.get(pair[1])
		var count: int = 0
		if first != null and second != null:
			var first_bounds: Rect2i = bounds_by_key[pair[0]]
			var area: Rect2i = first_bounds.intersection(bounds_by_key[pair[1]])
			for y: int in range(area.position.y, area.end.y):
				for x: int in range(area.position.x, area.end.x):
					if first.get_bit(x, y) and second.get_bit(x, y): count += 1
		results.intersections["%s/%s" % pair] = count
	for item: CanvasItem in originals: item.self_modulate = originals[item]
	RenderingServer.set_default_clear_color(old_clear)
	return results

static func _collect(node: Node, originals: Dictionary) -> void:
	if node is CanvasItem: originals[node] = node.self_modulate
	for child: Node in node.get_children(): _collect(child, originals)

static func _draw(viewport: Viewport) -> Image:
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()

static func _read_backings(viewport: Viewport) -> Array[PackedByteArray]:
	# Both backings are needed to retain dark panel edges and white glyph ink.
	var result: Array[PackedByteArray]
	for color: Color in [Color.BLACK, Color.WHITE]:
		RenderingServer.set_default_clear_color(color)
		var image: Image = _draw(viewport)
		image.convert(Image.FORMAT_RGB8)
		result.append(image.get_data())
	return result

static func _silhouette(viewport: Viewport, size: Vector2i, blank: Array[PackedByteArray]) -> Dictionary:
	var backing: Array[PackedByteArray] = _read_backings(viewport)
	var dark: PackedByteArray = backing[0]
	var light: PackedByteArray = backing[1]
	var blank_dark: PackedByteArray = blank[0]
	var blank_light: PackedByteArray = blank[1]
	var mask := BitMap.new()
	mask.create(size)
	var start: Vector2i = size
	var finish := Vector2i.ZERO
	for y: int in range(size.y):
		for x: int in range(size.x):
			var byte: int = (y * size.x + x) * 3
			var dark_ink: bool = dark[byte] != blank_dark[byte] or dark[byte + 1] != blank_dark[byte + 1] or dark[byte + 2] != blank_dark[byte + 2]
			var light_ink: bool = light[byte] != blank_light[byte] or light[byte + 1] != blank_light[byte + 1] or light[byte + 2] != blank_light[byte + 2]
			if dark_ink or light_ink:
				mask.set_bit(x, y, true)
				start = start.min(Vector2i(x, y))
				finish = finish.max(Vector2i(x + 1, y + 1))
	var bounds := Rect2i(start, finish - start) if finish.x > 0 else Rect2i()
	return {"mask": mask, "bounds": bounds}
