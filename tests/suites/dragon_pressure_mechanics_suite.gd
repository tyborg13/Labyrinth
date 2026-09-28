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
	_test_openings(expect)
	_test_compound_live_shots(expect)
	_test_field_changes_live_target(expect)
	_test_secondary_shot_target_policy(expect)
	_test_live_pursuit_keeps_fixed_field(expect)
	_test_snapshot_survivors_and_actor_hits(expect)
	_test_legacy_overload(expect)
	_test_keyed_fields_ignore_unannounced_fuel(expect)
	_test_owned_band_retirement(expect)
	_test_skybreak_retirement_preview(expect)
	_test_spires_survive_body_attacks(expect)
	_test_spire_pulse_overlap_and_clearing(expect)
	_test_breath_spire_outer_corridor(expect)
	_test_ice_cross_and_mantle_counterplay(expect)
	_test_ice_trail_owner_retirement(expect)
	_test_actual_dive_wake(expect)
	_test_refuge_anchor_and_light(expect)
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

static func _test_field_changes_live_target(expect: Callable) -> void:
	var combat := Combat.new()
	for illusion_hp: int in [4, 30]:
		var state: Dictionary = _arena("zekarion")
		state["player"]["pos"] = Vector2i(1,4)
		state["illusions"] = [{"id":8003,"pos":Vector2i(3,3),"hp":illusion_hp,"max_hp":30}]
		Surface.place(state, Vector2i(3,3), "electrified", _owner(state))
		_declare(expect, state, "tempest_breath")
		state = _roundtrip(expect, state, "Overload target survival")
		var field: Dictionary = _action(expect, state, "aoe", "surface_snapshot")
		expect.call(not Committed.live_tiles(combat, state, state["enemies"][0], field).has(state["player"]["pos"]), "The target-survival witness is outside Overload's fixed field")
		var before: Dictionary = state.duplicate(true)
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		expect.call((plan["projected_attack"] as Array).has(state["player"]["pos"]) == (illusion_hp <= 6), "The later live shot warning reflects whether the earlier field kills its closer illusion target")
		expect.call(state == before, "Forecasting an earlier field's damage cannot mutate a live actor")
		var hit: Dictionary = _resolve(state)
		expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == (4 if illusion_hp <= 6 else 0), "Overload's live shot retargets only when its closer illusion actually dies")
		expect.call(int(hit["illusions"][0]["hp"]) == (0 if illusion_hp <= 6 else 20), "The field and shot each damage the surviving opposing actor once")

static func _test_secondary_shot_target_policy(expect: Callable) -> void:
	var combat := Combat.new()
	for trap_tile: Vector2i in [Vector2i(1,4), Vector2i(1,5)]:
		var state: Dictionary = _arena("zekarion")
		state["player"]["pos"] = Vector2i(1,4)
		state["illusions"] = [{"id":8004,"pos":Vector2i(3,3),"hp":30,"max_hp":30}]
		# An underfoot trap is an explicit resolver-policy boundary witness,
		# not a claim about ordinary arena spawning. Adjacent traps are the
		# control: current trap damage affects only the center tile.
		state["traps"] = [{"id":"secondary_target_trap","pos":trap_tile,"element":"fire","base_damage":8,"damage":8}]
		_declare(expect, state, "tempest_breath")
		state = _roundtrip(expect, state, "secondary target policy")
		var before: Dictionary = state.duplicate(true)
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		expect.call((plan["projected_attack"] as Array).has(Vector2i(3,3)), "A secondary live shot warns at its actual closest actor before considering a trap")
		expect.call(not (plan["projected_attack"] as Array).has(Vector2i(1,4)), "A secondary shot cannot borrow the primary planner's trap preference to warn at the player")
		expect.call(state == before, "Secondary target-policy preview remains read-only")
		var hit: Dictionary = _resolve(state)
		expect.call(hit["player"]["hp"] == state["player"]["hp"] and int(hit["illusions"][0]["hp"]) == 26, "The real secondary shot hits the closer illusion for four while the player stays untouched")
		expect.call((hit["traps"] as Array).size() == 1, "Actor-first secondary targeting leaves the unselected trap armed")

