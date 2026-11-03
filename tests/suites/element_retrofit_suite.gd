extends RefCounted
## Binding instance contract from element_rules/design.md §3–4.
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Warbands = preload("res://tests/suites/warband_suite.gd")
const Snares = preload("res://tests/suites/snare_suite.gd")
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const CONTRACT: Dictionary = {
	"earth": {"key": "thornmother", "rule": "upheaval", "dials": {"pattern": "line_between", "length": 5, "health": 3}, "room_dials": {"pattern": "exit_lane", "health": 3}},
	"fire": {"key": "slagmaster", "rule": "wildfire", "dials": {"spread": "toward_player"}, "room_dials": {"spread": "away_from_entry"}},
	"air": {"key": "stormcaller", "rule": "gust", "dials": {"tiles": 1, "direction": "aimed"}, "room_dials": {"tiles": 1, "direction": "toward_entry"}},
	"ice": {"key": "oracle", "rule": "frostbite", "dials": {"damage": 2}, "room_dials": {"damage": 1}},
	"lightning": {"key": "dynamo", "rule": "lightning_storm", "dials": {"damage": 4, "chain": 0}, "room_dials": {"damage": 3, "chain": 0}},
	"shadow": {"key": "prior", "rule": "shadowstep", "dials": {"blink": 3}, "room_dials": {"blink": 2}},
}
# Chosen defaults: private persistence path and synthetic analytics identity.
const PRESSURE_SAVE: String = "user://el02-pressure-roundtrip.save"
const PRESSURE_COMBAT_ID: String = "el02-pressure-roundtrip"
const LEGACY_SAVE: String = "user://el02-legacy.save"
static func run(expect: Callable) -> void:
	run_orders(expect)
	run_pressures(expect)
	legacy_saves(expect)
	ordinary_enemies(expect)

static func run_orders(expect: Callable) -> void:
	var engine := Combat.new()
	for biome: String in CONTRACT:
		var row: Dictionary = CONTRACT[biome]
		for tier: int in [1, 2, 3]:
			var state: Dictionary = Warbands.battle(biome, tier)
			var instance: Dictionary = Rules.active(state)
			expect.call(not instance.is_empty(), "Warband installs instance: " + biome)
			if instance.is_empty(): continue
			var source: Dictionary = preload("res://scripts/warband_combat_rules.gd").captain(state)
			expect.call(instance["rule"] == row["rule"], "Warband rule: " + biome)
			expect.call(instance["source"] == {"kind": "enemy", "id": int(source["id"])}, "Warband source: " + biome)
			var cadence: Dictionary = {"anchor": "on_intent", "intent": "discharge"} if biome == "lightning" else {"anchor": "after_source_turn", "every": 1 if biome == "air" else 2}
			expect.call(same(instance["cadence"], cadence), "Warband cadence: " + biome)
			expect.call(same(instance["dials"], row["dials"]), "Warband dials: " + biome)
			var order: Dictionary = preload("res://scripts/warband_combat_rules.gd").order_for_objective(state["objective"])
			expect.call(order["text"] == instance["sentence"], "Warband exact panel sentence: " + biome)
			expect.call(Rules.error_for(state, instance).is_empty(), "Warband valid instance: " + biome)
			var steps: Array[Dictionary]
			var before: Dictionary = state.duplicate(true)
			state = Rules.dispatch(engine, state, str(cadence["anchor"]), -99, "discharge", steps)
			expect.call(state == before, "Follower cannot advance captain cadence: " + biome)
			# Freeze/skip completion counts, but on_intent never fires a skipped intent.
			state = Rules.complete_source_turn(engine, state, steps, int(source["id"]))
			expect.call(int(state["battlefield_rule"]["beats_fired"]) == (1 if biome == "air" else 0), "First source turn cadence: " + biome)
			state = Rules.complete_source_turn(engine, state, steps, int(source["id"]), "discharge" if biome == "lightning" else "")
			expect.call(int(state["battlefield_rule"]["beats_fired"]) == (2 if biome == "air" else 1), "Second source turn beat: " + biome)
			state["enemies"][0]["hp"] = 0
			Rules.clear_dead_source(state)
			expect.call(Rules.active(state).is_empty(), "Captain death ends rule: " + biome)
	var dynamo: Dictionary = Warbands.battle("lightning", 3)
	dynamo["enemies"][0]["charge"] = 2
	var intents: Array = Data.enemy_def("storm_capacitor")["intents"]
	expect.call(preload("res://scripts/enemy_mechanics/capacitor.gd").choose(dynamo["enemies"][0], intents, dynamo)["id"] == "charge", "Dynamo retains ordinary three-Charge threshold")

