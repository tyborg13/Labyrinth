extends SceneTree
const Runtime = preload("res://scripts/parallel_runtime.gd")
const EngineScript = preload("res://scripts/combat_engine.gd")
const Reference = preload("res://tests/fixtures/enemy_route_allocation_reference.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
var failures: Array[String]
var comparisons: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var engine := EngineScript.new()
	var reference := Reference.new()
	for origin: Vector2i in [Vector2i(-4, -3), Vector2i.ZERO, Vector2i(7, 4)]:
		for footprint: Vector2i in [Vector2i.ZERO, Vector2i.ONE, Vector2i(2, 3), Vector2i(3, 2), Vector2i(-2, -1)]:
			var actor: Dictionary = {"pos": origin, "footprint": footprint}
			for y: int in range(-6, 12):
				for x: int in range(-6, 14):
					var tile := Vector2i(x, y)
					_check(engine._enemy_distance_to_tile(actor, tile) == reference._enemy_distance_to_tile(actor, tile), "Footprint distance")
					_check(engine._closest_enemy_tile_to(actor, tile) == reference._closest_enemy_tile_to(actor, tile), "Closest footprint tile")
	for actor: Dictionary in [{}, {"footprint": Vector2i(2, 2)}, {"pos": Vector2i(9, 2)}]:
		for tile: Vector2i in [Vector2i(-20000, 0), Vector2i(20000, 0), Vector2i(9998, 0), Vector2i(-9999, 0), Vector2i.ZERO]:
			_check(engine._enemy_distance_to_tile(actor, tile) == reference._enemy_distance_to_tile(actor, tile), "Sentinel distance")
			_check(engine._closest_enemy_tile_to(actor, tile) == reference._closest_enemy_tile_to(actor, tile), "Sentinel closest tile")
	var candidate_usec: int = 0
	var reference_usec: int = 0
	var plans: int = 0
	var turns: int = 0
	for fixture_name: String in ["open", "blocked", "dense", "heart", "surface_ready"]:
		var base: Dictionary = Fixture._fixture(engine, fixture_name)
		for enemy_type: String in Data.enemies():
			var definition: Dictionary = Data.enemy_def(enemy_type)
			var intents: Array = engine._scaled_enemy_intents(definition.get("intents", []), 7)
			for intent: Dictionary in intents:
				var state: Dictionary = base.duplicate(true)
				var actor: Dictionary = engine._normalized_enemy({"id": 1, "type": enemy_type, "pos": Vector2i(6, 4), "hp": 80, "max_hp": 80, "intent": intent})
				state["enemies"][0] = actor
				var before: Dictionary = state.duplicate(true)
				for locked: bool in [false, true]:
					var started: int = Time.get_ticks_usec()
					var expected: Dictionary = reference.enemy_intent_plan(state, 0, {}, locked, locked)
					reference_usec += Time.get_ticks_usec() - started
					started = Time.get_ticks_usec()
					var actual: Dictionary = engine.enemy_intent_plan(state, 0, {}, locked, locked)
					candidate_usec += Time.get_ticks_usec() - started
					_check(actual == expected, "Plan %s/%s/%s/%s" % [fixture_name, enemy_type, intent.get("name", ""), locked])
					_check(state == before, "Planning cannot mutate source")
					plans += 1
				# Whole resolver output includes authoritative state, RNG, log and
				# presentation steps, so planning must preserve more than endpoints.
				_check(engine.resolve_enemy_turn_with_steps(state, 0, true) == reference.resolve_enemy_turn_with_steps(state, 0, true), "Turn %s/%s/%s" % [fixture_name, enemy_type, intent.get("name", "")])
				_check(state == before, "Turn resolver cannot mutate source")
				turns += 1
	print("ROUTE ALLOCATION RESULT: " + JSON.stringify({"comparisons": comparisons, "plans": plans, "turns": turns, "candidate_plan_usec": candidate_usec, "reference_plan_usec": reference_usec, "errors": failures}))
	print("TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	comparisons += 1
	if not ok:
		failures.append(label)
		push_error(label)
