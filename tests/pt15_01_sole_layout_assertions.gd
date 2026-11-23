extends RefCounted
## Retain the pt14 coverage assertion for unchanged layouts. A sole-forced
## move may increase soft coverage, but must satisfy every existing hard rule.
const Before = preload("res://tests/fixtures/pt15_01_before_sole_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")
const Reference = preload("res://tests/fixtures/pt15_01_preferred_side_placement.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const HERO_CLEARANCE_CASES: Array = ["boss_crowded", "dragon_crowded"]

static func check(board: Control, badges: Array, layouts: Array, silhouettes: Array, label: String, expect: Callable) -> Dictionary:
	var baseline: Array[Dictionary] = Before.layouts(board, badges)
	var diagnostics: Dictionary = {}
	var expected: Array[Dictionary] = Before.layouts(board, badges, true, Reference.place, diagnostics, true)
	_check_hero_clearance(board, layouts, expected, label, expect)
	expect.call(layouts == expected, label + ": preferred home and local search precede the other side, followed by title and hero HUD clearance")
	var old_by_key: Dictionary = {}
	for old: Dictionary in baseline: old_by_key[old["key"]] = old
	var changes: Array[Dictionary]
	var baseline_coverage: float = 0.0
	for old: Dictionary in baseline: baseline_coverage += Solver.coverage(old["rect"], silhouettes, old["key"])
	for layout: Dictionary in layouts:
		var sole: Rect2 = Solver.owner_sole_obstacle(silhouettes, layout["key"])
		var rect: Rect2 = layout["rect"]
		expect.call(bool(layout["above_everything"]) or not rect.intersects(sole, false), label + ": nonfallback chip avoids its owner's sole obstacle: " + str(layout["key"]))
		var old: Dictionary = old_by_key[layout["key"]]
		if rect == old["rect"]: continue
		var owner_blocked: bool = (old["rect"] as Rect2).intersects(sole, false)
		# Later chips also avoid earlier chips' resolved rectangles. Their changes
		# are part of the same deterministic sequential placement, not new policy.
		# The exact reference comparison above also validates changes where HUD
		# alone blocks the preferred home and the new same-side search wins.
		var change: Dictionary = {"key": layout["key"], "old_rect": str(old["rect"]), "new_rect": str(rect), "cause": "owner_sole" if owner_blocked else "preferred_side_search", "fallback": layout["above_everything"]}
		changes.append(change)
	if not changes.is_empty(): print("PT15 SOLE EXPECTATION CHANGE: " + JSON.stringify({"fixture": label, "chips": changes}))
	return {"changed": not changes.is_empty(), "baseline_coverage": baseline_coverage, "changes": changes, "diagnostics": diagnostics}

static func _check_hero_clearance(board: Control, layouts: Array[Dictionary], expected: Array[Dictionary], label: String, expect: Callable) -> void:
	var hero_rects: Array = board._status_plate_layout.cached_group("player").get("group_rects", [])
	var units: Dictionary = board._units_by_key(board._hud_layout_units())
	var half_tile: float = board._tile_width() * 0.5
	for index: int in range(mini(layouts.size(), expected.size())):
		var layout: Dictionary = layouts[index]
		var key: String = layout["key"]
		var offset: Vector2 = layout.get("hero_clearance_offset", Vector2.ZERO)
		if key == "enemy_1" and HERO_CLEARANCE_CASES.has(label.get_slice(" ", 0)):
			expect.call(offset != Vector2.ZERO, label + ": crowded fixture clears the hero HUD")
		if offset == Vector2.ZERO: continue
		var reference: Dictionary = expected[index]
		var natural: Rect2 = reference["rect"]
		var moved := Rect2(natural.position + offset, natural.size)
		var row_height: float = Badges.health_rect(board, units[key]).size.y + natural.size.y
		expect.call(hero_rects.any(func(rect: Rect2) -> bool: return natural.intersects(rect, false))
			and not hero_rects.any(func(rect: Rect2) -> bool: return moved.intersects(rect, false)),
			label + ": the additional chip move clears an overlapping hero HUD: " + key)
		expect.call((absf(offset.x) <= half_tile or is_equal_approx(absf(offset.x), half_tile))
			and offset.y <= 0.0 and (-offset.y <= row_height or is_equal_approx(-offset.y, row_height)),
			label + ": hero clearance stays within half a tile sideways and one HUD row upward: " + key)
		reference["rect"] = moved
		reference["center"] += offset
		reference["hero_clearance_offset"] = offset
		reference["above_everything"] = false
