extends RefCounted
## Geometry is in root viewport units. Content sizes are in the Control's
## local units. Candidate classification is triage, not a rendering assertion.

const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const EPSILON: float = 2.0
const OVERLAP_MIN_FRACTION: float = 0.12
const ALPHA_MIN: float = 0.025

static func scan(scene: Node, window: Window, hover_surfaces: Array[Node]) -> Dictionary:
	var viewport: Rect2 = window.get_visible_rect()
	var findings: Array[Dictionary]
	var counts := {"controls": 0, "labels": 0, "rich_text": 0, "buttons": 0, "textures": 0, "clipped_or_scrolled": 0}
	var groups: Dictionary = {}
	var scope: Array[Node] = hover_surfaces
	if scope.is_empty(): scope.assign([scene])
	var seen: Dictionary = {}
	for surface: Node in scope:
		for control: Control in controls_below(surface):
			if seen.has(control): continue
			seen[control] = true
			if not painted(control): continue
			counts["controls"] += 1
			var rect: Rect2 = bounds(control, window)
			var clip: Rect2 = ancestor_clip(control, window, viewport)
			var in_scroll: bool = scrolls(control)
			var visible: Rect2 = rect.intersection(clip)
			if not visible.has_area() or (in_scroll and not clip.grow(EPSILON).encloses(rect)):
				counts["clipped_or_scrolled"] += 1
			if in_scroll and not visible.has_area(): continue
			var text: Dictionary = text_data(control)
			var category: String = _category(control)
			if not category.is_empty(): counts[category] += 1
			var row := {"path": path(control, scene), "rect": rect_data(rect), "local_size": [control.size.x, control.size.y]}
			row.merge(text)
			if not in_scroll or clip.grow(EPSILON).encloses(rect):
				if rect.has_area() and not viewport.grow(EPSILON).encloses(rect):
					_emit(findings, "outside_viewport", row, {"limit": rect_data(viewport)})
				if not viewport.is_equal_approx(clip) and not clip.grow(EPSILON).encloses(rect) and not text.is_empty():
					_emit(findings, "ancestor_clip", row, {"limit": rect_data(clip)})
			var stack := control as Stack
			if stack != null and stack.entry_count() > 0:
				var margin: float = Stack.RELIC_CHOICE_SCREEN_MARGIN if bool(stack.get("_relic_layout")) and stack._bound_rect("glossary_choice_row").has_area() else Stack.SAFE_MARGIN
				var safe: Rect2 = viewport.grow(-margin)
				if not safe.grow(EPSILON).encloses(rect):
					_emit(findings, "outside_safe_margin", row, {"limit": rect_data(safe), "margin": margin})
			if not text.is_empty() and (visible.has_area() or not in_scroll):
				var problem: String = _text_problem(control, text)
				if not problem.is_empty(): _emit(findings, problem, row)
			if visible.has_area() and (control is TextureRect or (control is Button and control.icon != null)):
				var texture: Texture2D = control.texture if control is TextureRect else control.icon
				if texture == null or texture is PlaceholderTexture2D or (texture is AtlasTexture and texture.atlas == null):
					_emit(findings, "missing_texture", row, {"texture": texture.get_class() if texture != null else "null"})
			# Compare independent readable/interactive leaves. Containers, frames,
			# art layers and intentional child content do not form overlap pairs.
			if visible.has_area() and (not text.is_empty() or control is BaseButton):
				var group: Node = _layer(control, scene, surface)
				if not groups.has(group): groups[group] = []
				groups[group].append({"control": control, "visible": visible, "row": row})
	for group: Array in groups.values(): _overlaps(group, findings)
	if not findings.is_empty(): findings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (str(a.path) + str(a.check)) < (str(b.path) + str(b.check)))
	return {"counts": counts, "findings": findings, "surfaces": hover_surfaces.map(func(node: Node) -> String: return path(node, scene))}

static func controls_below(node: Node) -> Array[Control]:
	var result: Array[Control]
	_collect(node, result)
	return result

static func _collect(node: Node, result: Array[Control]) -> void:
	if node is Window and not node.visible: return
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Control: result.append(node)
	for child: Node in node.get_children(true):
		# Cached offscreen render targets are separate coordinate systems.
		if not child is SubViewport: _collect(child, result)