static func run_pressures(expect: Callable) -> void:
	var engine := Combat.new()
	for biome: String in CONTRACT:
		var row: Dictionary = CONTRACT[biome]
		for tier: int in [1, 2, 3]:
			var state: Dictionary = engine.create_combat(83, preload("res://scripts/room_generator.gd").new().generate_room(83, preload("res://tools/snare_inspection.gd").room_spec(biome, tier), Vector2i.RIGHT), {"hp": 100, "max_hp": 100, "deck_cards": []})
			var instance: Dictionary = Rules.active(state)
			expect.call(not instance.is_empty(), "Snare installs instance: " + biome)
			if instance.is_empty(): continue
			expect.call(instance["rule"] == row["rule"], "Snare rule: " + biome)
			expect.call(instance["source"] == {"kind": "room"}, "Snare room source: " + biome)
			expect.call(same(instance["cadence"], {"anchor": "after_player_turn", "every": 1}), "Snare cadence: " + biome)
			expect.call(same(instance["dials"], row["room_dials"]), "Snare dials: " + biome)
			expect.call(Pressure.definition(state)["text"] == instance["sentence"], "Snare exact panel sentence: " + biome)
			expect.call(Rules.error_for(state, instance).is_empty(), "Snare valid instance: " + biome)
			if biome == "fire": expect.call(Surfaces.element_at(state, state["snare_entry"]) == "fire", "Fire seeds entry before first beat")
			if biome == "ice": expect.call(not Surfaces.tiles(state, "ice").is_empty(), "Ice thresholds retained")
			state["analytics"] = {"combat_id": PRESSURE_COMBAT_ID}
			if biome == "shadow": state["umbra"]["stage"] = Combat.UMBRA_STAGE_FRINGE
			var initial_radius: int = engine.effective_umbra_radius(state)
			for turn: int in [1, 2]:
				Pressure.resolve(engine, state, turn)
				expect.call(int(state["battlefield_rule"]["beats_fired"]) == turn, "Pressure uses one shared beat per boundary: " + biome)
				if biome == "shadow":
					expect.call(initial_radius > 2 and engine.effective_umbra_radius(state) == initial_radius - turn / 2 and int(state["snare_pressure"]["radius_loss"]) == turn / 2, "Umbra shrinks exactly once at turn two")
				state = _pressure_roundtrip(engine, state, turn, expect)

static func _pressure_roundtrip(engine: RefCounted, state: Dictionary, turn: int, expect: Callable) -> Dictionary:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path(PRESSURE_SAVE)
	expect.call(Store.save_run_state({"combat_state": state}), "Pressure boundary save writes")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {})
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	expect.call(loaded == state, "Pressure save/load preserves the whole combat state")
	var before: Dictionary = state.duplicate(true)
	var events: Array = state.get("surface_events", []).duplicate(true)
	var telemetry: Array[Dictionary] = preload("res://scripts/snare_pressure_analytics.gd").records(state, {})
	var boundary_events: Array = events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "snare_pressure" and int(event.get("player_turn", -1)) == turn)
	expect.call(boundary_events.size() == 1, "Each completed boundary records exactly one pressure event")
	for resumed: Dictionary in [state, loaded]:
		# Cover standalone and production's already-dispatched boundary paths.
		for rule_dispatched: bool in [false, true]:
			Pressure.resolve(engine, resumed, turn, rule_dispatched)
			expect.call(resumed == before, "Repeated pressure boundary preserves whole state, before and after load")
			expect.call(resumed.get("surface_events", []) == events, "Repeated pressure boundary preserves events and sequence numbers")
			expect.call(preload("res://scripts/snare_pressure_analytics.gd").records(resumed, {}) == telemetry, "Repeated pressure boundary emits no duplicate telemetry")
	return loaded

