extends RefCounted
## Independent overlap checks for the actual retained HUD draw rectangles.

const UNIT_AND_PLATE_CLEARANCE: float = 8.0
const BRAZIER_AND_TETHER_CLEARANCE: float = 6.0
const PROOF_PLATE_WIDTH: float = 200.0
# Stable envelope of the procedural fire renderer across all phases, in fire widths.
const FIRE_ENVELOPE := Rect2(-0.52, -0.521, 1.04, 0.843)

static func inspect(hud: Control, board: Control, markers: Array[Dictionary], baseline: bool) -> Array[Dictionary]:
	var obstacles: Dictionary = {}
	var bodies: Dictionary = {}
	for unit: Dictionary in hud._visible_units():
		if hud._unit_is_preview_echo(unit) or int(unit.get("hp", 0)) <= 0 or bool(unit.get("death_animation", false)): continue
		var key: String = unit["key"]
		var body: Rect2 = board._unit_draw_rect(unit)
		bodies[key] = body
		obstacles[key + "/body"] = body.grow(UNIT_AND_PLATE_CLEARANCE)
		if bool(unit.get("boss_bar", false)) or unit.get("role") == "npc": continue
		var anchor: Rect2 = board._unit_health_bar_rect(unit, board._unit_center(unit))
		var frame: Rect2 = board._hud_health_rects_cache.get(key, anchor)
		var bars: Array[Rect2] = board._health_bar_collision_rects(unit, frame)
		for i: int in range(bars.size()): obstacles["%s/health[%d]" % [key, i]] = bars[i]

	var fixed: Array[Rect2] = hud._status_plate_layout.Groups.screen_reservations(hud)
	for i: int in range(fixed.size()):
		var rect: Rect2 = fixed[i]
		if rect.position.is_finite() and rect.end.is_finite() and rect.has_area():
			obstacles["fixed_hud[%d]" % i] = rect

	var brazier_count: int = 0
	for prop: Dictionary in board.presentation.get("scene_props", []):
		if not str(prop.get("kind", "")).begins_with("watch_brazier"): continue
		var texture: Texture2D = board._texture_for_scene_prop(prop)
		if texture == null: continue
		var rect: Rect2 = board._scene_prop_rect(texture, prop)
		if prop["kind"] == "watch_brazier_lit":
			var width: float = rect.size.x * 0.72
			var bowl: Vector2 = rect.position + rect.size * Vector2(0.5, 0.46)
			rect = rect.merge(Rect2(bowl + FIRE_ENVELOPE.position * width, FIRE_ENVELOPE.size * width))
		obstacles["brazier%s/%s" % [prop["tile"], prop["kind"]]] = rect.grow(BRAZIER_AND_TETHER_CLEARANCE)
		brazier_count += 1

	var results: Array[Dictionary]
	var bounds: Rect2 = hud._enemy_hud_viewport_bounds()
	for marker: Dictionary in markers:
		var rect: Rect2 = marker["rect"]
		var center: Vector2 = hud._tile_center(marker["tile"])
		var start := Vector2(rect.get_center().x, rect.end.y)
		var hits := PackedStringArray()
		if not baseline:
			start = hud._noctyrax_brazier_tether_anchor(rect, center)
			var expected_y: float = rect.position.y if center.y <= rect.get_center().y else rect.end.y
			if start != Vector2(rect.get_center().x, expected_y): hits.append("wrong tether edge")
		if _hits_rect(start.lerp(center, 0.001), center, rect.grow(-0.01)):
			hits.append("tether through own plate")

		for key: String in obstacles:
			var obstacle: Rect2 = obstacles[key]
			var area: float = rect.intersection(obstacle).get_area()
			if area > 0.0: hits.append("plate/%s=%s area=%.3f" % [key, obstacle, area])
		var unit_hits := PackedStringArray()
		for key: String in bodies:
			var body: Rect2 = bodies[key]
			if not _hits_rect(start, center, body): continue
			var reason: String = "brazier endpoint lies in unit" if body.has_point(center) else "no clear route selected"
			unit_hits.append("tether/%s=%s (%s)" % [key, body, reason])
		for other: Dictionary in markers:
			if other["tile"] == marker["tile"]: continue
			var other_rect: Rect2 = other["rect"]
			var other_center: Vector2 = hud._tile_center(other["tile"])
			var other_start := Vector2(other_rect.get_center().x, other_rect.end.y)
			if not baseline: other_start = hud._noctyrax_brazier_tether_anchor(other_rect, other_center)
			var overlap_area: float = rect.intersection(other_rect.grow(UNIT_AND_PLATE_CLEARANCE)).get_area()
			if overlap_area > 0.0: hits.append("plate/plate%s=%s area=%.3f" % [other["tile"], other_rect, overlap_area])
			if _hits_rect(start, center, other_rect.grow(BRAZIER_AND_TETHER_CLEARANCE)):
				hits.append("tether/plate%s=%s" % [other["tile"], other_rect])
			if _segments_meet(start, center, other_start, other_center):
				hits.append("tether/tether%s=[%s -> %s]" % [other["tile"], other_start, other_center])
		results.append({"start": start, "end": center, "length": start.distance_to(center), "hits": hits,
			"unit_hits": unit_hits, "in_bounds": bounds.encloses(rect), "braziers": brazier_count})
	return results

