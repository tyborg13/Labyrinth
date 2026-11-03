extends RefCounted
## Director-owned pressure data; all board forecasts use the resolving selector.
const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")

static func definition(state: Dictionary) -> Dictionary:
	var objective: Dictionary = state.get("objective", {})
	if str(objective.get("special_type", "")) != "umbral_snare": return {}
	return Library.variant("umbral_snare", str(objective["special_variant"])).get("pressure", {})

static func id(state: Dictionary) -> String:
	if str(state.get("objective", {}).get("special_type", "")) != "umbral_snare": return ""
	if state.has("snare_pressure"): return str(state["snare_pressure"]["id"])
	return str(definition(state).get("id", ""))

# One shared traversal: unweighted routes use FIFO; the rubble selector keeps
# deterministic Dijkstra ordering. Optional goals stop at the first reached exit.
# Units and surfaces never block. Terrain and seals still block.
static func walking_paths(state: Dictionary, start: Vector2i, rubble: bool = false, stop_at: Dictionary = {}) -> Dictionary:
	var blocked: Dictionary = {}
	for terrain: Dictionary in state.get("terrain", []):
		if Surfaces.terrain_is_live(terrain): blocked[terrain["pos"]] = true
	for exit: Dictionary in state["objective"].get("exits", []):
		if bool(exit.get("sealed", false)): blocked[exit["target_tile"]] = true
	var frontier: Array[Vector2i]
	frontier.append(start)
	var costs: Dictionary = {start: 0}
	var steps: Dictionary = {start: 0}
	var parents: Dictionary = {start: start}
	var discovery: Dictionary = {start: 0}
	var result: Dictionary = {"costs": costs, "steps": steps, "parents": parents}
	if not stop_at.is_empty():
		result["reached_goal"] = false
		var reachable_goal: bool = false
		for goal: Vector2i in stop_at:
			if Paths.is_passable(state["grid"], goal) and not blocked.has(goal): reachable_goal = true; break
		if not reachable_goal: return result
	var head: int = 0
	while head < frontier.size():
		if rubble: frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if costs[a] != costs[b]: return int(costs[a]) < int(costs[b])
			return int(steps[a]) < int(steps[b]) if steps[a] != steps[b] else int(discovery[a]) < int(discovery[b]))
		var tile: Vector2i = frontier.pop_front() if rubble else frontier[head]
		if not rubble: head += 1
		if stop_at.has(tile) and not blocked.has(tile):
			result["reached_goal"] = true
			return result
		for direction: Vector2i in Paths.DIRS_4:
			var next: Vector2i = tile + direction
			if not Paths.is_passable(state["grid"], next) or blocked.has(next): continue
			var cost: int = int(costs[tile]) + (2 if rubble and Surfaces.has_rubble(state, tile) else 1)
			var length: int = int(steps[tile]) + 1
			if costs.has(next) and (int(costs[next]) < cost or (int(costs[next]) == cost and int(steps[next]) <= length)): continue
			costs[next] = cost
			steps[next] = length
			parents[next] = tile
			if not discovery.has(next): discovery[next] = discovery.size()
			if not rubble or not frontier.has(next): frontier.append(next)
	return result

static func initialize(engine: RefCounted, state: Dictionary) -> void:
	var pressure_id: String = id(state)
	if pressure_id.is_empty() or state.has("snare_pressure"): return
	state["snare_pressure"] = {"id": pressure_id, "radius_loss": 0}
	var entry: Vector2i = state["snare_entry"]
	if pressure_id == "fire_rows":
		# Existing opening pressure is seeded on the physical entry at turn zero.
		Surfaces.place(state, entry, "fire", {"actor_kind": "room", "pressure": pressure_id})
	elif pressure_id == "frost_thresholds":
		var tiles: Array[Vector2i] = approach_tiles(state)
		for tile: Vector2i in tiles: Surfaces.place(state, tile, "ice", {"actor_kind": "room", "pressure": pressure_id})
		# Placement precedes the opening player activation, so a legal alternate
		# start on an approach receives ordinary Ice start contact immediately.
		engine._surface_contact(state, "player", -1, engine.INVALID_TILE, true)
		if not tiles.is_empty(): record_change(state, tiles, 0)
	var dispatcher: GDScript = load("res://scripts/battlefield_rules/dispatcher.gd")
	var key: String = str(definition(state).get("battlefield_instance", ""))
	if not key.is_empty(): dispatcher.install(engine, state, dispatcher.instance_for(key))

