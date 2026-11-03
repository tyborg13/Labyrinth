extends RefCounted
## bos-01 debug-only fixtures; no encounter tuning or production data changes.
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const Outcomes = preload("res://scripts/battlefield_rules/outcomes.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Analytics = preload("res://scripts/battlefield_rules/analytics.gd")
const Store = preload("res://scripts/progression_store.gd")
const SAVE_PATH: String = "user://bos01-continue.save"
const PROOF_BEATS: int = 8
const CLOCKWISE: Array = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const HALF_SENTENCE: String = "After each of its turns, its wind Pushes everyone 2 tiles, then turns a quarter clockwise."

static func run(expect: Callable) -> void:
	var engine := preload("res://scripts/combat_engine.gd").new()
	_gust(engine, expect)
	_half_health(engine, expect)
	_routes(engine, expect)
	_ground(engine, expect)
	_default_save_fields(engine, expect)
	preload("res://tests/suites/bos01_feedback1_suite.gd").run(expect)
	preload("res://tests/suites/bos01_feedback2_suite.gd").run(expect)
	preload("res://tests/suites/bos01_bot_policy_suite.gd").run(expect)

static func committed_damage(engine: RefCounted, state: Dictionary, index: int, damage: int, amplified: bool = false) -> Dictionary:
	# The fixture explicitly accepts this action, as the UI/console commit path does.
	return Committed.accept(engine, engine._damage_enemy(state, index, damage, amplified))

static func _default_save_fields(engine: RefCounted, expect: Callable) -> void:
	for declared: bool in [false, true]:
		var state: Dictionary = Base.battle(engine)
		var authored: Dictionary = switch_instance() if declared else Base.rule("gust", {"tiles": 1, "direction": "fixed:up"}, true)
		Rules.install(engine, state, authored)
		state = Rules.fire(engine, state)
		var event: Dictionary = state["surface_events"].filter(func(value: Dictionary) -> bool: return value.get("kind", "") == "battlefield_rule_fired")[0]
		expect.call(not event.has("half_health_switched") and not state["battlefield_rule"].has("half_health_switched"), "BOS01 default false switch metadata is absent from saved events and instances")
		expect.call(Analytics.record(event, {}, "bos01-default")["payload"]["half_health_switched"] == false, "BOS01 analytics exports false without adding saved metadata")

static func compare(engine: RefCounted, state: Dictionary, expect: Callable) -> Dictionary:
	Base.mature_fuel(state)
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Rules.forecast(engine, state)
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	var comparable: Dictionary = forecast.duplicate(true)
	comparable.erase("direction")
	expect.call(comparable == Outcomes.project(engine, before, after), "BOS01 forecast equals resolution")
	expect.call(state == before, "BOS01 forecast preserves held state and event stream")
	return after

static func _gust(engine: RefCounted, expect: Callable) -> void:
	for mode: String in ["toward_source", "turn_clockwise"]:
		for anchored: bool in [false, true]:
			var state: Dictionary = Base.battle(engine)
			state["enemies"][0].merge({"pos": Vector2i(5, 5), "anchored": anchored}, true)
			state["player"]["pos"] = Vector2i(5, 2)
			state["player"]["anchored"] = anchored
			Rules.install(engine, state, Base.rule("gust", {"tiles": 1, "direction": mode}, true))
			var expected: Vector2i = Vector2i.DOWN if mode == "toward_source" else Vector2i.UP
			for beat: int in range(PROOF_BEATS):
				var announcement: Vector2i = Rules.forecast(engine, state)["direction"]
				expect.call(announcement == expected and Gust.active(engine, state)["direction"] == expected, "BOS01 announced next direction matches held dial")
				# Move after the announcement. A resolution-time aim would reverse it.
				if mode == "toward_source": state["player"]["pos"] = Vector2i(8, 8) if beat % 2 == 0 else Vector2i(2, 2)
				if beat == PROOF_BEATS / 2:
					var saved := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
					saved.store_var({"combat_state": state}); saved.close()
					var continued: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
					preload("res://scripts/enemy_mechanics/wind.gd").lock_legacy_intents(engine, continued)
					expect.call(continued["battlefield_rule"]["locked_direction"] == announcement, "BOS01 Continue preserves new Gust announcement: " + mode)
					state = continued
					DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
				var before: Dictionary = state.duplicate(true)
				expect.call(Rules.forecast(engine, state)["direction"] == announcement, "BOS01 toward_source stays locked a beat ahead")
				state = compare(engine, state, expect)
				if anchored:
					expect.call(state["player"]["pos"] == before["player"]["pos"] and state["enemies"][0]["pos"] == before["enemies"][0]["pos"], "BOS01 Anchored hero and source hold")
				else:
					# The public direction is now captured before simulation. Check
					# landings independently so a late re-aim cannot hide behind it.
					expect.call(state["player"]["pos"] == before["player"]["pos"] + announcement, "BOS01 held announcement controls Gust landing: " + mode)
				if mode == "turn_clockwise":
					expected = CLOCKWISE[(beat + 1) % CLOCKWISE.size()]
					expect.call(state["battlefield_rule"]["locked_direction"] == expected, "BOS01 clockwise quarter turn after every beat")
				else:
					expected = engine._cardinal_direction(Vector2i(state["enemies"][0]["pos"]) - Vector2i(state["player"]["pos"]))
					expect.call(state["battlefield_rule"]["locked_direction"] == expected, "BOS01 toward_source announces the following beat after resolution")
			print("BOS01 GUST FIXTURE: %s anchored=%s (%d beats)" % [mode, anchored, PROOF_BEATS])
	var big: Dictionary = Base.battle(engine)
	big["enemies"][0].merge({"footprint": Vector2i(2, 2), "pos": Vector2i(4, 4)}, true)
	big["player"]["pos"] = Vector2i(4, 2)
	Rules.install(engine, big, Base.rule("gust", {"tiles": 1, "direction": "turn_clockwise"}, true))
	var moved: Dictionary = compare(engine, big, expect)
	expect.call(moved["enemies"][0]["pos"] == Vector2i(4, 3), "BOS01 existing forced mover moves an unanchored 2x2 source")
	print("BOS01 2x2 GUST: unanchored source moves from (4,4) to %s" % moved["enemies"][0]["pos"])

static func switch_instance() -> Dictionary:
	var instance: Dictionary = Base.rule("gust", {"tiles": 1, "direction": "fixed:right"}, true)
	instance["cadence"]["every"] = 3
	instance["at_half_health"] = {"cadence": {"every": 2}, "dials": {"tiles": 2}, "sentence": HALF_SENTENCE}
	return instance

static func switched_events(state: Dictionary) -> Array:
	return state.get("surface_events", []).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "battlefield_rule_switched")

