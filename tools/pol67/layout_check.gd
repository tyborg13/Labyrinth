extends RefCounted
## Measures the settled Control tree in capture pixels. This does not infer
## coverage from colors, textures, or custom CanvasItem drawing.

const FLOOR_PX: float = 14.0
const EDGE_EPSILON_PX: float = 0.5
const OVERLAP_AREA_EPSILON: float = 1.0


static func scan(viewport: SubViewport, shot: String, source: Node = null) -> Array[Dictionary]:
	var hits: Array[Dictionary]
	var interactive: Array[Dictionary]
	var bounds: Rect2 = viewport.get_visible_rect()
	_visit(source if source != null else viewport, viewport, shot, bounds, Transform2D.IDENTITY, [], "", hits, interactive, 1.0)
	for index: int in range(interactive.size()):
		var a: Dictionary = interactive[index]
		for other: int in range(index):
			var b: Dictionary = interactive[other]
			var first: Control = a.control
			var second: Control = b.control
			if a.layer != b.layer or not a.rect.intersects(b.rect) or first.is_ancestor_of(second) or second.is_ancestor_of(first):
				continue
			var polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(a.polygon, b.polygon)
			for intersection: PackedVector2Array in polygons:
				var area: float = _area(intersection)
				if area > OVERLAP_AREA_EPSILON:
					_add(hits, shot, first, a.rect, "interactive_overlap", 30, {
						"other_node": str(second.get_path()), "other_rect": _rect_values(b.rect),
						"intersection_rect": _rect_values(_bounds(intersection)), "area_px2": _rounded(area),
					})
	return hits


static func _visit(node: Node, capture_viewport: SubViewport, shot: String, bounds: Rect2, embedding: Transform2D, clips: Array,
		layer: String, hits: Array[Dictionary], interactive: Array[Dictionary], opacity: float) -> void:
	if node.is_queued_for_deletion(): return
	if node is Window:
		if not node.visible: return
		embedding = embedding.translated_local(Vector2(node.position))
		layer = str(node.get_path())
		clips = [{"rect": Rect2(embedding.origin, Vector2(node.size)), "path": str(node.get_path())}]
	elif node is SubViewport and node != capture_viewport:
		# Other SubViewports render through a texture; their Controls have a
		# different coordinate system from the capture.
		return
	elif node is CanvasLayer and not node.visible:
		return
	if node is CanvasItem:
		if not node.is_visible_in_tree(): return
		opacity *= node.modulate.a
		if is_zero_approx(opacity): return
	if node is Control:
		var control: Control = node
		var transform: Transform2D = embedding * control.get_global_transform_with_canvas()
		var local_rect := Rect2(Vector2.ZERO, control.size)
		var rect: Rect2 = transform * local_rect
		var shown: Rect2 = rect
		for clip: Dictionary in clips:
			shown = shown.intersection(clip.rect)
		if _is_popup(control): layer = str(control.get_path())
		if rect.has_area() and (clips.is_empty() or shown.has_area()) and not is_zero_approx(control.self_modulate.a):
			if not bounds.grow(EDGE_EPSILON_PX).encloses(rect):
				_add(hits, shot, control, rect, "outside_viewport", 40, {
					"viewport_rect": _rect_values(bounds),
					"outside_edges_px": _outside_edges(rect, bounds),
				})
			if shown.intersects(bounds):
				_text_checks(control, shot, transform, rect, clips, hits)
				_focus_check(control, shot, transform, rect, clips, hits)
				if _is_interactive(control):
					var polygon: PackedVector2Array = _quad(transform, local_rect)
					var parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
						polygon, _quad(Transform2D.IDENTITY, shown.intersection(bounds)))
					if not parts.is_empty():
						interactive.append({"control": control, "rect": rect, "polygon": parts[0], "layer": layer})
		if control.clip_contents:
			clips = clips + [{"rect": rect, "path": str(control.get_path())}]
	for child: Node in node.get_children(true):
		_visit(child, capture_viewport, shot, bounds, embedding, clips, layer, hits, interactive, opacity)


static func _is_popup(control: Control) -> bool:
	# Native tooltips are embedded Windows. Production also has in-canvas
	# tooltips, modal scrims and popovers that intentionally cover other UI.
	var name: String = str(control.name)
	return name.contains("Tooltip") or name.ends_with("Popup") or name.ends_with("Scrim") or name in [
		"RoomPreview", "NewDescentPanel", "RunEndRecapOverlay", "SettingsPanel", "DialogueOverlay",
		"ChronicleFrame", "GraftwrightDialogue", "EquipmentPicker", "CardInspection",
	]


static func _is_interactive(control: Control) -> bool:
	if control.get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE: return false
	if control is BaseButton: return not control.disabled
	if control is LineEdit: return control.editable
	if control is TextEdit: return control.editable or control.selecting_enabled
	if control is Range: return control is ScrollBar or control is Slider or control is SpinBox
	if control is RichTextLabel: return control.selection_enabled or control.meta_clicked.has_connections()
	return control.gui_input.has_connections() or (control.mouse_entered.has_connections() and not control.tooltip_text.is_empty()) or (
		control.focus_mode != Control.FOCUS_NONE and control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)


