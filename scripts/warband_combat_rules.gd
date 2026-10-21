extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Data = preload("res://scripts/game_data.gd")
const Identity = preload("res://scripts/enemy_identity.gd")
const FLEE_TILES: int = 2
const Library = preload("res://scripts/special_encounter_library.gd")

static func order_for_objective(objective: Dictionary) -> Dictionary:
	if str(objective.get("special_type", "")) != "warband": return {}
	return Library.definition("warband")["variants"].get(str(objective.get("special_variant", "")), {}).get("order", {})

static func order(state: Dictionary, enemy: Dictionary, id: String) -> bool:
	if not active(state) or not bool(enemy.get("is_leader", false)) or int(enemy.get("hp", 0)) <= 0: return false
	var leader: Dictionary = captain(state)
	return int(leader.get("id", -1)) == int(enemy.get("id", -2)) and str(order_for_objective(state["objective"]).get("id", "")) == id

static func order_line(objective: Dictionary) -> String:
	var value: Dictionary = order_for_objective(objective)
	return "Order: " + str(value["text"]) if not value.is_empty() else ""

static func order_axis(engine: RefCounted, delta: Vector2i) -> Vector2i:
	# Director: project onto the dominant cardinal axis, preferring x on ties.
	var direction: Vector2i = engine._cardinal_direction(delta)
	return Vector2i(-direction.y, direction.x)


static func active(state: Dictionary) -> bool:
	return str(state.get("objective", {}).get("special_type", "")) == "warband"

static func captain(state: Dictionary) -> Dictionary:
	if not active(state): return {}
	for enemy: Dictionary in state.get("enemies", []):
		if bool(enemy.get("is_leader", false)) and int(enemy.get("hp", 0)) > 0: return enemy
	return {}

static func command_bonus(state: Dictionary, enemy: Dictionary) -> int:
	if not active(state) or bool(enemy.get("is_leader", false)) or int(enemy.get("hp", 0)) <= 0: return 0
	var leader: Dictionary = captain(state)
	if leader.is_empty(): return 0
	var command: Dictionary = state["objective"]["command"]
	return Data.fixed_point_amount(command["damage_bonus"]) if Paths.manhattan(enemy["pos"], leader["pos"]) <= int(command["radius"]) else 0

# Recomputed at the point of use, including after forced movement. The saved
# intent remains authored; annotations make repeated preview passes idempotent.
static func action(state: Dictionary, enemy: Dictionary, original: Dictionary) -> Dictionary:
	if not active(state): return original
	var result: Dictionary = original.duplicate(true)
	var base: int = int(result.get("damage", 0)) - int(result.get("_warband_command_bonus", 0))
	var bonus: int = command_bonus(state, enemy) if base > 0 else 0
	if base > 0: result["damage"] = base + bonus
	result["_warband_command_bonus"] = bonus
	return result

static func intent(state: Dictionary, enemy: Dictionary, original: Dictionary) -> Dictionary:
	if not active(state): return original
	var result: Dictionary = original.duplicate(true)
	var actions: Array[Dictionary]
	for value: Dictionary in result.get("actions", []): actions.append(action(state, enemy, value))
	result["actions"] = actions
	return result

# Selected live intents can react to a Thrall death. Authored known-move lists
# keep every move, so pre-battle inspection never collapses Charge/Burst rows.
static func current_intent(state: Dictionary, enemy: Dictionary, original: Dictionary) -> Dictionary:
	return intent(state, enemy, preload("res://scripts/enemy_mechanics/capacitor.gd").effective_intent(state, enemy, original))

static func retreat_path(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i]
	if not active(state) or not bool(enemy.get("is_leader", false)) or int(enemy.get("hp", 0)) <= 0: return empty
	if bool(Data.enemy_def(str(enemy["type"])).get("immobile", false)): return empty
	var settings: Dictionary = state["objective"]["keep_distance"]
	var player: Vector2i = state["player"]["pos"]
	if Paths.manhattan(enemy["pos"], player) > int(settings["trigger_range"]): return empty
	var best: Dictionary = {}
	var best_screened: bool = false
	var best_distance: int = -1
	for record: Dictionary in engine._enemy_actual_path_records(state, enemy, int(settings["step_tiles"])):
		var tile: Vector2i = record["tile"]
		if tile == enemy["pos"]: continue
		var screened: bool = _has_screen(state, player, tile, int(enemy["id"]))
		var distance: int = Paths.manhattan(tile, player)
		if best.is_empty() or (screened and not best_screened) or (screened == best_screened and distance > best_distance):
			best = record
			best_screened = screened
			best_distance = distance
	return engine._vector2i_values(best.get("path", []))

