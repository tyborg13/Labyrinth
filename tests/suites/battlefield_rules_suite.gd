extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Outcomes = preload("res://scripts/battlefield_rules/outcomes.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Fixtures = preload("res://tests/suites/en02_enemies_suite.gd")
const SnareFixtures = preload("res://tests/suites/snare_pressure_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/battlefield_rules/analytics.gd")
const Gust = preload("res://scripts/enemy_mechanics/wind.gd")
# Chosen defaults: existing fixed-board fixture, private save path, proof damage.
const SAVE_PATH: String = "user://el01-roundtrip.save"
const TEST_DAMAGE: int = 2
const TEST_BLINK: int = 3

static func battle(engine: RefCounted) -> Dictionary:
	var state: Dictionary = Fixtures.fixture(engine, "crawler")
	state["enemies"][0]["pos"] = Vector2i(5, 2)
	state["enemies"][0]["hp"] = 50
	state["enemies"][0]["max_hp"] = 50
	state["enemies"][0]["intent"] = {"id": "test_wait", "time": 4, "actions": []}
	return state

static func rule(id: String, dials: Dictionary, enemy_source: bool = false) -> Dictionary:
	return {"rule": id, "source": {"kind": "enemy", "id": 1} if enemy_source else {"kind": "room"}, "cadence": {"anchor": "after_source_turn" if enemy_source else "after_player_turn", "every": 1}, "dials": dials, "sentence": "Test battlefield rule."}

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	_gust(engine, expect)
	_wildfire(engine, expect)
	_frostbite(engine, expect)
	_lightning(engine, expect)
	_upheaval(engine, expect)
	_shadowstep(engine, expect)
	_framework(engine, expect)
	preload("res://tests/suites/battlefield_rules_feedback_suite.gd").run(engine, battle, rule, resolve_and_compare, expect)
	preload("res://tests/suites/battlefield_rules_feedback_2_suite.gd").run(engine, battle, rule, resolve_and_compare, expect)
	print("Battlefield rules: six resolvers, all implemented dials, cadence, privacy, saves and analytics checked")

static func mature_fuel(state: Dictionary) -> void:
	# Primitive resolver witnesses explicitly model already-observed ground.
	# Fresh-ground scheduling is covered separately by battlefield_fuel_suite.
	state["turn"] = int(state.get("turn",1))+1

static func resolve_and_compare(engine: RefCounted, state: Dictionary, expect: Callable) -> Dictionary:
	mature_fuel(state)
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Rules.forecast(engine, state)
	expect.call(state == before, "Forecast is pure: " + str(state["battlefield_rule"]["rule"]))
	expect.call(not forecast.has("state"), "Public forecast never exposes a resolver snapshot")
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	var resolved: Dictionary = Outcomes.project(engine, before, after)
	var comparable: Dictionary = forecast.duplicate(true)
	comparable.erase("direction")
	# Collision sources are identical resolver contexts; snapshots never emit beats.
	expect.call(comparable == resolved, "Forecast equals real resolution: " + str(state["battlefield_rule"]["rule"]))
	expect.call(before.get("surface_events", []).filter(func(event: Dictionary) -> bool: return event.get("kind", "") == "battlefield_rule_fired").is_empty(), "Forecast emits no committed analytics")
	return after

static func _gust(engine: RefCounted, expect: Callable) -> void:
	for mode: String in ["aimed", "toward_entry", "fixed:up", "fixed:right", "fixed:down", "fixed:left"]:
		for distance: int in [1, 2]:
			var state: Dictionary = battle(engine)
			state["snare_entry"] = Vector2i(1, 5)
			var instance: Dictionary = rule("gust", {"tiles": distance, "direction": mode})
			instance["locked_direction"] = Vector2i.RIGHT
			Rules.install(engine, state, instance)
			var after: Dictionary = resolve_and_compare(engine, state, expect)
			var axis: Vector2i = {"aimed": Vector2i.RIGHT, "toward_entry": Vector2i.LEFT, "fixed:up": Vector2i.UP, "fixed:right": Vector2i.RIGHT, "fixed:down": Vector2i.DOWN, "fixed:left": Vector2i.LEFT}[mode]
			expect.call(after["player"]["pos"] == Vector2i(5, 5) + axis * distance, "Gust resolves authored direction and distance: " + mode)
	var state: Dictionary = battle(engine)
	state["player"]["anchored"] = true
	Rules.install(engine, state, rule("gust", {"tiles": 1, "direction": "fixed:right"}, true))
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(after["player"]["pos"] == state["player"]["pos"] and after["player"]["hp"] == state["player"]["hp"], "Gust Anchored guard prevents movement and collision")
	expect.call(after["enemies"][0]["pos"] == Vector2i(6, 2), "Gust gives its wielder no immunity")
	state = battle(engine)
	state["enemies"].append(Fixtures.enemy(2, Vector2i(6, 5)))
	state["enemies"].append(Fixtures.enemy(3, Vector2i(7, 5)))
	Rules.install(engine, state, rule("gust", {"tiles": 1, "direction": "fixed:right"}))
	after = resolve_and_compare(engine, state, expect)
	expect.call(after["player"]["pos"] == Vector2i(6, 5) and after["enemies"][2]["pos"] == Vector2i(8, 5), "Gust keeps farthest-first packed-line ordering")
	state["grid"][5][8] = "wall"
	after = resolve_and_compare(engine, state, expect)
	expect.call(not Rules.forecast(engine, state)["collision_markers"].is_empty(), "Gust blocked slides use real Collision markers")
	state = battle(engine)
	state["player"]["pos"] = Vector2i(9, 5)
	state["umbra"] = {"stage": "heart"}
	Rules.install(engine, state, rule("gust", {"tiles": 1, "direction": "fixed:right"}, true))
	var private_forecast: Dictionary = Rules.forecast(engine, state)
	expect.call(not private_forecast["collision_markers"].is_empty() and not private_forecast["collision_markers"][0].has("source"), "Gust forecast collision metadata never names its hidden source")
	resolve_and_compare(engine, state, expect)
	for mode: String in ["toward_source", "turn_clockwise", "fixed:invalid"]:
		expect.call(not Rules.error_for(state, rule("gust", {"tiles": 1, "direction": mode})).is_empty(), "Gust future direction errors: " + mode)

static func _wildfire(engine: RefCounted, expect: Callable) -> void:
	for mode: String in ["toward_player", "away_from_entry", "all"]:
		var state: Dictionary = battle(engine)
		state["snare_entry"] = Vector2i(1, 5)
		state["enemies"][0]["pos"] = Vector2i(2, 5)
		Surfaces.place(state, Vector2i(3, 5), "fire")
		Surfaces.place(state, Vector2i(4, 5), "ice")
		Rules.install(engine, state, rule("wildfire", {"spread": mode}, true))
		if mode == "toward_player":
			state["player"]["pos"] = Vector2i(2, 8)
			expect.call(Rules.forecast(engine, state)["direction"] == Vector2i.RIGHT, "Wildfire toward_player locks its next direction before hero movement")
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(Surfaces.element_at(after, Vector2i(4, 5)) == "fire" and Surfaces.element_at(after, Vector2i(5, 5)) != "fire", "Wildfire snapshot guard prevents recursive spread")
		expect.call(Surfaces.element_at(after, Vector2i(3, 4)) == ("fire" if mode == "all" else ""), "Wildfire spread dial: " + mode)
	var state: Dictionary = battle(engine)
	Surfaces.place(state, Vector2i(4, 5), "fire")
	state["self_flags"] = {"fire_immune_turn": {}}
	state["terrain"] = [{"pos": Vector2i(4, 4), "hp": 3, "kind": "crag_outcrop"}]
	state["grid"][6][4] = "wall"
	Rules.install(engine, state, rule("wildfire", {"spread": "all"}))
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(after["player"]["hp"] == state["player"]["hp"] and Surfaces.element_at(after, Vector2i(5, 5)) == "fire", "Wildfire placement adds no direct damage and respects Fireproof")
	expect.call(Surfaces.element_at(after, Vector2i(4, 4)).is_empty() and Surfaces.element_at(after, Vector2i(4, 6)).is_empty(), "Wildfire placement stops at terrain and walls")
	expect.call(not Rules.error_for(state, rule("wildfire", {"spread": "invalid"})).is_empty(), "Wildfire rejects unknown spread")

static func _frostbite(engine: RefCounted, expect: Callable) -> void:
	for damage: int in [0, 1, TEST_DAMAGE]:
		var state: Dictionary = battle(engine)
		for tile: Vector2i in [Vector2i(5, 5), Vector2i(5, 2)]: Surfaces.place(state, tile, "ice")
		state = engine._surface_contact(state, "player", -1, engine.INVALID_TILE, true)
		state = engine._surface_contact(state, "enemy", 1, engine.INVALID_TILE, true)
		state["enemies"].append(Fixtures.enemy(2, Vector2i(7, 7)))
		Rules.install(engine, state, rule("frostbite", {"damage": damage}))
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(int(after["player"]["freeze"]) == 1 and int(after["enemies"][0]["freeze"]) == 1 and Surfaces.tiles(after, "ice").is_empty(), "Frostbite Ice hit Freezes and expends Ice, including zero damage")
		expect.call(after["enemies"][1]["hp"] == state["enemies"][1]["hp"] and int(after["enemies"][1].get("freeze", 0)) == 0, "Frostbite leaves off-Ice units untouched")
		expect.call(after["player"]["hp"] == state["player"]["hp"] - (damage + 2 if damage > 0 else 0), "Frostbite uses ordinary Chilled damage")
	var state: Dictionary = battle(engine)
	Surfaces.place(state, Vector2i(5, 5), "ice")
	state["self_flags"] = {"ice_skate": {}}
	state = engine._surface_contact(state, "player", -1, engine.INVALID_TILE, true)
	Rules.install(engine, state, rule("frostbite", {"damage": 0}))
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(int(after["player"].get("freeze", 0)) == 0 and Surfaces.unit_on(after, after["player"], "ice"), "Frostbite preserves existing Skate protection from Chill")
	expect.call(not Rules.error_for(state, rule("frostbite", {"damage": -1})).is_empty(), "Frostbite rejects negative damage")

static func _lightning(engine: RefCounted, expect: Callable) -> void:
	for chain: int in range(4):
		var state: Dictionary = battle(engine)
		state["enemies"][0]["pos"] = Vector2i(4, 5)
		state["enemies"].append(Fixtures.enemy(2, Vector2i(6, 5)))
		Surfaces.place(state, Vector2i(5, 5), "electrified")
		Rules.install(engine, state, rule("lightning_storm", {"damage": TEST_DAMAGE, "chain": chain}))
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(int(after["player"]["hp"]) == 48 and int(after["player"]["shock"]) == 1, "Lightning Storm strikes Electrified units with Shock")
		expect.call(after["surfaces"] == state["surfaces"], "Lightning Storm never changes the field")
		expect.call(int(after["enemies"][0]["hp"]) == (50 if chain == 0 else 48) and int(after["enemies"][1]["hp"]) == (20 if chain == 0 else 18), "Lightning Storm chain dial uses existing Chain route: " + str(chain))
	var state: Dictionary = battle(engine)
	Rules.install(engine, state, rule("lightning_storm", {"damage": TEST_DAMAGE, "chain": 3}))
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(after["player"] == state["player"] and after["enemies"] == state["enemies"], "Lightning Storm empty-field guard prevents free Chain hits")
	Surfaces.place(state, Vector2i(5, 5), "electrified")
	state["battlefield_rule"]["dials"]["damage"] = 0
	after = resolve_and_compare(engine, state, expect)
	expect.call(after["player"]["hp"] == state["player"]["hp"] and int(after["player"]["shock"]) == 1, "Lightning Storm zero damage still applies Shock")
	expect.call(not Rules.error_for(state, rule("lightning_storm", {"damage": 1, "chain": 4})).is_empty(), "Lightning Storm rejects out-of-range Chain")

static func _upheaval(engine: RefCounted, expect: Callable) -> void:
	for length: int in [3, 5]:
		var state: Dictionary = battle(engine)
		state["enemies"].append(Fixtures.enemy(2, Vector2i(5, 4)))
		Rules.install(engine, state, rule("upheaval", {"pattern": "line_between", "length": length, "health": 3}, true))
		var marks: Array = state["battlefield_rule"]["marks"].duplicate()
		expect.call(marks.size() == length and marks.has(Vector2i(5, 4)), "Upheaval extends existing perpendicular geometry")
		state["player"]["pos"] = Vector2i(7, 7)
		expect.call(state["battlefield_rule"]["marks"] == marks, "Upheaval keeps marks locked a beat ahead")
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(after["terrain"].size() == length and after["terrain"][0]["hp"] == 3, "Upheaval raises authored-health Outcrops")
		expect.call(after["enemies"][1]["pos"] != Vector2i(5, 4), "Upheaval displaces occupants via Erupt")
	var state: Dictionary = SnareFixtures.battle("earth")
	Rules.install(engine, state, Rules.instance_for("snare_earth"))
	var mark: Vector2i = state["battlefield_rule"]["marks"][0]
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(engine._terrain_index_at_tile(after, mark) >= 0, "Upheaval exit_lane uses Snare's shortest-way selector")
	# A one-cell corridor has no alternate route: raising any interior tile seals it.
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()): state["grid"][y][x] = "floor" if y == 4 and x in range(1, 8) else "wall"
	state["terrain"] = []
	state["player"]["pos"] = Vector2i(4, 4)
	for exit: Dictionary in state["objective"]["exits"]: exit["sealed"] = exit["target_tile"] != Vector2i(7, 4)
	expect.call(not Rules.Upheaval.leaves_exit(state, Vector2i(6, 4)), "Upheaval last-way guard never seals the last open exit")
	state["battlefield_rule"]["marks"] = [Vector2i(6, 4)]
	after = resolve_and_compare(engine, state, expect)
	expect.call(after["terrain"].is_empty(), "Upheaval rechecks last-way guard at resolution")
	for pattern: String in ["ring_around_player", "beside_terrain"]:
		expect.call(not Rules.error_for(state, rule("upheaval", {"pattern": pattern, "health": 3})).is_empty(), "Upheaval future pattern errors: " + pattern)

