extends RefCounted
## Snare-only layout and saved combat state. No variant pressure is read here.
const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
# Enabling the second special exposes an eleventh legend concept. The existing
# one-row/ten-concept map gate needs the map owner's layout decision (spx-02).
const TODO_DESIGN_SNARE_LEGEND_LAYOUT: String = "TODO_DESIGN_SNARE_LEGEND_LAYOUT"
# Five walking tiles cannot guarantee no first-turn escape when existing Move/
# Blink cards remain legal. Preserve both explicit rules pending owner policy.
const TODO_DESIGN_FIRST_TURN_ESCAPE_POLICY: String = "TODO_DESIGN_FIRST_TURN_ESCAPE_POLICY"
const MIN_EXIT_PATH_TILES: int = 5
const SINGLE_DOOR_SEAL_TURN: int = 3
const SEALBINDER_HP: int = 4
const MIN_START_HUNTER_DISTANCE: int = 2
const MAX_PLACEMENT_ATTEMPTS: int = 20

static func active(state: Dictionary) -> bool:
	return str(state.get("objective", {}).get("special_type", "")) == "umbral_snare"

static func is_room(room: Dictionary) -> bool:
	return str(room.get("type", "")) == "special" and str(room.get("special_type", "")) == "umbral_snare"

static func objective(room: Dictionary) -> Dictionary:
	return {"special_type": "umbral_snare", "special_variant": room["special_variant"], "goal_met": true,
		"player_turns_completed": 0, "enemy_round_pending": false, "hunters_spawned": 0, "sealbinders_killed": 0}

# Outgoing connections are ordered by map lane by SectionMapGraph._link.
# Keep their ordinal through sorting; authored fixtures may supply map_lane.
static func formation(grid: Array, entry: Vector2i, objective_value: Dictionary) -> Dictionary:
	var exits: Array = objective_value["exits"].duplicate(true)
	for index: int in range(exits.size()):
		var path: Array[Vector2i] = Paths.find_path(grid, entry, exits[index]["target_tile"])
		if path.size() - 1 < MIN_EXIT_PATH_TILES: return {}
		exits[index]["path_tiles"] = path.size() - 1
		exits[index]["map_lane"] = exits[index].get("map_lane", index)
	exits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["path_tiles"]) < int(b["path_tiles"]) if a["path_tiles"] != b["path_tiles"] else int(a["map_lane"]) < int(b["map_lane"]))
	if exits.size() < 2: return {}
	var rules: Dictionary = Library.definition("umbral_snare")
	var positions: Array[Vector2i]
	var occupied: Dictionary = {entry: true}
	for exit: Dictionary in exits: occupied[exit["target_tile"]] = true
	for index: int in range(exits.size()):
		var exit: Dictionary = exits[index]
		exit["sealed"] = false
		exit["kept_open"] = false
		exit["role"] = "jailer" if index == 0 else "sealing"
		var path: Array[Vector2i] = Paths.find_path(grid, entry, exit["target_tile"])
		var tile: Vector2i = path[path.size() - 2]
		if index > 0:
			exit["seal_after_player_turns"] = SINGLE_DOOR_SEAL_TURN if exits.size() == 2 else int(rules["seal_after_player_turns"][index - 1])
			# Beside the threshold, inside the room; never occupy another exit.
			var beside: Array[Vector2i]
			for direction: Vector2i in Paths.DIRS_4:
				var candidate: Vector2i = exit["target_tile"] + direction
				if candidate.x > 0 and candidate.y > 0 and candidate.x < grid[0].size() - 1 and candidate.y < grid.size() - 1 and Paths.is_passable(grid, candidate) and not occupied.has(candidate): beside.append(candidate)
			if beside.is_empty(): return {}
			tile = beside[0]
			exit["sealbinder_id"] = index + 1
		if occupied.has(tile) or not Paths.is_passable(grid, tile): return {}
		positions.append(tile)
		occupied[tile] = true
	var variant: Dictionary = Library.variant("umbral_snare", str(objective_value["special_variant"]))
	var start_count: int = int(variant.get("start_hunters", 0))
	# reachable_tiles is already a stable breadth-first walk: nearest tiles
	# come first without repeating a path search inside a sorting comparator.
	var candidates: Array[Vector2i]
	if start_count > 0: candidates = Paths.reachable_tiles(grid, entry, grid.size() * grid[0].size())
	for tile: Vector2i in candidates:
		if positions.size() == exits.size() + start_count: break
		if occupied.has(tile) or Paths.manhattan(tile, entry) < MIN_START_HUNTER_DISTANCE: continue
		positions.append(tile)
		occupied[tile] = true
	if positions.size() != exits.size() + start_count: return {}
	return {"exits": exits, "positions": positions}