static func _half_health(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = Base.battle(engine)
	Rules.install(engine, state, switch_instance())
	state["battlefield_rule"].merge({"counter": 2, "beats_fired": 4}, true)
	state = committed_damage(engine, state, 0, 24, false)
	expect.call(switched_events(state).is_empty() and state["enemies"][0]["hp"] == 26, "BOS01 no switch above half Health")
	var unswitched: Dictionary = state.duplicate(true)
	state = committed_damage(engine, state, 0, 1, false)
	var instance: Dictionary = state["battlefield_rule"]
	expect.call(switched_events(state).size() == 1 and bool(instance.get("half_health_switched", false)), "BOS01 first exact half Health crossing switches")
	expect.call(instance["counter"] == 2 and instance["beats_fired"] == 4, "BOS01 half Health carries beat counter and index")
	expect.call(instance["cadence"] == {"anchor": "after_source_turn", "every": 2} and instance["dials"] == {"tiles": 2, "direction": "fixed:right"}, "BOS01 half Health merges only declared fields")
	expect.call(Rules.panel(state)["sentence"] == HALF_SENTENCE and Rules.panel(unswitched)["sentence"] != HALF_SENTENCE, "BOS01 panel replaces the sentence")
	expect.call(switched_events(state)[0]["banner"] == "TUNNEL CRAWLER GROWS FIERCER", "BOS01 banner uses uppercase source display name")
	var turns: Array[Dictionary]
	turns.append({"kind": "enemy", "enemy_id": 1, "time": 20})
	expect.call(Rules.project_turn_order(engine, state, turns, 3).size() == 2 and Rules.project_turn_order(engine, unswitched, turns, 3).size() == 2, "BOS01 clock redraw reads the carried counter")
	state = committed_damage(engine, state, 0, 1, false)
	expect.call(switched_events(state).size() == 1, "BOS01 half Health switches exactly once")
	state = Rules.dispatch(engine, state, "after_source_turn", 1)
	expect.call(state["battlefield_rule"]["beats_fired"] == 5, "BOS01 next beat continues the previous count")
	var events: Array = state["surface_events"].filter(func(event: Dictionary) -> bool: return event.get("kind", "") == "battlefield_rule_fired")
	expect.call(events.size() == 1 and events[0]["half_health_switched"], "BOS01 fired analytics includes saved switch flag")
	state["analytics"] = {"combat_id": "bos01-proof"}
	var records: Array[Dictionary] = Analytics.records(state, {})
	expect.call(records.size() == 2 and records[0]["payload"] == {"rule": "gust", "source_type": "crawler", "beat_index": 4}, "BOS01 switch analytics has additive exact payload")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": state}); file.close()
	var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
	preload("res://scripts/enemy_mechanics/wind.gd").lock_legacy_intents(engine, loaded)
	expect.call(loaded["battlefield_rule"] == state["battlefield_rule"] and Rules.forecast(engine, loaded) == Rules.forecast(engine, state), "BOS01 Continue preserves switch, count, sentence and forecast")
	loaded = committed_damage(engine, loaded, 0, 1, false)
	expect.call(switched_events(loaded).size() == 1, "BOS01 Continue cannot switch a second time")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	for defense: String in ["block", "stoneskin"]:
		var defended: Dictionary = Base.battle(engine)
		defended["enemies"][0]["hp"] = 40
		defended["enemies"][0][defense] = 70
		Rules.install(engine, defended, switch_instance())
		defended = committed_damage(engine, defended, 0, 100, false)
		expect.call(defended["enemies"][0]["hp"] == 10 and switched_events(defended).size() == 1, "BOS01 raw lethal hit crosses half on surviving source with " + defense)
	var clocked: Dictionary = Base.battle(engine)
	Rules.install(engine, clocked, switch_instance())
	var clock_before: Dictionary = clocked.duplicate(true)
	clocked = committed_damage(engine, clocked, 0, 25, false)
	var rail_turns: Array[Dictionary]
	for time: int in [10, 20, 30]: rail_turns.append({"kind": "enemy", "enemy_id": 1, "time": time})
	var old_beats: Array[Dictionary] = Rules.project_turn_order(engine, clock_before, rail_turns, 6).filter(func(entry: Dictionary) -> bool: return entry["kind"] == "beat")
	var new_beats: Array[Dictionary] = Rules.project_turn_order(engine, clocked, rail_turns, 6).filter(func(entry: Dictionary) -> bool: return entry["kind"] == "beat")
	expect.call(old_beats[0]["at"] == 30 and new_beats[0]["at"] == 20, "BOS01 switched cadence redraws the next clock beat")
	Rules.install(engine, clocked, switch_instance())
	clocked = committed_damage(engine, clocked, 0, 1, false)
	expect.call(switched_events(clocked).size() == 1 and clocked["battlefield_rule"]["dials"]["tiles"] == 2, "BOS01 reinstall keeps the once-per-fight switch")
	for changed_field: String in ["cadence", "dials"]:
		var partial: Dictionary = Base.battle(engine)
		var authored: Dictionary = switch_instance()
		authored["at_half_health"].erase("dials" if changed_field == "cadence" else "cadence")
		Rules.install(engine, partial, authored)
		partial = committed_damage(engine, partial, 0, 25, false)
		expect.call(switched_events(partial).size() == 1, "BOS01 optional half-Health fields work: " + changed_field)
	var redirected: Dictionary = Base.battle(engine)
	var changed_direction: Dictionary = switch_instance()
	changed_direction["at_half_health"]["dials"] = {"direction": "toward_source"}
	Rules.install(engine, redirected, changed_direction)
	redirected = committed_damage(engine, redirected, 0, 25, false)
	var held: Vector2i = redirected["battlefield_rule"]["locked_direction"]
	redirected["player"]["pos"] = Vector2i(2, 2)
	expect.call(Rules.forecast(engine, redirected)["direction"] == held, "BOS01 changed half-Health direction locks at the damage boundary")
	var odd: Dictionary = Base.battle(engine)
	odd["enemies"][0]["max_hp"] = 51
	Rules.install(engine, odd, switch_instance())
	odd = committed_damage(engine, odd, 0, 24, false)
	expect.call(switched_events(odd).is_empty(), "BOS01 integer half threshold waits at 26 of 51")
	odd = committed_damage(engine, odd, 0, 1, false)
	expect.call(switched_events(odd).size() == 1, "BOS01 integer half threshold fires at 25 of 51")
	var ordinary: Dictionary = Base.battle(engine)
	Rules.install(engine, ordinary, Base.rule("frostbite", {"damage": 0}, true))
	ordinary = committed_damage(engine, ordinary, 0, 30, false)
	expect.call(switched_events(ordinary).is_empty(), "BOS01 instances without at_half_health never switch")
	var dead: Dictionary = Base.battle(engine)
	Rules.install(engine, dead, switch_instance())
	dead = committed_damage(engine, dead, 0, 100, false)
	expect.call(switched_events(dead).is_empty() and Rules.active(dead).is_empty(), "BOS01 dead source ends its rule without a switch")
	for rule_name: String in ["stormcaller", "slagmaster", "oracle", "dynamo", "thornmother", "prior"]:
		var generic: Dictionary = Base.battle(engine)
		var authored: Dictionary = Rules.instance_for(rule_name, 1)
		authored["at_half_health"] = {"sentence": HALF_SENTENCE}
		if rule_name == "stormcaller": authored["locked_direction"] = Vector2i.DOWN
		Rules.install(engine, generic, authored)
		generic = committed_damage(engine, generic, 0, 25, false)
		expect.call(switched_events(generic).size() == 1 and Rules.panel(generic)["sentence"] == HALF_SENTENCE, "BOS01 half Health works for every rule: " + rule_name)
	if not events.is_empty():
		var legacy_event: Dictionary = events[0].duplicate(true)
		legacy_event.erase("half_health_switched")
		expect.call(Analytics.record(legacy_event, {}, "bos01-legacy")["payload"]["half_health_switched"] == false, "BOS01 pending legacy beat analytics defaults switch flag to false")
	print("BOS01 HALF HEALTH FIXTURE: first crossing, once, defended hit, carried count, Continue and analytics checked")

static func corridor(engine: RefCounted) -> Dictionary:
	var state: Dictionary = Base.battle(engine)
	# A horizontal three-cell-high floor; the last of three line marks splits it.
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			state["grid"][y][x] = "stone" if y in range(3, 6) and x in range(1, 10) else "wall"
	state["enemies"][0]["pos"] = Vector2i(2, 4)
	state["player"]["pos"] = Vector2i(7, 4)
	return state

static func _routes(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = corridor(engine)
	var instance: Dictionary = Base.rule("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true)
	Rules.install(engine, state, instance)
	expect.call(state["battlefield_rule"]["marks"] == [Vector2i(6, 3), Vector2i(6, 4)], "BOS01 line route guard skips exactly the floor-splitting mark")
	var after: Dictionary = compare(engine, state, expect)
	expect.call(after["terrain"].size() == 2 and engine._terrain_index_at_tile(after, Vector2i(6, 5)) < 0, "BOS01 guarded line raises its other marks")
	# Old held marks/saves also pass the guard at resolution.
	state["battlefield_rule"]["marks"] = [Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5)]
	after = compare(engine, state, expect)
	expect.call(after["terrain"].size() == 2, "BOS01 route guard rechecks old held lines at resolution")
	var big: Dictionary = Base.battle(engine)
	big["enemies"][0].merge({"pos": Vector2i(4, 4), "footprint": Vector2i(2, 2)}, true)
	big["player"]["pos"] = Vector2i(7, 4)
	# Up/left are walled, leaving down and right before the line.
	big["grid"][3][4] = "wall"
	big["grid"][4][3] = "wall"
	Rules.install(engine, big, instance)
	var source: Dictionary = big["enemies"][0]
	expect.call(big["battlefield_rule"]["marks"] == [Vector2i(6, 3)], "BOS01 2x2 prepared line skips exactly the two box-in marks")
	var guarded: Dictionary = compare(engine, big, expect)
	expect.call(guarded["terrain"].size() == 1 and guarded["terrain"][0]["pos"] == Vector2i(6, 3), "BOS01 2x2 guarded line keeps its safe mark")
	# A mark at (6,4) closes right; down remains legal: floor stays connected.
	expect.call(not Rules.Upheaval.line_preserves_routes(engine, big, big["battlefield_rule"], Vector2i(6, 4)), "BOS01 route guard keeps two exits for a 2x2 footprint")
	big["battlefield_rule"]["marks"] = [Vector2i(6, 4)]
	after = compare(engine, big, expect)
	expect.call(after["terrain"].is_empty() and after["enemies"][0]["pos"] == source["pos"], "BOS01 2x2 box-in mark is skipped")
	print("BOS01 ROUTE FIXTURES: corridor skips (6,5); 2x2 line skips (6,4),(6,5)")

static func _ground(engine: RefCounted, expect: Callable) -> void:
	var frost: Dictionary = Base.battle(engine)
	frost["illusions"] = [{"id": 7, "hp": 20, "max_hp": 20, "pos": Vector2i(7, 5)}]
	for actor: Dictionary in engine._surface_actor_records(frost):
		Surfaces.place(frost, actor["unit"]["pos"], "ice")
		frost = engine._surface_contact(frost, actor["kind"], actor["id"], engine.INVALID_TILE, true)
	Rules.install(engine, frost, Base.rule("frostbite", {"damage": 0}, true))
	var frozen: Dictionary = compare(engine, frost, expect)
	for actor: Dictionary in engine._surface_actor_records(frozen):
		expect.call(int(actor["unit"].get("freeze", 0)) == 1, "BOS01 Frostbite zero Freezes every Chilled unit")
	expect.call(Surfaces.tiles(frozen, "ice").is_empty(), "BOS01 Frostbite zero expends supporting Ice")
	var fire: Dictionary = Base.battle(engine)
	Surfaces.place(fire, Vector2i(3, 5), "fire")
	Rules.install(engine, fire, Base.rule("wildfire", {"spread": "all"}, true))
	var burned: Dictionary = compare(engine, fire, expect)
	for tile: Vector2i in [Vector2i(3, 4), Vector2i(2, 5), Vector2i(4, 5), Vector2i(3, 6)]:
		expect.call(Surfaces.surface_at(burned, tile)["elemental_source"]["actor_id"] == 1, "BOS01 beat Fire carries source id")
	# None of the six beats creates Ice. Exercise the same beat placement
	# resolver/context with Ice, rather than add an unapproved Frostbite dial.
	var ice: Dictionary = Base.battle(engine)
	ice["damage_context"] = {"actor_kind": "enemy", "actor_id": 1, "source_kind": "battlefield_rule", "rule": "frostbite", "player_card": false}
	ice = engine._place_action_surface(ice, {"type": "surface", "surface": "ice", "_enemy_id": 1}, Vector2i(3, 5))
	expect.call(Surfaces.surface_at(ice, Vector2i(3, 5))["elemental_source"]["actor_id"] == 1, "BOS01 beat placement path tags Ice with source id")
	var stone: Dictionary = Base.battle(engine)
	Rules.install(engine, stone, Base.rule("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true))
	var raised: Dictionary = compare(engine, stone, expect)
	for terrain: Dictionary in raised["terrain"]:
		expect.call(terrain["owner_id"] == 1 and terrain["owner_kind"] == "enemy", "BOS01 beat Outcrops carry source id for owner checks")
	print("BOS01 GROUND FIXTURE: Frostbite 0 Freezes all units; Fire/Ice/Outcrop ownership checked")
