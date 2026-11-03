extends RefCounted
## bos-02: production data, committed routing and before/after resolver witnesses.
const Combat = preload("res://scripts/combat_engine.gd")
const Boss = preload("res://tests/suites/dragon_boss_suite.gd")

const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Outcomes = preload("res://scripts/battlefield_rules/outcomes.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const IDS: Array = ["vyraketh", "tharokh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]
const HELPERS: Array = ["cinder_droplet", "burrow_grub", "rime_spitter", "gust_shrike", "lightning_wisp", "veilbound_acolyte"]
const HELPER_COUNTS: Array = [1, 2, 2, 1, 2, 2] # Director feedback 1, cumulative rung 4.
const RULE_IDS: Array = ["wildfire", "upheaval", "frostbite", "gust", "lightning_storm", "shadowstep"]
const ROUTING_TURN_LIMIT: int = 24

static func approved_sentences() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos02_dragon_sentences.json"))

static func acceptance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos04_dragon_acceptance.json"))

static func run(expect: Callable) -> void:
	for i: int in range(IDS.size()):
		_test_data_slots_and_routing(expect, i)
		_test_forecast_and_half(expect, str(IDS[i]))
	_test_faultline(expect)
	_test_fire_ownership(expect)
	_test_mantle(expect)
	_test_legacy_save(expect)

static func _test_data_slots_and_routing(expect: Callable, index: int) -> void:
	var id: String = IDS[index]
	var engine := Combat.new()
	var state: Dictionary = Boss._boss_combat_state(id)
	var instance: Dictionary = Rules.active(state)
	for key: String in ["rule","cadence","dials","sentence"]:
		expect.call(instance.get(key) == acceptance()[id][key],id+" pinned acceptance "+key)
	expect.call(instance.get("at_half_health",{}) == acceptance()[id].get("at_half_health",{}),id+" pinned complete half-Health turn-up")
	expect.call(instance["sentence"] == approved_sentences()[id]["sentence"], id + " uses the exact approved panel sentence")
	expect.call(instance.get("rule", "") == RULE_IDS[index] and int(instance.get("source", {}).get("id", -1)) == int(state["enemies"][0]["id"]), id + " installs its data instance")
	expect.call(state["enemies"].size() == 1 + int(HELPER_COUNTS[index]) and state["enemies"][0]["pos"] == Vector2i(4,3), id + " retains the dragon slot and approved helper count")
	for slot: int in range(1, 1 + int(HELPER_COUNTS[index])):
		expect.call(state["enemies"][slot]["type"] == HELPERS[index] and state["enemies"][slot]["pos"] == (Vector2i(2,3) if slot == 1 else Vector2i(6,5)), id + " spawns the exact lieutenant in its slot")
	for intent: Dictionary in Data.enemy_def(id)["intents"]:
		for action: Dictionary in intent["actions"]:
			expect.call(str(action.get("committed_shape", "")) not in ["surface_snapshot", "trail_snapshot"] and not action.has("field_anchor") and not action.has("record_trail") and str(action.get("type", "")) != "raise_terrain", id + " has no retired rider")
	# Use real clock routing, helper turns, start/end effects and committed beats.
	for _turn: int in range(ROUTING_TURN_LIMIT):
		if int(state.get("battlefield_rule", {}).get("beats_fired", 0)) > 0 or not engine.combat_outcome(state).is_empty(): break
		state = Commit.advance_to_player(engine, Commit.finish_player_activation(engine, state))["state"]
	expect.call(int(state.get("battlefield_rule", {}).get("beats_fired", 0)) > 0, id + " fires through the production turn clock")
	if index < 4:
		var finite: Dictionary = Boss._boss_combat_state(id)
		for slot: int in range(1, finite["enemies"].size()): finite["enemies"][slot]["hp"] = 0
		for _activation: int in range(5): finite = Commit.enemy_turn(engine, finite, 0)["state"]
		var dead: bool = true
		for slot: int in range(1, finite["enemies"].size()): dead = dead and int(finite["enemies"][slot]["hp"]) == 0
		expect.call(finite["enemies"].size() == 1 + int(HELPER_COUNTS[index]) and dead, id + " never renews its finite lieutenants")

static func beat_fixture(id: String) -> Dictionary:
	var state: Dictionary = Boss._boss_combat_state(id)
	# Debug-only floor/fuel witnesses; production actors, health and intents stay.
	for y: int in range(1, 8):
		for x: int in range(1, 8): state["grid"][y][x] = "stone"
	state["terrain"] = []
	state["traps"] = []
	for pair: Array in [[Vector2i(3,5), "fire"], [Vector2i(2,3), "ice"], [Vector2i(6,5), "electrified"]]: Surfaces.place(state, pair[0], pair[1])
	Rules.prepare(Combat.new(), state)
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	return state