static func painted(control: Control) -> bool:
	if not control.is_visible_in_tree() or control.self_modulate.a < ALPHA_MIN: return false
	var node: Node = control
	while node is CanvasItem:
		if node.modulate.a < ALPHA_MIN: return false
		node = node.get_parent()
	return true

static func bounds(control: Control, root_window: Window) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var rect: Rect2 = transform * Rect2(Vector2.ZERO, control.size)
	var window: Window = control.get_window()
	while window != null and window != root_window:
		rect.position += Vector2(window.position)
		window = window.get_parent().get_window()
	return rect

static func ancestor_clip(control: Control, window: Window, viewport: Rect2) -> Rect2:
	var clip: Rect2 = viewport
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is Window: break
		if parent is Control and parent.clip_contents:
			clip = clip.intersection(bounds(parent, window))
		parent = parent.get_parent()
	return clip

static func scrolls(control: Control) -> bool:
	var parent: Node = control.get_parent()
	while parent != null and not parent is Window:
		if parent is ScrollContainer: return true
		parent = parent.get_parent()
	return false

static func path(node: Node, scene: Node) -> String:
	var parts: PackedStringArray
	while node != null and node != scene:
		if node is Window and node.theme_type_variation == &"TooltipPanel":
			parts.insert(0, "TooltipPanel")
		elif str(node.name).begins_with("@"):
			parts.insert(0, "%s[%d]" % [node.get_class(), node.get_index(true)])
		else:
			parts.insert(0, str(node.name))
		if node.get_parent() == null: break
		node = node.get_parent()
	return "/".join(parts)

static func rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

static func text_data(control: Control) -> Dictionary:
	if control is Label:
		if control.text.strip_edges().is_empty(): return {}
		var font: Font = control.get_theme_font("font")
		var size: int = control.get_theme_font_size("font_size")
		var style: StyleBox = control.get_theme_stylebox("normal")
		var available: Vector2 = control.size - style.get_minimum_size()
		var lines: int = control.get_line_count()
		var visible: int = control.get_visible_line_count()
		var width: float = _line_width(control, font, size, control.text)
		var longest: float = _unbreakable_width(control, font, size, control.text)
		return {"text": control.text, "lines": lines, "visible_lines": visible,
			"width": width, "unbreakable_width": longest, "available": [available.x, available.y],
			"content_height": _label_height(control, lines), "wrap": control.autowrap_mode, "clip": control.clip_text,
			"overrun": control.text_overrun_behavior, "max_lines": control.max_lines_visible, "visible_ratio": control.visible_ratio}
	if control is RichTextLabel:
		if control.get_total_character_count() == 0 and control.get_content_height() == 0: return {}
		var style: StyleBox = control.get_theme_stylebox("normal")
		var available: Vector2 = control.size - style.get_minimum_size()
		if control.get_v_scroll_bar().visible: available.x -= control.get_v_scroll_bar().size.x
		return {"text": control.get_parsed_text(), "lines": control.get_line_count(),
			"visible_lines": control.get_visible_line_count(), "width": control.get_content_width(),
			"content_height": control.get_content_height(), "available": [available.x, available.y],
			"scroll": control.scroll_active, "visible_ratio": control.visible_ratio, "ready": control.is_finished()}
	if control is Button and not control.text.strip_edges().is_empty():
		var font: Font = control.get_theme_font("font")
		var size: int = control.get_theme_font_size("font_size")
		var style: StyleBox = control.get_theme_stylebox(_button_style(control))
		var available: Vector2 = control.size - style.get_minimum_size()
		if control.icon != null:
			var icon_width: float = control.icon.get_width()
			var max_icon_width: int = control.get_theme_constant("icon_max_width")
			if max_icon_width > 0: icon_width = minf(icon_width, max_icon_width)
			if control.expand_icon:
				icon_width = minf(icon_width, available.y * control.icon.get_width() / maxf(control.icon.get_height(), 1.0))
			if control.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
				available.x -= icon_width + control.get_theme_constant("h_separation")
		var lines: int = control.text.split("\n").size()
		return {"text": control.text, "lines": lines, "visible_lines": null,
			"width": _line_width(control, font, size, control.text),
			"content_height": font.get_height(size) * lines, "available": [available.x, available.y],
			"overrun": control.text_overrun_behavior, "clip": control.clip_text}
	return {}