static func _shadowstep(engine: RefCounted, expect: Callable) -> void:
	for who: Variant in ["all_hidden", ["crawler"], ["acolyte"]]:
		var state: Dictionary = battle(engine)
		state["umbra"] = {"stage": "heart", "vision_bonus": 0, "stage_reduction": 0}
		state["player"]["pos"] = Vector2i(5, 5)
		state["enemies"][0]["pos"] = Vector2i(5, 1)
		Rules.install(engine, state, rule("shadowstep", {"blink": TEST_BLINK, "who": who}))
		var forecast: Dictionary = Rules.forecast(engine, state)
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(forecast["moves"].is_empty() and forecast["hits"].is_empty() and forecast["collision_markers"].is_empty(), "Shadowstep forecast never discloses hidden enemy origins, identities or landings")
		var selected: bool = (who is String and who == "all_hidden") or (who is Array and who.has("crawler"))
		expect.call((after["enemies"][0]["pos"] != state["enemies"][0]["pos"]) == selected, "Shadowstep who dial selects authored enemy types")
	var state: Dictionary = battle(engine)
	state["umbra"] = {"stage": "heart", "vision_bonus": 0, "stage_reduction": 0}
	state["enemies"][0]["pos"] = Vector2i(5, 1)
	state["enemies"].append(Fixtures.enemy(2, Vector2i(5, 2)))
	Rules.install(engine, state, rule("shadowstep", {"blink": TEST_BLINK}))
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(after["enemies"][1]["pos"] == Vector2i(5, 4) and after["enemies"][0]["pos"] == Vector2i(5, 3), "Shadowstep nearest-first ordering and deterministic landing ties")
	state["enemies"][0]["pos"] = Vector2i(5, 3)
	after = resolve_and_compare(engine, state, expect)
	expect.call(after["enemies"][0]["pos"] == state["enemies"][0]["pos"], "Shadowstep visibility guard excludes revealed enemies")
	state["enemies"][0]["pos"] = Vector2i(5, 1)
	state["battlefield_rule"]["dials"]["blink"] = 1
	after = resolve_and_compare(engine, state, expect)
	expect.call(after["enemies"][0]["pos"] == state["enemies"][0]["pos"], "Shadowstep stays put with no visible landing")
	expect.call(not Rules.error_for(state, rule("shadowstep", {"blink": 0})).is_empty(), "Shadowstep rejects nonpositive Blink")

