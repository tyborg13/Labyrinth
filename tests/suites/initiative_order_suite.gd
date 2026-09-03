extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	_test_equal_initiative_ties_favor_player(expect)
	_test_turn_order_removes_only_missing_instances(expect)
	_test_status_death_creates_turn_order_boundary(expect)

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

static func _test_turn_order_removes_only_missing_instances(expect: Callable) -> void:
	var view := RunScene.new()
	var active_player: Dictionary = _turn_entry("player", "player", 0, 0, true)
	var future_player: Dictionary = _turn_entry("player", "player", 12, 3, false)
	var enemy_first: Dictionary = _turn_entry("enemy", "enemy:7", 8, 1, false)
	var enemy_repeat: Dictionary = _turn_entry("enemy", "enemy:7", 22, 4, false)
	var before: Array[Dictionary] = []
	before.append(active_player)
	before.append(enemy_first)
	before.append(future_player)
	before.append(enemy_repeat)
	var time_shifted_player: Dictionary = future_player.duplicate(true)
	time_shifted_player["time"] = 26
	var reordered: Array[Dictionary] = []
	reordered.append(active_player)
	reordered.append(enemy_first)
	reordered.append(enemy_repeat)
	reordered.append(time_shifted_player)
	var reordered_removed: Array = view.call("_turn_order_removed_indices", before, reordered) as Array
	expect.call(
		reordered_removed.is_empty(),
		"A Time-driven reorder should move persistent actor instances without treating the active portrait as removed"
	)

	var after_death: Array[Dictionary] = []
	after_death.append(active_player)
	after_death.append(future_player)
	var death_removed: Array = view.call("_turn_order_removed_indices", before, after_death) as Array
	expect.call(
		death_removed == [1, 3],
		"Defeating an enemy should remove every scheduled instance of that actor and preserve surviving portraits"
	)

	var combat := CombatEngine.new()
	var card_state: Dictionary = combat.create_combat(71517, _room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var committed_card_state: Dictionary = combat.finish_player_card(card_state, 0)
	var before_card_order: Array[Dictionary] = combat.current_turn_order(card_state, 10)
	var after_card_order: Array[Dictionary] = combat.current_turn_order(committed_card_state, 10)
	expect.call(
		str(view.call("_turn_order_motion_signature", before_card_order)) != str(view.call("_turn_order_motion_signature", after_card_order)),
		"Committing a real card Time cost should produce a turn-order motion boundary"
	)
	var card_removed: Array = view.call("_turn_order_removed_indices", before_card_order, after_card_order) as Array
	expect.call(
		card_removed.is_empty(),
		"Committing card Time should reflow the player's persistent forecast slot instead of removing the active player"
	)
	view.free()

static func _test_status_death_creates_turn_order_boundary(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var view := RunScene.new()
	var before_state: Dictionary = combat.create_combat(91517, _room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = (before_state.get("enemies", []) as Array).duplicate(true)
	expect.call(not enemies.is_empty(), "Burn death turn-order test requires a generated enemy")
	if enemies.is_empty():
		view.free()
		return
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["hp"] = 1
	enemy["burn"] = 5
	enemies[0] = enemy
	before_state["enemies"] = enemies
	before_state["current_actor"] = combat.call(
		"_enemy_actor_entry",
		before_state,
		enemy,
		int(before_state.get("initiative_clock", 0)),
		int(before_state.get("activation_seq", 0))
	) as Dictionary
	var before_order: Array[Dictionary] = combat.current_turn_order(before_state, 10)
	var burn_input: Dictionary = before_state.duplicate(true)
	var burn_result: Dictionary = combat.call("_resolve_enemy_start_of_turn", burn_input, 0) as Dictionary
	var after_state: Dictionary = burn_result.get("state", burn_input) as Dictionary
	var has_burn_step: bool = false
	for step_var: Variant in burn_result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var as Dictionary
		if str(step.get("kind", "")) == "status_damage" and str(step.get("label", "")) == "Burn":
			has_burn_step = true
			break
	expect.call(has_burn_step, "A lethal start-of-turn Burn should produce the production status-damage step")
	var after_order: Array[Dictionary] = combat.current_turn_order(after_state, 10)
	expect.call(
		str(view.call("_turn_order_motion_signature", before_order)) != str(view.call("_turn_order_motion_signature", after_order)),
		"A lethal production Burn step should create an immediate turn-order motion boundary"
	)
	var removed_indices: Array = view.call("_turn_order_removed_indices", before_order, after_order) as Array
	var expected_actor_key: String = "enemy:%s" % str((before_state.get("current_actor", {}) as Dictionary).get("actor_key", ""))
	var all_removed_match: bool = not removed_indices.is_empty()
	for index_var: Variant in removed_indices:
		var index: int = int(index_var)
		if index < 0 or index >= before_order.size() or str(view.call("_turn_order_actor_key", before_order[index])) != expected_actor_key:
			all_removed_match = false
			break
	expect.call(all_removed_match, "A lethal Burn should remove every scheduled instance of the defeated active enemy")
	view.free()

static func _turn_entry(kind: String, actor_key: String, time: int, sequence: int, active: bool) -> Dictionary:
	return {
		"kind": kind,
		"actor_key": actor_key,
		"time": time,
		"seq": sequence,
		"active": active,
		"eta": time
	}

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