static func approach_tiles(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var distances: Dictionary = walking_paths(state, state["snare_entry"])["costs"]
	for exit: Dictionary in state["objective"]["exits"]:
		if str(exit["role"]) != "sealing": continue
		var candidates: Array[Vector2i]
		for direction: Vector2i in Paths.DIRS_4:
			var tile: Vector2i = exit["target_tile"] + direction
			if tile.x <= 0 or tile.y <= 0 or tile.x >= state["grid"][0].size() - 1 or tile.y >= state["grid"].size() - 1: continue
			if distances.has(tile) and Surfaces.can_place(state, tile): candidates.append(tile)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if distances[a] != distances[b]: return int(distances[a]) < int(distances[b])
			return a.x < b.x if a.x != b.x else a.y < b.y)
		if not candidates.is_empty() and not result.has(candidates[0]): result.append(candidates[0])
	return result

static func preview(engine: RefCounted, state: Dictionary, player_turn: int = -1) -> Dictionary:
	# A live player-turn forecast must see the same state as the resolving
	# boundary, including expiring Fireproof and activation-end relic pulses.
	var prepared: Dictionary = engine.prepare_player_activation_end(state) if engine.is_player_turn(state) else state
	return _preview_prepared(engine, prepared, player_turn)

static func exit_lane(state: Dictionary) -> Array[Vector2i]:
	var pressure: Dictionary = definition(state)
	var tiles: Array[Vector2i]
	var hero: Vector2i = state["player"]["pos"]
	var routes: Dictionary = walking_paths(state, hero, true)
	var exits: Array = state["objective"]["exits"].filter(func(exit: Dictionary) -> bool: return not bool(exit.get("sealed", false)) and routes["costs"].has(exit["target_tile"]))
	exits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_tile: Vector2i = a["target_tile"]
		var b_tile: Vector2i = b["target_tile"]
		if routes["costs"][a_tile] != routes["costs"][b_tile]: return int(routes["costs"][a_tile]) < int(routes["costs"][b_tile])
		# Preserve spx-05's authored door order on equal walking costs.
		if int(a.get("path_tiles", 0)) != int(b.get("path_tiles", 0)): return int(a.get("path_tiles", 0)) < int(b.get("path_tiles", 0))
		return int(a.get("map_lane", 0)) < int(b.get("map_lane", 0)))
	if not exits.is_empty():
		var path: Array[Vector2i]
		var cursor: Vector2i = exits[0]["target_tile"]
		while cursor != hero:
			path.push_front(cursor)
			cursor = routes["parents"][cursor]
		for index: int in range(path.size()):
			var tile: Vector2i = path[index]
			if index + 1 < int(pressure["min_steps_from_hero"]) or is_threshold(state, tile) or Surfaces.has_rubble(state, tile) or not Surfaces.can_place(state, tile): continue
			tiles.append(tile)
			break
	return tiles

static func _preview_prepared(engine: RefCounted, state: Dictionary, player_turn: int) -> Dictionary:
	var pressure: Dictionary = definition(state)
	var pressure_id: String = str(pressure.get("id", ""))
	var tiles: Array[Vector2i]
	if pressure_id.is_empty() or engine.combat_outcome(state) != "": return {"id": pressure_id, "tiles": tiles}
	if player_turn < 0: player_turn = int(state["objective"].get("player_turns_completed", 0)) + 1
	var dispatcher: GDScript = load("res://scripts/battlefield_rules/dispatcher.gd")
	var beat: Dictionary = dispatcher.forecast(engine, state)
	for group: Array in beat.get("tiles", {}).values():
		for tile: Vector2i in group:
			if not tiles.has(tile): tiles.append(tile)
	if str(dispatcher.active(state).get("rule", "")) == "gust":
		return {"id": pressure_id, "tiles": tiles, "wind_preview": Wind.preview(engine, state, Wind.active(engine, state))}
	if pressure_id == "umbra_rings":
		var radius: int = engine.effective_umbra_radius(state)
		var next_radius: int = radius
		if player_turn % int(pressure["every_player_turns"]) == 0 and radius > int(pressure["min_radius"]):
			var trial: Dictionary = state.duplicate(true)
			trial["snare_pressure"]["radius_loss"] += 1
			# Ask the existing vision rules: temporary Clear/Light effects retain
			# their normal semantics rather than forecasting a fictitious radius.
			next_radius = engine.effective_umbra_radius(trial)
			var next_visible: Dictionary = engine.umbra_visible_tile_lookup(trial)
			for tile: Vector2i in engine.umbra_visible_tiles(state):
				if not next_visible.has(tile): tiles.append(tile)
		return {"id": pressure_id, "tiles": tiles, "radius": next_radius}
	return {"id": pressure_id, "tiles": tiles}