static func _label_height(label: Label, lines: int) -> float:
	var height: float = 0.0
	for line: int in range(lines):
		height += label.get_line_height(line)
	return height + maxi(0, lines - 1) * label.get_theme_constant("line_spacing")

static func _unbreakable_width(control: Label, font: Font, size: int, value: String) -> float:
	if control.autowrap_mode != TextServer.AUTOWRAP_WORD: return 0.0
	return _line_width(control, font, size, value.replace("\n", " ").replace("\t", " ").replace(" ", "\n"))

static func _line_width(control: Control, font: Font, size: int, value: String) -> float:
	var width: float = 0.0
	for part: String in value.split("\n"):
		var line := TextLine.new()
		if control.text_direction == Control.TEXT_DIRECTION_RTL: line.direction = TextServer.DIRECTION_RTL
		elif control.text_direction == Control.TEXT_DIRECTION_LTR: line.direction = TextServer.DIRECTION_LTR
		line.add_string(part.to_upper() if control is Label and control.uppercase else part, font, size, control.language)
		width = maxf(width, line.get_line_width())
	return width

static func _button_style(button: Button) -> String:
	match button.get_draw_mode():
		BaseButton.DRAW_DISABLED: return "disabled"
		BaseButton.DRAW_HOVER: return "hover"
		BaseButton.DRAW_HOVER_PRESSED: return "hover_pressed"
		BaseButton.DRAW_PRESSED: return "pressed"
	return "normal"

static func _text_problem(control: Control, data: Dictionary) -> String:
	if data.get("visible_ratio", 1.0) < 1.0 or not data.get("ready", true): return ""
	var available: Array = data["available"]
	if control is Button:
		if data["width"] > available[0] + EPSILON or data["content_height"] > available[1] + EPSILON:
			return "button_label_overflow"
		return ""
	if control is RichTextLabel:
		if data["width"] > available[0] + EPSILON: return "rich_text_width"
		if not data["scroll"] and data["content_height"] > available[1] + EPSILON: return "rich_text_height"
		return ""
	if data["max_lines"] >= 0 and data["lines"] > data["max_lines"]: return "line_limit"
	if data["visible_lines"] < data["lines"] and data["content_height"] > available[1] + EPSILON:
		return "hidden_lines"
	if control.autowrap_mode == TextServer.AUTOWRAP_OFF and data["width"] > available[0] + EPSILON:
		return "text_overrun"
	if data["unbreakable_width"] > available[0] + EPSILON: return "wrapped_word_overrun"
	return ""

static func _category(control: Control) -> String:
	if control is Label: return "labels"
	if control is RichTextLabel: return "rich_text"
	if control is BaseButton: return "buttons"
	if control is TextureRect: return "textures"
	return ""

static func _layer(control: Control, scene: Node, surface: Node) -> Node:
	var node: Node = control
	while node != scene and node != surface and node.get_parent() != null:
		if node is Window or node is Stack or node is CardWidget:
			return node
		if node is CanvasLayer or str(node.name).ends_with("Scrim"): return node
		node = node.get_parent()
	return node

static func _overlaps(group: Array, findings: Array[Dictionary]) -> void:
	for index: int in range(group.size()):
		var first: Dictionary = group[index]
		var a: Control = first.control
		var rect: Rect2 = first.visible
		for other_index: int in range(index + 1, group.size()):
			var second: Dictionary = group[other_index]
			var b: Control = second.control
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			var other: Rect2 = second.visible
			var hit: Rect2 = rect.intersection(other)
			if hit.size.x <= EPSILON or hit.size.y <= EPSILON: continue
			if hit.get_area() < OVERLAP_MIN_FRACTION * minf(rect.get_area(), other.get_area()): continue
			_emit(findings, "overlap", first.row, {"other": second.row, "intersection": rect_data(hit)})

static func _emit(rows: Array[Dictionary], name: String, witness: Dictionary, extra: Dictionary = {}) -> void:
	var row: Dictionary = witness.duplicate()
	row["check"] = name
	row.merge(extra)
	rows.append(row)
