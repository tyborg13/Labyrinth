extends RefCounted
const TODO_DESIGN_UPHEAVAL_LENGTH: String = "TODO_DESIGN_upheaval_even_or_missing_length"
const TODO_DESIGN_UPHEAVAL_ROOM_ORIGIN: String = "TODO_DESIGN_room_upheaval_line_between_origin"
const Paths = preload("res://scripts/path_utils.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")
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
	var planned: Dictionary = state.duplicate(true)
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
			if not Paths.is_passable(state["grid"], tile) or engine._terrain_index_at_tile(planned, tile) >= 0: continue
			if not line_preserves_routes(engine, planned, instance, tile): continue
			marks.append(tile)
			planned["terrain"].append({"pos": tile, "hp": int(instance["dials"]["health"]), "kind": "crag_outcrop"})
	else:
		# Primitive: the existing Snare rubble-lane selector, including threshold
		# exclusion, minimum distance and deterministic shortest-exit tie order.
		# Runtime load avoids the pressure -> Wind adapter -> dispatcher cycle.
		marks.assign(exit_lane(state))
		marks.assign(marks.filter(func(tile: Vector2i) -> bool: return leaves_exit(state, tile)))
	instance["marks"] = marks
	instance["marks_source"] = Fuel.stamped(state, {"actor_kind": instance["source"]["kind"], "actor_id": int(instance["source"].get("id", -1)), "source_kind": "battlefield_rule", "rule": "upheaval"})

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

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	if not Fuel.eligible(state, instance.get("marks_source", {})): return state
	var source: Dictionary = instance["source"]
	var origin: Vector2i = state.get("snare_entry", state["player"]["pos"])
	if str(source["kind"]) == "enemy": origin = engine._surface_actor(state, "enemy", int(source["id"]))["pos"]
	for tile: Vector2i in instance.get("marks", []):
		if str(instance["dials"]["pattern"]) == "exit_lane" and not leaves_exit(state, tile): continue
		if not Paths.is_passable(state["grid"], tile) or engine._terrain_index_at_tile(state, tile) >= 0: continue
		if str(instance["dials"]["pattern"]) == "line_between" and not line_preserves_routes(engine, state, instance, tile): continue
		var trial: Dictionary = state.duplicate(true)
		for actor: Dictionary in engine._surface_actor_records(trial):
			if not engine._surface_unit_intersects(actor["unit"], engine._vector2i_values([tile])): continue
			if engine._force_actor_anchored(trial, str(actor["kind"]), int(actor["id"])): continue
			# Primitive: Erupt's adjacent_free landing selection and placement,
			# including its deterministic rotation and ordinary ground entry.
			var destination: Vector2i = Burrow.adjacent_free(engine, trial, tile, origin, -1, actor["unit"])
			if destination == engine.INVALID_TILE: continue
			trial = engine._force_place_actor(trial, str(actor["kind"]), int(actor["id"]), destination)
			trial = engine.surface_actor_arrival(trial, str(actor["kind"]), int(actor["id"]), tile)
		# Recheck from the displaced hero's actual side of the raised tile.
		if str(instance["dials"]["pattern"]) == "exit_lane" and not leaves_exit(trial, tile): continue
		if str(instance["dials"]["pattern"]) == "line_between" and not line_preserves_routes(engine, trial, instance, tile): continue
		# Primitive: Raise Terrain, with ordinary occupancy and ground removal.
		# An impossible raise commits neither terrain nor its trial displacement.
		if Terrain.raise_outcrop(engine, trial, tile, int(instance["dials"]["health"]), {"actor_kind": source["kind"], "actor_id": int(source.get("id", -1))}): state = trial
	return state

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