static func _framework(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = battle(engine)
	var instance: Dictionary = rule("frostbite", {"damage": 0}, true)
	instance["cadence"]["every"] = 2
	Rules.install(engine, state, instance)
	Rules.dispatch(engine, state, "after_source_turn", 2)
	expect.call(int(state["battlefield_rule"]["counter"]) == 0, "Only the source advances source cadence")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(state["battlefield_rule"]["counter"]) == 1 and int(state["battlefield_rule"]["beats_fired"]) == 0, "Every-two source cadence counts first turn")
	state["enemies"][0]["freeze"] = 1
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(state["battlefield_rule"]["beats_fired"]) == 1 and int(state["battlefield_rule"]["counter"]) == 0, "Skipped source turns still count toward the beat")
	state = engine._damage_enemy(state, 0, 100, false)
	expect.call(Rules.active(state).is_empty() and state["battlefield_rule"].is_empty(), "Dead enemy source ends every rule immediately")
	state = battle(engine)
	instance = rule("frostbite", {"damage": 0}, true)
	instance["cadence"] = {"anchor": "on_intent", "intent": "test_wait"}
	Rules.install(engine, state, instance)
	Rules.dispatch(engine, state, "on_intent", 1, "other")
	expect.call(int(state["battlefield_rule"]["beats_fired"]) == 0, "on_intent ignores other intent IDs")
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(state["battlefield_rule"]["beats_fired"]) == 1, "on_intent resolves exactly once at source intent completion")
	state = battle(engine)
	instance = rule("frostbite", {"damage": 0})
	instance["cadence"]["every"] = 2
	Rules.install(engine, state, instance)
	state = engine.finish_player_activation(state)
	expect.call(int(state["battlefield_rule"]["counter"]) == 1, "Player cadence dispatches from normal completion")
	state = engine.finish_player_activation(state)
	expect.call(int(state["battlefield_rule"]["counter"]) == 1, "Repeated player completion never double-counts a beat")
	_primitive_edges(engine, expect)
	var ended: Dictionary = battle(engine)
	Rules.install(engine, ended, rule("lightning_storm", {"damage": TEST_DAMAGE, "chain": 0}))
	ended["player"]["hp"] = 0
	var ended_before: Dictionary = ended.duplicate(true)
	Rules.after_player_turn(engine, ended)
	expect.call(ended == ended_before and Rules.forecast(engine, ended)["hits"].is_empty(), "Completed fights never fire or forecast a later beat")
	var legacy_wind: Dictionary = Fixtures.fixture(engine, "gale_herald")
	legacy_wind["wind"] = {"direction": Vector2i.RIGHT, "rounds_left": 2, "source_id": 1}
	Gust.lock_legacy_intents(engine, legacy_wind)
	expect.call(Rules.active(legacy_wind).is_empty() and not legacy_wind.has("wind"), "Legacy saves load as none without a stale WindView mirror")
	_save_and_order(engine, expect)
	_migration(engine, expect)

