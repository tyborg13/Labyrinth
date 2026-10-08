extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")

static func run(engine: CombatEngine, template: Dictionary, expect: Callable) -> void:
	var state: Dictionary = template.duplicate(true)
	state["turn_queue"] = [_enemy(1, 13), _enemy(2, 20)]
	_check(engine, engine.finish_player_activation(state), true, "Pass with enemy first", expect)
	state["cards_played_this_turn"] = 2
	state["player_turn_time_spent"] = 3
	var fast: Dictionary = engine.finish_player_activation(state)
	_check(engine, fast, false, "Fast cards return at 12 before enemy 13", expect)
	state["turn_queue"][0]["time"] = 11
	_check(engine, engine.finish_player_activation(state), true, "One enemy then hero before second enemy", expect)
	state["turn_queue"][0]["time"] = 12
	_check(engine, engine.finish_player_activation(state), false, "Hero wins the equal-Time tie even with later sequence", expect)
	state = template.duplicate(true)
	state["turn_queue"] = [_enemy(1, 13), _enemy(2, 20)]
	state["relics"] = ["borrowed_hourglass"]
	_check(engine, engine.finish_player_activation(state), false, "Borrowed Hourglass immediate turn", expect)

	var stale: Dictionary = fast.duplicate(true)
	stale["enemies"][0]["hp"] = 0
	(stale["turn_queue"] as Array).append_array([_enemy(1, 1), _enemy(999, 2), {"kind": "stale", "time": 3}, "invalid"])
	_check(engine, stale, false, "Dead, missing, unknown and malformed entries are skipped", expect)
	stale = fast.duplicate(true)
	stale["turn_queue"] = []
	_check(engine, stale, false, "Empty queue returns directly to player", expect)
	stale = fast.duplicate(true)
	for enemy: Dictionary in stale["enemies"]:
		enemy["hp"] = 0
	_check(engine, stale, false, "Victory means no enemy activation", expect)
	expect.call(not engine.enemy_acts_before_next_player_turn({}), "Empty scheduled state has no enemy activation")

	state = template.duplicate(true)
	state["turn_queue"] = [_enemy(1, 13), _enemy(2, 20)]
	state["objective"] = {"type": "survive", "target_clock": 64, "reinforcement_interval": 8, "next_reinforcement_clock": 8, "reinforcement_waves_spawned": 0, "reinforcement_pool": ["crawler"]}
	var survival: Dictionary = engine.finish_player_activation(state)
	_check(engine, survival, true, "Due survival reinforcement with enemy first", expect)
	var popped: Dictionary = engine._pop_next_actor(survival.duplicate(true))
	expect.call(not (popped.get("reinforcement_steps", []) as Array).is_empty() and (popped["state"]["enemies"] as Array).size() > (survival["enemies"] as Array).size(), "Selection test actually crosses a reinforcement spawn")
	state["cards_played_this_turn"] = 2
	state["player_turn_time_spent"] = 3
	_check(engine, engine.finish_player_activation(state), false, "Due reinforcement does not precede an earlier hero", expect)
	state["cards_played_this_turn"] = 0
	state["player_turn_time_spent"] = 0
	state["objective"]["target_clock"] = 13
	_check(engine, engine.finish_player_activation(state), false, "Survival victory at enemy Time cancels its activation", expect)

static func _enemy(id: int, time: int) -> Dictionary:
	return {"kind": "enemy", "enemy_id": id, "time": time, "seq": id}

static func _check(engine: CombatEngine, scheduled: Dictionary, expected: bool, label: String, expect: Callable) -> void:
	var before: Dictionary = scheduled.duplicate(true)
	expect.call(engine.enemy_acts_before_next_player_turn(scheduled) == expected, "%s: banner decision agrees with expected activation" % label)
	expect.call(scheduled == before, "%s: decision preserves the entire scheduled state, including RNG, queue, log and reinforcement counters" % label)
	expect.call(engine.enemy_acts_before_next_player_turn(scheduled) == expected and scheduled == before, "%s: repeated decisions are deterministic and non-mutating" % label)
	var actual: Dictionary = engine.advance_one_activation_with_steps(scheduled, false)
	var resolved: Dictionary = actual["state"]
	var enemy_acted: bool = not bool(actual.get("complete", false)) and str((resolved.get("current_actor", {}) as Dictionary).get("kind", "")) == "transition"
	expect.call(enemy_acted == expected, "%s: real activation slice agrees with the banner decision" % label)
