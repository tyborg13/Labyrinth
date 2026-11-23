extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const BurstRules = preload("res://scripts/burst_rules.gd")

static func damage(enemy: Dictionary) -> int:
	return int((Data.enemy_def(str(enemy.get("type", ""))).get("death_burst", {}) as Dictionary).get("damage", 0)) + int(enemy.get("kindled_bonus", 0))

static func damage_actor(engine: RefCounted, state: Dictionary, actor: Dictionary, amount: int) -> Dictionary:
	if str(actor["kind"]) != "enemy":
		return engine._damage_actor_target(state, actor, amount, false, {"type": "aoe"})
	var index: int = engine._enemy_index_for_id(state, int(actor["id"]))
	return engine._damage_enemy_hit(state, index, amount, false, false)

## The same floor tiles for the Burst, animation and hover warning.
static func tiles(state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	return BurstRules.cross(state, enemy.get("pos", Vector2i(-1, -1)))

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
		engine._resolver_journal("begin", state, {"kind": "death_burst", "id": source["id"]})
		var owner: Dictionary = preload("res://scripts/reaction_presentation_trace.gd").cascade_begin(engine, state, {"action_type": "death_burst", "id": source["id"], "tile": source["pos"], "tiles": affected, "damage": amount})
		state["damage_context"] = {"actor_kind": "enemy", "actor_id": int(source["id"]), "source_kind": "death_burst", "player_card": false}
		state["damage_context"]["burst"] = true
		var before: Dictionary = state.duplicate(true)
		# The shared Burst: every unit on the cross once (units only; terrain and
		# traps are untouched, as before).
		var sources: Array[Vector2i]
		sources.append(source["pos"])
		var hit: Callable = func(next_state: Dictionary, actor: Dictionary, damage: int) -> Dictionary:
			return damage_actor(engine, next_state, actor, damage)
		state = BurstRules.resolve(engine, state, sources, amount, hit)["state"]
		Surfaces.place(state, source["pos"], "fire", state["damage_context"])
		var events: Array = state.get("death_burst_events", [])
		events.append({"id": int(source["id"]), "tile": source["pos"], "tiles": affected, "damage": amount,
			"before": _snapshot(before), "after": _snapshot(state)})
		state["death_burst_events"] = events
		engine._resolver_journal("end", state)
		preload("res://scripts/reaction_presentation_trace.gd").cascade_end(engine, state, owner)
	state["damage_context"] = prior_context
	state.erase("_death_burst_queue")
	state.erase("_death_burst_running")
	return state

static func _snapshot(state: Dictionary) -> Dictionary:
	return {"player": (state.get("player", {}) as Dictionary).duplicate(true), "enemies": (state.get("enemies", []) as Array).duplicate(true),
		"illusions": (state.get("illusions", []) as Array).duplicate(true), "surfaces": (state.get("surfaces", {}) as Dictionary).duplicate(true)}