static func _save_and_order(engine: RefCounted, expect: Callable) -> void:
	for id: String in Rules.RESOLVERS:
		var state: Dictionary = battle(engine)
		var template_id: String = {"gust": "stormcaller", "wildfire": "slagmaster", "frostbite": "oracle", "lightning_storm": "dynamo", "upheaval": "thornmother", "shadowstep": "prior"}[id]
		var instance: Dictionary = Rules.instance_for(template_id, 1)
		if id == "gust": instance["locked_direction"] = Vector2i.DOWN
		Rules.install(engine, state, instance)
		state["battlefield_rule"]["counter"] = 1
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_var({"combat_state": state}); file.close()
		var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
		expect.call(loaded == state and Rules.forecast(engine, loaded) == Rules.forecast(engine, state), "Save round-trip preserves dials, counters, marks and forecasts: " + id)
		var dead_source: Dictionary = engine._damage_enemy(state.duplicate(true), 0, 100, false)
		expect.call(Rules.active(dead_source).is_empty() and dead_source["battlefield_rule"].is_empty(), "Source death clears each resolver: " + id)
		var legacy: Dictionary = state.duplicate(true)
		legacy.erase("battlefield_rule"); legacy.erase("wind")
		Rules.prepare(engine, legacy)
		expect.call(Rules.active(legacy).is_empty() and not legacy.has("battlefield_rule"), "Legacy save without additive field loads as none")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var state: Dictionary = battle(engine)
	Rules.install(engine, state, rule("frostbite", {"damage": 0}, true))
	var order: Array[Dictionary] = engine.current_turn_order(state)
	var found: bool = false
	for index: int in range(1, order.size()):
		if str(order[index].get("kind", "")) != "beat": continue
		found = true
		expect.call(str(order[index - 1]["kind"]) == "enemy" and int(order[index - 1]["enemy_id"]) == 1 and int(order[index]["at"]) == int(order[index - 1]["time"]), "Turn-order beat sits immediately after its triggering source")
	expect.call(found, "Current turn-order projection includes the next beat")
	state["battlefield_rule"]["cadence"]["every"] = 2
	order = engine.current_turn_order(state, 20)
	var source_turns: int = 0
	for entry: Dictionary in order:
		if str(entry["kind"]) == "enemy" and int(entry.get("enemy_id", -1)) == 1: source_turns += 1
		if str(entry["kind"]) == "beat":
			expect.call(source_turns == 2, "Every-two beat follows the second projected source turn")
			break
	state["battlefield_rule"]["cadence"] = {"anchor": "after_player_turn", "every": 1}
	order = engine.current_turn_order(state)
	expect.call(order[0]["kind"] == "player" and order[1]["kind"] == "beat", "Player beat appears immediately after the active player turn")
	state["battlefield_rule"]["cadence"] = {"anchor": "on_intent", "intent": "test_wait"}
	order = engine.current_turn_order(state)
	expect.call(order.any(func(entry: Dictionary) -> bool: return str(entry["kind"]) == "beat"), "on_intent beat follows the announced matching intent")