static func _text_checks(control: Control, shot: String, transform: Transform2D, rect: Rect2,
		clips: Array, hits: Array[Dictionary]) -> void:
	var text: String
	var sizes: Dictionary = {}
	var content := Vector2.ZERO
	var available: Rect2 = Rect2(Vector2.ZERO, control.size)
	var horizontal: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	var vertical: VerticalAlignment = VERTICAL_ALIGNMENT_TOP
	var hidden_lines: int = 0
	var hides_width: bool = false
	var scrollable: bool = false
	if control is Label:
		text = control.text
		if text.is_empty(): return
		if control.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED: text = control.tr(text)
		if control.uppercase: text = text.to_upper()
		var settings: LabelSettings = control.label_settings
		var font: Font = settings.font if settings != null and settings.font != null else control.get_theme_font("font")
		var size: int = settings.font_size if settings != null else control.get_theme_font_size("font_size")
		sizes["label"] = size
		var normal: StyleBox = control.get_theme_stylebox("normal")
		available = _content_rect(available, normal)
		content = _label_extent(control, text, font, size, available.size.x)
		hidden_lines = maxi(0, control.get_line_count() - control.get_visible_line_count())
		hides_width = control.clip_text or control.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		horizontal = control.horizontal_alignment
		vertical = control.vertical_alignment
	elif control is RichTextLabel:
		text = control.get_parsed_text()
		if text.is_empty(): return
		sizes = _rich_sizes(control)
		available = _content_rect(available, control.get_theme_stylebox("normal"))
		content = Vector2(control.get_content_width(), control.get_content_height())
		var bar: VScrollBar = control.get_v_scroll_bar()
		if bar != null and bar.visible: available.size.x -= bar.size.x
		scrollable = control.scroll_active and bar != null and bar.visible and bar.max_value > bar.page
		horizontal = control.horizontal_alignment
		vertical = control.vertical_alignment
	elif control is Button or control is LineEdit or control is TextEdit:
		text = control.text
		if control is LineEdit and text.is_empty(): text = control.placeholder_text
		if text.is_empty(): return
		sizes["control"] = control.get_theme_font_size("font_size")
	else:
		return
	var scale_y: float = transform.y.length()
	for role: String in sizes:
		var pixel_size: float = float(sizes[role]) * scale_y
		if pixel_size + 0.001 < FLOOR_PX:
			_add(hits, shot, control, rect, "small_font", 20, {
				"font": role, "font_px": _rounded(pixel_size), "source_px": sizes[role], "floor_px": FLOOR_PX,
			})
	if content == Vector2.ZERO: return
	var excess: Vector2 = content - available.size
	if excess.x * transform.x.length() > EDGE_EPSILON_PX or (not scrollable and (excess.y * scale_y > EDGE_EPSILON_PX or hidden_lines > 0)):
		var clipped: bool = (hides_width and excess.x > 0) or hidden_lines > 0 or (control is RichTextLabel and not scrollable and excess.y > 0)
		_add(hits, shot, control, rect, "text_clipped" if clipped else "text_overflow", 60 if clipped else 50, {
			"content_size": _vector_values(content), "available_size": _vector_values(available.size),
			"hidden_lines": hidden_lines, "units": "local_px",
		})
	# When a parent clips a partially visible label, measure the content's
	# aligned footprint. Scrollable RichText has its own intentional window.
	var footprint: Vector2 = content.min(available.size) if scrollable or hides_width or hidden_lines > 0 else content
	var space: Vector2 = (available.size - footprint).max(Vector2.ZERO)
	var offset := Vector2(
		space.x * (0.5 if horizontal == HORIZONTAL_ALIGNMENT_CENTER else (1.0 if horizontal == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)),
		space.y * (0.5 if vertical == VERTICAL_ALIGNMENT_CENTER else (1.0 if vertical == VERTICAL_ALIGNMENT_BOTTOM else 0.0)))
	var text_rect: Rect2 = transform * Rect2(available.position + offset, footprint)
	for clip: Dictionary in clips:
		var clip_rect: Rect2 = clip.rect
		if not clip_rect.grow(EDGE_EPSILON_PX).encloses(text_rect):
			_add(hits, shot, control, rect, "text_clipped_by_parent", 60, {
				"clip_node": clip.path, "clip_rect": _rect_values(clip_rect), "content_rect": _rect_values(text_rect),
				"outside_edges_px": _outside_edges(text_rect, clip_rect),
			})
			break