static func roster(room: Dictionary, door_count: int) -> Array:
	var rules: Dictionary = Library.definition("umbral_snare")
	var result: Array = [rules["jailer"]["unit"]]
	for index: int in range(door_count - 1): result.append(rules["sealbinder"]["unit"])
	var variant: Dictionary = Library.variant("umbral_snare", str(room["special_variant"]))
	for index: int in range(int(variant.get("start_hunters", 0))): result.append(hunter_type(variant, index))
	return result

static func configure(layout: Dictionary, tier: int) -> void:
	var rules: Dictionary = Library.definition("umbral_snare")
	var exits: Array = layout["objective"]["exits"]
	var enemies: Array = layout["enemies"]
	var jailer: Dictionary = enemies[0]
	jailer["display_name"] = rules["jailer"]["title"]
	jailer["max_hp"] = ceili(float(jailer["max_hp"]) * float(rules["jailer"]["hp_multiplier"]))
	jailer["hp"] = jailer["max_hp"]
	jailer["stoneskin"] = rules["jailer"]["stoneskin_by_tier"][tier - 1]
	for index: int in range(1, exits.size()):
		var binder: Dictionary = enemies[index]
		binder["display_name"] = rules["sealbinder"]["title"]
		binder["snare_sealbinder"] = true
		binder["max_hp"] = SEALBINDER_HP
		binder["hp"] = SEALBINDER_HP
		binder["intent"] = seal_intent(layout["objective"], binder)
	for index: int in range(exits.size(), enemies.size()): enemies[index]["snare_hunter"] = true
	layout["objective"]["hunters_spawned"] = enemies.size() - exits.size()
	layout["special_type"] = "umbral_snare"
	layout["special_variant"] = layout["objective"]["special_variant"]
	# The special reward is the starting Gaoler + Sealbinder roster only.
	var roster_layout: Dictionary = {"enemies": enemies.slice(0, exits.size())}
	layout["special_starting_reward_embers"] = Library.starting_embers(roster_layout)
	for index: int in range(exits.size(), enemies.size()): enemies[index]["reward_embers"] = 0

static func hunter_type(variant: Dictionary, index: int) -> String:
	var value: Variant = variant["hunters"]
	return str(value[index % value.size()]) if value is Array else str(value)

static func seal_intent(objective_value: Dictionary, enemy: Dictionary) -> Dictionary:
	var left: int = 0
	for exit: Dictionary in objective_value.get("exits", []):
		if int(exit.get("sealbinder_id", -1)) == int(enemy["id"]): left = maxi(0, int(exit["seal_after_player_turns"]) - int(objective_value.get("player_turns_completed", 0)))
	return {"id": "snare_seal", "name": "Seal · %d" % left, "actions": []}

static func binder_killed(state: Dictionary, enemy: Dictionary) -> void:
	if not active(state) or not bool(enemy.get("snare_sealbinder", false)): return
	for exit: Dictionary in state["objective"]["exits"]:
		if int(exit.get("sealbinder_id", -1)) == int(enemy["id"]) and not bool(exit["sealed"]) and not bool(exit["kept_open"]):
			exit["kept_open"] = true
			state["objective"]["sealbinders_killed"] += 1

static func end_round(state: Dictionary) -> void:
	if not active(state) or not bool(state["objective"].get("enemy_round_pending", false)): return
	var objective_value: Dictionary = state["objective"]
	objective_value["enemy_round_pending"] = false
	for exit: Dictionary in objective_value["exits"]:
		if str(exit["role"]) != "sealing" or bool(exit["sealed"]) or bool(exit["kept_open"]): continue
		if int(objective_value["player_turns_completed"]) < int(exit["seal_after_player_turns"]): continue
		exit["sealed"] = true
		for enemy: Dictionary in state["enemies"]:
			if int(enemy["id"]) != int(exit["sealbinder_id"]): continue
			enemy["hp"] = 0
			enemy["snare_dissolved"] = true
			enemy["objective_cleared"] = true
	for enemy: Dictionary in state["enemies"]:
		if bool(enemy.get("snare_sealbinder", false)): enemy["intent"] = seal_intent(objective_value, enemy)

