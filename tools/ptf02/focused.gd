extends "res://tests/helpers/counted_program.gd"

const MapSuite = preload("res://tests/suites/section_map_v7_suite.gd")
const Rules = preload("res://tools/ptf02/map_rules.gd")
const EngineScript = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const DepthRules = preload("res://scripts/depth_rules.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await MapSuite.run(Callable(self, "_expect"))
	var engine := EngineScript.new()
	var state: Dictionary = engine.create_new_run(83, Store.default_data())
	for index: int in range(6): Rules.validate(state, index, Callable(self, "_expect"))
	var fallback: Dictionary = {"seed": 83, "current_room": Vector2i.ZERO, "mode": "room"}
	MapSuite.Graph.initialize(fallback, {"force_v7_fallback": true})
	for index: int in range(6): Rules.validate(fallback, index, Callable(self, "_expect"))
	for index: int in range(6):
		for node: Dictionary in state["rooms"].values():
			if int(node["section_index"]) != index or str(node["type"]) != "campfire": continue
			state["current_room"] = node["coord"]
			state["mode"] = "campfire"
			state["player_hp"] = 8
			_expect(engine.campfire_linger_heal(state) == 6, "Both Hearth rows expose a base Linger heal of six")
			_expect(int(engine.leave_campfire(state, engine.CAMPFIRE_LINGER_HEAL)["player_hp"]) == 14, "Both Hearth rows restore six HP")
			state[DepthRules.STATE_KEY] = 5
			_expect(engine.campfire_linger_heal(state) == 5 and int(engine.leave_campfire(state, engine.CAMPFIRE_LINGER_HEAL)["player_hp"]) == 13, "Umbra depth delta remains minus one at both Hearths")
			state[DepthRules.STATE_KEY] = 0
			state["player_hp"] = 22
			_expect(int(engine.leave_campfire(state, engine.CAMPFIRE_LINGER_HEAL)["player_hp"]) == 24, "Linger remains capped at maximum HP")
	_finish("PTF02 FOCUSED RESULT")