static func _test_live_pursuit_keeps_fixed_field(expect: Callable) -> void:
	var cases: Array[Dictionary]
	cases.assign([
		{"boss":"zekarion", "intent":"storm_claw", "surface":"electrified", "shape":"surface_snapshot"},
		{"boss":"iskaldra", "intent":"rime_talon", "surface":"ice", "shape":"surface_snapshot"},
		{"boss":"noctyrax", "intent":"void_claw", "surface":"", "shape":"refuge"},
	])
	var combat := Combat.new()
	for test: Dictionary in cases:
		var state: Dictionary = _arena(test["boss"])
		if not str(test["surface"]).is_empty(): Surface.place(state, Vector2i(1, 2), test["surface"], _owner(state))
		state["enemies"][0]["authored_trail"] = _tiles([Vector2i(1, 2)])
		state["guardian_braziers"] = [{"id":1,"pos":Vector2i(1,2),"lit":true},{"id":2,"pos":Vector2i(7,6),"lit":true}]
		_declare(expect, state, test["intent"])
		var field: Dictionary = _action(expect, state, "aoe", test["shape"])
		var anchored: Array[Vector2i] = Committed.live_tiles(combat, state, state["enemies"][0], field)
		state["player"]["pos"] = Vector2i(7, 4)
		state = _roundtrip(expect, state, "%s moved target" % test["intent"])
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		var destination: Vector2i = plan["destination"]
		expect.call(destination.x >= 4, "%s follows the current target rather than its old leftward route" % test["intent"])
		expect.call(_same_tiles(Committed.live_tiles(combat, state, state["enemies"][0], field), anchored), "%s pursuit cannot drag or retarget the fixed field" % test["intent"])
		expect.call((plan["projected_attack"] as Array).has(Vector2i(7,4)), "%s warns at the current reachable body target" % test["intent"])
		var result: Dictionary = _resolve(state)
		expect.call(int(result["player"]["hp"]) < int(state["player"]["hp"]), "%s pursuit reaches its current body target" % test["intent"])

static func _test_snapshot_survivors_and_actor_hits(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("zekarion")
	state["player"]["pos"] = Vector2i(2, 2)
	state["illusions"] = [{"id":8001,"pos":Vector2i(3,2),"hp":30,"max_hp":30}]
	for tile: Vector2i in [Vector2i(2,2), Vector2i(3,2)]: Surface.place(state, tile, "electrified", _owner(state))
	_declare(expect, state, "tempest_breath")
	var field: Dictionary = _action(expect, state, "aoe", "surface_snapshot")
	var area: Array[Vector2i] = Committed.live_tiles(combat, state, state["enemies"][0], field)
	expect.call(area.has(Vector2i(2,3)) and area.has(Vector2i(3,3)) and not area.has(Vector2i(2,4)), "New Overload includes adjacent cells, within one bounded diamond per charge")
	var hit: Dictionary = _resolve_action(state, field)
	expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == 6, "Overlapping charge neighborhoods hit the player once per field action")
	expect.call(int(hit["illusions"][0]["hp"]) == 24, "The same field also hits an illusion once instead of selecting only one actor")
	expect.call(Surface.has_surface(hit, Vector2i(2,2), "electrified") and Surface.has_surface(hit, Vector2i(3,2), "electrified"), "New Overload retains its announced charges")
	Surface.remove(state, Vector2i(2,2), "electrified", "test_clear")
	var partial: Array[Vector2i] = Committed.live_tiles(combat, state, state["enemies"][0], field)
	expect.call(not partial.has(Vector2i(1,2)) and partial.has(Vector2i(3,3)), "Removing one charge removes only its exclusive neighborhood while the surviving charge stays active")
	Surface.place(state, Vector2i(3,2), "ice", {"actor_kind":"player"})
	Surface.place(state, Vector2i(6,6), "electrified", {"actor_kind":"player"})
	state["enemies"][0]["pos"] = Vector2i(5, 3)
	state = _roundtrip(expect, state, "cleared Overload")
	expect.call(Committed.live_tiles(combat, state, state["enemies"][0], field).is_empty(), "Cleared/replaced anchors cancel the field; a later distant charge cannot join it")
	var empty: Dictionary = _resolve_action(state, field)
	expect.call(empty["player"]["hp"] == state["player"]["hp"] and Surface.has_surface(empty, Vector2i(6,6), "electrified"), "An empty snapshot neither falls back to a body hit nor consumes late fuel")

