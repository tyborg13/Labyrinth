extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const Snapshot = preload("res://scripts/enemy_mechanics/tether.gd")
const APPROACH_TILES: int = 2 # Brief: reposition up to two tiles before a Dive.

static func flying(unit: Dictionary) -> bool:
	return bool(Data.enemies().get(str(unit.get("type", "")), {}).get("flying", false))

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "dive_line"

static func action_for(intent: Dictionary) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if handles(action): return action
	return {}

static func traversable_terrain(state: Dictionary, tile: Vector2i) -> bool:
	for terrain: Dictionary in state.get("terrain", []):
		if terrain.get("pos") == tile and Surface.terrain_is_live(terrain):
			return str(terrain.get("kind", "")) in ["bramble", "ice_pillar"]
	return false

# Flight can cross Bramble and Ice Pillars, but the endpoint always obeys the
# ordinary occupancy check. Navigation returns only legal ending tiles.
static func can_cross(engine: RefCounted, state: Dictionary, unit: Dictionary, tile: Vector2i) -> bool:
	return flying(unit) and traversable_terrain(state, tile) and not engine._enemy_blocking_tiles_without_terrain(state, int(unit.get("id", -1))).has(tile)

static func navigation(engine: RefCounted, state: Dictionary, unit: Dictionary, budget: int, occupied: Dictionary) -> Dictionary:
	var paths: Dictionary = {unit["pos"]: engine._vector2i_values([unit["pos"]])}
	var queue: Array[Vector2i] = engine._vector2i_values([unit["pos"]])
	var cursor: int = 0
	while cursor < queue.size():
		var from: Vector2i = queue[cursor]; cursor += 1
		var path: Array[Vector2i] = engine._vector2i_values(paths[from])
		if path.size() > budget: continue
		for direction: Vector2i in Paths.DIRS_4:
			var to: Vector2i = from + direction
			if paths.has(to) or not Paths.is_passable(state.get("grid", []), to): continue
			if occupied.has(to) and not can_cross(engine, state, unit, to): continue
			var next: Array[Vector2i] = path.duplicate(); next.append(to)
			paths[to] = next; queue.append(to)
	var costs: Dictionary = {}; var hazards: Dictionary = {}
	for tile: Vector2i in paths.keys():
		if engine._terrain_index_at_tile(state, tile) >= 0: paths.erase(tile); continue
		costs[tile] = paths[tile].size() - 1; hazards[tile] = 0
	return {"paths": paths, "costs": costs, "hazards": hazards}

static func line(engine: RefCounted, state: Dictionary, start: Vector2i, hero: Vector2i, limit: int) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var distance: int = Paths.manhattan(start, hero)
	if distance < 1 or distance > limit or (start.x != hero.x and start.y != hero.y): return result
	var direction := Vector2i(signi(hero.x - start.x), signi(hero.y - start.y))
	for offset: int in range(1, distance + 1):
		var tile: Vector2i = start + direction * offset
		if not Paths.is_passable(state.get("grid", []), tile) or engine._terrain_index_at_tile(state, tile) >= 0: return engine._vector2i_values([])
		result.append(tile)
	return result

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, movement_disabled: bool = false, attack_disabled: bool = false) -> Dictionary:
	var action: Dictionary = action_for(intent)
	var enemy: Dictionary = state["enemies"][index]
	var start: Vector2i = enemy["pos"]
	var hero: Vector2i = state["player"]["pos"]
	var path: Array[Vector2i] = engine._vector2i_values([start])
	var tiles: Array[Vector2i] = line(engine, state, start, hero, int(action.get("max_length", 4)))
	if tiles.is_empty() and not movement_disabled:
		var records: Array[Dictionary] = engine._enemy_actual_path_records(state, enemy, APPROACH_TILES)
		for record: Dictionary in records:
			var candidate: Array[Vector2i] = line(engine, state, record["tile"], hero, int(action.get("max_length", 4)))
			if candidate.is_empty(): continue
			if tiles.is_empty() or record["path"].size() < path.size():
				path = engine._vector2i_values(record["path"]); tiles = candidate
	var destination: Vector2i = path.back()
	var direction := Vector2i(signi(hero.x - destination.x), signi(hero.y - destination.y))
	# Director feedback 1: right-hand side in the board's x-right/y-down grid.
	var side := Vector2i(-direction.y, direction.x)
	if movement_disabled: tiles.clear()
	var landing: Vector2i = destination
	var pushes: Array[Dictionary]
	var collisions: Array[Dictionary]
	var projected: Array[Vector2i] = engine._vector2i_values([])
	if not tiles.is_empty() and not attack_disabled:
		var simulated: Dictionary = state.duplicate(true)
		simulated["enemies"][index]["pos"] = destination
		simulated["damage_context"] = _damage_context(simulated, index)
		simulated = _push_passed_units(engine, simulated, index, action, tiles, side, pushes)
		for event: Dictionary in engine._surface_events_since(state, simulated):
			if str(event.get("kind", "")) == "force_collision": collisions.append(event)
		landing = _landing_tile(engine, simulated, index, destination, tiles)
		for tile: Vector2i in tiles:
			if landing == hero - direction or (tile - destination).length_squared() <= (landing - destination).length_squared(): projected.append(tile)
	return {"path": path, "route": path, "destination": destination, "movement_action_index": 0, "attack_action_index": 0, "attack_action": action, "projected_attack": projected,
		"projected_attack_target": hero if landing == hero - direction and not projected.is_empty() else landing, "target_key": "player", "target_tile": hero, "attack_available": not tiles.is_empty() and not attack_disabled, "cancelled": tiles.is_empty(), "side_direction": side, "side_push_previews": pushes, "side_push_collisions": collisions, "dive_tiles": tiles, "landing": landing, "movement_disabled": movement_disabled, "attack_disabled": attack_disabled}

