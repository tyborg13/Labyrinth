extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Illusions = preload("res://scripts/illusion_card_rules.gd")
const CommonRelics = preload("res://scripts/common_relic_rules.gd")

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["burrow", "erupt"]

static func targetable(enemy: Dictionary, action: Dictionary) -> bool:
	return not bool(enemy.get("burrowed", false)) or str(action.get("type", "")) not in ["melee", "ranged", "push", "pull", "swap", "petrify"]

static func legal_target(engine: RefCounted, state: Dictionary, action: Dictionary, tile: Vector2i) -> bool:
	if str(action.get("type", "")) not in ["swap", "petrify"]: return true
	if str(action.get("type", "")) == "swap":
		for illusion: Dictionary in state.get("illusions", []):
			if int(illusion.get("hp", 0)) > 0 and illusion.get("pos") == tile: return true
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and engine._enemy_footprint_tiles(enemy).has(tile) and targetable(enemy, action): return true
	return false

static func available(enemy: Dictionary, intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) == "erupt" and not bool(enemy.get("burrowed", false)): return false
		if str(action.get("type", "")) == "burrow" and bool(enemy.get("burrowed", false)): return false
		if bool(enemy.get("burrowed", false)) and str(action.get("type", "")) != "erupt": return false
	return true

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, bleed_steps: Array[Dictionary] = []) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	if str(action.get("type", "")) == "burrow":
		enemy["burrowed"] = true
		enemy["erupt_tile"] = state["player"]["pos"]
		enemy.erase("erupt_resolved")
		return state
	if not bool(enemy.get("burrowed", false)):
		return state
	var old_tile: Vector2i = enemy["pos"]
	var marked: Vector2i = enemy.get("erupt_tile", old_tile)
	var destination: Vector2i = landing_tile(engine, state, enemy)
	if destination == engine.INVALID_TILE:
		return state
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, action, bleed_steps)
	if engine._enemy_cannot_continue_after_bleed(state, index): return state
	enemy = state["enemies"][index]
	var blocked: bool = not Paths.is_passable(state.get("grid", []), marked) or engine._terrain_index_at_tile(state, marked) >= 0
	var occupants: Array[Dictionary] = engine._surface_actor_records(state)
	var struck_illusions: Dictionary = {}
	var struck_player: bool = false
	var health_loss: int = 0
	var block_loss: int = 0
	var attack: Dictionary = action.duplicate(true)
	attack["type"] = "aoe"
	attack["_origin_tile"] = destination
	# Snapshot neighbors before displacing the central occupant so it is hit once.
	var neighbors: Array[Dictionary]
	for actor: Dictionary in occupants:
		if str(actor["kind"]) == "enemy" and int(actor["id"]) == int(enemy["id"]): continue
		if not blocked and Surfaces.footprint_tiles(actor["unit"]).has(marked): continue
		var closest: Vector2i = engine._closest_enemy_tile_to(actor["unit"], destination)
		if Paths.manhattan(closest, destination) == 1 and not bool(actor["unit"].get("burrowed", false)): neighbors.append(actor)
	# Surfacing is committed before the impact, so reactions and chain bursts
	# find the body at the eruption tile rather than at its former mound.
	enemy["pos"] = destination
	enemy["burrowed"] = false
	enemy.erase("erupt_tile")
	enemy["erupt_resolved"] = true
	if not blocked:
		for actor: Dictionary in occupants:
			if str(actor["kind"]) == "enemy" and int(actor["id"]) == int(enemy["id"]): continue
			if not Surfaces.footprint_tiles(actor["unit"]).has(marked): continue
			if str(actor["kind"]) == "illusion": Illusions.note_enemy_hit(engine, state, struck_illusions, actor, attack)
			var hp_before: int = int(state["player"].get("hp", 0))
			var block_before: int = int(state["player"].get("block", 0))
			state = Burst.damage_actor(engine, state, actor, int(action.get("damage", 0)))
			if str(actor["kind"]) == "player":
				struck_player = true
				health_loss = maxi(0, hp_before - int(state["player"].get("hp", 0)))
				block_loss = maxi(0, block_before - int(state["player"].get("block", 0)))
			var unit: Dictionary = engine._surface_actor(state, str(actor["kind"]), int(actor["id"]))
			if int(unit.get("hp", 0)) <= 0 or bool(unit.get("burrowed", false)): continue
			if destination != marked: continue
			var free: Vector2i = adjacent_free(engine, state, marked, old_tile, int(enemy["id"]), unit)
			if free == engine.INVALID_TILE: continue
			state = engine._force_place_actor(state, str(actor["kind"]), int(actor["id"]), free)
			state = engine.surface_actor_arrival(state, str(actor["kind"]), int(actor["id"]), destination)
	enemy = state["enemies"][index]
	if int(enemy.get("hp", 0)) <= 0: return state
	enemy["pos"] = destination
	enemy["burrowed"] = false
	enemy.erase("erupt_tile")
	var source_tiles: Dictionary = {destination: true}
	for actor: Dictionary in neighbors:
		var direction: Vector2i = engine._cardinal_direction(engine._closest_enemy_tile_to(actor["unit"], destination) - destination)
		state = engine._force_move_actor(state, str(actor["kind"]), int(actor["id"]), direction, int(action.get("push", 1)), source_tiles, true)
	Surfaces.place(state, destination, str(action.get("surface", "rubble")), engine._surface_source(state, action))
	enemy = state["enemies"][index]
	enemy["expose"] = int(enemy.get("expose", 0)) + int(action.get("self_expose", 0))
	if struck_player:
		state = CommonRelics.blocked_attack(engine, state, int(enemy["id"]), health_loss, block_loss)
		state = Retaliate.after_enemy_hit(engine, state, int(enemy["id"]), attack, destination)
	if not struck_illusions.is_empty(): state = Illusions.after_enemy_hit(engine, state, int(enemy["id"]), struck_illusions)
	return state