static func _test_legacy_overload(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("zekarion")
	state["player"]["pos"] = Vector2i(2,3)
	Surface.place(state, Vector2i(2,2), "electrified", _owner(state))
	var legacy := {"id":"tempest_breath", "actions":[{"type":"aoe","damage":6,"range":0,"element":"lightning","committed_shape":"surface_snapshot","snapshot_surface":"electrified","consume_surface":"electrified","no_conduction":true}]}
	state["enemies"][0]["intent"] = Committed.commit(combat, state, 0, legacy)
	state = _roundtrip(expect, state, "legacy Overload")
	var field: Dictionary = _action(expect, state, "aoe", "surface_snapshot")
	Surface.place(state, Vector2i(3,2), "electrified", {"actor_kind":"player"})
	expect.call(_same_tiles(Committed.live_tiles(combat, state, state["enemies"][0], field), [Vector2i(2,2)]), "Saved no-radius Overload retains its old exact-cell geometry")
	var miss: Dictionary = _resolve_action(state, field)
	expect.call(miss["player"]["hp"] == state["player"]["hp"], "Legacy Overload cannot gain adjacent damage after reload")
	expect.call(not Surface.has_surface(miss, Vector2i(2,2), "electrified") and Surface.has_surface(miss, Vector2i(3,2), "electrified"), "Legacy consume removes only its surviving announced center, without conduction into later charge")
	state["player"]["pos"] = Vector2i(2,2)
	expect.call(int(state["player"]["hp"]) - int(_resolve_action(state, field)["player"]["hp"]) == 6, "Legacy center damage remains exactly one advertised hit")

static func _test_keyed_fields_ignore_unannounced_fuel(expect: Callable) -> void:
	var cases: Array[Dictionary]
	cases.assign([
		{"boss":"vyraketh","intent":"cinderfall","surface":"fire","key":"cinder_tiles"},
		{"boss":"iskaldra","intent":"rime_talon","surface":"ice","key":"authored_trail"},
	])
	var combat := Combat.new()
	for test: Dictionary in cases:
		var state: Dictionary = _arena(test["boss"])
		state["enemies"][0][test["key"]] = _tiles([Vector2i(2,2)])
		Surface.place(state, Vector2i(2,2), test["surface"], _owner(state))
		Surface.place(state, Vector2i(7,6), test["surface"], {"actor_kind":"player"})
		expect.call(Surface.has_surface(state, Vector2i(7,6), test["surface"]), "The keyed-field witness starts with actual unrelated fuel")
		_declare(expect, state, test["intent"])
		var field: Dictionary = _action(expect, state, "aoe", "surface_snapshot")
		expect.call(_same_tiles(field["declared_tiles"], [Vector2i(2,2)]), "%s snapshots its recorded field rather than unrelated shared fuel" % test["intent"])
		Surface.remove(state, Vector2i(2,2), test["surface"], "test_clear")
		state = _roundtrip(expect, state, test["intent"])
		expect.call(Committed.live_tiles(combat, state, state["enemies"][0], field).is_empty(), "%s clearing removes pressure while unrelated fuel remains" % test["intent"])

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
		expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == (0 if owned else 6), "Skybreak damage agrees with whether the old bridge survives")
		var saw_strike: bool = false
		for step: Dictionary in resolved["steps"]:
			if str(step.get("action_type", "")) == "lightning_strikes":
				saw_strike = true
				expect.call((step.get("tiles", []) as Array).has(Vector2i(3,3)) == (not owned), "Skybreak resolution FX excludes retired bridges and includes surviving conduction")
		expect.call(saw_strike, "Skybreak's resolved strike supplies a real FX footprint")

