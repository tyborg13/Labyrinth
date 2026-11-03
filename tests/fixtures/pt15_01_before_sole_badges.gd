extends "res://scripts/intent_badges.gd"
## Frozen pt14-04 placement (230731f2e), with current rest sources/registration.
## Only the owner sole obstacle is absent, so comparisons isolate this change.

static func place_chip(anchor: Vector2, badge: Dictionary, font: Font, obstacles: Array, previous: Array, bounds: Rect2 = Rect2(), silhouettes: Array = []) -> Dictionary:
	var center: Vector2 = anchor + FEET_OFFSET
	var rect: Rect2 = chip_rect(center, badge, font)
	var left_center := Vector2(anchor.x - FEET_OFFSET.x - (rect.end.x - center.x), anchor.y + FEET_OFFSET.y)
	var left_rect: Rect2 = chip_rect(left_center, badge, font)
	var owner_key: String = str(badge.get("key", ""))
	var prefer_left: bool = ChipPlacement.coverage(rect, silhouettes, owner_key) - ChipPlacement.coverage(left_rect, silhouettes, owner_key) > rect.get_area() * ChipPlacement.SIDE_MARGIN
	for left: bool in [prefer_left, not prefer_left]:
		var candidate: Rect2 = left_rect if left else rect
		if (not bounds.has_area() or bounds.encloses(candidate)) and not _overlaps(candidate, obstacles, previous):
			return {"center": left_center if left else center, "rect": candidate, "placement": "lower_left" if left else "lower_right", "above_everything": false}
	var clear: Dictionary = ChipPlacement.find_clear(rect, left_rect, obstacles, previous, bounds, prefer_left)
	if not clear.is_empty():
		return {"center": center + (clear["rect"] as Rect2).position - rect.position, "rect": clear["rect"], "placement": clear["placement"], "above_everything": false}
	return {"center": left_center if prefer_left else center, "rect": left_rect if prefer_left else rect, "placement": "lower_left" if prefer_left else "lower_right", "above_everything": true}


static func layouts(board: Control, badges: Array, with_sole_obstacles: bool = false, placement: Callable = Callable(), diagnostics: Variant = null) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if badges.is_empty(): return result
	var font: Font = Typography.ui_font()
	var sorted_badges: Array = badges.duplicate(true)
	sorted_badges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _first_order(str(a.get("order", ""))) < _first_order(str(b.get("order", ""))))
	var units: Array = board.call("_visible_units")
	# sb-01: the same plates/pills that reserve callout and intent space.
	var hud_rects: Array[Rect2]
	hud_rects.append_array(HudGroups.screen_reservations(board))
	hud_rects.append_array(fixed_order_rects(board, units, sorted_badges))
	hud_rects.append_array(terrain_health_rects(board))
	var boss_frame: Rect2 = boss_health_rect(board)
	if boss_frame.has_area(): hud_rects.append(boss_frame)
	var units_by_key: Dictionary = board.call("_units_by_key", units)
	var hud_entries: Array = board.get("_hud_layout_entries_cache")
	if hud_entries.is_empty(): hud_entries = board.call("_build_hud_layout_data", board.call("_hud_layout_units"))["entries"]
	var hud_by_key: Dictionary = {}
	for entry: Dictionary in hud_entries:
		var actor: Dictionary = units_by_key.get(str(entry.get("actor_key", "")), {})
		if not actor.is_empty() and not (board.call("_umbra_actor_clip_for_unit", actor) as Dictionary).is_empty(): continue
		var layout: Dictionary = entry.get("layout", {})
		hud_by_key[str(entry.get("actor_key", ""))] = layout
		for line: Rect2 in layout.get("line_rects", []): hud_rects.append(line)
	for actor: Dictionary in board.call("_hud_layout_units"):
		if bool(actor.get("death_animation", false)):
			var death_frame: Rect2 = death_health_rect(board, actor)
			if death_frame.has_area(): hud_rects.append(death_frame)
			continue
		if actor.get("role") == "npc" or not (board.call("_umbra_actor_clip_for_unit", actor) as Dictionary).is_empty(): continue
		var health: Rect2 = health_rect(board, actor)
		if not bool(actor.get("boss_bar", false)): hud_rects.append_array(board.call("_health_bar_collision_rects", actor, health))
		elif health.has_area() and not hud_rects.has(health): hud_rects.append(health)
		var crest: Rect2 = board.call("_leader_marker_rect", actor, health, hud_by_key.get(str(actor.get("key", "")), {}).get("intent_rect", Rect2()))
		if crest.has_area(): hud_rects.append(crest)
	# Only HUD reserves chip space. Coverage chooses a side using cached rest
	# silhouettes: animated draw bounds made an unchanged board jitter.
	var silhouettes: Array[Dictionary] = ChipPlacement.rest_silhouettes(board, units)
	for badge: Dictionary in sorted_badges:
		var unit: Dictionary = {}
		for candidate: Dictionary in units:
			if str(candidate.get("key", "")) == str(badge["key"]) and str(candidate.get("role", "")) == "enemy":
				unit = candidate
		if unit.is_empty() or bool(unit.get("death_animation", false)): continue
		var layout: Dictionary = badge.duplicate(true)
		var chip_obstacles: Array = hud_rects
		if with_sole_obstacles:
			chip_obstacles = hud_rects.duplicate()
			var sole: Rect2 = ChipPlacement.owner_sole_obstacle(silhouettes, str(badge["key"]))
			if sole.has_area(): chip_obstacles.append(sole)
		if diagnostics is Dictionary:
			diagnostics[str(badge["key"])] = {"obstacles": chip_obstacles.duplicate(), "previous": result.duplicate(true), "bounds": board.call("_enemy_hud_viewport_bounds"), "silhouettes": silhouettes}
		if placement.is_valid():
			layout.merge(placement.call(board.call("_unit_center", unit), badge, font, chip_obstacles, result, board.call("_enemy_hud_viewport_bounds"), silhouettes), true)
		else:
			layout.merge(place_chip(board.call("_unit_center", unit), badge, font, chip_obstacles, result, board.call("_enemy_hud_viewport_bounds"), silhouettes), true)
		layout["order_rect"] = order_rect(order_anchor_rect(board, unit), str(badge.get("order", "")), font)
		result.append(layout)
	return result
