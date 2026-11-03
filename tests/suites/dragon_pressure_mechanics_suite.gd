extends RefCounted

# Correctness witnesses for the coupled-pressure revision. These authored boards
# establish rules and counterplay; they do not establish native difficulty.
const Combat = preload("res://scripts/combat_engine.gd")
const BossSuite = preload("res://tests/suites/dragon_boss_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Committed = preload("res://scripts/guardian_combat_rules.gd")
const Shapes = preload("res://scripts/committed_pattern_shapes.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Store = preload("res://scripts/progression_store.gd")

static func run(expect: Callable) -> void:
	var previous_run_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://dragon_pressure_mechanics_run.save")
	preload("res://tests/suites/dragon_element_rules_suite.gd").run(expect)
	preload("res://tests/suites/dragon_feedback1_suite.gd").run(expect)
	_test_openings(expect)
	_test_compound_live_shots(expect)
	_test_owned_band_retirement(expect)
	_test_skybreak_retirement_preview(expect)
	_test_ice_cross_and_mantle_counterplay(expect)
	_test_ice_trail_owner_retirement(expect)
	Store.set_run_storage_path(previous_run_path)

static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(values)
	return result

static func _same_tiles(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for tile: Variant in a:
		if not b.has(tile): return false
	return true

static func _arena(boss_id: String) -> Dictionary:
	var state: Dictionary = BossSuite._boss_combat_state(boss_id)
	var boss: Dictionary = BossSuite._boss_from_state(state).duplicate(true)
	state["enemies"] = [boss]
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["illusions"] = []
	state["surface_events"] = []
	state["player"]["pos"] = Vector2i(1, 4)
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	boss["pos"] = Vector2i(4, 3)
	boss["hp"] = 2000
	boss["max_hp"] = 2000
	boss["block"] = 0
	boss["stoneskin"] = 0
	return state

static func _declare(expect: Callable, state: Dictionary, id: String) -> void:
	var enemy: Dictionary = state["enemies"][0]
	var intents: Array = Data.enemy_def(str(enemy["type"]))["intents"]
	var index: int = -1
	for i: int in range(intents.size()):
		if str(intents[i].get("id", "")) == id: index = i
	expect.call(index >= 0, "Production intent exists: %s/%s" % [enemy["type"], id])
	if index < 0: return
	enemy["dragon_cycle"] = index - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 930928
	Combat.new()._assign_enemy_intent(state, 0, rng)

static func _action(expect: Callable, state: Dictionary, type: String, shape: String = "") -> Dictionary:
	for action: Dictionary in state["enemies"][0]["intent"]["actions"]:
		if str(action.get("type", "")) == type and (shape.is_empty() or Committed.shape(action) == shape):
			return action.duplicate(true)
	expect.call(false, "Intent must contain %s/%s" % [type, shape])
	return {}

static func _resolve(state: Dictionary) -> Dictionary:
	return Combat.new().resolve_enemy_turn_with_steps(state, 0, false)["state"]

static func _resolve_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var combat := Combat.new()
	next["current_actor"] = combat._enemy_actor_entry(next, next["enemies"][0], 0, 0)
	return combat._resolve_enemy_action(next, 0, action)

static func _roundtrip(expect: Callable, state: Dictionary, label: String) -> Dictionary:
	var wrapper := {"mode":"combat", "combat_units_schema":1, "surface_rules_version":5, "combat_state":state}
	expect.call(Store.save_run_state(wrapper), "%s saves through the production transactional store" % label)
	var loaded: Dictionary = Store.load_saved_run()

	expect.call(loaded == wrapper, "%s round-trips every declared field and actor value" % label)
	return loaded.get("combat_state", state) as Dictionary

static func _owner(state: Dictionary) -> Dictionary:
	return {"actor_kind":"enemy", "actor_id":state["enemies"][0]["id"]}

static func _test_openings(expect: Callable) -> void:
	for id: String in ["vyraketh", "tharokh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]:
		var state: Dictionary = BossSuite._boss_combat_state(id)
		var boss_id: int = int(BossSuite._boss_from_state(state)["id"])
		var entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == boss_id)
		expect.call(entries.size() == 1 and int(entries[0]["time"]) == 12, "%s has one announced opening at clock12" % id)

static func _test_compound_live_shots(expect: Callable) -> void:
	var cases: Array[Dictionary]
	cases.assign([
		{"boss":"vyraketh", "intent":"kindle_ground"},
		{"boss":"vyraketh", "intent":"crownfire"},
		{"boss":"tharokh", "intent":"faultline"},
		{"boss":"iskaldra", "intent":"crystal_mantle"},
		{"boss":"zekarion", "intent":"tempest_breath"},
		{"boss":"noctyrax", "intent":"void_claw"},
	])
	var combat := Combat.new()
	for test: Dictionary in cases:
		var state: Dictionary = _arena(test["boss"])
		# Place the independent field away from the live direct target.
		state["player"]["pos"] = Vector2i(2, 3)
		state["enemies"][0]["cinder_tiles"] = _tiles([Vector2i(6, 6)])
		Surface.place(state, Vector2i(6, 6), "electrified" if test["boss"] == "zekarion" else "fire", _owner(state))
		state["guardian_braziers"] = [{"id":1,"pos":Vector2i(6,6),"lit":true}]
		_declare(expect, state, test["intent"])
		if test["intent"] == "kindle_ground":
			# Move off the announced setup band but stay within the live shot.
			state["player"]["pos"] = Vector2i(3, 2)
		var before: Dictionary = state.duplicate(true)
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		expect.call((plan["projected_attack"] as Array).has(state["player"]["pos"]), "%s warns about its live attack alongside an independent field" % test["intent"])
		expect.call(state == before, "%s warning does not mutate the revealed state" % test["intent"])
		var loaded: Dictionary = _roundtrip(expect, state, test["intent"])
		expect.call(combat.enemy_intent_plan(loaded, 0) == plan, "%s preview survives reload" % test["intent"])
		var hit: Dictionary = _resolve(loaded)
		expect.call(int(hit["player"]["hp"]) < int(state["player"]["hp"]), "%s live attack actually resolves outside its remote field" % test["intent"])
		if test["boss"] in ["vyraketh", "zekarion"] and test["intent"] != "kindle_ground":
			state["surfaces"] = {}
			expect.call((combat.enemy_intent_plan(state, 0)["projected_attack"] as Array).has(state["player"]["pos"]), "%s retains its body warning after all fuel is cleared" % test["intent"])
			expect.call(int(_resolve(state)["player"]["hp"]) < int(state["player"]["hp"]), "%s retains its live attack after field denial" % test["intent"])

static func _owned_count(state: Dictionary, surface: String) -> int:
	var count: int = 0
	for tile: Vector2i in Surface.tiles(state, surface):
		var source: Dictionary = Surface.surface_at(state, tile).get("elemental_source", {})
		if source.get("actor_kind", "") == "enemy" and int(source.get("actor_id", -1)) == int(state["enemies"][0]["id"]): count += 1
	return count

static func _test_owned_band_retirement(expect: Callable) -> void:
	for id: String in ["vyraketh", "zekarion"]:
		var state: Dictionary = _arena(id)
		var surface: String = "fire" if id == "vyraketh" else "electrified"
		var intent: String = "kindle_ground" if id == "vyraketh" else "skybreak"
		Surface.place(state, Vector2i(7,5), surface, _owner(state))
		Surface.place(state, Vector2i(7,6), surface, _owner(state))
		Surface.place(state, Vector2i(6,1), surface, {"actor_kind":"enemy","actor_id":9999})
		Surface.place(state, Vector2i(7,2), surface, {"actor_kind":"player","actor_id":-1})
		for tile: Vector2i in [Vector2i(7,5), Vector2i(7,6), Vector2i(6,1), Vector2i(7,2)]:
			expect.call(Surface.has_surface(state, tile, surface), "%s ownership witness starts on real floor" % id)
		_declare(expect, state, intent)
		var type: String = "cinder_marks" if id == "vyraketh" else "lightning_strikes"
		var marks: Array = _action(expect, state, type)["declared_tiles"]
		expect.call(marks.size() == 7, "%s fills a seven-cell connected pressure band in an open arena" % id)
		state = _resolve(state)
		expect.call(not Surface.has_surface(state, Vector2i(7,5), surface) and not Surface.has_surface(state, Vector2i(7,6), surface), "%s replaces its old field instead of accumulating permanent charges" % id)
		expect.call(Surface.has_surface(state, Vector2i(6,1), surface) and Surface.has_surface(state, Vector2i(7,2), surface), "%s retirement preserves another enemy's and the player's same-element surfaces" % id)
		expect.call(_owned_count(state, surface) == 7, "%s owns only the newly resolved band" % id)
		state["player"]["pos"] = Vector2i(3,6)
		_declare(expect, state, intent)
		state = _resolve(_roundtrip(expect, state, "%s second band" % id))
		expect.call(_owned_count(state, surface) <= 7, "%s repeated cast remains bounded after reload" % id)
		expect.call(Surface.has_surface(state, Vector2i(6,1), surface) and Surface.has_surface(state, Vector2i(7,2), surface), "%s repeated retirement remains owner-only" % id)

static func _test_skybreak_retirement_preview(expect: Callable) -> void:
	var combat := Combat.new()
	for owned: bool in [true, false]:
		var state: Dictionary = _arena("zekarion")
		state["player"]["pos"] = Vector2i(2,4)
		var source: Dictionary = _owner(state) if owned else {"actor_kind":"enemy", "actor_id":9999}
		for tile: Vector2i in [Vector2i(2,4), Vector2i(3,4), Vector2i(3,3)]:
			Surface.place(state, tile, "electrified", source)
		_declare(expect, state, "skybreak")
		var strike: Dictionary = _action(expect, state, "lightning_strikes")
		state["player"]["pos"] = Vector2i(3,3)
		expect.call(not (strike["declared_tiles"] as Array).has(Vector2i(3,3)), "Skybreak bridge witness stands outside the new band")
		state = _roundtrip(expect, state, "Skybreak conductor ownership")
		var before: Dictionary = state.duplicate(true)
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		expect.call((plan["projected_attack"] as Array).has(Vector2i(3,3)) == (not owned), "Skybreak warning conducts only through bridges that survive its own field retirement")
		expect.call(state == before, "Forecasting Skybreak field retirement cannot remove live surfaces or append events")
		var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false)
		var hit: Dictionary = resolved["state"]
		expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == (0 if owned else 5), "Skybreak's approved five damage agrees with whether the old bridge survives")
		var saw_strike: bool = false
		for step: Dictionary in resolved["steps"]:
			if str(step.get("action_type", "")) == "lightning_strikes":
				saw_strike = true
				expect.call((step.get("tiles", []) as Array).has(Vector2i(3,3)) == (not owned), "Skybreak resolution FX excludes retired bridges and includes surviving conduction")
		expect.call(saw_strike, "Skybreak's resolved strike supplies a real FX footprint")

static func _test_ice_cross_and_mantle_counterplay(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("iskaldra")
	_declare(expect, state, "crystal_mantle")
	state = _resolve(state)
	expect.call(int(state["enemies"][0].get("frost_armor", 0)) == 2 and str(state["enemies"][0]["intent"]["id"]) == "shatterstorm", "Two-layer Mantle leads directly into its threatening Shatter payoff")
	var strong: Array = combat.enemy_intent_plan(state, 0)["projected_attack"]
	state = combat._damage_enemy(state, 0, 4)
	state = combat._damage_enemy(state, 0, 4)
	var weak: Array = combat.enemy_intent_plan(state, 0)["projected_attack"]
	expect.call(weak.size() < strong.size(), "Spending attacks to break Mantle shrinks the already announced Shatter field")
	_declare(expect, state, "whiteout_lance")
	var cross: Dictionary = _action(expect, state, "aoe", "cross")
	var area: Array[Vector2i] = Committed.live_tiles(combat, state, state["enemies"][0], cross)
	var origin: Vector2i = state["enemies"][0]["pos"]
	for offset: Vector2i in [Vector2i(-1,0),Vector2i(2,0),Vector2i(0,-1),Vector2i(0,2)]:
		expect.call(area.has(origin + offset), "Whiteout covers each of the four full-body cross arms")
	state = _resolve(state)
	for tile: Vector2i in area: expect.call(Surface.has_surface(state, tile, "ice"), "Every resolved cross cell receives Ice")
	expect.call(_same_tiles(state["enemies"][0].get("authored_trail", []), area), "The stored Whiteout trail equals its actual resolved cross")

static func _test_ice_trail_owner_retirement(expect: Callable) -> void:
	var state: Dictionary = _arena("iskaldra")
	state["enemies"][0]["authored_trail"] = _tiles([Vector2i(2,1),Vector2i(1,2),Vector2i(1,6)])
	Surface.place(state, Vector2i(2,1), "ice", _owner(state))
	Surface.place(state, Vector2i(1,2), "ice", {"actor_kind":"player"})
	Surface.place(state, Vector2i(1,6), "ice", {"actor_kind":"enemy","actor_id":9999})
	Surface.place(state, Vector2i(7,6), "ice", _owner(state))
	for tile: Vector2i in [Vector2i(2,1), Vector2i(1,2), Vector2i(1,6), Vector2i(7,6)]:
		expect.call(Surface.has_surface(state, tile, "ice"), "Ice retirement witness starts with all four owned/foreign surfaces")
	_declare(expect, state, "whiteout_lance")
	state = _resolve(state)
	expect.call(not Surface.has_surface(state, Vector2i(2,1), "ice"), "New Whiteout retires the old owned trail")
	expect.call(Surface.has_surface(state, Vector2i(1,2), "ice") and Surface.has_surface(state, Vector2i(1,6), "ice"), "Trail retirement cannot erase same-element replacements owned by someone else")
	expect.call(Surface.has_surface(state, Vector2i(7,6), "ice"), "Trail retirement is restricted to the recorded old trail")