static func sealed_tiles(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if active(state):
		for exit: Dictionary in state["objective"]["exits"]:
			if bool(exit.get("sealed", false)): result[exit["target_tile"]] = true
	return result

static func escape_context(state: Dictionary) -> Dictionary:
	if not active(state): return {}
	var open_count: int = 0
	var escaped: bool = false
	for exit: Dictionary in state["objective"]["exits"]:
		if bool(exit.get("sealed", false)): continue
		open_count += 1
		if exit["target_tile"] == state["player"]["pos"] and int(state["player"]["hp"]) > 0: escaped = true
	return {"doors_open_at_escape": open_count if escaped else 0, "sealbinders_killed": int(state["objective"].get("sealbinders_killed", 0))}

# Removal by sealing is silent and earns no death effects. Keep its silhouette
# in the visual snapshot; omit it only from the board's audio snapshot.
static func sound_snapshot(state: Dictionary, shown: Dictionary) -> Dictionary:
	if not active(state): return {"state": state, "shown": shown}
	var silent: Dictionary = state.duplicate(false)
	var enemies: Array[Dictionary]
	for enemy: Dictionary in state.get("enemies", []):
		if not bool(enemy.get("snare_dissolved", false)): enemies.append(enemy)
	silent["enemies"] = enemies
	var presentation: Dictionary = shown.duplicate(false)
	if shown.has("death_animation_units"):
		var deaths: Array[Dictionary]
		for enemy: Dictionary in shown["death_animation_units"]:
			if not bool(enemy.get("snare_dissolved", false)): deaths.append(enemy)
		presentation["death_animation_units"] = deaths
	return {"state": silent, "shown": presentation}

# In initiative combat a round runs from player completion to the next player
# preparation. The saved pending bit keeps preview, resume and batch idempotent.
static func start_round(engine: RefCounted, state: Dictionary) -> void:
	if not active(state) or engine.combat_outcome(state) != "": return
	var objective: Dictionary = state["objective"]
	if bool(objective.get("enemy_round_pending", false)): return
	objective["enemy_round_pending"] = true
	objective["player_turns_completed"] = int(objective.get("player_turns_completed", 0)) + 1
	var rules: Dictionary = Library.definition("umbral_snare")
	var variant: Dictionary = rules["variants"][objective["special_variant"]]
	if int(variant.get("start_hunters", 0)) > 0 or int(objective["hunters_spawned"]) >= int(rules["hunters_max"]): return
	var entry: Vector2i = state.get("snare_entry", Vector2i(-1, -1))
	if entry.x < 0: return
	var blocked: Dictionary = engine._enemy_blocking_tiles(state)
	var candidates: Array[Vector2i]
	candidates.append(entry)
	candidates.append_array(Paths.reachable_tiles(state["grid"], entry, state["grid"].size() * state["grid"][0].size()))
	for tile: Vector2i in candidates:
		if blocked.has(tile) or not Paths.is_passable(state["grid"], tile): continue
		var rng := RandomNumberGenerator.new()
		rng.state = int(state["rng_state"])
		var hunter: Dictionary = engine._spawned_enemy_entry(state, hunter_type(variant, int(objective["hunters_spawned"])), engine._next_enemy_id(state), tile, false)
		hunter["snare_hunter"] = true
		hunter["reward_embers"] = 0
		state["enemies"].append(hunter)
		engine._assign_enemy_intent(state, state["enemies"].size() - 1, rng)
		engine._schedule_enemy_after_spawn(state, state["enemies"].back(), 0)
		state["rng_state"] = rng.state
		objective["hunters_spawned"] += 1
		break

static func resolve_phase(engine: RefCounted, state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var steps: Array[Dictionary]
	start_round(engine, next_state)
	for index: int in range(next_state["enemies"].size()):
		if engine.combat_outcome(next_state) != "": break
		if int(next_state["enemies"][index]["hp"]) <= 0: continue
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(next_state, index)
		next_state = result["state"]
		steps.append_array(result["steps"])
	var before_seals: Dictionary = next_state.duplicate(true)
	if engine.combat_outcome(next_state) == "": end_round(next_state)
	engine._append_commit_step(steps, before_seals, next_state, "snare_round_end")
	return {"state": next_state, "steps": steps}
