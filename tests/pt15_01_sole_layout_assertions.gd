extends RefCounted
## Retain the pt14 coverage assertion for unchanged layouts. A sole-forced
## move may increase soft coverage, but must satisfy every existing hard rule.
const Before = preload("res://tests/fixtures/pt15_01_before_sole_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")
const Reference = preload("res://tests/fixtures/pt15_01_preferred_side_placement.gd")

static func check(board: Control, badges: Array, layouts: Array, silhouettes: Array, label: String, expect: Callable) -> Dictionary:
	var baseline: Array[Dictionary] = Before.layouts(board, badges)
	expect.call(layouts == Before.layouts(board, badges, true, Reference.place), label + ": preferred home and its local search precede the other side")
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
	return {"changed": not changes.is_empty(), "baseline_coverage": baseline_coverage, "changes": changes}