static func _migration(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = Fixtures.fixture(engine, "gale_herald")
	state["enemies"][0]["intent"] = Fixtures.intent("gale_herald", "call_the_wind")
	state["enemies"].append(Fixtures.enemy(2, Vector2i(8, 8)))
	state = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
	var before: Dictionary = state.duplicate(true)
	state = engine.resolve_enemy_turn_with_steps(state, 1)["state"]
	expect.call(state["player"]["pos"] == before["player"]["pos"] and state["wind"]["rounds_left"] == before["wind"]["rounds_left"], "Gust migration never fires after a follower's turn")
	expect.call(Rules.panel(state) == {"rule": "gust", "name": "Gust", "icon": "wind", "sentence": "After each of the Gale Herald's turns, its wind Pushes everyone 1 tile."}, "Gust panel returns exact approved instance sentence")
	var events: Array = state["surface_events"].filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "battlefield_rule_fired")
	expect.call(events.size() == 1, "Only actual cadence beats record battlefield analytics")
	var record: Dictionary = Analytics.record(events[0], {}, "test_combat")
	expect.call(record["event_type"] == "battlefield_rule_fired" and record["payload"].size() == 9 and record["payload"]["source_type"] == "gale_herald" and record["payload"]["beat_index"] == 1, "Battlefield analytics has exact additive payload")
	var authored: Array = FileAccess.get_file_as_string("res://spec/peer_benchmark/element_rules/design.md").split("\n")
	authored.append_array(FileAccess.get_file_as_string("res://spec/peer_benchmark/encounter_redesign/bos_03_implementation.md").split("\n"))
	# bos-02 adds owner-approved dragon sentences after the original fixture
	# table. Its brief overrides the draft's broader Noctyrax wording.
	var dragons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos02_dragon_sentences.json"))
	for id: String in Rules.data()["instances"]:
		var sentence: String = Rules.data()["instances"][id]["sentence"]
		var approved: bool = sentence == str(dragons[id]["sentence"]) if dragons.has(id) else authored.any(func(line: String) -> bool: return line.ends_with(sentence + " |"))
		expect.call(approved, "Panel sentence is verbatim director data: " + id)

