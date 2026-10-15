extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const En04 = preload("res://tests/suites/en04_enemies_suite.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Guardian = preload("res://scripts/guardian_combat_rules.gd")
const Scene = preload("res://scripts/run_scene.gd")
const PLAYER_ROUNDS: int = 8
const MAX_ACTIVATIONS_PER_ROUND: int = 32
const FIXTURE_PLAYER_HP: int = 10000
const FAR_HERO := Vector2i(5, 7)
const NEAR_HERO := Vector2i(5, 5)
const SIGHT_BLOCKER := Vector2i(5, 3)
const CRAWLER_POS := Vector2i(2, 2)
const HARRIER_POS := Vector2i(8, 2)

static func fixture(engine: RefCounted, squad: bool, blocked: bool = false, type: String = "briar_weaver") -> Dictionary:
	var state: Dictionary = En04.fixture(engine, type)
	state["player"]["hp"] = FIXTURE_PLAYER_HP
	state["player"]["max_hp"] = FIXTURE_PLAYER_HP
	state["player"]["pos"] = NEAR_HERO if blocked else FAR_HERO
	if blocked: state["grid"][SIGHT_BLOCKER.y][SIGHT_BLOCKER.x] = "wall"
	if squad:
		for helper: Dictionary in [En04.enemy(2, CRAWLER_POS), En04.enemy(3, HARRIER_POS, En04.FIXTURE_HELPER_HP, "harrier")]:
			state["enemies"].append(helper)
		var rng := RandomNumberGenerator.new()
		rng.state = state["rng_state"]
		for index: int in range(1, state["enemies"].size()): engine._assign_enemy_intent(state, index, rng)
		state["rng_state"] = rng.state
	return state

static func thornwall_fixture(engine: RefCounted, squad: bool, blocked: bool = false) -> Dictionary:
	var state: Dictionary = fixture(engine, squad, blocked)
	state["enemies"][0]["intent"] = En04.intent("briar_weaver", "thornwall")
	return engine._initialize_initiative_queue(state)

static func run(expect: Callable) -> void:
	var engine: RefCounted = Combat.new()
	for squad: bool in [false, true]:
		for blocked: bool in [false, true]:
			_thornwall_repeats(engine, expect, squad, blocked)
	_all_authored_intents(engine, expect)

static func _thornwall_repeats(engine: RefCounted, expect: Callable, squad: bool, blocked: bool) -> void:
	var label: String = "%s/%s" % ["squad" if squad else "solo", "blocked_sight" if blocked else "out_of_range"]
	var state: Dictionary = thornwall_fixture(engine, squad, blocked)
	var activations: int = 0
	var trace: PackedStringArray
	for round_index: int in range(PLAYER_ROUNDS):
		state = engine.finish_player_activation(state)
		var complete: bool = false
		for slice_index: int in range(MAX_ACTIVATIONS_PER_ROUND):
			var result: Dictionary = engine.advance_one_activation_with_steps(state)
			state = result["state"]
			if activated_enemy(result) == 1:
				activations += 1
				var display: Dictionary = display_state(engine, state, 1)
				trace.append("%d:%s/next=%d/tooltip=%s/badge=%s/threat=%d" % [state["initiative_clock"], state["enemies"][0].get("intent", {}).get("id", "<empty>"), scheduled_time(state, 1), display["tooltip"], display["badge"], display["threat_tiles"]])
				_assert_continuity(engine, expect, state, 1, "%s activation %d" % [label, activations])
				if activations == 1:
					expect.call(not state["terrain"].is_empty(), label + " actually resolves Thornwall before checking the regression")
					expect.call(state["enemies"][0].get("intent", {}).get("id", "") == "lash_of_thorns", label + " keeps the authored Lash intent when Thornwall and Root Mend are unavailable")
					expect.call(bool(display["cancelled"]) and int(display["threat_tiles"]) == 0, label + " shows the existing cancelled attack badge without inventing an unreachable threat")
					_lash_becomes_reachable(engine, expect, state, label)
			if bool(result["complete"]):
				complete = true
				break
		expect.call(complete and engine.is_player_turn(state), label + " returns to the hero each round")
		expect.call(engine.combat_outcome(state).is_empty(), label + " remains a live combat")
	expect.call(activations >= PLAYER_ROUNDS, label + " repeatedly activates after Thornwall")
	print("FIX04 TRACE %s: %s" % [label, " | ".join(trace)])

static func _lash_becomes_reachable(engine: RefCounted, expect: Callable, after: Dictionary, label: String) -> void:
	var scene: Control = Scene.new()
	var blocked_result: Dictionary = engine.resolve_enemy_turn_with_steps(after, 0)
	var lash: Dictionary = En04.intent("briar_weaver", "lash_of_thorns")
	expect.call(int(blocked_result["time_cost"]) == int(lash["time"]), label + " unreachable Lash still pays its authored Time")
	expect.call(scene._analytics_enemy_action_events(blocked_result, {}).is_empty(), label + " unreachable Lash creates no fabricated hit analytics")
	var state: Dictionary = after.duplicate(true)
	state["player"]["pos"] = NEAR_HERO
	state["grid"][SIGHT_BLOCKER.y][SIGHT_BLOCKER.x] = "stone"
	var display: Dictionary = display_state(engine, state, 1)
	expect.call(bool(display["badge"]) and not bool(display["cancelled"]) and int(display["threat_tiles"]) > 0, label + " committed Lash immediately exposes its real threat when range and sight permit")
	var hp_before: int = state["player"]["hp"]
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	expect.call(int(result["state"]["player"]["hp"]) < hp_before, label + " the displayed Lash resolves real damage")
	var events: Array[Dictionary] = scene._analytics_enemy_action_events(result, {})
	expect.call(events.size() == 1, label + " reachable Lash retains exactly one action event")
	if not events.is_empty():
		var event: Dictionary = events[0]
		expect.call(str(event["event_type"]) == "enemy_action_resolved" and str(event["payload"]["intent_id"]) == "lash_of_thorns" and str(event["payload"]["enemy_type"]) == "briar_weaver", label + " reachable Lash keeps its analytics attribution")
	scene.free()

static func _all_authored_intents(engine: RefCounted, expect: Callable) -> void:
	var intent_count: int = 0
	for type: String in Data.enemies():
		for authored: Dictionary in Data.enemy_def(type)["intents"]:
			for blocked: bool in [false, true]:
				var state: Dictionary = fixture(engine, false, blocked, type)
				# Prime held follow-ups through their real preceding turn before forcing
				# the authored intent under test (Icefall, Lob, Burrow, Veil).
				for prior: Dictionary in Data.enemy_def(type)["intents"]:
					if str(prior.get("next_intent", "")) == str(authored["id"]):
						state["enemies"][0]["intent"] = engine._surface_prepare_enemy_intent(state, state["enemies"][0], prior.duplicate(true))
						state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
						break
				var enemy: Dictionary = state["enemies"][0]
				var chosen: Dictionary = engine._surface_prepare_enemy_intent(state, enemy, authored.duplicate(true))
				if bool(Data.enemy_def(type).get("intent_cycle", false)): chosen = Guardian.commit(engine, state, 0, chosen)
				enemy["intent"] = chosen
				state = engine._initialize_initiative_queue(state)
				state["current_actor"] = {"kind": "transition"}
				var result: Dictionary = engine.advance_one_activation_with_steps(state)
				state = result["state"]
				var label: String = "%s/%s/%s" % [type, authored["id"], "blocked_sight" if blocked else "out_of_range"]
				expect.call(activated_enemy(result) == 1, label + " resolves the intended actor through the real clock")
				expect.call(engine.combat_outcome(state).is_empty(), label + " retains a live combat for the next-intent invariant")
				for survivor: Dictionary in state["enemies"]:
					if int(survivor.get("hp", 0)) > 0: _assert_continuity(engine, expect, state, int(survivor["id"]), label)
				intent_count += 1
	print("ENEMY INTENT INVARIANT: %d enemy types, %d authored intent resolutions" % [Data.enemies().size(), intent_count])

static func activated_enemy(result: Dictionary) -> int:
	for step: Dictionary in result.get("steps", []):
		if str(step.get("boundary", "")) == "initiative_activate": return int(step["state"]["current_actor"].get("enemy_id", -1))
	return -1

static func scheduled_time(state: Dictionary, id: int) -> int:
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == id: return int(entry["time"])
	return -1

static func display_state(engine: RefCounted, state: Dictionary, id: int) -> Dictionary:
	var board: Control = Board.new()
	board.combat_state = state
	var result: Dictionary = {"tooltip": false, "badge": false, "cancelled": false, "threat_tiles": 0}
	var key: String = "enemy_%d" % id
	for unit: Dictionary in board._visible_units():
		if str(unit.get("key", "")) == key:
			var intent: Dictionary = unit.get("intent", {})
			result["tooltip"] = not board._intent_display_name(intent).is_empty() and not board._intent_rows(intent).is_empty()
	for badge: Dictionary in Badges.build(engine, state, state)["badges"]:
		if str(badge["key"]) == key:
			result["badge"] = true
			result["cancelled"] = badge["cancelled"]
	result["threat_tiles"] = engine.enemy_threat_tiles(state, engine._enemy_index_for_id(state, id)).get("projected_attack", []).size()
	board.free()
	return result

static func _assert_continuity(engine: RefCounted, expect: Callable, state: Dictionary, id: int, label: String) -> void:
	var enemy: Dictionary = state["enemies"][engine._enemy_index_for_id(state, id)]
	var intent: Dictionary = enemy.get("intent", {})
	expect.call(not str(intent.get("id", "")).is_empty() and not (intent.get("actions", []) as Array).is_empty(), label + " has a non-empty next intent for enemy %d" % id)
	expect.call(scheduled_time(state, id) > int(state["initiative_clock"]), label + " schedules a later turn for enemy %d" % id)
	var display: Dictionary = display_state(engine, state, id)
	expect.call(bool(display["tooltip"]), label + " exposes named intent and action rows in the unit tooltip for enemy %d" % id)
	var visible: bool = engine.is_enemy_visible_to_player(state, enemy)
	expect.call(bool(display["badge"]) == visible, label + " exposes an at-rest intent badge while preserving Umbra visibility for enemy %d" % id)