static func legacy_saves(expect: Callable) -> void:
	for kind: String in ["bramble", "ice_pillar"]:
		var saved: Dictionary = {"surface_rules_version": Surfaces.RULES_VERSION, "combat_state": {"terrain": [{"kind": kind, "pos": Vector2i(2, 2), "rounds_left": 3}, {"kind": "outcrop", "pos": Vector2i(3, 2), "hp": 3}], "player": {"hp": 17}, "turn": 4}, "log": [kind]}
		var file := FileAccess.open(LEGACY_SAVE, FileAccess.WRITE)
		file.store_var(saved)
		file.close()
		var loaded: Dictionary = Store._load_run_dictionary(LEGACY_SAVE)
		expect.call(loaded["combat_state"]["terrain"].size() == 1 and loaded["combat_state"]["terrain"][0] == saved["combat_state"]["terrain"][1], "Load removes legacy terrain only: " + kind)
		expect.call(loaded["combat_state"]["player"] == saved["combat_state"]["player"] and loaded["combat_state"]["turn"] == 4 and loaded["log"] == saved["log"], "Load preserves boundary and history: " + kind)
		DirAccess.remove_absolute(LEGACY_SAVE)
	for old_type: String in ["grow_bramble"]:
		var saved: Dictionary = {"combat_state": {"enemies": [{"id": 1, "intent": {"id": "thornwall", "name": "held", "time": 5, "actions": [{"type": old_type, "damage": 4}]}}]}}
		var file := FileAccess.open(LEGACY_SAVE, FileAccess.WRITE)
		file.store_var(saved)
		file.close()
		var loaded: Dictionary = Store._load_run_dictionary(LEGACY_SAVE)
		var intent: Dictionary = loaded["combat_state"]["enemies"][0]["intent"]
		expect.call(intent["id"] == saved["combat_state"]["enemies"][0]["intent"]["id"] and int(intent["time"]) == 5 and intent["name"] == "held", "Legacy action keeps intent identity and Time: " + old_type)
		expect.call(intent["actions"][0]["type"] == "upheaval_mark", "Legacy action resumes through shared piece: " + old_type)
		DirAccess.remove_absolute(LEGACY_SAVE)

static func ordinary_enemies(expect: Callable) -> void:
	var engine := Combat.new()
	var fixture: GDScript = preload("res://tests/suites/en04_enemies_suite.gd")
	var state: Dictionary = fixture.fixture(engine)
	var action: Dictionary = fixture.intent("briar_weaver", "thornwall")["actions"][0]
	var weaver: GDScript = preload("res://scripts/enemy_mechanics/bramble.gd")
	state = weaver.resolve(engine, state, 0, action)
	expect.call(state["terrain"].is_empty(), "Thornwall is a mark, not immediate terrain")
	var marks: Array = state["enemies"][0]["upheaval_pending"]["marks"].duplicate()
	state["player"]["pos"] = marks[0]
	var prior: Vector2i = state["player"]["pos"]
	state = engine.prepare_next_player_turn(state)
	state = weaver.begin_turn(engine, state, 0)
	expect.call(state["player"]["pos"] != prior, "Thornwall uses Upheaval displacement")
	for tile: Vector2i in marks:
		var index: int = engine._terrain_index_at_tile(state, tile)
		expect.call(index >= 0 and int(state["terrain"][index]["hp"]) == 3, "Thornwall raises health-3 Outcrops")
	var thralls: GDScript = preload("res://tests/helpers/thr01_fixture.gd")
	state = thralls.bolt()
	state = engine._resolve_enemy_intent(state, 0, state["enemies"][0]["intent"])
	expect.call(Surfaces.element_at(state, state["player"]["pos"]) == "electrified", "Arc Bolt uses the existing Electrified target rider")
	for key: String in ["wildfire", "frostbite", "lightning_storm", "upheaval", "shadowstep"]:
		expect.call(Icons.icon_texture(key) != null, "Approved rule icon loads: " + key)

static func same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not same(a[index], b[index]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return float(a) == float(b)
	return a == b