static func _primitive_edges(engine: RefCounted, expect: Callable) -> void:
	# Fireproof protects ordinary ground entry during a Gust, never by rule name.
	for fireproof: bool in [false, true]:
		var state: Dictionary = battle(engine)
		Surfaces.place(state, Vector2i(6, 5), "fire")
		if fireproof: state["self_flags"] = {"fire_immune_turn": {}}
		Rules.install(engine, state, rule("gust", {"tiles": 1, "direction": "fixed:right"}))
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(int(after["player"]["hp"]) == (50 if fireproof else 48), "Gust entry respects existing Fireproof")
	for id: String in ["frostbite", "lightning_storm"]:
		var state: Dictionary = battle(engine)
		state["illusions"] = [{"id": 7, "hp": 20, "max_hp": 20, "pos": Vector2i(6, 5)}]
		Surfaces.place(state, Vector2i(6, 5), "ice" if id == "frostbite" else "electrified")
		state = engine._surface_contact(state, "illusion", 7, engine.INVALID_TILE, true)
		Rules.install(engine, state, rule(id, {"damage": TEST_DAMAGE, "chain": 0}))
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(int(after["illusions"][0].get("freeze" if id == "frostbite" else "shock", 0)) == 1, "Battlefield hits include illusion statuses: " + id)
	for damage: int in [3, 4]:
		var state: Dictionary = battle(engine)
		Surfaces.place(state, state["player"]["pos"], "electrified")
		Rules.install(engine, state, rule("lightning_storm", {"damage": damage, "chain": 0}))
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(int(after["player"]["hp"]) == 50 - damage, "Lightning Storm supports each first-wave damage dial")
	for protection: String in ["light", "truesight"]:
		var state: Dictionary = battle(engine)
		state["umbra"] = {"stage": "heart", "light_sources": []}
		state["enemies"][0]["pos"] = Vector2i(5, 1)
		if protection == "truesight": state["umbra"]["truesight_activations"] = 1
		else: state["umbra"]["light_sources"] = [{"pos": Vector2i(5, 1), "radius": 0, "activations_left": 1}]
		Rules.install(engine, state, rule("shadowstep", {"blink": 2}))
		var after: Dictionary = resolve_and_compare(engine, state, expect)
		expect.call(after["enemies"][0]["pos"] == state["enemies"][0]["pos"], "Shadowstep respects existing revelation: " + protection)
	var state: Dictionary = battle(engine)
	state["umbra"] = {"stage": "heart"}
	state["enemies"][0]["pos"] = Vector2i(5, 2)
	Rules.install(engine, state, rule("shadowstep", {"blink": 2}))
	Surfaces.place(state, Vector2i(5, 4), "fire")
	var after: Dictionary = resolve_and_compare(engine, state, expect)
	expect.call(after["enemies"][0]["pos"] == Vector2i(5, 4) and int(after["enemies"][0]["hp"]) == 48, "Shadowstep Blink triggers ordinary ground entry")
	var lethal: Dictionary = SnareFixtures.battle("air")
	lethal["player"]["hp"] = 1
	lethal["player"]["pos"] = lethal["snare_entry"]
	lethal = engine.finish_player_activation(lethal)
	var pressure_events: Array = lethal["surface_events"].filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "snare_pressure")
	expect.call(int(lethal["player"]["hp"]) == 0 and int(lethal["objective"]["player_turns_completed"]) == 1 and pressure_events.size() == 1, "Lethal Gust preserves Snare round bookkeeping and its pressure analytics")
	_analytics_callers(engine, expect)