static func _has_screen(state: Dictionary, player: Vector2i, tile: Vector2i, captain_id: int) -> bool:
	var path: Array[Vector2i] = Paths.find_path(state["grid"], player, tile)
	if path.is_empty(): return false
	for follower: Dictionary in state["enemies"]:
		if int(follower["id"]) == captain_id or int(follower["hp"]) <= 0: continue
		var pos: Vector2i = follower["pos"]
		if pos == tile or pos == player: continue
		var first: Array[Vector2i] = Paths.find_path(state["grid"], player, pos)
		var second: Array[Vector2i] = Paths.find_path(state["grid"], pos, tile)
		if not first.is_empty() and not second.is_empty() and first.size() + second.size() == path.size() + 1: return true
	return false

static func break_followers(engine: RefCounted, state: Dictionary, leader_id: int) -> Dictionary:
	var objective: Dictionary = state["objective"]
	if bool(objective.get("completed_by_leader", false)): return state
	# Reveal happens before the break snapshot/animation, including followers
	# whose own Fade flag was active. This does not execute their Ambush.
	if str(order_for_objective(objective).get("id", "")) == "prior_veil":
		for follower: Dictionary in state["enemies"]:
			if int(follower["id"]) != leader_id: follower["veiled"] = false
	var cleared: int = 0
	# Resolve all escape routes before removing anyone. Reserving destinations
	# prevents followers crossing/stacking in the simultaneous presentation beat.
	var blocked: Dictionary = engine._occupied_actor_tiles(state)
	for terrain: Dictionary in state.get("terrain", []):
		if int(terrain.get("hp", 0)) > 0: blocked[terrain["pos"]] = true
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["id"]) == leader_id or int(enemy["hp"]) <= 0: continue
		var path: Array[Vector2i] = flee_path(state["grid"], enemy["pos"], blocked)
		enemy["warband_flee_path"] = path
		enemy["warband_fled"] = true
		enemy["objective_cleared"] = true
		enemy["hp"] = 0
		blocked[path.back()] = true
		cleared += 1
	objective["completed_by_leader"] = true
	objective["followers_cleared"] = cleared
	engine._log(state, str(objective["break_line"]))
	return state

static func flee_path(grid: Array, start: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var best: Array[Vector2i]
	best.append(start)
	var nearest: int = 99999
	# A board edge is the interior walkable boundary; wall/door cells remain
	# impassable. Choose the shortest legal route to its nearest reachable edge.
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			if x != 1 and y != 1 and y != grid.size() - 2 and x != (grid[y] as Array).size() - 2: continue
			var end := Vector2i(x, y)
			if not Paths.is_passable(grid, end) or (blocked.has(end) and end != start): continue
			var path: Array[Vector2i] = Paths.find_path(grid, start, end, blocked)
			if path.is_empty() or path.size() >= nearest: continue
			nearest = path.size()
			best.assign(path.slice(0, FLEE_TILES + 1))
	return best

# The legacy batch API shares the same Warband activation rules as the modern
# scheduler; ordinary encounters retain their exact existing batch path.
static func resolve_phase(engine: RefCounted, state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var steps: Array[Dictionary]
	for index: int in range((next.get("enemies", []) as Array).size()):
		if engine.combat_outcome(next) != "": break
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(next, index, false)
		next = result["state"]
		steps.append_array(result["steps"])
	return {"state": next, "steps": steps}

# A batched area hit can queue a Tick/Ooze death before the captain's death.
# Recognize the actually dead captain before draining that queue; absence in an
# information-limited forecast must never count as a captain death.
static func broken(state: Dictionary) -> bool:
	if not active(state): return false
	if bool(state.get("objective", {}).get("completed_by_leader", false)): return true
	for enemy: Dictionary in state.get("enemies", []):
		if bool(enemy.get("is_leader", false)) and int(enemy.get("hp", 0)) <= 0: return true
	return false

static func suppress_death_effects(state: Dictionary, enemy: Dictionary) -> bool:
	return not bool(enemy.get("is_leader", false)) and broken(state)
