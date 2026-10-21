extends RefCounted
class_name SectionMapGraph

# Coordinates retain the existing four-depth difficulty bands. Screen placement
# and connectivity are authored independently; a coordinate is a persistent id.
const DepthRules = preload("res://scripts/depth_rules.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const VERSION: int = 1
const LAYOUT_REVISION: int = 7
const Specials = preload("res://scripts/special_encounter_library.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const ROOM_COUNTS: Array[int] = [10, 11, 11, 11, 11, 12]
const FIGHT_COUNTS: Array[int] = [6, 6, 7, 7, 7, 7]
const INVALID: Vector2i = Vector2i(-999, -999)

static func enabled(state: Dictionary) -> bool:
	return int(state.get("section_map_version", 0)) == VERSION

static func key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

static func room(state: Dictionary, coord: Vector2i) -> Dictionary:
	return (state.get("rooms", {}) as Dictionary).get(key(coord), {}) as Dictionary

static func active_section(state: Dictionary) -> int:
	return int(room(state, state.get("current_room", Vector2i.ZERO)).get("section_index", 0))

static func section(state: Dictionary, index: int) -> Dictionary:
	var sections: Array = state.get("map_sections", [])
	return sections[index] as Dictionary if index >= 0 and index < sections.size() else {}

# Search limits affect implementation work only; accepted sections always satisfy
# the same contract. The old generator is retained solely for compatibility proof.
const WALK_COUNT: int = 5
const TOPOLOGY_ATTEMPTS: int = 50
const SECTION_ATTEMPTS: int = 50
const TYPE_REPAIR_LIMIT: int = 12000
const NODE_SEED_RUN_MULTIPLIER: int = 15485863
const NODE_SEED_SECTION_MULTIPLIER: int = 32452843
const NODE_SEED_STEP_MULTIPLIER: int = 49979687
const NODE_SEED_LANE_MULTIPLIER: int = 67867967
const TYPE_WEIGHTS: Dictionary = {"combat": 46, "mystery": 22, "guardian": 10, "scavenger": 10, "graftwright": 6, "event": 6}
const MYSTERY_WEIGHTS: Dictionary = {"event": 70, "combat": 20, "treasure": 5, "scavenger": 5}
# Three opening combats are the only legal threshold fan-out: combat may
# repeat only with three children, and the physical mapping has three doors.
const OPENING_CHILD_COUNT: int = 3

static func modern(state: Dictionary) -> bool:
	# The panel's compact snapshot retains section metadata but historically
	# omits the top-level revision. An explicit older revision always wins.
	var revision: int = int(state.get("section_map_layout_revision", section(state, 0).get("lane_count", 0)))
	return enabled(state) and revision >= 4

static func full_visibility(state: Dictionary, index: int) -> bool:
	return modern(state) and index < 5

static func display_type(node: Dictionary) -> String:
	if str(node.get("type", "")) == "mystery":
		return str(node.get("mystery_type", "mystery")) if bool(node.get("scouted", false)) else "mystery"
	return str(node.get("type", ""))

static func initialize(state: Dictionary, diagnostics: Dictionary = {}) -> void:
	var revision: int = int(state.get("section_map_layout_revision", LAYOUT_REVISION))
	if revision == 3:
		_initialize_revision_3(state)
	else:
		_initialize_walk_revision(state, revision, diagnostics)

static func _initialize_revision_4(state: Dictionary) -> void:
	_initialize_walk_revision(state, 4)

static func _initialize_walk_revision(state: Dictionary, revision: int, diagnostics: Dictionary = {}) -> void:
	var seed_value: int = int(state.get("seed", 0))
	var rooms: Dictionary = {}
	var sections: Array[Dictionary] = []
	for index: int in range(6):
		var section_started: int = Time.get_ticks_usec() if diagnostics.get("enabled", false) else 0
		var section_diagnostics: Dictionary = {"enabled": true} if diagnostics.get("enabled", false) else {}
		if diagnostics.get("force_v7_fallback", false): section_diagnostics["force_fallback"] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
		var count: int = ROOM_COUNTS[index]
		var boss_id: String = Bosses.boss_id_for_depth(seed_value, (index + 1) * 4)
		var layout: Dictionary = {}
		if revision >= 7:
			layout = _section_layout_v7(rng, seed_value, index, section_diagnostics, state)
		elif revision >= 5:
			layout = _section_layout_v5(rng, seed_value, index, section_diagnostics, state)
		else:
			for attempt: int in range(SECTION_ATTEMPTS):
				layout = _walk_layout(rng, count)
				_prepare_types(layout, seed_value, index, count)
				var repair: Dictionary = {"remaining": TYPE_REPAIR_LIMIT}
				if _repair_types(layout, rng, count, FIGHT_COUNTS[index] - 1, 0, repair, state): break
				layout = {}
			if layout.is_empty():
				layout = _fallback_layout(count, FIGHT_COUNTS[index] - 1)
		if revision >= 6 and not Specials.place(layout, rng, count, Bosses.element_for_boss(boss_id)):
			layout = _fallback_layout_v7(seed_value, index) if revision >= 7 else _fallback_layout(count, FIGHT_COUNTS[index] - 1)
			# Placement mutates the layout, so release builds must execute it
			# independently of the debug-only assertion.
			var fallback_placed: bool = Specials.place(layout, rng, count, Bosses.element_for_boss(boss_id))
			assert(fallback_placed, "Revision 6 fallback must place enabled special encounters")
		var entry: Vector2i = Vector2i.ZERO if index == 0 else Vector2i(-index * 4, 0)
		var boss := Vector2i((index + 1) * 4, 0)
		var lanes: int = int(layout.get("lane_count", 5 if revision >= 5 else 4))
		var lane_doors: bool = str(layout.get("door_mode", "")) == "lane"
		var info: Dictionary = {"index": index, "boss_id": boss_id, "title": Bosses.room_name_for_boss(boss_id), "entry": entry, "boss": boss, "room_count": count, "fight_count": FIGHT_COUNTS[index], "scouts": 2, "entered": false, "lane_count": lanes, "walks": layout["walks"]}
		# Revision 7 sections are wider than the screen and scroll sideways.
		if revision >= 7: info["scroll"] = true
		sections.append(info)
		rooms[key(entry)] = _node(entry, index, 0, 1, index * 4, "start", "none")
		rooms[key(entry)]["map_lane"] = float(lanes - 1) * 0.5
		var bands: Dictionary = _depth_bands(layout["rows"], index, count)
		info["depth_bands"] = bands
		var slots: Dictionary = {}
		var ids: Dictionary = {}
		var guardians: Array[Vector2i] = []
		for cell: Vector2i in layout["order"]:
			var depth: int = index * 4 + int(bands[cell.x])
			var slot: int = int(slots.get(depth, 0))
			assert(slot < 8 * depth, "Section map depth ring capacity exceeded")
			slots[depth] = slot + 1
			var coord: Vector2i = _ring_coord(depth, slot)
			ids[cell] = coord
			var data: Dictionary = layout["nodes"][cell]
			var type: String = data["type"]
			var node: Dictionary = _node(coord, index, cell.x, cell.y, depth, type, "none")
			_apply_type_fields(node, type, data.get("combat_element", "fire"))
			if type == "special":
				node.merge({"special_type": data["special_type"], "special_variant": data["special_variant"], "map_landmark": true}, true)
			if type == "mystery":
				node["mystery_type"] = data["mystery_type"]
				node["mystery_element"] = data["combat_element"]
			if type == "guardian":
				var guardian: Dictionary = Guardians.for_boss(boss_id)
				node.merge({"element": guardian["element"], "boss_id": boss_id, "guardian_id": guardian["id"], "guardian_relic": guardian["relic"], "map_landmark": true}, true)
				guardians.append(coord)
			if index == 5 and cell.x in [ceili(count / 2.0), count - 1]: node["map_landmark"] = true
			rooms[key(coord)] = node
		info["guardians"] = guardians
		info["guardian"] = guardians[0]
		var firsts: Array[Vector2i] = []
		for lane: int in layout["rows"][1]: firsts.append(ids[Vector2i(1, lane)])
		if lane_doors: _link_by_lane(rooms, entry, firsts)
		else: _link(rooms, entry, firsts)
		for cell: Vector2i in layout["order"]:
			var destinations: Array[Vector2i] = []
			for target: Vector2i in layout["children"].get(cell, []): destinations.append(ids[target])
			if cell.x == count - 1: destinations.append(boss)
			if lane_doors: _link_by_lane(rooms, ids[cell], destinations)
			else: _link(rooms, ids[cell], destinations)
		var boss_room: Dictionary = _node(boss, index, count, 1, (index + 1) * 4, "boss", Bosses.element_for_boss(boss_id))
		boss_room["map_lane"] = float(lanes - 1) * 0.5
		boss_room["boss_id"] = boss_id
		rooms[key(boss)] = boss_room
		if index > 0: _link(rooms, Vector2i(index * 4, 0), _coords([entry]))
		if revision >= 5 and diagnostics.get("enabled", false):
			section_diagnostics["generation_usec"] = Time.get_ticks_usec() - section_started
			if not diagnostics.has("sections"): diagnostics["sections"] = []
			diagnostics["sections"].append(section_diagnostics)
	state["section_map_version"] = VERSION
	state["section_map_layout_revision"] = revision
	state["map_sections"] = sections
	state["rooms"] = rooms
	rooms[key(Vector2i.ZERO)].merge({"visited": true, "revealed": true, "map_outline": true}, true)
	refresh_knowledge(state)

static func _weighted_roll(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: int = 0
	for weight: int in weights.values(): total += weight
	var roll: int = rng.randi_range(1, total)
	for type: String in weights:
		roll -= int(weights[type])
		if roll <= 0: return type
	return str(weights.keys()[0])

# Revision 5 generates structure independently of encounter assignment. Structural
# samples are rejected before invoking the solver. Exhausted structural batches
# and failed or budget-exhausted assignments advance the outer 50-attempt limit.
# Every use of the canned topology is logged.
const V5_LANE_COUNT: int = 5
const V5_WALK_COUNT: int = 6
const V5_MOVE_WEIGHTS: Array[int] = [30, 40, 30]
const V5_STRUCTURAL_PROPOSALS: int = TOPOLOGY_ATTEMPTS
# Count work, never elapsed time: retries and accepted graphs are seed-stable.
# Calibrated by tools/section_map_performance.gd, including the New Game hang.
const V5_TYPE_NODE_BUDGET: int = 40
const V5_TYPE_BITS: Dictionary = {"combat": 1, "mystery": 2, "guardian": 4, "scavenger": 8, "graftwright": 16, "event": 32, "treasure": 64, "campfire": 128}

static func _section_layout_v5(rng: RandomNumberGenerator, seed_value: int, index: int, diagnostics: Dictionary = {}, depth_state: Dictionary = {}, structure_check: Callable = Callable(), type_node_budget: int = V5_TYPE_NODE_BUDGET) -> Dictionary:
	var count: int = ROOM_COUNTS[index]
	for attempt: int in range(SECTION_ATTEMPTS):
		var layout: Dictionary = _walk_layout_v5(rng, count, diagnostics, structure_check)
		if layout.is_empty(): continue
		if _assign_types_v5(layout, rng, seed_value, index, count, diagnostics, depth_state, type_node_budget): return layout
	_diagnostic_v5(diagnostics, "fallback")
	print("SECTION MAP V5 FALLBACK seed=%d section=%d after %d topology attempts" % [seed_value, index + 1, SECTION_ATTEMPTS])
	return _fallback_layout(count, FIGHT_COUNTS[index] - 1)

# Room types for an accepted topology (revisions 5-7 share the solver and its rules).
static func _assign_types_v5(layout: Dictionary, rng: RandomNumberGenerator, seed_value: int, index: int, count: int, diagnostics: Dictionary, depth_state: Dictionary, type_node_budget: int) -> bool:
	_prepare_types(layout, seed_value, index, count)
	var domains: Array = []
	layout["positions"] = {}
	for cell: Vector2i in layout["order"]:
		layout["positions"][cell] = domains.size()
		var candidates: Array[String]
		if bool(layout["nodes"][cell]["fixed"]): candidates.append(layout["nodes"][cell]["type"])
		else:
			var weights: Dictionary = TYPE_WEIGHTS.duplicate()
			weights["guardian"] = DepthRules.guardian_weight(depth_state, int(weights["guardian"]))
			while not weights.is_empty():
				var type: String = _weighted_roll(rng, weights)
				candidates.append(type)
				weights.erase(type)
		domains.append(candidates)
	var search: Dictionary = {"remaining": type_node_budget, "failed": {}}
	var started: int = Time.get_ticks_usec()
	var solved: bool = _solve_types_v5(layout, domains, count, FIGHT_COUNTS[index] - 1, search)
	_diagnostic_v5(diagnostics, "solver_nodes", int(layout.get("solver_nodes", 0)))
	_diagnostic_v5(diagnostics, "solver_memo_hits", int(search.get("memo_hits", 0)))
	if diagnostics.get("enabled", false):
		diagnostics["max_attempt_nodes"] = maxi(int(diagnostics.get("max_attempt_nodes", 0)), int(layout.get("solver_nodes", 0)))
		diagnostics["max_attempt_usec"] = maxi(int(diagnostics.get("max_attempt_usec", 0)), Time.get_ticks_usec() - started)
	if solved: return true
	_diagnostic_v5(diagnostics, "solver_budget_exhausted" if search.get("exhausted", false) else "solver_unsatisfiable")
	return false

# Revision 7 (map-03): a branching web instead of walks, so routes split and
# rejoin the way the genre's maps do. Seven lanes. Each room's doors face the lane
# they lead to (up, right or down), so a path can never turn straight back
# through the wall it entered by. Every route meets a real choice at least three
# times, never more than two rooms apart; the single doors that gather paths into
# the Relic and Ember Hearth rows stretch a gap to three at most. With this many
# choices a route may run two fights under the section's target (one over at most),
# so a quieter path is itself a choice. Director-tuned values (owner-approved
# mockup, 2026-10-21; reference model spec/peer_benchmark/staged/map-03/).
const V7_LANE_COUNT: int = 7
const V7_START_LANE: int = 3
const V7_EXIT_WEIGHTS: Array = [32, 58, 10] # one, two or three exits
const V7_MERGE_PERCENT: int = 45
const V7_FORCED_MERGE_PERCENT: int = 75
const V7_MAX_WIDTH: int = 6
const V7_FORCED_MAX_WIDTH: int = 4
const V7_MAX_RUN: int = 2
const V7_MIN_CHOICES: int = 3
const V7_ROW_TRIES: int = 24
const V7_STRUCTURAL_PROPOSALS: int = 400
const V7_TYPE_NODE_BUDGET: int = 64
const V7_FIGHT_SLACK: int = 2 # a route may run two fights under the section target
const V7_FORBID_UP: int = 1
const V7_FORBID_DOWN: int = 2

static func _section_layout_v7(rng: RandomNumberGenerator, seed_value: int, index: int, diagnostics: Dictionary = {}, depth_state: Dictionary = {}) -> Dictionary:
	var count: int = ROOM_COUNTS[index]
	# Tests force the fallback through the diagnostics hook.
	if not diagnostics.get("force_fallback", false):
		for attempt: int in range(SECTION_ATTEMPTS):
			var layout: Dictionary = _web_layout_v7(rng, index, count, diagnostics)
			if layout.is_empty(): continue
			if _assign_types_v5(layout, rng, seed_value, index, count, diagnostics, depth_state, V7_TYPE_NODE_BUDGET): return layout
	_diagnostic_v5(diagnostics, "fallback")
	print("SECTION MAP V7 FALLBACK seed=%d section=%d after %d topology attempts" % [seed_value, index + 1, SECTION_ATTEMPTS])
	return _fallback_layout_v7(seed_value, index)

# One prevalidated revision-7 section per index, for exhausted generation or
# special placement. tools/section_map_v7_fallbacks.gd regenerates the data;
# section_map_v7_suite checks every map rule and every boss element's placement.
const V7_FALLBACK_PATH: String = "res://data/section_map_v7_fallbacks.json"

static func _fallback_layout_v7(seed_value: int, index: int) -> Dictionary:
	var count: int = ROOM_COUNTS[index]
	var stored: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(V7_FALLBACK_PATH)) as Dictionary)[str(index)]
	var rows: Dictionary = {}
	for step: String in stored["rows"]:
		var lanes: Array = []
		for lane: Variant in stored["rows"][step]: lanes.append(int(lane))
		rows[int(step)] = lanes
	var children: Dictionary = {}
	for cell: String in stored["children"]:
		var targets: Array = []
		for target: String in stored["children"][cell]: targets.append(_fallback_cell(target))
		children[_fallback_cell(cell)] = targets
	var layout: Dictionary = _layout_from_children_v7(rows, children, count)
	_prepare_types(layout, seed_value, index, count)
	layout["positions"] = {}
	for cell: Vector2i in layout["order"]:
		layout["positions"][cell] = (layout["positions"] as Dictionary).size()
		var node: Dictionary = layout["nodes"][cell]
		var cell_key: String = "%d,%d" % [cell.x, cell.y]
		if not bool(node["fixed"]): node["type"] = str(stored["types"][cell_key])
		# Stored hidden types keep the section legal for every run seed.
		if stored["mystery_types"].has(cell_key): node["mystery_type"] = str(stored["mystery_types"][cell_key])
		_prefix_bounds(layout, cell)
	assert(_complete_types_legal(layout, count, FIGHT_COUNTS[index] - 1), "Stored revision-7 fallback is legal")
	return layout

static func _fallback_cell(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func _web_layout_v7(rng: RandomNumberGenerator, index: int, count: int, diagnostics: Dictionary = {}) -> Dictionary:
	var mid: int = ceili(count / 2.0)
	for proposal: int in range(V7_STRUCTURAL_PROPOSALS):
		_diagnostic_v5(diagnostics, "structural_samples")
		# The threshold fans out up, right and down, so its three doors differ.
		var top: int = rng.randi_range(0, 1)
		var bottom: int = rng.randi_range(5, 6)
		var rows: Dictionary = {1: [top, V7_START_LANE, bottom]}
		var forbid: Dictionary = {Vector2i(1, top): V7_FORBID_DOWN, Vector2i(1, V7_START_LANE): 0, Vector2i(1, bottom): V7_FORBID_UP}
		var run_in: Dictionary = {}
		var choices_in: Dictionary = {}
		for lane: int in rows[1]:
			run_in[Vector2i(1, lane)] = 0
			choices_in[Vector2i(1, lane)] = 0
		var children: Dictionary = {}
		var legal: bool = true
		for step: int in range(1, count - 1):
			var forced: bool = step + 1 in [mid, count - 1]
			var eligible_left: int = 0
			for later: int in range(step, count - 1):
				if later + 1 not in [mid, count - 1]: eligible_left += 1
			var row: Dictionary = {}
			for row_try: int in range(V7_ROW_TRIES):
				_diagnostic_v5(diagnostics, "row_samples")
				row = _web_row_v7(rng, step, rows[step], forbid, run_in, choices_in, forced, eligible_left, int(step + 2 in [mid, count - 1]))
				if not row.is_empty(): break
			if row.is_empty():
				legal = false
				break
			var next_lanes: Array = []
			for cell: Vector2i in row["children"]:
				children[cell] = row["children"][cell]
				var meta: Vector2i = row["meta"][cell]
				for target: Vector2i in children[cell]:
					if not run_in.has(target):
						next_lanes.append(target.y)
						forbid[target] = 0
						run_in[target] = meta.x
						choices_in[target] = meta.y
					else:
						run_in[target] = maxi(int(run_in[target]), meta.x)
						choices_in[target] = mini(int(choices_in[target]), meta.y)
					# Entered from below (the path rose a lane): no door back down.
					if target.y < cell.y: forbid[target] = int(forbid[target]) | V7_FORBID_DOWN
					elif target.y > cell.y: forbid[target] = int(forbid[target]) | V7_FORBID_UP
			next_lanes.sort()
			rows[step + 1] = next_lanes
		if not legal: continue
		var fewest: int = 999
		for lane: int in rows[count - 1]: fewest = mini(fewest, int(choices_in[Vector2i(count - 1, lane)]))
		if fewest < V7_MIN_CHOICES: continue
		var repeated: int = 1
		var monotone: bool = false
		for step: int in range(2, count):
			repeated = repeated + 1 if rows[step] == rows[step - 1] else 1
			monotone = monotone or repeated > 2
		if monotone or _depth_bands_or_empty(rows, index, count).is_empty(): continue
		return _layout_from_children_v7(rows, children, count)
	_diagnostic_v5(diagnostics, "structural_exhausted")
	return {}

# One row of exits, top lane first. Children form contiguous lane ranges that
# never cross; a room may share its first exit with the room above (a merge).
static func _web_row_v7(rng: RandomNumberGenerator, step: int, lanes: Array, forbid: Dictionary, run_in: Dictionary, choices_in: Dictionary, forced: bool, eligible_left: int, gather_ahead: int) -> Dictionary:
	var row_children: Dictionary = {}
	var meta: Dictionary = {}
	var previous_max: int = -1
	var width: Dictionary = {}
	for lane: int in lanes:
		var cell := Vector2i(step, lane)
		var allowed: Array[int]
		for target: int in [lane - 1, lane, lane + 1]:
			if target < 0 or target >= V7_LANE_COUNT or target < previous_max: continue
			if target < lane and int(forbid[cell]) & V7_FORBID_UP: continue
			if target > lane and int(forbid[cell]) & V7_FORBID_DOWN: continue
			allowed.append(target)
		if allowed.is_empty(): return {}
		var run: int = int(run_in[cell])
		var need_fork: bool = not forced and (run >= V7_MAX_RUN or run + gather_ahead > V7_MAX_RUN or (int(choices_in[cell]) < V7_MIN_CHOICES and int(choices_in[cell]) + eligible_left <= V7_MIN_CHOICES))
		var exits: int = 1 if forced else _weighted_index_v7(rng, V7_EXIT_WEIGHTS) + 1
		if need_fork: exits = maxi(exits, 2)
		exits = mini(exits, allowed.size())
		if need_fork and exits < 2: return {}
		var merge: int = V7_FORCED_MERGE_PERCENT if forced else V7_MERGE_PERCENT
		var first: int = 0
		if not (allowed.has(previous_max) and rng.randi_range(0, 99) < merge):
			first = rng.randi_range(0, allowed.size() - exits)
			if allowed.has(previous_max) and first == 0 and allowed.size() > exits: first = 1
		var targets: Array[Vector2i]
		for offset: int in range(first, first + exits):
			targets.append(Vector2i(step + 1, allowed[offset]))
			width[allowed[offset]] = true
		row_children[cell] = targets
		previous_max = allowed[first + exits - 1]
		var fork: bool = exits >= 2
		meta[cell] = Vector2i(0 if fork else run + 1, int(choices_in[cell]) + int(fork))
	if width.size() < 2 or width.size() > (V7_FORCED_MAX_WIDTH if forced else V7_MAX_WIDTH): return {}
	return {"children": row_children, "meta": meta}

static func _weighted_index_v7(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: int = 0
	for weight: int in weights: total += weight
	var roll: int = rng.randi_range(0, total - 1)
	for index: int in range(weights.size()):
		if roll < weights[index]: return index
		roll -= weights[index]
	return weights.size() - 1

static func _layout_from_children_v7(rows: Dictionary, children: Dictionary, count: int) -> Dictionary:
	var parents: Dictionary = {}
	var order: Array[Vector2i]
	for step: int in range(1, count):
		for lane: int in rows[step]: order.append(Vector2i(step, lane))
	for cell: Vector2i in children:
		(children[cell] as Array).sort()
		for target: Vector2i in children[cell]:
			if not parents.has(target): parents[target] = []
			parents[target].append(cell)
	return {"rows": rows, "children": children, "parents": parents, "order": order, "walks": [], "nodes": {}, "door_mode": "lane", "lane_count": V7_LANE_COUNT, "fight_slack": V7_FIGHT_SLACK}

# Revision 7 doors face the destination's lane; the boss and the next section's
# threshold always sit straight ahead.
static func _link_by_lane(rooms: Dictionary, source: Vector2i, destinations: Array[Vector2i]) -> void:
	var origin: Dictionary = rooms[key(source)]
	var lane: float = float(origin.get("map_lane", 0))
	var links: Array[Dictionary]
	for destination: Vector2i in destinations:
		var target: Dictionary = rooms.get(key(destination), {}) as Dictionary
		var direction: Vector2i = Vector2i.RIGHT
		if not target.is_empty() and str(target.get("type", "")) != "boss" and int(target.get("section_index", -1)) == int(origin.get("section_index", -2)):
			var delta: float = float(target.get("map_lane", lane)) - lane
			direction = Vector2i.UP if delta < 0.0 else (Vector2i.DOWN if delta > 0.0 else Vector2i.RIGHT)
		links.append({"coord": destination, "door_dir": direction, "kind": "outward"})
	origin["connections"] = links

static func _diagnostic_v5(diagnostics: Dictionary, reason: String, amount: int = 1) -> void:
	if diagnostics.get("enabled", false): diagnostics[reason] = int(diagnostics.get(reason, 0)) + amount

# The optional check lets the headless regression force rejection without
# changing the production validator or any generated encounter data.
static func _walk_layout_v5(rng: RandomNumberGenerator, count: int, diagnostics: Dictionary = {}, structure_check: Callable = Callable()) -> Dictionary:
	for proposal: int in range(V5_STRUCTURAL_PROPOSALS):
		_diagnostic_v5(diagnostics, "structural_samples")
		var openings: Array[int] = []
		var available: Array[int] = []
		available.assign([0, 1, 2, 3, 4])
		for offset: int in range(OPENING_CHILD_COUNT): openings.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
		var walks: Array = []
		var edges: Dictionary = {}
		var masks: Array[int] = []
		masks.resize(count)
		var rejected: bool = false
		for walk_index: int in range(V5_WALK_COUNT):
			var lane: int = openings[walk_index] if walk_index < OPENING_CHILD_COUNT else openings[rng.randi_range(0, OPENING_CHILD_COUNT - 1)]
			var walk: Array[int] = []
			walk.append(lane)
			masks[1] |= 1 << lane
			for step: int in range(1, count - 1):
				var moves: Dictionary = {}
				var fixed_destination: int = -1
				if step + 1 in [ceili(count / 2.0), count - 1] or (step == 1 and lane in [openings.min(), openings.max()]):
					for existing: Vector2i in edges.get(step, []):
						if existing.x == lane: fixed_destination = existing.y
				for delta: int in range(-1, 2):
					var target: int = clampi(lane + delta, 0, V5_LANE_COUNT - 1)
					if fixed_destination >= 0 and target != fixed_destination: continue
					var crossing: bool = false
					for edge: Vector2i in edges.get(step, []): crossing = crossing or (lane - edge.x) * (target - edge.y) < 0
					if not crossing: moves[str(target)] = int(moves.get(str(target), 0)) + V5_MOVE_WEIGHTS[delta + 1]
				var next_lane: int = lane if moves.is_empty() else int(_weighted_roll(rng, moves))
				if not edges.has(step): edges[step] = []
				# Fixed rows and the entry's outer physical thresholds each permit
				# only one onward edge. Reuse it as a structural legal-move rule.
				var edge := Vector2i(lane, next_lane)
				if not edges[step].has(edge): edges[step].append(edge)
				walk.append(next_lane)
				masks[step + 1] |= 1 << next_lane
				lane = next_lane
			walks.append(walk)
		var wide: bool = false
		var repeated: int = 0
		for step: int in range(1, count):
			var width: int = 0
			for lane: int in range(V5_LANE_COUNT): width += int((masks[step] & (1 << lane)) != 0)
			if width < 2: rejected = true
			wide = wide or width >= 4
			repeated = repeated + 1 if step > 1 and masks[step] == masks[step - 1] else 1
			if repeated > 3: rejected = true
		if rejected or not wide: continue
		var layout: Dictionary = _layout_from_walks(walks, count)
		var legal: bool = bool(structure_check.call(layout, count)) if structure_check.is_valid() else _structure_legal_v5(layout, count)
		if legal: return layout
	_diagnostic_v5(diagnostics, "structural_exhausted")
	return {}

static func _structure_legal_v5(layout: Dictionary, count: int) -> bool:
	var wide: bool = false
	var previous: Array = []
	var repeated: int = 0
	for step: int in range(1, count):
		var row: Array = layout["rows"][step]
		if row.size() < 2 or row.size() > V5_LANE_COUNT: return false
		wide = wide or row.size() >= 4
		repeated = repeated + 1 if row == previous else 1
		if repeated > 3: return false
		previous = row
	if not wide: return false
	for children: Array in layout["children"].values():
		if children.size() >= 2 and int(children[0].x) in [ceili(count / 2.0), count - 1]: return false
	if not _physical_doors_legal(layout): return false
	return _long_divergence_v5(layout)

static func _long_divergence_v5(layout: Dictionary) -> bool:
	# A pair of generating walks witnesses divergence when possible. The walks
	# cover every edge, so dynamic programming also includes their recombinations.
	var pairs: Dictionary = {}
	for a: int in layout["rows"][1]:
		for b: int in layout["rows"][1]: pairs[Vector2i(a, b)] = int(a != b)
	for step: int in range(1, layout["rows"].size()):
		var next: Dictionary = {}
		for pair: Vector2i in pairs:
			for a: Vector2i in layout["children"].get(Vector2i(step, pair.x), []):
				for b: Vector2i in layout["children"].get(Vector2i(step, pair.y), []):
					var length: int = int(pairs[pair]) + 1 if a != b else 0
					if length >= 4: return true
					var lanes := Vector2i(a.y, b.y)
					next[lanes] = maxi(int(next.get(lanes, 0)), length)
		pairs = next
	return false

# Each branch narrows one most-constrained domain. The old cardinality-witness
# search decided unrelated rooms first and could spend hundreds of thousands of
# nodes discovering the same incompatible fork/route requirements. Section and
# route forward checks now run before every decision; failed propagated states
# are canonicalised independently of candidate preference order.
static func _solve_types_v5(layout: Dictionary, domains: Array, count: int, fights: int, search: Dictionary) -> bool:
	if int(search["remaining"]) <= 0:
		search["exhausted"] = true
		return false
	search["remaining"] = int(search["remaining"]) - 1
	layout["solver_nodes"] = int(layout.get("solver_nodes", 0)) + 1
	var signature: String = _type_signature_v5(domains)
	if search["failed"].has(signature):
		search["memo_hits"] = int(search.get("memo_hits", 0)) + 1
		return false
	if not _propagate_types_v5(layout, domains, count, fights):
		search["failed"][signature] = true
		return false
	var propagated_signature: String = _type_signature_v5(domains)
	if search["failed"].has(propagated_signature):
		search["memo_hits"] = int(search.get("memo_hits", 0)) + 1
		return false
	var choice: int = -1
	var degree: int = -1
	for offset: int in range(domains.size()):
		if domains[offset].size() <= 1: continue
		var cell: Vector2i = layout["order"][offset]
		var constraints: int = layout["parents"].get(cell, []).size() + layout["children"].get(cell, []).size()
		for parent: Vector2i in layout["parents"].get(cell, []): constraints += layout["children"][parent].size() - 1
		if choice < 0 or domains[offset].size() < domains[choice].size() or (domains[offset].size() == domains[choice].size() and constraints > degree):
			choice = offset
			degree = constraints
	if choice < 0:
		for offset: int in range(domains.size()):
			var cell: Vector2i = layout["order"][offset]
			layout["nodes"][cell]["type"] = domains[offset][0]
			_prefix_bounds(layout, cell)
		if _complete_types_legal(layout, count, fights): return true
		search["failed"][signature] = true
		search["failed"][propagated_signature] = true
		return false
	# Branch directly on the seeded type preference. With MRV and fork matching,
	# a separate fight-membership decision adds work to every successful room.
	for type: String in domains[choice]:
		var branch: Array = domains.duplicate(true)
		branch[choice] = [type]
		if _solve_types_v5(layout, branch, count, fights, search): return true
		# A cutoff is not a proof of failure and must never enter the memo table.
		if search.get("exhausted", false): return false
	search["failed"][signature] = true
	search["failed"][propagated_signature] = true
	return false

static func _type_signature_v5(domains: Array) -> String:
	var masks: PackedByteArray = PackedByteArray()
	for domain: Array in domains:
		var mask: int = 0
		for type: String in domain: mask |= int(V5_TYPE_BITS[type])
		masks.append(mask)
	return masks.hex_encode()

static func _propagate_types_v5(layout: Dictionary, domains: Array, count: int, fights: int) -> bool:
	var changed: bool = true
	while changed:
		changed = false
		var contributions: Dictionary = {}
		for offset: int in range(domains.size()):
			var cell: Vector2i = layout["order"][offset]
			var values: Array[int] = []
			values.assign([1, 0, 1, 0])
			for type: String in domains[offset]:
				var fight: int = int(type in ["combat", "guardian"] or (type == "mystery" and layout["nodes"][cell]["mystery_type"] == "combat"))
				var service: int = int(type in ["scavenger", "graftwright", "event"] or (type == "mystery" and layout["nodes"][cell]["mystery_type"] != "combat"))
				values[0] = mini(values[0], fight)
				values[1] = maxi(values[1], fight)
				values[2] = mini(values[2], int(type == "guardian"))
				values[3] = maxi(values[3], service)
			contributions[cell] = values
		var before: Dictionary = _route_bounds_v5(layout, contributions, false)
		var after: Dictionary = _route_bounds_v5(layout, contributions, true)
		for offset: int in range(domains.size()):
			var cell: Vector2i = layout["order"][offset]
			var candidates: Array = domains[offset]
			var legal: Array[String] = []
			for type: String in candidates:
				if type == "guardian" and (cell.x < 3 or cell.x > count - 3): continue
				if type == "scavenger" and cell.x < 3: continue
				if type == "graftwright" and int(before[cell][0]) < 3: continue
				var fight: int = int(type in ["combat", "guardian"] or (type == "mystery" and layout["nodes"][cell]["mystery_type"] == "combat"))
				var service: int = int(type in ["scavenger", "graftwright", "event"] or (type == "mystery" and layout["nodes"][cell]["mystery_type"] != "combat"))
				if int(before[cell][0]) + fight + int(after[cell][0]) < fights - int(layout.get("fight_slack", 1)): continue
				if int(before[cell][1]) + fight + int(after[cell][1]) > fights + 1: continue
				if int(before[cell][2]) + int(type == "guardian") + int(after[cell][2]) > 1: continue
				if int(before[cell][3]) + service + int(after[cell][3]) < 1: continue
				if not _local_type_possible_v5(layout, domains, cell, type): continue
				legal.append(type)
			domains[offset] = legal
			if legal.is_empty(): return false
			changed = changed or legal.size() < candidates.size()
		if not _fork_types_possible_v5(layout, domains): return false
		var cardinalities: Dictionary = _section_counts_v5(domains)
		if not cardinalities["possible"]: return false
		for offset: int in cardinalities["forced"]:
			changed = changed or domains[offset].size() != 1
			domains[offset] = [cardinalities["forced"][offset]]
	# The candidate checks above propagate to a fixed point. Check the global
	# route/bypass bounds once there, rather than rebuilding a third DAG pass
	# at each intermediate narrowing of exactly the same domains.
	return _types_possible_v5(layout, domains, count, fights)

static func _fork_types_possible_v5(layout: Dictionary, domains: Array) -> bool:
	# Hall's condition detects a fork with too few distinct remaining colours,
	# even before any child is assigned. At a three-way fork each Combat slot
	# gets a separate bit, preserving the explicit repeat exception.
	for children: Array in layout["children"].values():
		if children.size() < 2: continue
		if children.size() == 2:
			var first: Array = domains[layout["positions"][children[0]]]
			var second: Array = domains[layout["positions"][children[1]]]
			if first.is_empty() or second.is_empty() or (first.size() == 1 and first == second): return false
			continue
		var masks: Array[int]
		for offset: int in range(children.size()):
			var mask: int = 0
			for type: String in domains[layout["positions"][children[offset]]]:
				var bit: int = int(V5_TYPE_BITS[type])
				if type == "combat" and children.size() == 3: bit = 1 << (8 + offset)
				mask |= bit
			if mask == 0: return false
			masks.append(mask)
		for subset: int in range(1, 1 << children.size()):
			if (subset & (subset - 1)) == 0: continue
			var union: int = 0
			var needed: int = 0
			for offset: int in range(children.size()):
				if subset & (1 << offset):
					union |= masks[offset]
					needed += 1
			while union > 0:
				union &= union - 1
				needed -= 1
			if needed > 0: return false
	return true

# Counts include both mandatory and still-possible witnesses. When all remaining
# slots are needed, force them now, before branching on any unrelated room.
static func _section_counts_v5(domains: Array) -> Dictionary:
	var forced: Dictionary = {}
	for required: String in ["guardian", "scavenger"]:
		var assigned: int = 0
		var slots: Array[int]
		for offset: int in range(domains.size()):
			if not domains[offset].has(required): continue
			if domains[offset].size() == 1: assigned += 1
			else: slots.append(offset)
		var needed: int = (2 if required == "guardian" else 1) - assigned
		if slots.size() < needed: return {"possible": false}
		if needed > 0 and slots.size() == needed:
			for offset: int in slots:
				if forced.has(offset) and forced[offset] != required: return {"possible": false}
				forced[offset] = required
	return {"possible": true, "forced": forced}

static func _local_type_possible_v5(layout: Dictionary, domains: Array, cell: Vector2i, type: String) -> bool:
	if type in ["guardian", "scavenger", "graftwright", "campfire", "treasure"]:
		for neighbor: Vector2i in layout["parents"].get(cell, []) + layout["children"].get(cell, []):
			var domain: Array = domains[layout["positions"][neighbor]]
			if domain.size() == 1 and domain[0] == type: return false
	for parent: Vector2i in layout["parents"].get(cell, []):
		var siblings: Array = layout["children"][parent]
		if type == "combat" and siblings.size() == 3: continue
		for sibling: Vector2i in siblings:
			if sibling == cell: continue
			var domain: Array = domains[layout["positions"][sibling]]
			if domain.size() == 1 and domain[0] == type: return false
	return true

static func _route_bounds_v5(layout: Dictionary, contributions: Dictionary, reverse: bool) -> Dictionary:
	var result: Dictionary = {}
	var totals: Dictionary = {}
	var order: Array = layout["order"].duplicate()
	if reverse: order.reverse()
	for cell: Vector2i in order:
		var neighbors: Array = layout["children" if reverse else "parents"].get(cell, [])
		var values: Array[int] = []
		values.assign([999, 0, 0, 999])
		for neighbor: Vector2i in neighbors:
			values[0] = mini(values[0], totals[neighbor][0])
			values[1] = maxi(values[1], totals[neighbor][1])
			values[2] = maxi(values[2], totals[neighbor][2])
			values[3] = mini(values[3], totals[neighbor][3])
		if neighbors.is_empty(): values.assign([0, 0, 0, 0])
		result[cell] = values
		totals[cell] = [values[0] + contributions[cell][1], values[1] + contributions[cell][0], values[2] + contributions[cell][2], values[3] + contributions[cell][3]]
	return result

static func _types_possible_v5(layout: Dictionary, domains: Array, count: int, fights: int) -> bool:
	# For partial assignments, propagate both extremal bounds over EVERY route.
	# A minimum of possible maxima and maximum of mandatory minima prove a
	# contradiction without enumerating routes or exhausting an arbitrary budget.
	var bounds: Dictionary = {}
	var guardian_slots: int = 0
	var scavenger_slots: int = 0
	var bypass: bool = false
	for offset: int in range(domains.size()):
		var cell: Vector2i = layout["order"][offset]
		var domain: Array = domains[offset]
		var node: Dictionary = layout["nodes"][cell]
		var min_fight: int = 1
		var max_fight: int = 0
		var min_guardian: int = 1
		var max_service: int = 0
		for type: String in domain:
			if type == "guardian" and (cell.x < 3 or cell.x > count - 3):
				if domain.size() == 1: return false
				continue
			if type == "scavenger" and cell.x < 3:
				if domain.size() == 1: return false
				continue
			var is_fight: bool = type in ["combat", "guardian"] or (type == "mystery" and node["mystery_type"] == "combat")
			min_fight = mini(min_fight, int(is_fight))
			max_fight = maxi(max_fight, int(is_fight))
			min_guardian = mini(min_guardian, int(type == "guardian"))
			max_service = maxi(max_service, int(type in ["scavenger", "graftwright", "event"] or (type == "mystery" and node["mystery_type"] != "combat")))
		guardian_slots += int(domain.has("guardian") and cell.x >= 3 and cell.x <= count - 3)
		scavenger_slots += int(domain.has("scavenger") and cell.x >= 3)
		var upper_min: int = 999
		var lower_max: int = 0
		var guardian_max: int = 0
		var guardian_min: int = 999
		var service_min: int = 999
		var parents: Array = layout["parents"].get(cell, [])
		for parent: Vector2i in parents:
			var prefix: Array = bounds[parent]
			upper_min = mini(upper_min, prefix[0])
			lower_max = maxi(lower_max, prefix[1])
			guardian_max = maxi(guardian_max, prefix[2])
			guardian_min = mini(guardian_min, prefix[3])
			service_min = mini(service_min, prefix[4])
			var parent_domain: Array = domains[layout["positions"][parent]]
			if domain.size() == 1 and parent_domain.size() == 1 and domain[0] in ["guardian", "scavenger", "graftwright", "campfire", "treasure"] and domain[0] == parent_domain[0]: return false
		if parents.is_empty():
			upper_min = 0
			guardian_min = 0
			service_min = 0
		if domain.size() == 1 and domain[0] == "graftwright" and upper_min < 3: return false
		var current: Array = [upper_min + max_fight, lower_max + min_fight, guardian_max + min_guardian, guardian_min + min_guardian, service_min + max_service]
		bounds[cell] = current
		if int(current[2]) > 1 or int(current[1]) > fights + 1: return false
		if cell.x == count - 1:
			if int(current[0]) < fights - int(layout.get("fight_slack", 1)) or int(current[4]) < 1: return false
			bypass = bypass or int(current[3]) == 0
		var children: Array = layout["children"].get(cell, [])
		var assigned: Dictionary = {}
		for child: Vector2i in children:
			var child_domain: Array = domains[layout["positions"][child]]
			if child_domain.size() != 1: continue
			var type: String = child_domain[0]
			if assigned.has(type) and not (type == "combat" and children.size() == 3): return false
			assigned[type] = true
	return guardian_slots >= 2 and scavenger_slots >= 1 and bypass

static func _walk_layout(rng: RandomNumberGenerator, count: int) -> Dictionary:
	for attempt: int in range(TOPOLOGY_ATTEMPTS):
		var walks: Array = []
		var edges: Dictionary = {}
		for walk_index: int in range(WALK_COUNT):
			var lane: int = rng.randi_range(0, 3)
			if walk_index == 1:
				var alternatives: Array[int] = []
				for candidate: int in range(4):
					if candidate != int(walks[0][0]): alternatives.append(candidate)
				lane = alternatives[rng.randi_range(0, alternatives.size() - 1)]
			var walk: Array[int] = []
			walk.assign([lane])
			for step: int in range(1, count - 1):
				var moves: Array[int] = _walk_moves(lane, _coords(edges.get(step, [])))
				var next_lane: int = lane if moves.is_empty() else moves[rng.randi_range(0, moves.size() - 1)]
				if not edges.has(step): edges[step] = []
				var move := Vector2i(lane, next_lane)
				if not edges[step].has(move): edges[step].append(move)
				walk.append(next_lane)
				lane = next_lane
			walks.append(walk)
		var layout: Dictionary = _layout_from_walks(walks, count)
		var valid: bool = layout["rows"][1].size() == OPENING_CHILD_COUNT
		for row: Array in layout["rows"].values(): valid = valid and row.size() >= 2
		# Fixed rows cannot be repaired by changing their types. Reject a
		# topology that forks into them before spending the type-search budget.
		for children: Array in layout["children"].values():
			if children.size() >= 2 and int(children[0].x) in [ceili(count / 2.0), count - 1]: valid = false
		if valid and _physical_doors_legal(layout): return layout
	return _layout_from_walks(_fallback_walks(count), count)

static func _walk_moves(lane: int, edges: Array[Vector2i]) -> Array[int]:
	var moves: Array[int] = []
	# Roll uniformly among the three deltas, then clamp. At an outer lane,
	# two different deltas stay in that lane; do not deduplicate those rolls.
	for delta: int in range(-1, 2):
		var target: int = clampi(lane + delta, 0, 3)
		var crosses: bool = false
		for edge: Vector2i in edges: crosses = crosses or (lane - edge.x) * (target - edge.y) < 0
		if not crosses: moves.append(target)
	return moves

static func _door_directions(count: int) -> Array[Vector2i]:
	return _coords([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]) if count == 3 else (_coords([Vector2i.UP, Vector2i.DOWN]) if count == 2 else _coords([Vector2i.RIGHT]))

static func _physical_doors_legal(layout: Dictionary) -> bool:
	# A branch's physical door must not occupy its destination's incoming
	# threshold. Preserve the established direction/order mapping exactly.
	var firsts: Array = layout["rows"][1]
	var first_directions: Array[Vector2i] = _door_directions(firsts.size())
	for offset: int in range(firsts.size()):
		var cell := Vector2i(1, firsts[offset])
		if _door_directions(layout["children"].get(cell, []).size()).has(-first_directions[offset]): return false
	for source: Vector2i in layout["children"]:
		var children: Array = layout["children"][source]
		var directions: Array[Vector2i] = _door_directions(children.size())
		for offset: int in range(children.size()):
			var target: Vector2i = children[offset]
			if _door_directions(layout["children"].get(target, []).size()).has(-directions[offset]): return false
	return true

static func _layout_from_walks(walks: Array, count: int) -> Dictionary:
	var rows: Dictionary = {}
	var children: Dictionary = {}
	var parents: Dictionary = {}
	for walk: Array in walks:
		for step: int in range(1, count):
			var cell := Vector2i(step, walk[step - 1])
			if not rows.has(step): rows[step] = []
			if not rows[step].has(cell.y): rows[step].append(cell.y)
			if step == count - 1: continue
			var target := Vector2i(step + 1, walk[step])
			if not children.has(cell): children[cell] = []
			if not parents.has(target): parents[target] = []
			if not children[cell].has(target): children[cell].append(target)
			if not parents[target].has(cell): parents[target].append(cell)
	var order: Array[Vector2i] = []
	for step: int in range(1, count):
		rows[step].sort()
		for lane: int in rows[step]: order.append(Vector2i(step, lane))
	for targets: Array in children.values(): targets.sort()
	return {"rows": rows, "children": children, "parents": parents, "order": order, "walks": walks, "nodes": {}}

static func _prepare_types(layout: Dictionary, seed_value: int, index: int, count: int) -> void:
	for cell: Vector2i in layout["order"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_value * NODE_SEED_RUN_MULTIPLIER + index * NODE_SEED_SECTION_MULTIPLIER + cell.x * NODE_SEED_STEP_MULTIPLIER + cell.y * NODE_SEED_LANE_MULTIPLIER)
		var type: String = "combat" if cell.x == 1 else ("campfire" if cell.x == count - 1 else ("treasure" if cell.x == ceili(count / 2.0) else ""))
		layout["nodes"][cell] = {"type": type, "fixed": not type.is_empty(), "mystery_type": _weighted_roll(rng, MYSTERY_WEIGHTS), "combat_element": Elements.all_elements()[rng.randi_range(0, 4)]}

# Weighted first rolls, then weighted re-rolls of offending assignments. Prefix
# bounds summarize EVERY incoming route, including paths created by merges.
static func _repair_types(layout: Dictionary, rng: RandomNumberGenerator, count: int, fights: int, position: int, budget: Dictionary, depth_state: Dictionary = {}) -> bool:
	if int(budget["remaining"]) <= 0: return false
	if position == layout["order"].size(): return _complete_types_legal(layout, count, fights)
	var cell: Vector2i = layout["order"][position]
	var node: Dictionary = layout["nodes"][cell]
	var candidates: Array[String] = []
	if bool(node["fixed"]):
		candidates.append(node["type"])
	else:
		var weights: Dictionary = TYPE_WEIGHTS.duplicate()
		weights["guardian"] = DepthRules.guardian_weight(depth_state, int(weights["guardian"]))
		while not weights.is_empty():
			var type: String = _weighted_roll(rng, weights)
			candidates.append(type)
			weights.erase(type)
	for type: String in candidates:
		budget["remaining"] = int(budget["remaining"]) - 1
		node["type"] = type
		_prefix_bounds(layout, cell)
		if _prefix_type_legal(layout, cell, count, fights) and _repair_types(layout, rng, count, fights, position + 1, budget, depth_state): return true
		if int(budget["remaining"]) <= 0: break
	if not bool(node["fixed"]): node["type"] = ""
	return false

static func _is_fight(node: Dictionary) -> bool:
	return str(node["type"]) in ["combat", "special", "guardian"] or (str(node["type"]) == "mystery" and str(node["mystery_type"]) == "combat")

static func _is_service(node: Dictionary) -> bool:
	return str(node["type"]) in ["scavenger", "graftwright", "event"] or (str(node["type"]) == "mystery" and str(node["mystery_type"]) != "combat")

static func _prefix_bounds(layout: Dictionary, cell: Vector2i) -> void:
	var node: Dictionary = layout["nodes"][cell]
	for metric: String in ["fights", "guardians", "services"]:
		var low: int = 999
		var high: int = 0
		var parents: Array = layout["parents"].get(cell, [])
		for parent: Vector2i in parents:
			low = mini(low, int(layout["nodes"][parent]["min_" + metric]))
			high = maxi(high, int(layout["nodes"][parent]["max_" + metric]))
		if parents.is_empty(): low = 0
		var increment: int = int(_is_fight(node)) if metric == "fights" else (int(str(node["type"]) == "guardian") if metric == "guardians" else int(_is_service(node)))
		node["min_" + metric] = low + increment
		node["max_" + metric] = high + increment

static func _prefix_type_legal(layout: Dictionary, cell: Vector2i, count: int, fights: int) -> bool:
	var node: Dictionary = layout["nodes"][cell]
	var type: String = node["type"]
	if type == "guardian" and (cell.x < 3 or cell.x > count - 3): return false
	if type == "scavenger" and cell.x < 3: return false
	if type == "graftwright" and int(node["min_fights"]) < 3: return false
	if int(node["max_guardians"]) > 1 or int(node["max_fights"]) > fights + 1: return false
	var remaining_fights: int = 0
	for step: int in range(cell.x + 1, count - 1):
		if step != ceili(count / 2.0): remaining_fights += 1
	if int(node["min_fights"]) + remaining_fights < fights - int(layout.get("fight_slack", 1)): return false
	for parent: Vector2i in layout["parents"].get(cell, []):
		if type in ["guardian", "scavenger", "graftwright", "campfire", "treasure"] and str(layout["nodes"][parent]["type"]) == type: return false
		var siblings: Array = layout["children"][parent]
		if siblings.size() < 2: continue
		for sibling: Vector2i in siblings:
			if sibling == cell or sibling.y > cell.y: continue
			if str(layout["nodes"][sibling]["type"]) == type and not (type == "combat" and siblings.size() == 3): return false
	return true

static func _complete_types_legal(layout: Dictionary, count: int, fights: int) -> bool:
	var guardians: int = 0
	var scavengers: int = 0
	var bypass: bool = false
	for cell: Vector2i in layout["order"]:
		var node: Dictionary = layout["nodes"][cell]
		guardians += int(str(node["type"]) == "guardian")
		scavengers += int(str(node["type"]) == "scavenger")
		if cell.x != count - 1: continue
		if int(node["min_fights"]) < fights - int(layout.get("fight_slack", 1)) or int(node["max_fights"]) > fights + 1 or int(node["min_services"]) < 1 or int(node["max_guardians"]) > 1: return false
		bypass = bypass or int(node["min_guardians"]) == 0
	return guardians >= 2 and scavengers >= 1 and bypass

static func _fallback_walks(count: int) -> Array:
	# Alternating split/merge diamonds keep all four lanes usable without
	# putting consecutive forks across an incoming physical threshold.
	var walks: Array = []
	for walk_index: int in range(WALK_COUNT):
		var walk: Array[int] = []
		for step: int in range(1, count):
			var lane: int = 0 if walk_index in [0, 4] else (3 if walk_index == 1 else 1)
			if walk_index == 3 and step % 2 == 0 and step not in [ceili(count / 2.0), count - 1]: lane = 2
			walk.append(lane)
		walks.append(walk)
	return walks

static func _straight_fallback_walks(count: int) -> Array:
	var walks: Array = []
	for lane: int in [0, 1, 3, 0, 3]:
		var walk: Array[int] = []
		for step: int in range(count - 1): walk.append(lane)
		walks.append(walk)
	return walks

static func _fallback_layout(count: int, fights: int) -> Dictionary:
	var layout: Dictionary = _layout_from_walks(_straight_fallback_walks(count), count)
	_prepare_types(layout, 0, 0, count)
	var fight_steps: Array[int] = []
	fight_steps.assign([1, 2, 3])
	for step: int in range(5, count - 1):
		if step != ceili(count / 2.0) and fight_steps.size() < fights: fight_steps.append(step)
	for cell: Vector2i in layout["order"]:
		var node: Dictionary = layout["nodes"][cell]
		if not bool(node["fixed"]):
			node["type"] = "combat" if fight_steps.has(cell.x) else "event"
			if cell.x == 3 and cell.y < 3: node["type"] = "guardian"
			if cell.x == 4: node["type"] = "scavenger"
		_prefix_bounds(layout, cell)
		assert(_prefix_type_legal(layout, cell, count, fights))
	assert(_complete_types_legal(layout, count, fights))
	return layout

static func _depth_bands(rows: Dictionary, index: int, count: int) -> Dictionary:
	var result: Dictionary = _depth_bands_or_empty(rows, index, count)
	assert(not result.is_empty(), "Final depth ring overflow")
	return result

# Rooms keep the four-depth difficulty bands; each band's id ring holds 8 × depth
# rooms, so later rows spill into the next band. Empty when the last band overflows.
static func _depth_bands_or_empty(rows: Dictionary, index: int, count: int) -> Dictionary:
	var result: Dictionary = {}
	var sizes: Dictionary = {1: 0, 2: 0, 3: 0}
	var base: int = (count - 1) / 3
	var remainder: int = (count - 1) % 3
	var first_end: int = base
	var second_end: int = base * 2 + int(remainder == 2)
	for step: int in range(1, count):
		var band: int = 1 if step <= first_end else (2 if step <= second_end else 3)
		result[step] = band
		sizes[band] += rows[step].size()
	for band: int in range(1, 4):
		var capacity: int = 8 * (index * 4 + band)
		while int(sizes[band]) > capacity:
			if band >= 3: return {}
			var last: int = 0
			for step: int in result:
				if int(result[step]) == band: last = maxi(last, step)
			result[last] = band + 1
			sizes[band] -= rows[last].size()
			sizes[band + 1] += rows[last].size()
	return result

static func _apply_type_fields(node: Dictionary, type: String, combat_element: String) -> void:
	node["type"] = type
	node["element"] = combat_element if type in ["combat", "special"] else "none"
	node["npcs"] = [{"id": "scavenger", "pos": Vector2i(3, 4)}] if type == "scavenger" else []
	node["merchant_kind"] = "scavenger" if type == "scavenger" else ""

static func resolve_mystery(state: Dictionary, node: Dictionary) -> void:
	if not modern(state) or str(node.get("type", "")) != "mystery": return
	var type: String = str(node["mystery_type"])
	_apply_type_fields(node, type, str(node.get("mystery_element", "fire")))
	node["was_mystery"] = true
	record_event(state, "mystery_resolved", {"room": node["coord"], "type": type})

static func _initialize_revision_3(state: Dictionary) -> void:
	var seed_value: int = int(state.get("seed", 0))
	var rooms: Dictionary = {}
	var sections: Array[Dictionary] = []
	for index: int in range(6):
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
		var count: int = ROOM_COUNTS[index]
		var boss_id: String = Bosses.boss_id_for_depth(seed_value, (index + 1) * 4)
		var entry: Vector2i = Vector2i.ZERO if index == 0 else Vector2i(-index * 4, 0)
		var boss: Vector2i = Vector2i((index + 1) * 4, 0)
		var info: Dictionary = {"index": index, "boss_id": boss_id, "title": Bosses.room_name_for_boss(boss_id), "entry": entry, "boss": boss, "room_count": count, "fight_count": FIGHT_COUNTS[index], "scouts": 2, "entered": false}
		sections.append(info)
		rooms[key(entry)] = _node(entry, index, 0, 1, index * 4, "start", "none")
		var previous: Array[Vector2i] = []
		previous.assign([entry])
		var slots: Dictionary = {}
		var step: int = 1
		var landmark_groups: Dictionary = {}
		var group: int = 0
		var fights_left: int = FIGHT_COUNTS[index] - 1
		while step < count:
			var length: int = mini(3, count - step)
			var width: int = 3 if group == 1 and index < 5 else 2
			var group_fights: int = mini(2, fights_left) if length == 3 else 0
			if index == 1 and group == 1:
				group_fights = 1
			if index == 0 and group == 1:
				group_fights = 1
			fights_left -= group_fights
			var lanes: Array = [0, 2] if width == 2 else [0, 1, 2]
			# Outer branches remain distinct. Short alternating middle branches
			# let the last section vary its route without jumping across lanes.
			if width == 2 and group % 2 == 1:
				lanes = [0, 1] if rng.randi_range(0, 1) == 0 else [1, 2]
			var paths: Array = []
			for branch: int in range(width):
				var types: Array[String] = []
				for offset: int in range(length):
					if offset < group_fights:
						types.append("combat")
					elif step + offset == count - 1:
						types.append("campfire")
					else:
						var services: Array[String] = []
						services.assign(["treasure", "scavenger", "event"])
						types.append(services[posmod(index + group + branch + rng.randi_range(0, 2), 3)])
				# Each branch has the same combat burden but a different service/order.
				for offset: int in range(types.size() - 1, 0, -1):
					var swap: int = rng.randi_range(0, offset)
					var held: String = types[offset]
					types[offset] = types[swap]
					types[swap] = held
				if index == 0 and group == 0 and types[0] != "combat":
					var combat_index: int = types.find("combat")
					types[combat_index] = types[0]
					types[0] = "combat"
				# Every path through an earlier group has the same fight budget.
				# Gate using that minimum plus this branch's preceding combats,
				# never map depth (service order is shuffled).
				var fights_before: int = FIGHT_COUNTS[index] - 1 - fights_left - group_fights
				for previous_section: int in range(index): fights_before += FIGHT_COUNTS[previous_section]
				for offset: int in range(types.size()):
					if types[offset] == "combat":
						fights_before += 1
					elif types[offset] in ["treasure", "scavenger", "event"] and fights_before >= 3:
						if posmod(seed_value * 13 + index * 37 + group * 19 + branch * 7 + offset * 11, 5) == 0:
							types[offset] = "graftwright"
				var path: Array[Vector2i] = []
				for offset: int in range(length):
					var local_step: int = step + offset
					var depth: int = index * 4 + mini(3, 1 + int((local_step - 1) * 3 / (count - 1)))
					var slot: int = int(slots.get(depth, 0))
					slots[depth] = slot + 1
					var coord: Vector2i = _ring_coord(depth, slot)
					var element: String = Elements.all_elements()[rng.randi_range(0, 4)] if types[offset] == "combat" else "none"
					var node: Dictionary = _node(coord, index, local_step, lanes[branch], depth, types[offset], element)
					if group == 1 and branch == 0 and types[offset] != "combat" and not landmark_groups.has(group):
						landmark_groups[group] = true
						node["map_landmark"] = true
					if group == 2 and branch == width - 1 and types[offset] != "combat" and not landmark_groups.has(group):
						landmark_groups[group] = true
						node["map_landmark"] = true
					rooms[key(coord)] = node
					path.append(coord)
					if offset > 0:
						_link(rooms, path[offset - 1], _coords([coord]))
				paths.append(path)
			if group == 1:
				var chosen_path: Array = paths[posmod(seed_value + index, paths.size())]
				for guardian_coord: Vector2i in chosen_path:
					var guardian_room: Dictionary = rooms[key(guardian_coord)]
					if str(guardian_room["type"]) != "combat": continue
					var guardian: Dictionary = Guardians.for_boss(boss_id)
					guardian_room["type"] = "guardian"
					guardian_room["element"] = guardian["element"]
					guardian_room["boss_id"] = boss_id
					guardian_room["guardian_id"] = guardian["id"]
					guardian_room["guardian_relic"] = guardian["relic"]
					guardian_room["map_landmark"] = true
					info["guardian"] = guardian_coord
					break
			var firsts: Array[Vector2i] = []
			var lasts: Array[Vector2i] = []
			for path_value: Array in paths:
				firsts.append(path_value[0])
				lasts.append(path_value[-1])
			if group == 0:
				_link(rooms, entry, firsts)
			else:
				_connect_groups(rooms, previous, firsts, group % 2 == 0)
			previous = lasts
			step += length
			group += 1
		var boss_room: Dictionary = _node(boss, index, count, 1, (index + 1) * 4, "boss", Bosses.element_for_boss(boss_id))
		boss_room["boss_id"] = boss_id
		rooms[key(boss)] = boss_room
		for coord: Vector2i in previous:
			_link(rooms, coord, _coords([boss]))
		if index > 0:
			_link(rooms, Vector2i(index * 4, 0), _coords([entry]))
	state["section_map_version"] = VERSION
	state["section_map_layout_revision"] = 3
	state["map_sections"] = sections
	state["rooms"] = rooms
	var start: Dictionary = rooms[key(Vector2i.ZERO)]
	start["visited"] = true
	start["revealed"] = true
	start["map_outline"] = true
	refresh_knowledge(state)

static func _coords(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Vector2i in values:
		result.append(value)
	return result

static func _ring_coord(depth: int, slot: int) -> Vector2i:
	# Allocate unique ids across the full square perimeter of a depth band.
	var perimeter: Array[Vector2i] = []
	for y: int in range(-depth, depth + 1):
		perimeter.append(Vector2i(depth, y))
	for x: int in range(depth - 1, -depth - 1, -1):
		perimeter.append(Vector2i(x, depth))
	for y: int in range(depth - 1, -depth - 1, -1):
		perimeter.append(Vector2i(-depth, y))
	for x: int in range(-depth + 1, depth):
		perimeter.append(Vector2i(x, -depth))
	return perimeter[slot % perimeter.size()]

static func _node(coord: Vector2i, index: int, step: int, lane: int, depth: int, type: String, element: String) -> Dictionary:
	return {"coord": coord, "section_index": index, "map_step": step, "map_lane": lane, "depth": depth, "type": type, "element": element, "connections": [], "npcs": [{"id": "scavenger", "pos": Vector2i(3, 4)}] if type == "scavenger" else [], "merchant_kind": "scavenger" if type == "scavenger" else "", "revealed": false, "map_outline": false, "visited": false, "cleared": type == "start", "sealed": false}

static func _link(rooms: Dictionary, source: Vector2i, destinations: Array[Vector2i]) -> void:
	var directions: Array[Vector2i] = _door_directions(destinations.size())
	var links: Array[Dictionary] = []
	for index: int in range(destinations.size()):
		links.append({"coord": destinations[index], "door_dir": directions[index], "kind": "outward"})
	(rooms[key(source)] as Dictionary)["connections"] = links

# Keep group boundaries planar: each edge spans at most one lane, every room
# has a continuation, and every generated destination can be reached. Nearby
# splits/merges preserve options without resetting every route at each fork.
static func _connect_groups(rooms: Dictionary, sources: Array[Vector2i], targets: Array[Vector2i], reverse: bool) -> void:
	var candidates: Array[Vector2i]
	for i: int in range(sources.size()):
		for j: int in range(targets.size()):
			var distance: int = absi(int(rooms[key(sources[i])]["map_lane"]) - int(rooms[key(targets[j])]["map_lane"]))
			if distance <= 1: candidates.append(Vector2i(i, j))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(int(rooms[key(sources[a.x])]["map_lane"]) - int(rooms[key(targets[a.y])]["map_lane"]))
		var db: int = absi(int(rooms[key(sources[b.x])]["map_lane"]) - int(rooms[key(targets[b.y])]["map_lane"]))
		if da != db: return da < db
		return a.x > b.x if reverse else a.x < b.x)
	var chosen: Array[Vector2i]
	for candidate: Vector2i in candidates:
		var crosses: bool = false
		for edge: Vector2i in chosen:
			crosses = crosses or (candidate.x - edge.x) * (candidate.y - edge.y) < 0
		if not crosses: chosen.append(candidate)
	for i: int in range(sources.size()):
		var destinations: Array[Vector2i]
		for j: int in range(targets.size()):
			if chosen.has(Vector2i(i, j)): destinations.append(targets[j])
		_link(rooms, sources[i], destinations)

static func descendants(state: Dictionary, start: Vector2i, max_hops: int = 99) -> Dictionary:
	var result: Dictionary = {}
	var queue: Array[Vector2i] = []
	queue.assign([start])
	var distances: Array[int] = []
	distances.assign([0])
	var source_section: int = int(room(state, start).get("section_index", -1))
	while not queue.is_empty():
		var coord: Vector2i = queue.pop_front()
		var hops: int = distances.pop_front()
		if result.has(coord) or hops > max_hops:
			continue
		var node: Dictionary = room(state, coord)
		if node.is_empty() or int(node.get("section_index", -2)) != source_section:
			continue
		result[coord] = hops
		for link: Dictionary in node.get("connections", []):
			queue.append(link.get("coord", INVALID))
			distances.append(hops + 1)
	return result

static func refresh_knowledge(state: Dictionary) -> void:
	if not enabled(state):
		return
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var index: int = active_section(state)
	var info: Dictionary = section(state, index)
	if not bool(info.get("entered", false)):
		info["entered"] = true
		record_event(state, "section_entered", {"section": index, "boss_id": info.get("boss_id", ""), "scouts": info.get("scouts", 2)})
	var discoveries: Array[String] = []
	var nearby: Dictionary = descendants(state, current, 3)
	if full_visibility(state, index):
		for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
			if int(node.get("section_index", -1)) != index: continue
			if not bool(node.get("revealed", false)): discoveries.append(key(node["coord"]))
			node["revealed"] = true
			node["map_outline"] = true
	for coord: Vector2i in nearby:
		var node: Dictionary = room(state, coord)
		node["map_outline"] = true
		if int(nearby[coord]) <= 2 and not bool(node.get("revealed", false)):
			node["revealed"] = true
			discoveries.append(key(coord))
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == index and (bool(node.get("map_landmark", false)) or str(node.get("type", "")) == "boss"):
			if not bool(node.get("revealed", false)):
				discoveries.append(key(node.get("coord", INVALID)))
			node["revealed"] = true
			node["map_outline"] = true
	# Crossing a defeated boss opens only the next threshold, never its rooms.
	var current_node: Dictionary = room(state, current)
	if str(current_node.get("type", "")) == "boss" and bool(current_node.get("cleared", false)):
		for link: Dictionary in current_node.get("connections", []):
			room(state, link.get("coord", INVALID))["revealed"] = true
	if not discoveries.is_empty():
		record_event(state, "route_revealed", {"source": "proximity", "section": index, "rooms": discoveries})

static func scout_options(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if not enabled(state) or int(section(state, active_section(state)).get("scouts", 0)) <= 0:
		return result
	if str(state.get("mode", "")) not in ["room", "combat", "pre_battle"]:
		return result
	for coord: Vector2i in descendants(state, state.get("current_room", Vector2i.ZERO)):
		var node: Dictionary = room(state, coord)
		if full_visibility(state, active_section(state)):
			if str(node.get("type", "")) == "mystery" and not bool(node.get("scouted", false)) and not bool(node.get("visited", false)) and not bool(node.get("sealed", false)):
				result.append(coord)
			continue
		var visible: bool = bool(node.get("map_outline", false)) or (bool(node.get("recovery_marker", false)) and int(node.get("recovery_amount", 0)) > 0)
		if visible and not bool(node.get("revealed", false)) and not bool(node.get("sealed", false)):
			result.append(coord)
	return result

static func scout_targets(state: Dictionary, target: Vector2i) -> Array[Vector2i]:
	return _coords([target]) if scout_options(state).has(target) else _coords([])

static func scout(state: Dictionary, target: Vector2i) -> Dictionary:
	var targets: Array[Vector2i] = scout_targets(state, target)
	if targets.is_empty():
		return state.duplicate(true)
	var next: Dictionary = state.duplicate(true)
	var info: Dictionary = section(next, active_section(next))
	info["scouts"] = int(info.get("scouts", 2)) - 1
	var node: Dictionary = room(next, target)
	node["revealed"] = true
	node["map_outline"] = true
	var mystery: bool = modern(next) and str(node.get("type", "")) == "mystery"
	if mystery: node["scouted"] = true
	var outlined: Array[Vector2i]
	for link: Dictionary in node.get("connections", []):
		var neighbor: Vector2i = link.get("coord", INVALID)
		var destination: Dictionary = room(next, neighbor)
		if int(destination.get("section_index", -1)) != active_section(next): continue
		if not bool(destination.get("map_outline", false)): outlined.append(neighbor)
		destination["map_outline"] = true
	# Keep branch as a legacy payload alias; scope/target distinguish direct
	# room scouting from the older multi-room branch reveal in saved logs.
	record_event(next, "map_scout_used", {"section": active_section(next), "scope": "mystery" if mystery else "room", "target": target, "branch": target, "rooms": targets, "outlined_rooms": outlined, "remaining": info["scouts"]})
	return next

static func record_choice(state: Dictionary, destination: Vector2i) -> void:
	if not enabled(state):
		return
	var known: Array[String] = []
	var known_metadata: Array[Dictionary] = []
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == active_section(state) and bool(node.get("revealed", false)):
			known.append(key(node.get("coord", INVALID)))
			known_metadata.append({"room": node.get("coord", INVALID), "type": display_type(node), "element": node.get("mystery_element", "none") if display_type(node) == "combat" and str(node.get("type", "")) == "mystery" else node.get("element", ""), "step": node.get("map_step", 0), "landmark": node.get("map_landmark", false)})
	record_event(state, "route_choice_committed", {"section": active_section(state), "origin": state.get("current_room", Vector2i.ZERO), "destination": destination, "known_rooms": known, "known_room_metadata": known_metadata, "scouts": section(state, active_section(state)).get("scouts", 0)})

static func record_event(state: Dictionary, event_type: String, payload: Dictionary) -> void:
	var events: Array = state.get("map_events", [])
	var revision: int = int(state.get("map_event_revision", 0)) + 1
	events.append({"revision": revision, "type": event_type, "payload": payload})
	state["map_events"] = events
	state["map_event_revision"] = revision