static func _test_forecast_and_half(expect: Callable, id: String) -> void:
	var engine := Combat.new()
	var state: Dictionary = beat_fixture(id)
	var snapshot: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Rules.forecast(engine, state)
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	var actual: Dictionary = Outcomes.project(engine, state, after)
	for key: String in actual: expect.call(forecast.get(key) == actual[key], id + " forecast equals resolved " + key)
	expect.call(snapshot == state, id + " forecast leaves the live board unchanged")
	var authored: Dictionary = acceptance()[id].duplicate(true)
	state["enemies"][0]["hp"] = int(state["enemies"][0]["max_hp"]) / 2
	state = Commit.accept(engine, state)
	if id == "noctyrax":
		expect.call(not state["battlefield_rule"].has("half_health_switched") and not authored.has("at_half_health"), "Noctyrax has no half-Health switch")
		return
	var expected: Dictionary = authored.duplicate(true)
	for field: String in ["cadence","dials"]:
		if authored["at_half_health"].has(field): expected[field].merge(authored["at_half_health"][field],true)
	expected["sentence"] = authored["at_half_health"]["sentence"]
	for key: String in ["cadence", "dials", "sentence"]: expect.call(state["battlefield_rule"][key] == expected[key], id + " applies half-Health " + key)
	expect.call(state["battlefield_rule"]["sentence"] == approved_sentences()[id]["at_half_health_sentence"], id + " uses the exact approved half-Health sentence")
	expect.call(bool(state["battlefield_rule"].get("half_health_switched", false)), id + " latches the half-Health switch")
	var count: int = state["surface_events"].size()
	state = Commit.accept(engine, state)
	expect.call(state["surface_events"].size() == count, id + " switches exactly once")

static func _stone(tile: Vector2i, owner_kind: String, owner: int) -> Dictionary:
	return {"id": "test_%s_%s" % [tile, owner_kind], "kind": "crag_outcrop", "pos": tile, "hp": 4, "max_hp": 4, "owner_kind": owner_kind, "owner_id": owner, "surface_on_destroy": "rubble"}

