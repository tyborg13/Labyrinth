extends RefCounted
## Capture live tooltip text and bounds using the same coordinates as the rendered frame.

# Both revisions register the icon square at this offset inside the painted ring.
const MARK_ICON_SCALE := 0.22
const MARK_ICON_MIN := 24.0
const MARK_ICON_MAX := 40.0
const MARK_ICON_OFFSET := Vector2(-0.16, 0.22)
const MARK_SHADOW_RADIUS_SCALE := 0.62
const MARK_SHADOW_OUTSET := 4.0


static func tile_rect(board: Control, tile: Vector2i) -> Rect2:
	var polygon: PackedVector2Array = board.call("_tile_polygon", tile)
	if polygon.is_empty(): return Rect2()
	var transform := board.get_global_transform_with_canvas()
	var bounds := Rect2(transform * polygon[0], Vector2.ZERO)
	for vertex: Vector2 in polygon:
		bounds = bounds.expand(transform * vertex)
	return bounds


static func medallions(board: Control) -> Array[Array]:
	var results: Array[Array]
	for layer: Control in board.call("_retained_render_layers"):
		if not layer.is_visible_in_tree() or layer.get("_render_layer_kind") != "effects": continue
		var regions: Array = layer.get("_tooltip_regions")
		var tile_regions: Dictionary = layer.get("_tile_tooltip_regions")
		var size := clampf(layer._tile_width() * MARK_ICON_SCALE, MARK_ICON_MIN, MARK_ICON_MAX)
		var offset := Vector2(layer._tile_width(), layer._tile_height()) * MARK_ICON_OFFSET
		for index: int in tile_regions:
			var tile: Vector2i = tile_regions[index]["tile"]
			var rect: Rect2 = regions[index]["rect"]
			if not rect.size.is_equal_approx(Vector2.ONE * size): continue
			if not rect.get_center().is_equal_approx(layer._tile_center(tile) + offset): continue
			var radius := size * MARK_SHADOW_RADIUS_SCALE + MARK_SHADOW_OUTSET
			var painted := Rect2(rect.get_center() - Vector2.ONE * radius, Vector2.ONE * 2.0 * radius)
			results.append(edges(layer.get_global_transform_with_canvas() * painted))
	return results


static func popups(viewport: SubViewport, heading: Control) -> Array[Dictionary]:
	var results: Array[Dictionary]
	for window: Window in viewport.get_embedded_subwindows():
		if not window.visible or window.theme_type_variation != &"TooltipPanel": continue
		var rect := Rect2(Vector2(window.position), Vector2(window.size))
		if rect.intersects(viewport.get_visible_rect()):
			results.append({"rect": edges(rect), "panels": _panels(window)})
	if heading != null:
		var focus := heading.get_node_or_null("PreBattleObjectiveFocusTooltip") as Control
		if focus != null and focus.is_visible_in_tree():
			results.append({"rect": edges(focus.get_global_rect()), "panels": _panels(focus)})
	return results


static func _panels(node: Node) -> Array[Dictionary]:
	var panels: Array[Dictionary]
	var stack := node.find_child("BoardTileTooltipStack", true, false)
	if stack != null:
		for panel: Control in stack.get_children():
			if panel.is_visible_in_tree(): panels.append(_panel_text(panel))
	else:
		panels.append(_panel_text(node))
	return panels


static func _panel_text(node: Node) -> Dictionary:
	var lines: PackedStringArray
	_read_lines(node, lines)
	var title := lines[0] if not lines.is_empty() else ""
	return {"title": title, "lines": lines.slice(1)}


static func _read_lines(node: Node, lines: PackedStringArray) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	var value := ""
	if node is Label: value = node.text
	elif node is RichTextLabel: value = node.get_parsed_text()
	if not value.is_empty(): lines.append_array(value.split("\n"))
	for child: Node in node.get_children(true):
		_read_lines(child, lines)


static func edges(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
