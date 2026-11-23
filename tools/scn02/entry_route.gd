extends RefCounted
## Find a forward path on the generated graph and clear the rooms before entry.

const RunEngine = preload("res://scripts/run_engine.gd")
const Objective = preload("res://scripts/combat_objective_rules.gd")

const MAX_RESOLUTION_STEPS: int = 64


static func find(run: Dictionary, destination: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = run["current_room"]
	var rooms: Dictionary = run["rooms"]
	var queue: Array[Vector2i]
	queue.append(start)
	var parents: Dictionary = {start: start}
	var offset: int = 0
	while offset < queue.size():
		var coord: Vector2i = queue[offset]
		offset += 1
		var room: Dictionary = rooms.get(_key(coord), {})
		if coord == destination:
			var path: Array[Vector2i]
			while coord != start:
				path.push_front(coord)
				coord = parents[coord]
			return path
		for connection: Dictionary in room.get("connections", []):
			var next: Vector2i = connection["coord"]
			var next_room: Dictionary = rooms.get(_key(next), {})
			if parents.has(next) or next_room.is_empty() or int(next_room["depth"]) < int(room["depth"]):
				continue
			parents[next] = coord
			queue.append(next)
	var no_path: Array[Vector2i]
	return no_path


static func before_last(engine: RefCounted, initial: Dictionary, path: Array[Vector2i]) -> Dictionary:
	var run: Dictionary = initial
	for index: int in range(path.size() - 1):
		if not engine.available_moves(run).has(path[index]):
			return {}
		run = _clear(engine, engine.move_to_pre_battle(run, path[index]))
		if run.get("mode") != "room":
			return {}
	return run if not path.is_empty() and engine.available_moves(run).has(path.back()) else {}


static func victory_state(combat: Dictionary) -> Dictionary:
	var result: Dictionary = combat.duplicate(true)
	for enemy: Dictionary in result.get("enemies", []):
		enemy["hp"] = 0
	var objective: Dictionary = result.get("objective", {})
	match objective.get("type"):
		Objective.SURVIVE:
			result["initiative_clock"] = int(objective.get("target_clock", result.get("initiative_clock", 0)))
		Objective.REACH_EXIT:
			var targets: Array[Vector2i] = Objective.exit_target_tiles(objective)
			if not targets.is_empty():
				result["player"]["pos"] = targets[0]
	return result


static func _clear(engine: RefCounted, run: Dictionary) -> Dictionary:
	for step: int in range(MAX_RESOLUTION_STEPS):
		match run.get("mode"):
			RunEngine.MODE_PRE_BATTLE:
				run = engine.begin_pre_battle_combat(run)
			"combat":
				run = engine.finish_combat(run, victory_state(run["combat_state"]))
			"reward":
				run = engine.continue_dragon_reward(run) if engine.is_dragon_reward(run) else engine.skip_reward_for_heal(run)
			RunEngine.MODE_ESCAPE:
				run = engine.continue_pending_escape(run)
			"campfire":
				run = engine.leave_campfire(run)
			"treasure":
				if run.get("pending_relics", []).is_empty(): return run
				run = engine.claim_relic(run, run["pending_relics"][0])
			"event":
				var events = preload("res://scripts/event_rules.gd")
				var choice: String = "continue" if run.get("event_state", {}).get("page") == "result" else events.first_available_choice_id(run)
				run = engine.resolve_map_event(run, choice)
			"graftwright":
				run = engine.leave_graftwright(run)
			_:
				return run
	return run


static func _key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