static func _test_spires_survive_body_attacks(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("tharokh")
	_declare(expect, state, "stonewake")
	var marks: Array = _action(expect, state, "raise_terrain")["declared_tiles"]
	expect.call(marks.size() == 4, "Stonewake declares four route-preserving spires")
	state = _resolve(state)
	expect.call(combat._dragon_spires(state).size() == 4, "Stonewake's own setup line cannot immediately destroy its new spires")
	for id: String in ["worldspine_claw", "bedrock_breath"]:
		_declare(expect, state, id)
		state = _resolve(_roundtrip(expect, state, id))
		expect.call(combat._dragon_spires(state).size() == 4, "%s preserves the four spires without player destruction" % id)
	_declare(expect, state, "faultline")
	state = _resolve(state)
	expect.call(combat._dragon_spires(state).is_empty(), "Faultline remains the consuming payoff")
	for tile: Vector2i in marks: expect.call(Surface.has_surface(state, tile, "rubble"), "Consumed spires retain their Rubble counterplay")

static func _test_spire_pulse_overlap_and_clearing(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("tharokh")
	state["player"]["pos"] = Vector2i(3,2)
	state["illusions"] = [{"id":8002,"pos":Vector2i(4,1),"hp":30,"max_hp":30}]
	for tile: Vector2i in [Vector2i(2,2), Vector2i(4,2), Vector2i(6,2)]:
		state["terrain"].append({"id":100+tile.x,"kind":combat.DRAGON_SPIRE_KIND,"pos":tile,"hp":4,"max_hp":4,"owner_id":state["enemies"][0]["id"],"surface_on_destroy":"rubble"})
	_declare(expect, state, "worldspine_claw")
	var pulse: Dictionary = _action(expect, state, "terrain_burst")
	var hit: Dictionary = _resolve_action(state, pulse)
	expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == 4, "Overlapping spire pulses hit the player once per action")
	expect.call(int(hit["illusions"][0]["hp"]) == 26, "A persistent pulse affects every opposing actor in its field")
	expect.call(combat._dragon_spires(hit).size() == 3, "Claw's pulse does not consume spires")
	state = combat._damage_terrain(state, combat._terrain_index_at_tile(state, Vector2i(2,2)), 4)
	state["player"]["pos"] = Vector2i(2,1)
	expect.call(not (combat._boss_action_threat_tiles(state, state["enemies"][0], pulse) as Array).has(Vector2i(2,1)), "Breaking one spire removes its isolated warning cells")
	hit = _resolve_action(_roundtrip(expect, state, "broken spire"), pulse)
	expect.call(hit["player"]["hp"] == state["player"]["hp"], "A broken spire cannot still pulse after reload")
	expect.call(combat._dragon_spires(hit).size() == 2, "The other persistent spires survive that denied pulse")

static func _test_breath_spire_outer_corridor(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("tharokh")
	state["player"]["pos"] = Vector2i(2,4)
	for tile: Vector2i in [Vector2i(2,5), Vector2i(1,2)]:
		state["terrain"].append({"id":200+tile.x,"kind":combat.DRAGON_SPIRE_KIND,"pos":tile,"hp":4,"max_hp":4,"owner_id":state["enemies"][0]["id"],"surface_on_destroy":"rubble"})
	_declare(expect, state, "bedrock_breath")
	var lane: Dictionary = _action(expect, state, "aoe")
	# A held westward lane is avoided from the southern corridor. Breath's
	# surviving-spire field must still contest that formerly free outer cell.
	var refuge := Vector2i(4,5)
	state["player"]["pos"] = refuge
	expect.call(not Committed.live_tiles(combat, state, state["enemies"][0], lane).has(refuge), "Outer-corridor witness is outside the held body attack")
	expect.call((combat.enemy_intent_plan(state, 0)["projected_attack"] as Array).has(refuge), "Breath warning includes the two-cell spire corridor")
	var intact: Dictionary = _resolve(_roundtrip(expect, state, "Breath outer corridor"))
	expect.call(int(state["player"]["hp"]) - int(intact["player"]["hp"]) == 4, "Avoiding the lane alone still pays exactly one small spire pulse")
	expect.call(combat._dragon_spires(intact).size() == 2, "The broader Breath pulse retains its destructible sources")
	var guarded: Dictionary = state.duplicate(true)
	guarded["player"]["block"] = 4
	guarded = _resolve(guarded)
	expect.call(guarded["player"]["hp"] == state["player"]["hp"] and int(guarded["player"]["block"]) == 0, "Ordinary guard can pay for retaining the contested corridor")
	var distant: Dictionary = state.duplicate(true)
	distant["player"]["pos"] = Vector2i(5,5)
	expect.call(not (combat.enemy_intent_plan(distant, 0)["projected_attack"] as Array).has(Vector2i(5,5)), "The farther corridor remains a real unthreatened alternative")
	var cleared: Dictionary = combat._damage_terrain(state, combat._terrain_index_at_tile(state, Vector2i(2,5)), 4)
	expect.call(not (combat.enemy_intent_plan(cleared, 0)["projected_attack"] as Array).has(refuge), "Destroying the relevant spire immediately opens its unique outer corridor")
	cleared = _resolve(_roundtrip(expect, cleared, "Cleared Breath corridor"))
	expect.call(cleared["player"]["hp"] == state["player"]["hp"] and combat._dragon_spires(cleared).size() == 1, "The earned opening survives reload without erasing the other spire")
	var legacy: Dictionary = state.duplicate(true)
	for action: Dictionary in legacy["enemies"][0]["intent"]["actions"]:
		if str(action.get("type", "")) == "terrain_burst": action["radius"] = 1
	legacy = _roundtrip(expect, legacy, "Previously declared narrow Breath")
	expect.call(not (combat.enemy_intent_plan(legacy, 0)["projected_attack"] as Array).has(refuge), "An already saved narrow Breath warning is not widened on reload")

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

static func _test_actual_dive_wake(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("vaeloryx")
	_declare(expect, state, "razor_dive")
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	var path: Array = plan["path"]
	expect.call(path.size() > 1, "Dive witness includes a committed approach")
	if path.size() <= 1: return
	var dive: Dictionary = _action(expect, state, "aoe", "swept_path")
	var original_area: Array = dive["declared_tiles"].duplicate()
	var origin: Vector2i = state["enemies"][0]["pos"]
	# A new blocker interrupts the held path; the wake must not use the longer
	# original route or invent cells beyond the actual surviving movement.
	state["terrain"].append({"id":9001,"kind":"crate","pos":path[1],"hp":99,"max_hp":99})
	var actual_geometry: Dictionary = dive.duplicate(true)
	actual_geometry["_resolved_path"] = _tiles([origin])
	var expected: Array[Vector2i] = Shapes.swept_shape(combat, state, origin, actual_geometry)
	state = _resolve(state)
	var wake: Array = state["enemies"][0].get("dive_wake", [])
	expect.call(state["enemies"][0]["pos"] == origin and _same_tiles(wake, expected), "Dive records only the actual blocked-path wake")
	expect.call(wake.size() < original_area.size(), "Interrupted Dive cannot retain the untraveled part of its old warning")
	expect.call(str(state["enemies"][0]["intent"]["id"]) == "hollow_gale", "Dive's wake feeds the following Gale")
	state = _roundtrip(expect, state, "Dive wake")
	var field: Dictionary = _action(expect, state, "aoe", "trail_snapshot")
	expect.call(_same_tiles(field["declared_tiles"], wake), "Gale snapshots the persisted actual wake")
	state["enemies"][0]["pos"] = Vector2i(6,5)
	expect.call(_same_tiles(Committed.live_tiles(combat, state, state["enemies"][0], field), wake), "Displacing Vaeloryx cannot move the stored wake")
	var witness := Vector2i(-1,-1)
	for tile: Vector2i in wake:
		if combat._enemy_distance_to_tile(state["enemies"][0], tile) > 2 and combat._terrain_index_at_tile(state, tile) < 0:
			witness = tile
			break
	expect.call(witness.x >= 0, "Wake has a witness outside the displaced dragon's body ring")
	if witness.x < 0: return
	state["player"]["pos"] = witness
	expect.call((combat.enemy_intent_plan(state, 0)["projected_attack"] as Array).has(witness), "Gale warns about its remote wake even when its body ring misses")
	var hit: Dictionary = _resolve(state)
	expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == 5, "The remote wake resolves exactly one separate five-damage hit")
	expect.call((hit["enemies"][0].get("dive_wake", []) as Array).is_empty(), "Gale consumes the wake instead of leaving an unbounded recurring field")

static func _test_refuge_anchor_and_light(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _arena("noctyrax")
	state["guardian_braziers"] = [{"id":101,"pos":Vector2i(2,2),"lit":false},{"id":102,"pos":Vector2i(6,6),"lit":true}]
	state["player"]["pos"] = Vector2i(2,3)
	_declare(expect, state, "last_eclipse")
	var field: Dictionary = _action(expect, state, "aoe", "refuge")
	var anchored: Array = field["declared_tiles"].duplicate()
	expect.call(str(field.get("field_anchor", "")) == "player" and field.get("field_center") == Vector2i(2,3), "Eclipse anchors its ground warning to the declared player position, including player-made Light")
	expect.call(anchored.has(Vector2i(2,6)) and not anchored.has(Vector2i(2,7)), "Eclipse holds a radius-three field rather than a one-step refuge escape")
	state = combat.apply_player_action(state, {"type":"move","range":1}, Vector2i(2,2))
	expect.call(bool(state["guardian_braziers"][0]["lit"]), "The refuge witness relights through real player arrival")
	state = _roundtrip(expect, state, "relit refuge sweep")
	state["enemies"][0]["pos"] = Vector2i(5,3)
	expect.call(_same_tiles(Committed.live_tiles(combat, state, state["enemies"][0], field), anchored), "Relighting and boss displacement cannot erase or move the announced refuge sweep")
	expect.call((combat.enemy_intent_plan(state, 0)["projected_attack"] as Array).has(Vector2i(2,2)), "Standing in Light remains visibly unsafe inside the separate refuge sweep")
	var hit: Dictionary = _resolve(state)
	expect.call(int(state["player"]["hp"]) - int(hit["player"]["hp"]) == 5, "Light avoids Eclipse's dark hit but not the independently announced five-damage sweep")
	state["player"]["pos"] = Vector2i(6,6)
	expect.call(_same_tiles(Committed.live_tiles(combat, state, state["enemies"][0], field), anchored), "Moving to a different refuge cannot retarget the already revealed sweep")
	var safe: Dictionary = _resolve(_roundtrip(expect, state, "other refuge"))
	expect.call(safe["player"]["hp"] == state["player"]["hp"], "Reaching a different lit refuge outside the sweep remains valid counterplay")

	# Existing saved warnings omit the opt-in field anchor. Their authored
	# brazier target must survive the revision and a production store round-trip.
	var legacy: Dictionary = _arena("noctyrax")
	legacy["guardian_braziers"] = [{"id":101,"pos":Vector2i(2,2),"lit":true},{"id":102,"pos":Vector2i(6,6),"lit":true}]
	legacy["player"]["pos"] = Vector2i(2,3)
	var old_intent: Dictionary = {}
	for candidate: Dictionary in Data.enemy_def("noctyrax")["intents"]:
		if candidate["id"] == "last_eclipse": old_intent = candidate.duplicate(true)
	for action: Dictionary in old_intent["actions"]:
		if Committed.shape(action) == "refuge":
			action.erase("field_anchor")
			action["field_radius"] = 2
	legacy["enemies"][0]["intent"] = Committed.commit(combat, legacy, 0, old_intent)
	legacy = _roundtrip(expect, legacy, "legacy brazier sweep")
	var old_field: Dictionary = _action(expect, legacy, "aoe", "refuge")
	expect.call(int(old_field.get("refuge_id", -1)) == 101 and old_field.get("field_center") == Vector2i(2,2), "Unflagged legacy warnings retain their nearest-brazier identity and anchor")
	legacy["player"]["pos"] = Vector2i(6,6)
	expect.call(_same_tiles(Committed.live_tiles(combat, legacy, legacy["enemies"][0], old_field), old_field["declared_tiles"]), "Legacy brazier sweeps remain fixed after player movement")

	for id: String in ["void_claw", "starless_breath"]:
		var followup: Dictionary = _arena("noctyrax")
		followup["player"]["pos"] = Vector2i(2,3)
		_declare(expect, followup, id)
		var followup_field: Dictionary = _action(expect, followup, "aoe", "refuge")
		expect.call(followup_field.get("field_center") == Vector2i(2,3), "%s contests the declared player position without requiring a brazier" % id)
		expect.call(int(followup_field["field_radius"]) == (2 if id == "void_claw" else 1), "%s preserves its smaller escape window" % id)
