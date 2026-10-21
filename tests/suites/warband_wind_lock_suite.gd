extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Orders = preload("res://tests/suites/warband_orders_suite.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const View = preload("res://scripts/enemy_mechanics/wind_view.gd")
const PLAYER_TILES: Array = [Vector2i(2, 3), Vector2i(8, 3), Vector2i(2, 8), Vector2i(8, 8)]
const SELECTION_SEEDS: int = 32
const PROOF_MOVE_RANGE: int = 20

class ForecastBoard extends Control:
	var combat_state: Dictionary = {}

static func run(expect: Callable) -> void:
	for ordinary: bool in [true, false]:
		var engine := Combat.new()
		var state: Dictionary = Orders.battle("air", ordinary)
		var enemy: Dictionary = state["enemies"][0]
		var intent: Dictionary = engine._surface_prepare_enemy_intent(state, enemy, Orders.authored(state, "call_the_wind"))
		expect.call(not intent.is_empty(), "Wind fixture has authored Call")
		if intent.is_empty(): continue
		state["enemies"][0]["intent"] = intent
		var action: Dictionary = intent["actions"][0]
		var locked: Vector2i = action["_wind_direction"]
		var board := ForecastBoard.new()
		var reaim_differs: bool = false
		for tile: Vector2i in PLAYER_TILES:
			# A player move/action creates a new board state; every presentation
			# consumer must still use the direction in the announced intent.
			state = engine.apply_player_action(state, {"type": "move", "range": PROOF_MOVE_RANGE}, tile)
			expect.call(state["player"]["pos"] == tile, "Regression uses the real player movement action")
			reaim_differs = reaim_differs or Wind.direction(engine, state, state["enemies"][0]) != locked
			state = engine.apply_prevalidated_player_action(state, {"type": "block", "amount": 1}, Vector2i(-1, -1))
			var before: Dictionary = state.duplicate(true)
			var plan: Dictionary = engine.enemy_intent_plan(state, 0)
			expect.call(plan["wind"]["direction"] == locked, "Hero movement/card play never re-aims announced wind")
			board.combat_state = state
			var forecast: Dictionary = View.forecast(board)
			expect.call(forecast["layers"][0]["wind"]["direction"] == locked, "Dashed slide preview uses locked direction")
			expect.call(state == before, "Hover/slide preview is read-only")
			var called: Dictionary = Wind.resolve(engine, state.duplicate(true), 0, action)
			expect.call(Wind.active(engine, called)["direction"] == locked, "Wind chip's active source and real blow use locked direction")
			var steps: Array[Dictionary]
			called = Wind.end_turn(engine, called, steps)
			expect.call(steps[0]["action_direction"] == locked, "Resolved gust matches announced direction")
			if not ordinary:
				# Held wind persists through other actors' activations and hero moves.
				called["player"]["pos"] = PLAYER_TILES[0]
				expect.call(Wind.active(engine, called)["direction"] == locked, "Stormcaller held gust never tracks player")
		expect.call(reaim_differs, "Regression crosses positions that formerly changed direction")
		# The next own-turn selection may choose a new announcement. Only that
		# explicit selection replaces the action's saved direction.
		var next: Dictionary = engine._surface_prepare_enemy_intent(state, state["enemies"][0], intent)
		expect.call(next["actions"][0]["_wind_direction"] == Wind.direction(engine, state, state["enemies"][0]), "Own-turn intent selection re-aims next Call")
		expect.call(intent["actions"][0]["_wind_direction"] == locked, "New selection preserves prior owned intent")
		var resumed: Dictionary = state.duplicate(true)
		resumed["enemies"][0]["intent"] = Orders.authored(state, "call_the_wind")
		Wind.lock_legacy_intents(engine, resumed)
		var saved_direction: Vector2i = resumed["enemies"][0]["intent"]["actions"][0]["_wind_direction"]
		resumed["player"]["pos"] = PLAYER_TILES[1]
		Wind.lock_legacy_intents(engine, resumed)
		expect.call(resumed["enemies"][0]["intent"]["actions"][0]["_wind_direction"] == saved_direction, "Legacy load chooses exactly once without replacing saved locks")
		var selected_calls: int = 0
		var rng := RandomNumberGenerator.new()
		for seed: int in range(SELECTION_SEEDS):
			rng.seed = seed
			engine._assign_enemy_intent(state, 0, rng)
			for selected: Dictionary in state["enemies"][0]["intent"].get("actions", []):
				if str(selected.get("type", "")) == "call_wind":
					selected_calls += 1
					expect.call(selected.has("_wind_direction"), "Production selection records direction")
		expect.call(selected_calls > 0, "Production selection exercised Call")
		board.free()
	print("Warband wind lock: both sources, hero moves, card play, hover, real gust, held wind and own-turn re-aim checked")