static func check_fallbacks(hud: Control, tile: Vector2i) -> bool:
	var markers: Array[Dictionary]
	markers.append({"tile": tile, "width": PROOF_PLATE_WIDTH})
	var center: Vector2 = hud._tile_center(tile)
	var full := Rect2(center + Vector2(-PROOF_PLATE_WIDTH * 0.5, -hud._tile_height() * 1.6 - 54.0), Vector2(PROOF_PLATE_WIDTH, 54.0))
	var compact := Rect2(full.position + Vector2(0, 20), Vector2(PROOF_PLATE_WIDTH, 34.0))
	var expanded := Rect2(full.position + Vector2(0, 35), full.size)
	var unit_rects: Array[Rect2]
	var obstacles: Dictionary = {"fixed_hud": unit_rects, "hard": unit_rects, "bodies": unit_rects, "units": unit_rects}
	obstacles["bounds"] = expanded
	var expanded_layout: Dictionary = hud._noctyrax_brazier_layout(markers, obstacles)
	obstacles["bounds"] = compact
	var compact_layout: Dictionary = hud._noctyrax_brazier_layout(markers, obstacles)
	var covering_unit: Array[Rect2]
	covering_unit.append(compact)
	obstacles["units"] = covering_unit
	var crowded_layout: Dictionary = hud._noctyrax_brazier_layout(markers, obstacles)
	return (_placed_at(expanded_layout, 1, expanded) and _placed_at(compact_layout, 2, compact)
		and _placed_at(crowded_layout, 3, compact) and crowded_layout["overlap"] > 0.0)

static func check_crossing(hud: Control) -> bool:
	var first: Dictionary = {"start": Vector2(20, 20), "end": Vector2(120, 120), "rect": Rect2(0, 0, 40, 20)}
	var second: Dictionary = {"start": Vector2(120, 20), "end": Vector2(20, 120), "rect": Rect2(100, 0, 40, 20)}
	return hud._noctyrax_brazier_tether_conflicts(first, second) == 1 and hud._noctyrax_brazier_tether_conflicts(second, first) == 1

static func _placed_at(layout: Dictionary, stage: int, rect: Rect2) -> bool:
	return layout["stage"] == stage and layout["placements"].size() == 1 and layout["placements"][0]["rect"] == rect

static func _hits_rect(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	if rect.has_point(start) or rect.has_point(end): return true
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return (_segments_meet(start, end, rect.position, top_right)
		or _segments_meet(start, end, top_right, rect.end)
		or _segments_meet(start, end, rect.end, bottom_left)
		or _segments_meet(start, end, bottom_left, rect.position))

static func _segments_meet(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null: return true
	for point: Vector2 in [a, b]:
		if is_zero_approx(point.distance_to(Geometry2D.get_closest_point_to_segment(point, c, d))): return true
	for point: Vector2 in [c, d]:
		if is_zero_approx(point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))): return true
	return false
