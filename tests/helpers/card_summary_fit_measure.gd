extends RefCounted

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const EDGE_INSET_PX: float = 2.0
# The native-composition lower inset used by the existing pt13-03 audit.
const LOWER_INSET: float = 14.0

static func measure(face: Control, definition: Dictionary) -> Dictionary:
	var legibility: Dictionary = Audit.measure(face, definition)
	var result: Dictionary = {"margin_px": null, "row_count": 0, "continuation_errors": [], "floor_errors": Audit.floor_errors(legibility), "overflow_y": legibility["overflow_px"]["y"], "text_px": legibility["text_px"], "icon_px": legibility["icon_px"]}
	if not face is Audit.Card:
		result["layout"] = "text-only"
		return result
	var summary: Control = face.get("_summary_icon_box")
	if summary != null and summary.is_visible_in_tree():
		var inverse: Transform2D = face.get_global_transform_with_canvas().affine_inverse()
		var scale_x: float = face.get_global_transform_with_canvas().get_scale().abs().x
		var parchment: float = face.call("_summary_parchment_width")
		var left: float = (face.size.x - parchment) * 0.5
		for row: Node in summary.find_children("*", "HBoxContainer", true, false):
			if row.get_parent() != summary and not row.get_parent().has_meta("summary_action_group"):
				continue
			var start: Vector2 = inverse * row.get_global_transform_with_canvas().origin
			var end: Vector2 = inverse * (row.get_global_transform_with_canvas() * row.size)
			var margin: float = minf(start.x - left, left + parchment - end.x) * scale_x
			result["margin_px"] = margin if result["margin_px"] == null else minf(result["margin_px"], margin)
			result["row_count"] += 1
		var bounds: Rect2 = _full_item_bounds(summary, inverse)
		var screen_scale_y: float = face.get_global_transform_with_canvas().get_scale().abs().y
		result["overflow_y"] = maxf(float(result["overflow_y"]), maxf(-bounds.position.y, bounds.end.y - (face.size.y - LOWER_INSET)) * screen_scale_y)
		for glyph: Node in summary.find_children("*", "", true, false):
			if not glyph.has_meta("summary_continuation_glyph"): continue
			var parent: Node = glyph.get_parent()
			if glyph.get_index() + 1 >= parent.get_child_count() or parent.get_child(glyph.get_index() + 1).has_meta("summary_continuation_glyph"):
				result["continuation_errors"].append("Continuation glyph has no following item on its line")
	var layout: Array = []
	for region: Control in [face.get("art_frame"), face.get("details_panel"), summary]:
		layout.append(_geometry(region))
	result["layout"] = JSON.stringify(layout).sha256_text()
	return result

static func _full_item_bounds(summary: Control, inverse: Transform2D) -> Rect2:
	var bounds := Rect2()
	var found: bool = false
	# Include row containers, composite tokens, icons, value suffixes and text.
	# Label-only bounds miss tall icons and oversized wrapped-line containers.
	for node: Node in summary.find_children("*", "Control", true, false):
		var item: Control = node
		if not item.is_visible_in_tree(): continue
		var transform: Transform2D = inverse * item.get_global_transform_with_canvas()
		var rect: Rect2 = transform * Rect2(Vector2.ZERO, item.size)
		bounds = bounds.merge(rect) if found else rect
		found = true
	return bounds

static func _geometry(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is Control:
		result.append_array([node.position.x, node.position.y, node.size.x, node.size.y, node.custom_minimum_size.x, node.custom_minimum_size.y, node.visible])
	if node is BoxContainer: result.append(node.get_theme_constant("separation"))
	if node is Label: result.append_array([node.text, node.get_theme_font_size("font_size")])
	# Art's reflection/shadow and rarity effects animate independently of rules.
	if node.name == "ArtFrame": return result
	for child: Node in node.get_children(): result.append(_geometry(child))
	return result
