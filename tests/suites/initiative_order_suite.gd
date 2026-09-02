extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")

static func run(expect: Callable) -> void:
	_test_equal_initiative_ties_favor_player(expect)

static func _test_equal_initiative_ties_favor_player(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(15135, _room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var queue: Array = (state.get("turn_queue", []) as Array).duplicate(true)
	expect.call(not queue.is_empty(), "Initiative tie coverage requires one queued enemy")
	if queue.is_empty():
		return
	var tied_time: int = int(state.get("initiative_clock", 0)) + combat.player_base_initiative(state)
	var enemy_entry: Dictionary = (queue[0] as Dictionary).duplicate(true)
	enemy_entry["time"] = tied_time
	enemy_entry["seq"] = 1
	state["turn_queue"] = [enemy_entry]
	state["activation_seq"] = 1

	var forecast: Array[Dictionary] = combat.current_turn_order(state, 3)
	expect.call(forecast.size() >= 3, "Initiative tie forecast should show the active player and both tied future actors")
	if forecast.size() >= 3:
		expect.call(
			str(forecast[1].get("kind", "")) == "player"
			and int(forecast[1].get("time", -1)) == tied_time
			and str(forecast[2].get("kind", "")) == "enemy"
			and int(forecast[2].get("time", -1)) == tied_time,
			"The turn-order forecast should show the player winning an exact clock tie"
		)

	var scheduled_state: Dictionary = combat.finish_player_activation(state)
	var scheduled_order: Array[Dictionary] = combat.current_turn_order(scheduled_state, 2)
	expect.call(
		scheduled_order.size() >= 2
		and str(scheduled_order[0].get("kind", "")) == "player"
		and int(scheduled_order[0].get("time", -1)) == tied_time
		and str(scheduled_order[1].get("kind", "")) == "enemy"
		and int(scheduled_order[1].get("time", -1)) == tied_time,
		"The committed initiative queue should preserve the forecasted player-first tie break"
	)
	var advanced: Dictionary = combat.advance_one_activation_with_steps(scheduled_state)
	var resolved_state: Dictionary = advanced.get("state", {}) as Dictionary
	expect.call(
		combat.is_player_turn(resolved_state)
		and int(resolved_state.get("initiative_clock", -1)) == tied_time,
		"Initiative resolution should activate the player before an enemy at the same clock time"
	)
	var remaining_queue: Array = resolved_state.get("turn_queue", []) as Array
	expect.call(
		remaining_queue.size() == 1 and str((remaining_queue[0] as Dictionary).get("kind", "")) == "enemy",
		"Winning an initiative tie should leave the tied enemy queued to act afterward"
	)

static func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Initiative Tie Test Room",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 2),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}],
		"loot": [],
		"traps": []
	}
