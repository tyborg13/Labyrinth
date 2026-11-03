extends RefCounted
## Director feedback 1: switch-free forecasts and the two independent route guards.
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const Dragon = preload("res://scripts/dragon_combat_rules.gd")
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const BENCHMARK_SIZE: int = 64
const BENCHMARK_SAMPLES: int = 5
const BENCHMARK_SOURCE := Vector2i(5, 5)
const BENCHMARK_HERO := Vector2i(32, 32)
const BENCHMARK_EXIT := Vector2i(62, 62)
const RING: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(2, 3)]

# Observe the private resolver snapshot at the damage boundary, not just the
# public projection (which intentionally omits cadence/latch/event metadata).
class DamageObserver extends Combat:
	var observations: Array[Dictionary]
	func _damage_enemy(state: Dictionary, enemy_index: int, damage: int, apply_freeze_multiplier: bool = true, bypass_defense: bool = false, apply_relic_bonus: bool = true, apply_direct_amplification: bool = true) -> Dictionary:
		var after: Dictionary = super._damage_enemy(state, enemy_index, damage, apply_freeze_multiplier, bypass_defense, apply_relic_bonus, apply_direct_amplification)
		observations.append(after.get("battlefield_rule", {}).duplicate(true))
		return after

static func run(expect: Callable) -> void:
	_announced_collision(expect)
	var engine := Combat.new()
	_objective_exit(engine, expect)
	_displaced_source(engine, expect)
	_fifo(engine, expect)
	_benchmark(engine, expect)

static func _announced_collision(expect: Callable) -> void:
	var engine := DamageObserver.new()
	var state: Dictionary = Base.battle(engine)
	state["player"]["pos"] = Vector2i(5, 2)
	state["enemies"][0].merge({"pos": Vector2i(5, 5), "hp": 26, "max_hp": 50}, true)
	var authored: Dictionary = Base.rule("gust", {"tiles": 1, "direction": "toward_source"}, true)
	authored["at_half_health"] = {"dials": {"direction": "turn_clockwise", "tiles": 2}, "cadence": {"every": 2}, "sentence": Base.rule("gust", {}, true)["sentence"]}
	Rules.install(engine, state, authored)
	state["enemies"][0]["pos"] = Vector2i(5, 9)
	var before: Dictionary = state.duplicate(true)
	engine.observations.clear()
	var forecast: Dictionary = Rules.forecast(engine, state)
	expect.call(forecast["direction"] == Vector2i.DOWN, "BOS01 F1 Collision forecast returns the announced Down direction")
	expect.call(not engine.observations.is_empty(), "BOS01 F1 Collision preview actually damages the 26/50 source")
	for instance: Dictionary in engine.observations:
		expect.call(instance["dials"] == authored["dials"] and instance["cadence"] == authored["cadence"] and instance["locked_direction"] == Vector2i.DOWN and not bool(instance.get("half_health_switched", false)), "BOS01 F1 preview never applies or latches half Health")
	expect.call(state == before, "BOS01 F1 Collision forecast leaves the announcement and saved state untouched")
	var value: Dictionary = Gust.active(engine, state)
	var primitive: Dictionary = Gust.preview(engine, state, value)["state"]
	expect.call(primitive["enemies"][0]["hp"] == 24 and primitive["battlefield_rule"]["dials"] == authored["dials"] and not bool(primitive["battlefield_rule"].get("half_health_switched", false)), "BOS01 F1 Gust preview also suppresses the private switch")
	var after: Dictionary = preload("res://scripts/battlefield_rules/committed.gd").beat(engine, state.duplicate(true))
	expect.call(after["player"]["pos"] == Vector2i(5, 3), "BOS01 F1 Collision resolution still pushes Down")
	expect.call(bool(after["battlefield_rule"].get("half_health_switched", false)) and after["battlefield_rule"]["cadence"]["every"] == 2 and after["battlefield_rule"]["dials"]["tiles"] == 2, "BOS01 F1 only committed Collision applies the switch")
	var comparable: Dictionary = forecast.duplicate(true)
	comparable.erase("direction")
	expect.call(comparable == preload("res://scripts/battlefield_rules/outcomes.gd").project(engine, before, after), "BOS01 F1 Collision forecast equals the committed beat")

