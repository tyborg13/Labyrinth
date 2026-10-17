extends RefCounted

# Instrumented revision-4 control flow, kept outside the runtime generator.
# Its output is compared against the production graph by section_map_variety.gd.
const Graph = preload("res://scripts/section_map_graph.gd")
const DepthRules = preload("res://scripts/depth_rules.gd")

static func bump(stats: Dictionary, reason: String, amount: int = 1) -> void:
	stats[reason] = int(stats.get(reason, 0)) + amount

static func generate(seed_value: int, index: int, stats: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
	var count: int = Graph.ROOM_COUNTS[index]
	for attempt: int in range(Graph.SECTION_ATTEMPTS):
		var layout: Dictionary = _walk_layout(rng, count, stats)
		Graph._prepare_types(layout, seed_value, index, count)
		var budget: Dictionary = {"remaining": Graph.TYPE_REPAIR_LIMIT}
		if _repair(layout, rng, count, Graph.FIGHT_COUNTS[index] - 1, 0, budget, stats):
			bump(stats, "sections")
			if layout["walks"] == Graph._fallback_walks(count): bump(stats, "accepted_canned_topology")
			return layout
		bump(stats, "type_search_failed")
		if int(budget["remaining"]) <= 0: bump(stats, "type_budget_exhausted")
	bump(stats, "section_fallback")
	bump(stats, "sections")
	return Graph._fallback_layout(count, Graph.FIGHT_COUNTS[index] - 1)

static func _walk_layout(rng: RandomNumberGenerator, count: int, stats: Dictionary) -> Dictionary:
	for attempt: int in range(Graph.TOPOLOGY_ATTEMPTS):
		bump(stats, "topology_candidates")
		var walks: Array = []
		var edges: Dictionary = {}
		for walk_index: int in range(Graph.WALK_COUNT):
			var lane: int = rng.randi_range(0, 3)
			if walk_index == 1:
				var alternatives: Array[int] = []
				for candidate: int in range(4):
					if candidate != int(walks[0][0]): alternatives.append(candidate)
				lane = alternatives[rng.randi_range(0, alternatives.size() - 1)]
			var walk: Array[int] = []
			walk.assign([lane])
			for step: int in range(1, count - 1):
				var moves: Array[int] = Graph._walk_moves(lane, Graph._coords(edges.get(step, [])))
				bump(stats, "crossing_moves_rejected", 3 - moves.size())
				var next_lane: int = lane if moves.is_empty() else moves[rng.randi_range(0, moves.size() - 1)]
				if not edges.has(step): edges[step] = []
				var move := Vector2i(lane, next_lane)
				if not edges[step].has(move): edges[step].append(move)
				walk.append(next_lane)
				lane = next_lane
			walks.append(walk)
		var layout: Dictionary = Graph._layout_from_walks(walks, count)
		var valid: bool = layout["rows"][1].size() == Graph.OPENING_CHILD_COUNT
		if not valid: bump(stats, "opening_count")
		var rows_valid: bool = true
		for row: Array in layout["rows"].values(): rows_valid = rows_valid and row.size() >= 2
		if not rows_valid: bump(stats, "row_count")
		valid = valid and rows_valid
		var fixed_valid: bool = true
		for children: Array in layout["children"].values():
			if children.size() >= 2 and int(children[0].x) in [ceili(count / 2.0), count - 1]: fixed_valid = false
		if not fixed_valid: bump(stats, "fixed_row_fork")
		valid = valid and fixed_valid
		# Match production's short circuit; its door mapping assumes 3 openings.
		if valid:
			if Graph._physical_doors_legal(layout): return layout
			bump(stats, "door_compatibility")
	bump(stats, "topology_fallback")
	return Graph._layout_from_walks(Graph._fallback_walks(count), count)

static func _repair(layout: Dictionary, rng: RandomNumberGenerator, count: int, fights: int, position: int, budget: Dictionary, stats: Dictionary) -> bool:
	if int(budget["remaining"]) <= 0: return false
	if position == layout["order"].size():
		if Graph._complete_types_legal(layout, count, fights): return true
		var guardians: int = 0
		var scavengers: int = 0
		var bypass: bool = false
		for cell: Vector2i in layout["order"]:
			var node: Dictionary = layout["nodes"][cell]
			guardians += int(node["type"] == "guardian")
			scavengers += int(node["type"] == "scavenger")
			if cell.x != count - 1: continue
			bypass = bypass or int(node["min_guardians"]) == 0
			if int(node["min_services"]) < 1: bump(stats, "per_route_service")
			if int(node["max_guardians"]) > 1: bump(stats, "per_route_guardian")
			if int(node["min_fights"]) < fights - 1 or int(node["max_fights"]) > fights + 1: bump(stats, "per_route_fights")
		if guardians < 2 or scavengers < 1 or not bypass: bump(stats, "section_counts")
		return false
	var cell: Vector2i = layout["order"][position]
	var node: Dictionary = layout["nodes"][cell]
	var candidates: Array[String] = []
	if bool(node["fixed"]): candidates.append(node["type"])
	else:
		var weights: Dictionary = Graph.TYPE_WEIGHTS.duplicate()
		weights["guardian"] = DepthRules.guardian_weight({}, int(weights["guardian"]))
		while not weights.is_empty():
			var type: String = Graph._weighted_roll(rng, weights)
			candidates.append(type)
			weights.erase(type)
	for type: String in candidates:
		budget["remaining"] = int(budget["remaining"]) - 1
		node["type"] = type
		Graph._prefix_bounds(layout, cell)
		if Graph._prefix_type_legal(layout, cell, count, fights):
			if _repair(layout, rng, count, fights, position + 1, budget, stats): return true
		else: _count_prefix_rejections(layout, cell, count, fights, stats)
		if int(budget["remaining"]) <= 0: break
	if not bool(node["fixed"]): node["type"] = ""
	return false

static func _count_prefix_rejections(layout: Dictionary, cell: Vector2i, count: int, fights: int, stats: Dictionary) -> void:
	var node: Dictionary = layout["nodes"][cell]
	var type: String = node["type"]
	if type == "guardian" and (cell.x < 3 or cell.x > count - 3): bump(stats, "guardian_rows")
	if type == "scavenger" and cell.x < 3: bump(stats, "scavenger_rows")
	if type == "graftwright" and int(node["min_fights"]) < 3: bump(stats, "graftwright_fights")
	if int(node["max_guardians"]) > 1: bump(stats, "per_route_guardian")
	var remaining: int = 0
	for step: int in range(cell.x + 1, count - 1):
		if step != ceili(count / 2.0): remaining += 1
	if int(node["max_fights"]) > fights + 1 or int(node["min_fights"]) + remaining < fights - 1: bump(stats, "per_route_fights")
	for parent: Vector2i in layout["parents"].get(cell, []):
		if type in ["guardian", "scavenger", "graftwright", "campfire", "treasure"] and str(layout["nodes"][parent]["type"]) == type: bump(stats, "consecutive_special")
		var siblings: Array = layout["children"][parent]
		if siblings.size() < 2: continue
		for sibling: Vector2i in siblings:
			if sibling == cell or sibling.y > cell.y: continue
			if str(layout["nodes"][sibling]["type"]) == type and not (type == "combat" and siblings.size() == 3): bump(stats, "fork_type_distinctness")