static func directions(away: Vector2i) -> Array[Vector2i]:
	var first: Vector2i = Vector2i(signi(away.x), 0) if abs(away.x) >= abs(away.y) and away.x != 0 else Vector2i(0, signi(away.y))
	if first == Vector2i.ZERO: first = Vector2i.UP
	var result: Array[Vector2i]
	for _index: int in range(4):
		result.append(first)
		first = Vector2i(-first.y, first.x)
	return result

static func adjacent_free(engine: RefCounted, state: Dictionary, center: Vector2i, old: Vector2i, id: int, occupant: Dictionary = {}) -> Vector2i:
	var occupied: Dictionary = engine._enemy_blocking_tiles(state, id)
	for tile: Vector2i in Surfaces.footprint_tiles(occupant): occupied.erase(tile)
	for direction: Vector2i in directions(center - old):
		var candidate: Vector2i = center + direction
		var moved: Dictionary = occupant.duplicate(true)
		moved["pos"] = candidate
		var fits: bool = true
		for tile: Vector2i in Surfaces.footprint_tiles(moved):
			if tile == center or not Paths.is_passable(state.get("grid", []), tile) or occupied.has(tile): fits = false
		if fits: return candidate
	return engine.INVALID_TILE

static func landing_tile(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Vector2i:
	var center: Vector2i = enemy.get("erupt_tile", enemy["pos"])
	if Paths.is_passable(state.get("grid", []), center) and engine._terrain_index_at_tile(state, center) < 0:
		var can_displace: bool = true
		for actor: Dictionary in engine._surface_actor_records(state):
			if str(actor["kind"]) == "enemy" and int(actor["id"]) == int(enemy["id"]): continue
			if not bool(actor["unit"].get("burrowed", false)) and Surfaces.footprint_tiles(actor["unit"]).has(center):
				can_displace = adjacent_free(engine, state, center, enemy["pos"], int(enemy["id"]), actor["unit"]) != engine.INVALID_TILE
				if not can_displace: break
		if can_displace: return center
	var occupied: Dictionary = engine._enemy_blocking_tiles(state, int(enemy["id"]))
	var queue: Array[Vector2i]
	queue.append(center)
	var seen: Dictionary = {center: true}
	var grid: Array = state.get("grid", [])
	var order: Array[Vector2i] = directions(center - Vector2i(enemy["pos"]))
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_front()
		for direction: Vector2i in order:
			var candidate: Vector2i = tile + direction
			if candidate.y < 0 or candidate.y >= grid.size() or candidate.x < 0 or candidate.x >= (grid[candidate.y] as Array).size() or seen.has(candidate): continue
			seen[candidate] = true
			if Paths.is_passable(grid, candidate) and not occupied.has(candidate): return candidate
			queue.append(candidate)
	return engine.INVALID_TILE

static func threat(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var tiles: Array[Vector2i]
	var destination: Vector2i = enemy["pos"]
	var action: Dictionary = (intent.get("actions", []) as Array)[0]
	if int(enemy.get("freeze", 0)) <= 0 and int(enemy.get("shock", 0)) <= 0 and int(enemy.get("petrify", 0)) <= 0:
		if str(action["type"]) == "burrow":
			tiles.append(state["player"]["pos"])
		else:
			destination = landing_tile(engine, state, enemy)
			if destination != engine.INVALID_TILE:
				if not Paths.is_passable(state.get("grid", []), enemy.get("erupt_tile", destination)) or engine._terrain_index_at_tile(state, enemy.get("erupt_tile", destination)) >= 0:
					action = action.duplicate(true)
					action["damage"] = 0
				tiles.append(destination)
				var marked: Vector2i = enemy.get("erupt_tile", destination)
				if int(action.get("damage", 0)) > 0 and not tiles.has(marked): tiles.append(marked)
				for direction: Vector2i in directions(Vector2i.ONE):
					if Paths.is_passable(state.get("grid", []), destination + direction): tiles.append(destination + direction)
	var path: Array[Vector2i]
	path.append(enemy["pos"])
	return {"move": [], "attack": tiles, "projected_path": path, "projected_attack": tiles, "projected_destination": destination,
		"projected_attack_action": action, "projected_attack_element": "earth", "projected_attack_from": enemy["pos"], "projected_attack_target": destination}

static func animation_step(before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = after["enemies"][index]
	if str(action["type"]) == "erupt" and not bool(enemy.get("erupt_resolved", false)): return {}
	return {"kind": str(action["type"]), "actor_key": "enemy_%d" % int(enemy["id"]), "actor_name": Data.enemy_def(str(enemy["type"]))["name"],
		"tile": enemy["pos"], "from": before["enemies"][index]["pos"], "to": enemy["pos"], "state_after": after.duplicate(true)}

static func projected_player_force(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var trial: Dictionary = state.duplicate(true)
	var from: Vector2i = state["player"]["pos"]
	var sequence: int = int(state.get("surface_event_sequence", 0))
	trial = engine._resolve_enemy_action(trial, index, action)
	var to: Vector2i = trial["player"]["pos"]
	var path: Array[Vector2i]
	path.append(from)
	if to != from: path.append(to)
	var collision: Dictionary = {}
	for event: Dictionary in trial.get("surface_events", []):
		if int(event.get("sequence", 0)) > sequence and str(event.get("kind", "")) == "force_collision" and str(event.get("actor_kind", "")) == "player":
			collision = {"tile": event.get("tile", from), "blocked_tile": event.get("blocked_tile", from), "direction": event.get("direction", Vector2i.ZERO),
				"damage": int(event.get("damage", 0)), "actor_key": "player", "blocker_kind": str(event.get("blocker_kind", ""))}
	if path.size() < 2 and collision.is_empty(): return {}
	return {"path": path, "destination": to, "collision": collision}