static func resolve(engine: RefCounted, state: Dictionary, player_turn: int, rule_dispatched: bool = false) -> void:
	if not state.has("snare_pressure") or int(state["snare_pressure"].get("last_resolved_turn", -1)) == player_turn: return
	if not rule_dispatched and engine.combat_outcome(state) != "": return
	state["snare_pressure"]["last_resolved_turn"] = player_turn
	var forecast: Dictionary = _preview_prepared(engine, state, player_turn)
	var tiles: Array[Vector2i]
	tiles.assign(forecast["tiles"])
	var pressure_id: String = str(forecast["id"])
	# Production already dispatched this anchor. Standalone pressure callers use
	# exactly the same saved turn guard, including duplicate/resumed completion.
	if not rule_dispatched:
		var after: Dictionary = load("res://scripts/battlefield_rules/dispatcher.gd").after_player_turn(engine, state, player_turn)
		if not is_same(after, state): state.merge(after, true)
	if pressure_id == "umbra_rings" and int(forecast.get("radius", engine.effective_umbra_radius(state))) < engine.effective_umbra_radius(state):
		state["snare_pressure"]["radius_loss"] += 1
	# Legacy analytics identify the pressure; tiles describe this committed beat,
	# never the next forecast prepared by the dispatcher after it resolves.
	tiles.clear()
	if pressure_id not in ["headwind", "umbra_rings"]:
		for group: Array in state.get("battlefield_rule", {}).get("last_beat_tiles", {}).values():
			for tile: Vector2i in group:
				if not tiles.has(tile): tiles.append(tile)
	record_change(state, tiles, player_turn)

static func presentation_projection(forecast: Dictionary) -> Dictionary:
	var wind: Dictionary = forecast.get("wind_preview", {})
	var markers: Array[Dictionary]
	for event: Dictionary in wind.get("collision_markers", []):
		var marker: Dictionary = {}
		# Only fields consumed by the shared collision icon/tooltip and dedup.
		for key: String in ["tile", "blocked_tile", "damage", "blocker_kind", "tooltip_override", "actor_key"]:
			if event.has(key): marker[key] = event[key]
		markers.append(marker)
	return {
		"tiles": (forecast.get("tiles", []) as Array).duplicate(true),
		"displacement_paths": (wind.get("displacement_paths", []) as Array).duplicate(true),
		"collision_markers": markers,
	}

static func record_change(state: Dictionary, tiles: Array[Vector2i], player_turn: int = -1) -> void:
	if player_turn < 0: player_turn = int(state["objective"].get("player_turns_completed", 0)) + 1
	Surfaces.record_event(state, {"kind": "snare_pressure", "id": id(state), "player_turn": player_turn, "tiles": tiles.duplicate()})

static func is_threshold(state: Dictionary, tile: Vector2i) -> bool:
	for exit: Dictionary in state.get("objective", {}).get("exits", []):
		if exit["target_tile"] == tile: return true
	return false

static func visible_tile(state: Dictionary, tile: Vector2i) -> bool:
	if str(state.get("objective", {}).get("special_type", "")) != "umbral_snare": return false
	for exit: Dictionary in state["objective"]["exits"]:
		if tile == exit["target_tile"] or tile == exit["door_tile"]: return true
	for enemy: Dictionary in state.get("enemies", []):
		if bool(enemy.get("snare_sealbinder", false)) and int(enemy.get("hp", 0)) > 0 and enemy["pos"] == tile: return true
	return false