static func _damage_context(state: Dictionary, index: int) -> Dictionary:
	return {"actor_kind": "enemy", "actor_id": state["enemies"][index]["id"], "source_kind": "direct_attack", "player_card": false}

static func _push_passed_units(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, tiles: Array[Vector2i], side: Vector2i, previews: Array[Dictionary]) -> Dictionary:
	var actors: Array[Dictionary] = engine._surface_actor_records(state)
	var pushed: Dictionary = {}
	# The final line tile is the hero; only strictly intermediate units are passed.
	for tile_index: int in range(tiles.size() - 1):
		for actor: Dictionary in actors:
			if actor["kind"] == "player" or pushed.has(actor["key"]) or actor["key"] == engine._enemy_key(state["enemies"][index]) or not Surface.footprint_tiles(actor["unit"]).has(tiles[tile_index]): continue
			pushed[actor["key"]] = true
			var origin: Vector2i = actor["unit"]["pos"]
			previews.append({"actor_key": actor["key"], "from": origin, "to": origin + side * int(action.get("side_push", 1))})
			state = engine._force_move_actor(state, actor["kind"], actor["id"], side, int(action.get("side_push", 1)), {}, true)
	return state

static func _landing_tile(engine: RefCounted, state: Dictionary, index: int, start: Vector2i, tiles: Array[Vector2i]) -> Vector2i:
	var enemy: Dictionary = state["enemies"][index]
	var occupied: Dictionary = engine._enemy_path_blockers(state, enemy, true, false)
	# After all pushes, stop on the last legal path tile before an occupied landing.
	for tile_index: int in range(tiles.size() - 2, -1, -1):
		if engine._enemy_can_occupy_anchor(state, enemy, tiles[tile_index], occupied): return tiles[tile_index]
	return start

static func available(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary) -> bool:
	return action_for(intent).is_empty() or bool(plan(engine, state, index, intent, bool(state["enemies"][index].get("immobilize", false))).get("attack_available", false))

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var forecast: Dictionary = plan(engine, state, index, state["enemies"][index]["intent"], bool(context.get("movement_disabled", false)), bool(context.get("attack_disabled", false)))
	context["flight_started"] = false
	context["dive_plan"] = forecast
	if bool(forecast["cancelled"]): return state
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "move_toward"}, bleed_steps)
	if engine._enemy_cannot_continue_after_bleed(state, index): return state
	state = engine._move_enemy_along_planned_path(state, index, engine._vector2i_values(forecast["path"]), context, APPROACH_TILES)
	context["approach_after"] = Snapshot.snapshot(state)
	if bool(forecast["attack_disabled"]): return state
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "ranged"}, bleed_steps)
	if engine._enemy_cannot_continue_after_bleed(state, index): return state
	context["flight_started"] = true
	var previous: Dictionary = state.get("damage_context", {}).duplicate(true)
	state["damage_context"] = _damage_context(state, index)
	var tiles: Array[Vector2i] = engine._vector2i_values(forecast["dive_tiles"])
	var pushes: Array[Dictionary]
	var hero_tile: Vector2i = state["player"]["pos"]
	state = _push_passed_units(engine, state, index, action, tiles, forecast["side_direction"], pushes)
	var landing: Vector2i = _landing_tile(engine, state, index, forecast["destination"], tiles)
	state["enemies"][index]["pos"] = landing
	action = preload("res://scripts/warband_combat_rules.gd").action(state, state["enemies"][index], action)
	if Paths.manhattan(landing, hero_tile) == 1: state = Reflect.damage_line(engine, state, index, action, engine._vector2i_values([hero_tile]))
	state["damage_context"] = previous
	return state

static func step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary) -> Dictionary:
	var forecast: Dictionary = context.get("dive_plan", plan(engine, before, index, before["enemies"][index]["intent"]))
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	losses.append_array(engine._enemy_target_losses(before, after))
	return {"kind": "ranged", "action_type": "dive_line", "element": "air", "actor_key": engine._enemy_key(before["enemies"][index]), "from": forecast["destination"], "to": after["enemies"][index]["pos"], "tiles": forecast["projected_attack"], "target_losses": losses, "impact_actor_keys": engine._target_loss_keys(losses), "approach_path": forecast["path"], "approach_after": context.get("approach_after", {}), "en05_after": Snapshot.snapshot(after), "label": "Dive", "cancelled": bool(forecast["cancelled"]) or not bool(context.get("flight_started", true))}