static func _test_faultline(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._arena("tharokh")
	var id: int = int(state["enemies"][0]["id"])
	state["terrain"] = [_stone(Vector2i(2,4), "enemy", id), _stone(Vector2i(6,6), "player", id), _stone(Vector2i(7,6), "enemy", 999)]
	load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._declare(expect, state, "faultline")
	var burst: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._action(expect, state, "terrain_burst")
	expect.call(int(burst["radius"]) == 1, "Faultline uses radius 1")
	var tiles: Array = engine._boss_action_threat_tiles(state, state["enemies"][0], burst)
	expect.call(tiles.has(Vector2i(1,4)) and not tiles.has(Vector2i(2,2)) and not tiles.has(Vector2i(6,5)), "Faultline forecasts radius one around only its own stone")
	state = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._resolve_action(state, burst)
	expect.call(engine._dragon_spires(state).is_empty() and engine._terrain_index_at_tile(state, Vector2i(6,6)) >= 0 and engine._terrain_index_at_tile(state, Vector2i(7,6)) >= 0, "Faultline consumes only Tharokh's enemy-owned Outcrops")
	# Held Upheaval marks use the same route guard in planning and resolution.
	state = Boss._boss_combat_state("tharokh")
	var held: Array = state["battlefield_rule"]["marks"].duplicate()
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	var predicted: Dictionary = Rules.forecast(engine, state)
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	state = Rules.fire(engine, state)
	for tile: Vector2i in predicted["tiles"]["rise"]:
		expect.call(held.has(tile) and engine._terrain_index_at_tile(state, tile) >= 0, "Upheaval resolves its held, route-safe marks")
	# preserve_owned_terrain retains the current lane geometry and spares stone.
	state = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._arena("tharokh")
	state["terrain"] = [_stone(Vector2i(3,3), "enemy", id)]
	load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._declare(expect, state, "bedrock_breath")
	var lane: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._action(expect, state, "aoe", "line")
	expect.call(bool(lane.get("preserve_owned_terrain", false)), "Tharokh's lane retains preserve_owned_terrain")
	var lane_tiles: Array = preload("res://scripts/guardian_combat_rules.gd").live_tiles(engine, state, state["enemies"][0], lane)
	expect.call(lane_tiles.has(Vector2i(2,3)), "Tharokh's lane sees through its own Outcrop as it did its old spires")
	state = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._resolve_action(state, lane)
	expect.call(engine._terrain_index_at_tile(state, Vector2i(3,3)) >= 0, "Tharokh's lane spares its owned Outcrop")

static func _test_fire_ownership(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._arena("vyraketh")
	var owner: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._owner(state)
	Surfaces.place(state, Vector2i(3,5), "fire", owner)
	state["enemies"][0]["cinder_tiles"] = engine._vector2i_values([Vector2i(3,5)])
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	state = Rules.fire(engine, state)
	var spread: Array = Surfaces.tiles(state, "fire").filter(func(tile: Vector2i) -> bool: return tile != Vector2i(3,5))
	expect.call(not spread.is_empty(), "Wildfire spreads actual Fire")
	for tile: Vector2i in spread: expect.call(Surfaces.surface_at(state, tile)["elemental_source"]["actor_id"] == owner["actor_id"], "Beat Fire belongs to Vyraketh")
	expect.call(engine._cinder_fire_entries(state, int(owner["actor_id"])).size() == 1, "Crownfire remembers only its original marks")
	var steps: Array[Dictionary]
	state = engine._enemy_detonate_cinders(state, 0, {"damage":8, "element":"fire"}, steps)
	for tile: Vector2i in spread: expect.call(Surfaces.has_surface(state, tile, "fire"), "Crownfire leaves spread Fire undetonated")
	load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._declare(expect, state, "cinder_maw")
	var renew: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._action(expect, state, "cinder_marks")
	Surfaces.place(state, Vector2i(7,2), "fire", {"actor_kind":"player"})
	state = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._resolve_action(state, renew)
	for tile: Vector2i in spread:
		if not renew["declared_tiles"].has(tile): expect.call(not Surfaces.has_surface(state, tile, "fire"), "Maw retires beat-owned spread")
	expect.call(Surfaces.has_surface(state, Vector2i(7,2), "fire"), "Maw preserves player Fire")

static func _test_mantle(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._arena("iskaldra")
	Surfaces.place(state, state["enemies"][0]["pos"], "ice")
	var hp: int = int(state["enemies"][0]["hp"])
	state["enemies"][0]["frost_armor"] = 1
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	state = Rules.fire(engine, state)
	expect.call(int(state["enemies"][0]["hp"]) == hp and int(state["enemies"][0]["frost_armor"]) == 0, "Mantle absorbs the beat like any other damage")
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	state = Rules.fire(engine, state)
	expect.call(int(state["enemies"][0]["hp"]) == hp - 3 and int(state["enemies"][0].get("freeze", 0)) == 0, "Iskaldra takes three without being Frozen")

static func _test_legacy_save(expect: Callable) -> void:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://bos02_legacy.save")
	var state: Dictionary = Boss._boss_combat_state("vaeloryx")
	load("res://tests/suites/dragon_pressure_mechanics_suite.gd")._declare(expect, state, "razor_dive")
	var dive: Dictionary = state["enemies"][0]["intent"]
	dive["actions"][1]["record_trail"] = "dive_wake"
	dive["committed_plan"]["attack_action"]["record_trail"] = "dive_wake"
	state["enemies"][0]["dive_wake"] = [Vector2i(3,3)]
	state["terrain"] = [{"id":"legacy", "kind":"dragon_spire", "pos":Vector2i(7,7), "hp":4, "owner_id":1}]
	expect.call(Store.save_run_state({"mode":"combat", "combat_state":state}), "Legacy dragon fields save")
	var loaded: Dictionary = Store.load_saved_run()["combat_state"]
	expect.call(not loaded["enemies"][0].has("dive_wake") and loaded["terrain"][0]["kind"] == "crag_outcrop" and loaded["terrain"][0]["owner_kind"] == "enemy", "Old saves drop dive_wake and migrate dragon_spire to ordinary Outcrops")
	var loaded_dive: Dictionary = loaded["enemies"][0]["intent"]
	expect.call(not loaded_dive["actions"][1].has("record_trail") and not loaded_dive["committed_plan"]["attack_action"].has("record_trail"), "Old Razor saves drop both active and cached wake recorders")
	expect.call(loaded_dive["committed_plan"]["projected_attack"] == dive["committed_plan"]["projected_attack"], "Old Razor saves preserve the retained held attack geometry")
	state = Boss._boss_combat_state("zekarion")
	var overload: Dictionary = Data.enemy_def("zekarion")["intents"][2].duplicate(true)
	# bos-02: old saves preserve their pre-tuning bolt while dropping its rider.
	overload["actions"][0]["damage"] = 4
	overload["actions"].append({"type":"aoe", "damage":5, "committed_shape":"surface_snapshot", "snapshot_surface":"electrified"})
	state["enemies"][0]["intent"] = preload("res://scripts/guardian_combat_rules.gd").commit(Combat.new(), state, 0, overload)
	expect.call(Store.save_run_state({"mode":"combat", "combat_state":state}), "Legacy Overload rider saves")
	loaded = Store.load_saved_run()["combat_state"]
	var loaded_overload: Dictionary = loaded["enemies"][0]["intent"]
	expect.call(loaded_overload["actions"].size() == 1 and int(loaded_overload["actions"][0]["damage"]) == 4 and not loaded_overload.has("committed_plan"), "Old Overload saves retain shot 4 and discard the removed rider's held plan")
	Store.set_run_storage_path(previous)
