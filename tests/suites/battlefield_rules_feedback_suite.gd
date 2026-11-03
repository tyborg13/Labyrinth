extends RefCounted
## el-01 feedback 1 reproductions and safety boundaries. All numbers are fixtures.
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
const SnareFixtures = preload("res://tests/suites/snare_pressure_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const EXPOSURE: int = 3
const DAMAGE: int = 2
const BONUS_RELIC: String = "el01_feedback_bonus"
const BENCHMARK_QUERIES: int = 100

class CountingEngine extends Combat:
	var board_resolutions: int = 0
	var invalid_placements: int = 0
	func _resolve_board_attack(state: Dictionary, action: Dictionary, target: Vector2i, actor_kind: String = "player", actor_id: int = -1, trace: Dictionary = {}, supplied_impact: Array[Vector2i] = []) -> Dictionary:
		board_resolutions += 1
		return super._resolve_board_attack(state, action, target, actor_kind, actor_id, trace, supplied_impact)
	func _force_place_actor(state: Dictionary, kind: String, id: int, anchor: Vector2i) -> Dictionary:
		if anchor == INVALID_TILE: invalid_placements += 1
		return super._force_place_actor(state, kind, id, anchor)

static func run(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	_hits(engine, battle, rule, compare, expect)
	_burial(engine, battle, rule, compare, expect)
	_memo(battle, rule, expect)
	_intents(engine, battle, rule, expect)
	_exit_data(engine, expect)
	_occupied_marks(battle, rule, compare, expect)
	print("EL01 FEEDBACK CHECKS: Expose, traps, on-hit reactions, burial, memo dependencies, intent gates, authored selector and occupied guards PASS")

static func _hits(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	var relics: Dictionary = Data.relics()
	relics[BONUS_RELIC] = {"name": "Test attack bonus", "effects": [{"type": "first_attack_bonus", "value": 99}, {"type": "damage_vs_status", "status": "expose", "value": 99}]}
	for id: String in ["frostbite", "lightning_storm"]:
		var state: Dictionary = battle.call(engine)
		state["relics"] = [BONUS_RELIC]
		state["enemies"][0]["expose"] = EXPOSURE
		var tile: Vector2i = state["enemies"][0]["pos"]
		Surfaces.place(state, tile, "ice" if id == "frostbite" else "electrified")
		Rules.install(engine, state, rule.call(id, {"damage": DAMAGE, "chain": 0}))
		var after: Dictionary = compare.call(engine, state, expect)
		expect.call(int(after["enemies"][0]["hp"]) == 45 and int(after["enemies"][0]["expose"]) == 0, "Shared attack consumes enemy Expose without player bonuses: " + id)
		state = battle.call(engine)
		tile = Vector2i(7, 7)
		Surfaces.place(state, tile, "ice" if id == "frostbite" else "electrified")
		state["traps"] = [{"id": "test_trap", "pos": tile, "element": "fire", "damage": DAMAGE}]
		Rules.install(engine, state, rule.call(id, {"damage": DAMAGE, "chain": 0}))
		after = compare.call(engine, state, expect)
		expect.call(after["traps"].is_empty() and after["surface_events"].any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "trap_triggered"), "Shared attack triggers struck traps: " + id)
		# Enemy-sourced beats retain the ordinary on-hit Retaliate path.
		state = battle.call(engine)
		state["enemies"][0]["pos"] = Vector2i(5, 4)
		state["retaliate"] = {"amount": 3}
		Surfaces.place(state, state["player"]["pos"], "ice" if id == "frostbite" else "electrified")
		Rules.install(engine, state, rule.call(id, {"damage": DAMAGE, "chain": 0}, true))
		after = compare.call(engine, state, expect)
		expect.call(int(after["enemies"][0]["hp"]) == 47, "Shared attack preserves Retaliate against its source: " + id)
	relics.erase(BONUS_RELIC)
	engine._relic_effect_cache_valid = false

static func _burial(engine: RefCounted, battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	for id: String in ["frostbite", "lightning_storm", "shadowstep"]:
		var state: Dictionary = battle.call(engine)
		state["enemies"][0]["type"] = "burrow_grub"
		state["enemies"][0]["burrowed"] = true
		if id == "shadowstep":
			state["umbra"] = {"stage": "heart"}
			state["enemies"][0]["pos"] = Vector2i(5, 2)
		else:
			Surfaces.place(state, state["enemies"][0]["pos"], "ice" if id == "frostbite" else "electrified")
			state = engine._surface_contact(state, "enemy", 1, engine.INVALID_TILE, true)
		Rules.install(engine, state, rule.call(id, {"damage": DAMAGE, "chain": 0, "blink": 2}))
		var after: Dictionary = compare.call(engine, state, expect)
		if id == "frostbite": expect.call(int(after["enemies"][0]["hp"]) == 46 and int(after["enemies"][0]["freeze"]) == 1, "Frostbite uses area targetability for buried units")
		elif id == "lightning_storm": expect.call(int(after["enemies"][0]["hp"]) == 48 and int(after["enemies"][0]["shock"]) == 1, "Lightning uses area targetability for buried units")
		else: expect.call(after["enemies"][0]["pos"] == Vector2i(5, 4) and bool(after["enemies"][0]["burrowed"]), "Shadowstep uses existing Blink targetability for buried units")

static func _memo(battle: Callable, rule: Callable, expect: Callable) -> void:
	var engine := CountingEngine.new()
	var state: Dictionary = battle.call(engine)
	for y: int in range(1, 10):
		for x: int in range(1, 10): Surfaces.place(state, Vector2i(x, y), "electrified")
	Rules.install(engine, state, rule.call("lightning_storm", {"damage": DAMAGE, "chain": 3}))
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	var started: int = Time.get_ticks_usec()
	var first: Dictionary = Rules.forecast(engine, state)
	for query: int in range(BENCHMARK_QUERIES - 1):
		expect.call(Rules.forecast(engine, state) == first, "Memo returns the same complete forecast on unchanged input")
	expect.call(engine.board_resolutions == 1, "Memo unchanged queries execute the real resolver exactly once")
	print("EL01 FORECAST MEMO: %d queries, %d resolver executions, %.3f ms" % [BENCHMARK_QUERIES, engine.board_resolutions, (Time.get_ticks_usec() - started) / 1000.0])
	first["tiles"]["strike"].clear()
	if not first["hits"].is_empty(): first["hits"][0]["statuses"].clear()
	expect.call(not Rules.forecast(engine, state)["tiles"]["strike"].is_empty() and engine.board_resolutions == 1, "Memo owns nested results across caller mutation")
	var expected: int = 1
	state["player"]["hp"] -= 1
	Rules.forecast(engine, state); expected += 1
	expect.call(engine.board_resolutions == expected, "Memo validates in-place board changes")
	state["battlefield_rule"]["dials"]["damage"] += 1
	Rules.forecast(engine, state); expected += 1
	expect.call(engine.board_resolutions == expected, "Memo validates rule dials")
	var definition: Dictionary = Data.enemies()["crawler"]
	definition["_el01_test_revision"] = 1
	Rules.forecast(engine, state); expected += 1
	expect.call(engine.board_resolutions == expected, "Memo validates in-place enemy catalog changes")
	definition.erase("_el01_test_revision")
	Rules.forecast(engine, state)
	expect.call(engine.board_resolutions == expected, "Memo reuses a fully matching restored catalog entry")
	var pressure: Dictionary = Specials._data["types"]["umbral_snare"]["variants"]["earth"]["pressure"]
	var minimum: int = int(pressure["min_steps_from_hero"])
	pressure["min_steps_from_hero"] = minimum + 1
	Rules.forecast(engine, state); expected += 1
	expect.call(engine.board_resolutions == expected, "Memo validates authored encounter data changes")
	pressure["min_steps_from_hero"] = minimum
	var key: int = hash(Rules.forecast_inputs(engine, state))
	Rules._forecast_memo._entries[key] = {"inputs": ["colliding foreign input"], "result": {"wrong": true}}
	var result: Dictionary = Rules.forecast(engine, state); expected += 1
	expect.call(not result.has("wrong") and engine.board_resolutions == expected, "Memo validates complete dependencies inside a hash collision")

static func _intents(engine: RefCounted, battle: Callable, rule: Callable, expect: Callable) -> void:
	for disabled: String in ["none", "freeze", "shock", "petrify", "missing_surface", "immobilize", "dead_on_start"]:
		var state: Dictionary = battle.call(engine)
		var intent: Dictionary = {"id": "test_discharge", "time": 4, "actions": [{"type": "block", "amount": 1}]}
		if disabled == "missing_surface": intent["actions"][0]["requires_surface"] = {"subject": "player", "surface": "ice"}
		elif disabled == "immobilize": intent["actions"] = [{"type": "move_toward", "range": 1}]
		state["enemies"][0]["intent"] = intent
		if disabled in ["freeze", "shock", "petrify"]: state["enemies"][0][disabled] = 1
		elif disabled == "immobilize": state["enemies"][0]["immobilize"] = true
		elif disabled == "dead_on_start":
			state["enemies"][0]["hp"] = 1
			Surfaces.place(state, state["enemies"][0]["pos"], "fire")
		var instance: Dictionary = rule.call("lightning_storm", {"damage": DAMAGE, "chain": 0}, true)
		instance["cadence"] = {"anchor": "on_intent", "intent": "test_discharge"}
		Rules.install(engine, state, instance)
		var order: Array[Dictionary] = engine.current_turn_order(state)
		var projected: bool = order.any(func(entry: Dictionary) -> bool: return str(entry["kind"]) == "beat")
		var after: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		var fired: bool = after.get("surface_events", []).any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "battlefield_rule_fired")
		expect.call(projected == fired and fired == (disabled == "none"), "on_intent projection and real availability agree: " + disabled)

static func _exit_data(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = SnareFixtures.battle("earth")
	var pressure: Dictionary = Specials._data["types"]["umbral_snare"]["variants"]["earth"]["pressure"]
	var original: int = int(pressure["min_steps_from_hero"])
	for minimum: int in [2, 4]:
		pressure["min_steps_from_hero"] = minimum
		state["battlefield_rule"].erase("marks")
		Rules.prepare(engine, state)
		preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
		var old: Array = Pressure.preview(engine, state)["tiles"]
		var shared: Array[Vector2i] = Rules.Upheaval.exit_lane(state)
		expect.call(shared == old and (not shared.is_empty() if minimum == 2 else shared.is_empty()), "Shared exit lane reads the authored catalog minimum: " + str(minimum))
	pressure["min_steps_from_hero"] = original

static func _occupied_marks(battle: Callable, rule: Callable, compare: Callable, expect: Callable) -> void:
	var engine := CountingEngine.new()
	var state: Dictionary = battle.call(engine)
	for row: Array in state["grid"]: row.fill("wall")
	state["grid"][2][5] = "floor"
	state["grid"][5][5] = "floor"
	Rules.install(engine, state, rule.call("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true))
	state["battlefield_rule"]["marks"] = [Vector2i(5, 5)]
	var after: Dictionary = compare.call(engine, state, expect)
	expect.call(engine.invalid_placements == 0 and after["player"]["pos"] == Vector2i(5, 5) and after["terrain"].is_empty(), "Upheaval occupied no-landing guard never attempts an invalid placement")
	state = SnareFixtures.battle("earth")
	for row: Array in state["grid"]: row.fill("wall")
	for tile: Vector2i in [Vector2i(5, 4), Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(7, 5)]: state["grid"][tile.y][tile.x] = "floor"
	state["snare_entry"] = Vector2i(5, 4)
	state["player"]["pos"] = Vector2i(5, 5)
	state["terrain"] = []
	for index: int in range(state["objective"]["exits"].size()):
		state["objective"]["exits"][index]["sealed"] = index != 0
		if index == 0: state["objective"]["exits"][index]["target_tile"] = Vector2i(7, 5)
	Rules.install(engine, state, Rules.instance_for("snare_earth"))
	state["battlefield_rule"]["marks"] = [Vector2i(5, 5)]
	expect.call(Rules.Upheaval.leaves_exit(state, Vector2i(5, 5)), "Occupied exit mark is initially reachable from the hero")
	after = compare.call(engine, state, expect)
	expect.call(after["player"]["pos"] == Vector2i(5, 5) and after["terrain"].is_empty(), "Upheaval post-displacement exit guard keeps the displaced hero's last way open")