static func _upheaval() -> Dictionary:
	return Base.rule("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true)

static func _objective_exit(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = Base.battle(engine)
	var exit_tile := Vector2i(5, 4)
	state["objective"]["exits"] = [{"target_tile": exit_tile, "sealed": false}]
	expect.call(Dragon.spire_preserves_routes(engine, state, state["enemies"][0], exit_tile), "BOS01 F1 sole-exit mark is structurally safe")
	Rules.install(engine, state, _upheaval())
	expect.call(state["battlefield_rule"]["marks"] == [Vector2i(4, 4), Vector2i(6, 4)], "BOS01 F1 objective guard skips only the sole declared exit")
	state["battlefield_rule"]["marks"] = [exit_tile]
	Base.mature_fuel(state)
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	expect.call(after["terrain"].is_empty(), "BOS01 F1 objective guard rejects a held sole-exit mark")

static func _displaced_source(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = Base.battle(engine)
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()): state["grid"][y][x] = "stone" if RING.has(Vector2i(x, y)) else "wall"
	state["enemies"][0]["pos"] = Vector2i(2, 2)
	state["player"]["pos"] = Vector2i(4, 4)
	var instance: Dictionary = _upheaval()
	instance["marks"] = [Vector2i(2, 2)]
	Rules.install(engine, state, instance)
	expect.call(Rules.Upheaval.line_preserves_routes(engine, state, instance, Vector2i(2, 2)), "BOS01 F1 ring source has two exits before displacement")
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	expect.call(after["terrain"].is_empty() and after["enemies"][0]["pos"] == Vector2i(2, 2), "BOS01 F1 post-displacement guard rejects both rise and source movement")
	var forecast: Dictionary = Rules.forecast(engine, state)
	expect.call(forecast["moves"].is_empty() and forecast["tiles"]["rise"].is_empty(), "BOS01 F1 ring forecast commits neither a rise nor a displacement")

static func _fifo(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = Base.battle(engine)
	state["objective"]["exits"] = [{"target_tile": Vector2i(7, 5), "sealed": true}]
	state["terrain"] = [{"pos": Vector2i(6, 5), "hp": 3}]
	var start: Vector2i = state["player"]["pos"]
	var fifo: Dictionary = Pressure.walking_paths(state, start)
	var weighted: Dictionary = Pressure.walking_paths(state, start, true)
	expect.call(fifo == weighted, "BOS01 F1 FIFO preserves Dijkstra costs, steps and deterministic parents without Rubble")
	var goals: Dictionary = {Vector2i(5, 4): true}
	var early: Dictionary = Pressure.walking_paths(state, start, false, goals)
	expect.call(early["reached_goal"] and early["costs"].size() < fifo["costs"].size(), "BOS01 F1 unweighted goal search stops at the first reachable exit")
	goals = {Vector2i(7, 5): true}
	var blocked: Dictionary = Pressure.walking_paths(state, start, false, goals)
	expect.call(not blocked["reached_goal"] and blocked["costs"].size() == 1, "BOS01 F1 blocked sole exit returns without flooding the floor")
	Surfaces.place(state, start, "rubble")
	weighted = Pressure.walking_paths(state, start, true)
	expect.call(weighted["costs"][Vector2i(5, 4)] == 2, "BOS01 F1 weighted Rubble still costs two to leave")

static func _benchmark(engine: RefCounted, expect: Callable) -> void:
	var fixture: Dictionary = Base.battle(engine)
	var grid: Array
	for y: int in range(BENCHMARK_SIZE):
		var row: Array[String]
		for x: int in range(BENCHMARK_SIZE): row.append("wall" if x == 0 or y == 0 or x == BENCHMARK_SIZE - 1 or y == BENCHMARK_SIZE - 1 else "stone")
		grid.append(row)
	fixture["grid"] = grid
	fixture["enemies"][0]["pos"] = BENCHMARK_SOURCE
	fixture["player"]["pos"] = BENCHMARK_HERO
	fixture["objective"]["exits"] = [{"target_tile": BENCHMARK_EXIT, "sealed": false}]
	var timings: Array[float]
	for sample: int in range(BENCHMARK_SAMPLES):
		var state: Dictionary = fixture.duplicate(true)
		var instance: Dictionary = _upheaval()
		instance["dials"]["length"] = 5
		var started: int = Time.get_ticks_usec()
		Rules.Upheaval.prepare(engine, state, instance)
		timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
		expect.call(instance["marks"].size() == 5, "BOS01 F1 64x64 timing covers all five objective-guarded marks")
	timings.sort()
	print("BOS01 F1 64x64 PREPARE: min=%.3f median=%.3f max=%.3f ms (%d samples, five marks, one exit)" % [timings[0], timings[BENCHMARK_SAMPLES / 2], timings[-1], BENCHMARK_SAMPLES])