static func _label_extent(label: Label, text: String, font: Font, size: int, width: float) -> Vector2:
	var paragraph := TextParagraph.new()
	var flags: int = TextServer.BREAK_MANDATORY
	match label.autowrap_mode:
		TextServer.AUTOWRAP_ARBITRARY: flags |= TextServer.BREAK_GRAPHEME_BOUND
		TextServer.AUTOWRAP_WORD: flags |= TextServer.BREAK_WORD_BOUND
		TextServer.AUTOWRAP_WORD_SMART: flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.break_flags = flags
	paragraph.width = width if label.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	paragraph.direction = label.text_direction as TextServer.Direction
	paragraph.add_string(text, font, size, label.language)
	var result := Vector2.ZERO
	var line_count: int = paragraph.get_line_count()
	for index: int in range(line_count):
		var line: Vector2 = paragraph.get_line_size(index)
		result.x = maxf(result.x, line.x)
		result.y += maxf(line.y, label.get_line_height())
	var spacing: float = label.label_settings.line_spacing if label.label_settings != null else label.get_theme_constant("line_spacing")
	result.y += maxi(0, line_count - 1) * spacing
	return result


static func _rich_sizes(label: RichTextLabel) -> Dictionary:
	# RichTextLabel exposes its laid-out content dimensions. Font overrides
	# are available for theme roles and literal BBCode size tags.
	var sizes: Dictionary = {}
	var markup: String = label.text
	if label.bbcode_enabled and not markup.is_empty():
		var tags := RegEx.new()
		tags.compile("\\[(/?)([a-zA-Z_]+)(?:[= ][^\\]]*)?\\]|([^\\[]+)|\\[")
		var stack: Array[String]
		var size_stack: Array[int]
		for token: RegExMatch in tags.search_all(markup):
			var tag: String = token.get_string(2)
			var closing: bool = token.get_string(1) == "/"
			if tag == "font_size":
				var literal: String = token.get_string().trim_suffix("]").get_slice("=", 1)
				if closing and not size_stack.is_empty(): size_stack.pop_back()
				elif literal.is_valid_int(): size_stack.append(int(literal))
			elif tag in ["b", "i", "code", "img", "lb", "rb"]:
				if closing: stack.erase(tag)
				elif tag not in ["lb", "rb"]: stack.append(tag)
			if not token.get_string(3).strip_edges().is_empty() and "img" not in stack:
				if not size_stack.is_empty():
					sizes["bbcode_%d" % size_stack.back()] = size_stack.back()
				else:
					var role: String = "mono" if "code" in stack else ("bold_italics" if "b" in stack and "i" in stack else ("bold" if "b" in stack else ("italics" if "i" in stack else "normal")))
					sizes[role] = label.get_theme_font_size(role + "_font_size")
	if sizes.is_empty(): sizes["normal"] = label.get_theme_font_size("normal_font_size")
	return sizes


static func _content_rect(rect: Rect2, style: StyleBox) -> Rect2:
	var origin := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	return Rect2(rect.position + origin, (rect.size - style.get_minimum_size()).max(Vector2.ZERO))


static func _focus_check(control: Control, shot: String, transform: Transform2D, rect: Rect2,
		clips: Array, hits: Array[Dictionary]) -> void:
	if clips.is_empty() or not control.has_focus() or not control.has_theme_stylebox("focus"): return
	var style: StyleBox = control.get_theme_stylebox("focus")
	if style is StyleBoxEmpty: return
	var local := Rect2(Vector2.ZERO, control.size)
	if style is StyleBoxFlat:
		local = local.grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)
	elif style is StyleBoxTexture:
		local = local.grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)
	var frame: Rect2 = transform * local
	for clip: Dictionary in clips:
		var clip_rect: Rect2 = clip.rect
		if not clip_rect.grow(EDGE_EPSILON_PX).encloses(frame):
			_add(hits, shot, control, rect, "focus_frame_clipped", 45, {
				"focus_rect": _rect_values(frame), "clip_node": clip.path, "clip_rect": _rect_values(clip_rect),
				"outside_edges_px": _outside_edges(frame, clip_rect),
			})
			return


static func _add(hits: Array[Dictionary], shot: String, control: Control, rect: Rect2,
		kind: String, severity: int, measured: Dictionary) -> void:
	hits.append({"shot": shot, "node": str(control.get_path()), "rect": _rect_values(rect),
		"size": _vector_values(rect.size), "kind": kind, "severity": severity, "measured": measured})


static func _quad(transform: Transform2D, rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([transform * rect.position, transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end, transform * Vector2(rect.position.x, rect.end.y)])


static func _area(points: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for i: int in range(points.size()):
		twice_area += points[i].cross(points[(i + 1) % points.size()])
	return absf(twice_area) * 0.5


static func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result


static func _outside_edges(rect: Rect2, limit: Rect2) -> Array:
	return [_rounded(maxf(0.0, limit.position.x - rect.position.x)), _rounded(maxf(0.0, limit.position.y - rect.position.y)),
		_rounded(maxf(0.0, rect.end.x - limit.end.x)), _rounded(maxf(0.0, rect.end.y - limit.end.y)) ]


static func _rect_values(rect: Rect2) -> Array:
	return [_rounded(rect.position.x), _rounded(rect.position.y), _rounded(rect.size.x), _rounded(rect.size.y)]


static func _vector_values(value: Vector2) -> Array:
	return [_rounded(value.x), _rounded(value.y)]


static func _rounded(value: float) -> float:
	return snappedf(value, 0.01)