static func _analytics_callers(engine: RefCounted, expect: Callable) -> void:
	var store_script: GDScript = preload("res://scripts/analytics_store.gd")
	var previous: String = store_script.storage_dir()
	store_script.set_storage_dir("user://el01-analytics")
	var run_engine := preload("res://scripts/run_engine.gd").new()
	var run: Dictionary = run_engine.create_new_run(Fixtures.FIXTURE_SEED, Store.default_data())
	var state: Dictionary = battle(engine)
	state["analytics"] = {"combat_id": "el01-test-combat"}
	Surfaces.place(state, state["player"]["pos"], "electrified")
	Rules.install(engine, state, rule("lightning_storm", {"damage": TEST_DAMAGE, "chain": 0}))
	mature_fuel(state)
	state = Rules.fire(engine, state)
	for caller: String in ["UI", "console"]:
		store_script.clear_storage()
		var host = preload("res://scripts/run_scene.gd").new() if caller == "UI" else preload("res://tools/headless_playtest.gd").new()
		host.set("_analytics_store", store_script.new())
		host.set("_progression", run["progression"].duplicate(true))
		host.set("_run_state", run)
		for retry: int in range(2):
			if caller == "UI": host._analytics_flush_surface_events(state)
			else: host._log_combat_transition(run, "battlefield_test", state)
		var beats: Array = store_script.load_all_events().filter(func(event: Dictionary) -> bool: return event["event_type"] == "battlefield_rule_fired")
		expect.call(beats.size() == 1 and beats[0]["payload"]["damage_to_player"] == TEST_DAMAGE and beats[0]["payload"]["affected_units"] == 1, "Battlefield committed JSONL retries deduplicate in " + caller)
		host.free()
	store_script.clear_storage()
	store_script.set_storage_dir(previous)
