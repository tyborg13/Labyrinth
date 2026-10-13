extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")

static func damage(enemy: Dictionary) -> int:
	return int((Data.enemy_def(str(enemy.get("type", ""))).get("death_burst", {}) as Dictionary).get("damage", 0)) + int(enemy.get("kindled_bonus", 0))

static func damage_actor(engine: RefCounted, state: Dictionary, actor: Dictionary, amount: int) -> Dictionary:
	if str(actor["kind"]) != "enemy":
		return engine._damage_actor_target(state, actor, amount, false, {"type": "aoe"})
	var index: int = engine._enemy_index_for_id(state, int(actor["id"]))
	if index < 0: return state
	var exposed: int = int(state["enemies"][index].get("expose", 0))
	state = engine._damage_enemy(state, index, amount + exposed, true, false, false)
	if amount > 0: state = engine._consume_enemy_expose(state, index)
	return state

static func tiles(state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var center: Vector2i = enemy.get("pos", Vector2i(-1, -1))
	var grid: Array = state.get("grid", [])
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var tile: Vector2i = center + Vector2i(x, y)
			if (x != 0 or y != 0) and tile.y >= 0 and tile.y < grid.size() and tile.x >= 0 and tile.x < (grid[tile.y] as Array).size():
				result.append(tile)
	return result

# The death hook queues first. Nested deaths append to this same FIFO; they
# never recursively detonate before the current burst has hit every occupant.
static func on_death(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Dictionary:
	if not Data.enemy_def(str(enemy.get("type", ""))).has("death_burst"):
		return state
	var id: int = int(enemy.get("id", -1))
	var actual: Dictionary = state["enemies"][engine._enemy_index_for_id(state, id)]
	if bool(actual.get("death_burst_resolved", false)):
		return state
	actual["death_burst_resolved"] = true
	var queue: Array = state.get("_death_burst_queue", [])
	queue.append(actual.duplicate(true))
	state["_death_burst_queue"] = queue
	if bool(state.get("_death_burst_running", false)):
		return state
	state["_death_burst_running"] = true
	var prior_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	while not queue.is_empty():
		var source: Dictionary = queue.pop_front()
		var affected: Array[Vector2i] = tiles(state, source)
		var amount: int = damage(source)
		state["damage_context"] = {"actor_kind": "enemy", "actor_id": int(source["id"]), "source_kind": "death_burst", "player_card": false}
		var before: Dictionary = state.duplicate(true)
		for actor: Dictionary in engine._surface_actor_records(state):
			if not engine._surface_unit_intersects(actor["unit"], affected):
				continue
			state = damage_actor(engine, state, actor, amount)
		Surfaces.place(state, source["pos"], "fire", state["damage_context"])
		var events: Array = state.get("death_burst_events", [])
		events.append({"id": int(source["id"]), "tile": source["pos"], "tiles": affected, "damage": amount,
			"before": _snapshot(before), "after": _snapshot(state)})
		state["death_burst_events"] = events
	state["damage_context"] = prior_context
	state.erase("_death_burst_queue")
	state.erase("_death_burst_running")
	return state

static func _snapshot(state: Dictionary) -> Dictionary:
	return {"player": (state.get("player", {}) as Dictionary).duplicate(true), "enemies": (state.get("enemies", []) as Array).duplicate(true),
		"illusions": (state.get("illusions", []) as Array).duplicate(true), "surfaces": (state.get("surfaces", {}) as Dictionary).duplicate(true)}
