extends RefCounted
const Bot = preload("res://tools/encounter_bot.gd")
const Game = preload("res://scripts/game_data.gd")
const MeasurementBot = preload("res://tools/encounter_measurement_bot.gd")
const MeasuredEngine = preload("res://tools/encounter_measurement_engine.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const MetricRepair = preload("res://tools/encounter_metric_repair.gd")
const MEASUREMENT_FIXTURE: Dictionary = {"size": 11, "player": Vector2i(1, 3), "far_enemy": Vector2i(8, 3), "wall": Vector2i(5, 3), "second_enemy": Vector2i(4, 3), "conductor_aim": Vector2i(5, 3), "conduction_primary": Vector2i(4, 3), "conduction_wall": Vector2i(3, 3), "second_id": 2, "hp": 30}
const PRICING_FIXTURE: Dictionary = {"time": 9, "quicken": 2, "finished_for_follow_up": 1}
var checks: int = 0
var failures: int = 0
var assertion_callback: Callable
var fixture_callback: Callable
var arena_callback: Callable
var fixture_defaults: Dictionary

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1
	assertion_callback.call(condition, message)

func policy_fixture(hand: Array) -> Dictionary:
	return fixture_callback.call(hand)

func arena_room() -> Dictionary:
	return arena_callback.call()

func open_grid() -> Array:
	var grid: Array
	for y: int in range(MEASUREMENT_FIXTURE["size"]):
		var row: Array[String]
		for x: int in range(MEASUREMENT_FIXTURE["size"]): row.append("stone")
		grid.append(row)
	return grid

func without_measurement(state: Dictionary) -> Dictionary:
	var clean: Dictionary = state.duplicate(true)
	clean.erase(MeasuredEngine.METRICS)
	for enemy: Dictionary in clean["enemies"]: enemy.erase(MeasuredEngine.SHOCK_SOURCE)
	return clean

func test_overrides() -> void:
	var original: Dictionary = Bot.deck_presets()
	var addition: Dictionary = {"card": "skybolt", "fields": {}}
	var appended: Dictionary = MeasurementBot.overridden_presets(original, addition)
	for tier: String in ["1", "2", "3"]:
		check(appended[tier] == original[tier] + ["skybolt"], "exactly one named card follows tier preset " + tier)
	check(original == Bot.deck_presets(), "original tier presets remain unchanged")
	check(MeasurementBot.overridden_presets(original, {}) == original, "none retains exact presets")
	var source_bytes: String = FileAccess.get_sha256(Game.CARDS_PATH)
	var source: Dictionary = Game.card_def("skybolt").duplicate(true)
	var engine := MeasuredEngine.new()
	engine.added_card = "skybolt"
	engine.field_overrides = {"burn": true, "time": 9, "action_fields": {"range": 5, "ignore_los": null, "shock_all_hits": false}}
	var variant: Dictionary = engine.card_def("skybolt")
	check(variant["burn"] and variant["time"] == 9 and variant["actions"][0]["range"] == 5, "override reaches top-level and action fields")
	check(not variant["actions"][0].has("ignore_los") and not variant["actions"][0]["shock_all_hits"], "null removes field and false is retained")
	check(engine.card_def("dull_bolt") == Bot.CombatEngine.new().card_def("dull_bolt"), "other card definitions are untouched")
	check(Game.card_def("skybolt") == source and FileAccess.get_sha256(Game.CARDS_PATH) == source_bytes, "override changes neither shared cache nor data file")
	var state: Dictionary = policy_fixture(["skybolt"])
	var actions: Array = engine.card_play_actions("skybolt", state)
	var after: Dictionary = engine.finish_player_card(engine.apply_player_action(engine.prepare_player_card(state, 0), actions[0], fixture_defaults["enemy"]), 0)
	check(after["deck"]["burned"].has("skybolt") and not after["deck"]["discard"].has("skybolt"), "Exhaust uses production burn destination")
	check(int(after["player_turn_time_spent"]) - int(state["player_turn_time_spent"]) == 9, "Time override is paid by production card finish")
	var duplicate_input: Dictionary = {"card": "dull_bolt", "fields": {"time": 9}}
	var original_bolt: Dictionary = Game.card_def("dull_bolt").duplicate(true)
	var original_combat_bolt: Dictionary = Bot.CombatEngine.new().card_def("dull_bolt").duplicate(true)
	var duplicate: Dictionary = MeasurementBot.prepare_addition(original, duplicate_input)
	var instance_id: String = str(duplicate["deck_card"])
	var isolated: Dictionary = MeasurementBot.overridden_presets(original, duplicate)
	check(instance_id != "dull_bolt" and isolated["2"] == original["2"] + [instance_id], "an overridden duplicate isolates only the one added copy")
	check(not duplicate_input.has("deck_card") and original == Bot.deck_presets(), "duplicate setup preserves its input and reward presets")
	var isolated_engine := MeasuredEngine.new()
	isolated_engine.added_card = "dull_bolt"
	isolated_engine.override_card_id = instance_id
	isolated_engine.field_overrides = duplicate["fields"]
	check(isolated_engine.card_def("dull_bolt") == original_combat_bolt, "existing copies retain their complete original combat definition")
	check(isolated_engine.card_def(instance_id)["time"] == 9, "only the added instance receives the overridden definition")
	var duplicate_state: Dictionary = policy_fixture([instance_id, "dull_bolt"])
	var duplicate_action: Dictionary = isolated_engine.card_play_actions(instance_id, duplicate_state)[0]
	duplicate_state = isolated_engine.finish_player_card(isolated_engine.apply_player_action(isolated_engine.prepare_player_card(duplicate_state, 0), duplicate_action, fixture_defaults["enemy"]), 0)
	check(duplicate_state["player_turn_time_spent"] == 9 and duplicate_state["deck"]["hand"].has("dull_bolt"), "added instance resolves with its own cost and preserves original hand copies")
	check(Game.card_def("dull_bolt") == original_bolt and FileAccess.get_sha256(Game.CARDS_PATH) == source_bytes, "duplicate registration never rewrites an authored definition or file")
	Game.cards().erase(instance_id)

func pricing_observation(engine: RefCounted, state: Dictionary, mode: String) -> Dictionary:
	var prepared: Dictionary = engine.prepare_player_card(state, 0, mode)
	var actions: Array = engine.card_play_actions("skybolt", prepared)
	var resolved: Dictionary = prepared
	for action: Dictionary in actions:
		resolved = engine.apply_player_action(resolved, action, fixture_defaults["enemy"])
	return {"card": engine.card_def("skybolt", prepared), "prepared": prepared, "actions": actions, "after": without_measurement(engine.finish_player_card(resolved, 0))}

func test_override_production_pricing() -> void:
	var original: Dictionary = Game.cards()["skybolt"]
	var source: Dictionary = original.duplicate(true)
	var source_bytes: String = FileAccess.get_sha256(Game.CARDS_PATH)
	var engine := MeasuredEngine.new()
	engine.added_card = "skybolt"
	for scenario: String in ["Quicken", "Empower", "Follow-up", "Follow-up + Empower"]:
		var empowered: bool = scenario.contains("Empower")
		var follow_up: bool = scenario.contains("Follow-up")
		var authored: Dictionary = source.duplicate(true)
		authored["time"] = PRICING_FIXTURE["time"]
		engine.field_overrides = {"time": PRICING_FIXTURE["time"]}
		if empowered:
			authored["empower"] = Game.cards()["chain_bolt"]["empower"].duplicate(true)
			engine.field_overrides["empower"] = authored["empower"].duplicate(true)
		if follow_up:
			authored["follow_up"] = Game.cards()["quick_stab"]["follow_up"].duplicate(true)
			engine.field_overrides["follow_up"] = authored["follow_up"].duplicate(true)
		var state: Dictionary = policy_fixture(["skybolt"])
		state["turn_flags"]["quicken_pending"] = PRICING_FIXTURE["quicken"]
		state["turn_flags"]["cards_finished"] = PRICING_FIXTURE["finished_for_follow_up"] if follow_up else 0
		var mode: String = "empower" if empowered else "play"
		var measured: Dictionary = pricing_observation(engine, state, mode)
		# Independent control: an authored definition resolved entirely by the
		# unmodified production engine, with the same identity and combat state.
		Game.cards()["skybolt"] = authored
		var production: Dictionary = pricing_observation(Bot.CombatEngine.new(), state, mode)
		Game.cards()["skybolt"] = original
		check(measured == production, scenario + " override matches authored production definition, keyword actions and resolved state")
		var expected_time: int = int(PRICING_FIXTURE["time"]) - int(PRICING_FIXTURE["quicken"])
		if empowered: expected_time += int(authored["empower"]["cost"]["time"])
		check(int(measured["after"]["player_turn_time_spent"]) - int(state["player_turn_time_spent"]) == expected_time, scenario + " pays discounted printed Time plus any Empower surcharge")
		check(bool(measured["actions"][0].get("_empowered", false)) == empowered and bool(measured["actions"][0].get("_follow_up_active", false)) == follow_up, scenario + " resolves the requested keyword mode")
		check(Game.cards()["skybolt"] == source and FileAccess.get_sha256(Game.CARDS_PATH) == source_bytes, scenario + " leaves authored cache and file unchanged")

func test_reach_and_policy() -> void:
	var state: Dictionary = policy_fixture(["skybolt"])
	state["grid"] = open_grid()
	state["player"]["pos"] = MEASUREMENT_FIXTURE["player"]
	state["enemies"][0]["pos"] = MEASUREMENT_FIXTURE["far_enemy"]
	state["grid"][MEASUREMENT_FIXTURE["wall"].y][MEASUREMENT_FIXTURE["wall"].x] = "wall"
	state["umbra"]["stage"] = "clear"
	var engine := MeasuredEngine.new()
	engine.added_card = "skybolt"
	var action: Dictionary = engine.card_play_actions("skybolt", state)[0]
	check(engine.valid_targets_for_player_action(state, action).has(MEASUREMENT_FIXTURE["far_enemy"]), "Skybolt can target a visible enemy beyond five and behind a wall")
	var policy := Bot.Policy.new()
	policy.engine = engine
	var before: Dictionary = state.duplicate(true)
	var selected: Dictionary = policy.choose(state)
	check(not selected.is_empty() and selected.get("card", "") == "skybolt", "unchanged policy selects the long-range blocked-LOS cast")
	check(state == before, "speculative policy search does not leak counters to source state")
	check(selected["state"][MeasuredEngine.METRICS]["casts"].get("skybolt", 0) == 1, "selected state counts only one committed cast, not search branches")
	check(selected["state"][MeasuredEngine.METRICS]["skybolt_casts_beyond_5"] == 1 and selected["state"][MeasuredEngine.METRICS]["skybolt_casts_without_los"] == 1, "selected state records actual reach and physical LOS")
	engine.field_overrides = {"action_fields": {"range": 5, "ignore_los": null}}
	check(not engine.valid_targets_for_player_action(state, engine.card_play_actions("skybolt", state)[0]).has(MEASUREMENT_FIXTURE["far_enemy"]), "V3 restores range and LOS limits")
	for card_id: String in ["wildfire_halo", "stormstring_shot"]:
		var close: Dictionary = policy_fixture([card_id])
		var reference: Dictionary = policy.choose(close)
		check(reference.get("card", "") == card_id, "unchanged policy can play reference " + card_id)

func test_conduction_and_cancellation() -> void:
	var state: Dictionary = policy_fixture(["skybolt"])
	var engine := MeasuredEngine.new()
	engine.added_card = "skybolt"
	var second: Dictionary = engine._spawned_enemy_entry(state, "crawler", MEASUREMENT_FIXTURE["second_id"], MEASUREMENT_FIXTURE["second_enemy"], false)
	second["hp"] = MEASUREMENT_FIXTURE["hp"]
	second["max_hp"] = MEASUREMENT_FIXTURE["hp"]
	second["intent"] = state["enemies"][0]["intent"].duplicate(true)
	state["enemies"].append(second)
	Ground.place(state, fixture_defaults["enemy"], "electrified")
	Ground.place(state, MEASUREMENT_FIXTURE["second_enemy"], "electrified")
	var prepared: Dictionary = engine.prepare_player_card(state, 0)
	var action: Dictionary = engine.card_play_actions("skybolt", prepared)[0]
	var after: Dictionary = engine.apply_player_action(prepared, action, fixture_defaults["enemy"])
	var production := Bot.CombatEngine.new()
	var expected: Dictionary = production.apply_player_action(production.prepare_player_card(state, 0), action, fixture_defaults["enemy"])
	check(without_measurement(after) == expected, "instrumented action is identical to production outside offline counters")
	check(after[MeasuredEngine.METRICS]["skybolt_hits"] == 2, "conduction counts both actual enemies once")
	check(after["enemies"][0]["shock"] == 1 and after["enemies"][1]["shock"] == 1, "production Skybolt shocks both hits")
	engine.field_overrides = {"action_fields": {"shock_all_hits": false}}
	var v1: Dictionary = engine.apply_player_action(prepared, engine.card_play_actions("skybolt", prepared)[0], fixture_defaults["enemy"])
	check(v1["enemies"][0]["shock"] == 1 and v1["enemies"][1]["shock"] == 0, "V1's measurement-only adapter Shocks only the primary enemy")
	var native_v1: Dictionary = production.apply_player_action(prepared, engine.card_play_actions("skybolt", prepared)[0], fixture_defaults["enemy"])
	check(native_v1["enemies"][1]["shock"] == 1, "production remains unchanged; the primary-only adapter is offline only")
	check(v1[MeasuredEngine.METRICS]["skybolt_hits"] == 2 and v1["enemies"][1]["hp"] == after["enemies"][1]["hp"], "primary-only adapter preserves conducted damage and hit counts")
	var ground: Dictionary = prepared.duplicate(true)
	Ground.place(ground, MEASUREMENT_FIXTURE["conductor_aim"], "electrified")
	ground = engine.apply_player_action(ground, engine.card_play_actions("skybolt", ground)[0], MEASUREMENT_FIXTURE["conductor_aim"])
	check(ground[MeasuredEngine.METRICS]["skybolt_hits"] == 2 and ground["enemies"][0]["shock"] == 0 and ground["enemies"][1]["shock"] == 0, "V1 conductor aim damages both enemies without inventing a primary enemy")
	var turn: Dictionary = engine.resolve_enemy_turn_with_steps(after, 0)["state"]
	check(turn[MeasuredEngine.METRICS]["skybolt_cancelled_attacks"] == 1, "one actual shocked activation cancels one damaging intent")
	check(not after[MeasuredEngine.METRICS].has("unexpected") and after[MeasuredEngine.METRICS]["skybolt_cancelled_attacks"] == 0, "enemy preview/branch result leaves original counters untouched")
	var frozen: Dictionary = after.duplicate(true)
	frozen["enemies"][0]["freeze"] = 1
	check(engine.resolve_enemy_turn_with_steps(frozen, 0)["state"][MeasuredEngine.METRICS]["skybolt_cancelled_attacks"] == 0, "Frozen activation is not attributed to Shock")
	var dead: Dictionary = after.duplicate(true)
	dead["enemies"][0]["hp"] = 0
	check(engine.resolve_enemy_turn_with_steps(dead, 0)["state"][MeasuredEngine.METRICS]["skybolt_cancelled_attacks"] == 0, "dead enemies do not cancel attacks")
	var lethal: Dictionary = state.duplicate(true)
	lethal["objective"] = {"type": "kill_leader", "leader_id": fixture_defaults["enemy_id"]}
	lethal["enemies"][0]["hp"] = 1
	lethal["surfaces"] = {}
	var killed: Dictionary = engine.apply_player_action(lethal, action, fixture_defaults["enemy"])
	check(killed[MeasuredEngine.METRICS]["skybolt_kills"] == 1 and killed[MeasuredEngine.METRICS]["skybolt_hits"] == 1, "lethal hit counts once, excluding objective-cleared followers")

func test_conduction_origin() -> void:
	var state: Dictionary = policy_fixture(["skybolt"])
	var engine := MeasuredEngine.new()
	engine.added_card = "skybolt"
	state["grid"] = open_grid()
	state["player"]["pos"] = MEASUREMENT_FIXTURE["player"]
	state["enemies"][0]["pos"] = MEASUREMENT_FIXTURE["conduction_primary"]
	var second: Dictionary = engine._spawned_enemy_entry(state, "crawler", MEASUREMENT_FIXTURE["second_id"], MEASUREMENT_FIXTURE["far_enemy"], false)
	second["hp"] = MEASUREMENT_FIXTURE["hp"]
	second["max_hp"] = MEASUREMENT_FIXTURE["hp"]
	state["enemies"].append(second)
	var wall: Vector2i = MEASUREMENT_FIXTURE["conduction_wall"]
	state["grid"][wall.y][wall.x] = "wall"
	for x: int in range(MEASUREMENT_FIXTURE["conduction_primary"].x, MEASUREMENT_FIXTURE["far_enemy"].x + 1):
		Ground.place(state, Vector2i(x, MEASUREMENT_FIXTURE["far_enemy"].y), "electrified")
	var action: Dictionary = engine.card_play_actions("skybolt", state)[0]
	var after: Dictionary = engine.apply_player_action(engine.prepare_player_card(state, 0), action, MEASUREMENT_FIXTURE["conduction_primary"])
	check(after[MeasuredEngine.METRICS]["skybolt_hits"] == 2 and after[MeasuredEngine.METRICS]["skybolt_hits_beyond_5"] == 1, "conducted reach is measured from caster, not the nearer conduction entry")
	check(after[MeasuredEngine.METRICS]["skybolt_hits_without_los"] == 2, "both conducted and primary LOS are measured from caster")

func test_metric_refresh() -> void:
	var previous: Dictionary = {"seed": 1, "hp_lost": 3, "card_usage": MeasuredEngine.empty_metrics()}
	previous["card_usage"]["casts"]["skybolt"] = 1
	previous["card_usage"]["skybolt_hits"] = 2
	var observed: Dictionary = previous.duplicate(true)
	observed["card_usage"]["skybolt_hits_beyond_5"] = 1
	observed["card_usage"]["skybolt_hits_without_los"] = 2
	observed["card_usage"]["origin_metric"] = MetricRepair.ORIGIN_VERSION
	var calls: Dictionary = {"n": 0}
	var replay: Callable = func() -> Dictionary:
		calls["n"] += 1
		return observed
	var refreshed: Dictionary = MetricRepair.refresh(previous, replay)
	check(calls["n"] == 1 and refreshed["hp_lost"] == previous["hp_lost"] and refreshed["card_usage"]["skybolt_hits_beyond_5"] == 1, "metric refresh replays geometry while preserving outcome fields")
	check(not previous["card_usage"].has("origin_metric") and previous["card_usage"]["skybolt_hits_beyond_5"] == 0, "refresh does not mutate its original record")
	var zero: Dictionary = previous.duplicate(true)
	zero["card_usage"] = MeasuredEngine.empty_metrics()
	zero = MetricRepair.refresh(zero, replay)
	check(calls["n"] == 1 and zero["card_usage"]["origin_metric"] == MetricRepair.ORIGIN_VERSION, "zero-cast records require no fight replay")
	check(not MetricRepair.needs_replay(refreshed) and MetricRepair.needs_replay(previous), "refreshed counters are idempotent")

func run(assertion: Callable, fixture: Callable, arena: Callable, defaults: Dictionary) -> void:
	checks = 0
	failures = 0
	assertion_callback = assertion
	fixture_callback = fixture
	arena_callback = arena
	fixture_defaults = defaults
	test_overrides()
	test_override_production_pricing()
	test_reach_and_policy()
	test_conduction_and_cancellation()
	test_conduction_origin()
	test_metric_refresh()
	var original: Dictionary = Bot.Policy.new().run_room(fixture_defaults["seed"], arena_room(), Bot.deck_presets()["2"])
	var measured := Bot.Policy.new()
	measured.engine = MeasuredEngine.new()
	check(measured.run_room(fixture_defaults["seed"], arena_room(), Bot.deck_presets()["2"]) == original, "none with counters retains exact policy outcome and decisions")
	print("SKYBOLT OVERRIDES: %s (%d checks; %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
