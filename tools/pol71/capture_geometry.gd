extends RefCounted

const IntentBadges = preload("res://scripts/intent_badges.gd")


static func controls(viewport: Viewport, scene: Node) -> Dictionary:
	var rects: Dictionary = {}
	_collect(scene, "", viewport.get_stretch_transform(), rects)
	return rects


# Output-pixel edges and anonymous paths follow tools/pol69/geometry.gd.
static func _collect(node: Node, path: String, stretch: Transform2D, rects: Dictionary) -> void:
	if node.is_queued_for_deletion() or node is Viewport:
		return
	if (node is CanvasItem and not node.is_visible_in_tree()) or (node is CanvasLayer and not node.visible):
		return
	var part: String = str(node.name)
	if part.begins_with("@"):
		part = "@%s[%d]" % [node.get_class(), node.get_index(true)]
	var key: String = path.path_join(part)
	if node is Control:
		var rect: Rect2 = stretch * node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
		if rect.has_area(): rects[key] = rect_values(rect)
	for child: Node in node.get_children(true):
		_collect(child, key, stretch, rects)


static func plates(board: Control) -> Dictionary:
	var units: Dictionary = {}
	for unit: Dictionary in board._visible_units():
		units[unit["key"]] = unit
	if not units.has("player") or not units.has("enemy_1"):
		return {}
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var health: Dictionary = board._hud_health_rects_cache
	var hero: Dictionary = units["player"]
	var hero_frame: Rect2 = health.get("player", Rect2())
	var hero_plates: Dictionary = board._status_plate_layout.resolve(board, hero, hero_frame)
	var foe_frame: Rect2 = health.get("enemy_1", Rect2())
	var intent: Rect2
	for chip: Dictionary in IntentBadges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if chip.get("key") == "enemy_1": intent = chip["rect"]
	var rows: Dictionary = {}
	for status: Dictionary in hero_plates["statuses"]:
		var rect: Rect2 = transform * status["rect"]
		var health_overlap: Rect2 = rect.intersection(transform * foe_frame)
		var intent_overlap: Rect2 = rect.intersection(transform * intent)
		rows[status["icon"]] = {
			"rect": rect_values(rect),
			"health_overlap_pct": _percent(health_overlap.get_area(), rect.get_area()),
			"intent_overlap_pct": _percent(intent_overlap.get_area(), rect.get_area()),
			"combined_overlap_pct": _percent(health_overlap.get_area() + intent_overlap.get_area() - health_overlap.intersection(intent_overlap).get_area(), rect.get_area()),
		}
	return {"hero_health": rect_values(transform * hero_frame), "foe_health": rect_values(transform * foe_frame),
		"intent_chip": rect_values(transform * intent), "chips": rows}


static func rect_values(rect: Rect2) -> Array[float]:
	var values: Array[float] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return values


static func _percent(part: float, total: float) -> float:
	return snappedf(100.0 * part / total, 0.01)
