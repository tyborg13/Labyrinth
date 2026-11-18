extends RefCounted
const TODO_DESIGN_UPHEAVAL_LENGTH: String = "TODO_DESIGN_upheaval_even_or_missing_length"
const TODO_DESIGN_UPHEAVAL_ROOM_ORIGIN: String = "TODO_DESIGN_room_upheaval_line_between_origin"
const Paths = preload("res://scripts/path_utils.gd")
const Rise = preload("res://scripts/battlefield_rules/upheaval_rise.gd")
const Fuel = preload("res://scripts/battlefield_rules/fuel.gd")
const PATTERNS: Array = ["line_between", "exit_lane", "ring_around_player", "beside_terrain"]

static func dial_error(_state: Dictionary, instance: Dictionary) -> String:
	var dials: Dictionary = instance.get("dials", {})
	if int(dials.get("health", 0)) <= 0: return "Upheaval requires positive health"
	var pattern: String = str(dials.get("pattern", ""))
	if pattern == "line_between":
		if str(instance["source"]["kind"]) != "enemy": return TODO_DESIGN_UPHEAVAL_ROOM_ORIGIN
		var length: int = int(dials.get("length", 0))
		if length <= 0 or length % 2 == 0: return TODO_DESIGN_UPHEAVAL_LENGTH
		return ""
	if pattern == "exit_lane": return ""
	return "Upheaval pattern is not implemented: " + pattern

static func prepare(engine: RefCounted, state: Dictionary, instance: Dictionary) -> void:
	if instance.has("marks"): return
	var marks: Array[Vector2i]
	if str(instance["dials"]["pattern"]) == "line_between":
		var source: Dictionary = engine._surface_actor(state, "enemy", int(instance["source"]["id"]))
		var hero: Vector2i = state["player"]["pos"]
		var delta: Vector2i = hero - Vector2i(source["pos"])
		# Primitive: line3_perpendicular_front_of_hero (Bramble/Thornwall),
		# extended symmetrically to the authored length. Occupants can be marked.
		var front := hero - Vector2i(signi(delta.x), signi(delta.y))
		var axis := Vector2i(0, 1) if delta.y == 0 else Vector2i(1, 0)
		var half: int = int(instance["dials"]["length"]) / 2
		for offset: int in range(-half, half + 1):
			var tile: Vector2i = front + axis * offset
			if not Paths.is_passable(state["grid"], tile) or engine._terrain_index_at_tile(state, tile) >= 0: continue
			marks.append(tile)
	else:
		# Primitive: the existing Snare rubble-lane selector, including threshold
		# exclusion, minimum distance and deterministic shortest-exit tie order.
		# Runtime load avoids the pressure -> Wind adapter -> dispatcher cycle.
		marks.assign(exit_lane(state))
	instance["marks"] = marking_guard(engine, state, instance, marks)
	instance["marks_source"] = Fuel.stamped(state, {"actor_kind": instance["source"]["kind"], "actor_id": int(instance["source"].get("id", -1)), "source_kind": "battlefield_rule", "rule": "upheaval"})

static func marking_guard(engine: RefCounted, state: Dictionary, instance: Dictionary, candidates: Array[Vector2i]) -> Array[Vector2i]:
	# One batch against the marking board; accepted earlier marks participate in
	# the whole set. Keep the established authored order and route primitives.
	var planned: Dictionary = state.duplicate(true)
	var result: Array[Vector2i]
	for tile: Vector2i in candidates:
		if Rise.site_blocked(engine, planned, tile): continue
		var allowed: bool = line_preserves_routes(engine, planned, instance, tile) if str(instance["dials"]["pattern"]) == "line_between" else leaves_exit(planned, tile)
		if not allowed: continue
		# Check the entire accepted prefix with its current occupants, using
		# the same placement and throw as the beat.
		var trial: Array[Vector2i]
		trial.assign(result)
		trial.append(tile)
		var outcome: Array = Rise.attempt(engine, state, instance, trial)["outcomes"]
		if str(outcome.back()["category"]) != "raised": continue
		result.append(tile)
		planned["terrain"].append({"pos": tile, "hp": int(instance["dials"]["health"]), "kind": "crag_outcrop"})
	return result

static func line_preserves_routes(engine: RefCounted, state: Dictionary, instance: Dictionary, tile: Vector2i) -> bool:
	var source: Dictionary = engine._surface_actor(state, "enemy", int(instance["source"]["id"]))
	# Worldspine owns connectivity and footprint-aware structural exits. The
	# Snare guard additionally preserves any declared open objective exit.
	if not load("res://scripts/dragon_combat_rules.gd").spire_preserves_routes(engine, state, source, tile): return false
	if not state.get("objective", {}).get("exits", []).is_empty(): return leaves_exit(state, tile)
	return true

static func exit_lane(state: Dictionary) -> Array[Vector2i]:
	return load("res://scripts/snare_pressure_rules.gd").exit_lane(state)

static func leaves_exit(state: Dictionary, tile: Vector2i) -> bool:
	var trial: Dictionary = state.duplicate(true)
	trial["terrain"].append({"pos": tile, "hp": 1})
	# Primitive: Snare walking-path reachability / never seal the last exit.
	var goals: Dictionary = {}
	for exit: Dictionary in trial.get("objective", {}).get("exits", []):
		if not bool(exit.get("sealed", false)): goals[exit["target_tile"]] = true
	if goals.is_empty(): return false
	var routes: Dictionary = load("res://scripts/snare_pressure_rules.gd").walking_paths(trial, trial["player"]["pos"], false, goals)
	return bool(routes["reached_goal"])

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary, trace: Dictionary = {}) -> Dictionary:
	var marks: Array[Vector2i]
	marks.assign(instance.get("marks", []))
	var result: Dictionary = Rise.attempt(engine, state, instance, marks)
	trace["upheaval"] = result["outcomes"]
	return result["state"]

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
