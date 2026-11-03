extends RefCounted
## Proof-only boards using the existing camera, HUD and approved source assets.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Fixtures = preload("res://tests/suites/en02_enemies_suite.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const SOURCE_POSITION := Vector2i(4, 3)
const HERO_POSITION := Vector2i(6, 6)
const PROOF_WAIT_TIME: int = 4
const PROOF_ROOM_DEPTH: int = 2
const HALF_HEALTH_PROOF_MARGIN: int = 1
const ROOM_COORD := Vector2i(1, 0)
const TOWARD_SOURCE_SENTENCE: String = "After each of your turns, the Roc's wind Pushes everyone 1 tile toward it."
const CLOCKWISE_SENTENCE: String = "After each Vaeloryx turn, its wind Pushes everyone 1 tile, then turns a quarter clockwise."
const HALF_HEALTH_SENTENCE: String = "After each of its turns, its wind Pushes everyone 2 tiles, then turns a quarter clockwise."
const CASES: Array = ["toward_source", "turn_clockwise", "half_health"]

static func battle(engine: RefCounted, case_name: String) -> Dictionary:
	var state: Dictionary = Fixtures.fixture(engine, "gallows_roc" if case_name == "toward_source" else "vaeloryx")
	state["enemies"][0]["pos"] = SOURCE_POSITION
	state["player"]["pos"] = HERO_POSITION
	state["enemies"][0]["intent"] = {"id": "bos01_proof_wait", "time": PROOF_WAIT_TIME, "actions": []}
	if case_name == "toward_source": state["enemies"][0]["anchored"] = true
	var instance: Dictionary = {"rule": "gust", "source": {"kind": "enemy", "id": 1}, "cadence": {"anchor": "after_player_turn" if case_name == "toward_source" else "after_source_turn", "every": 1}, "dials": {"tiles": 1, "direction": "toward_source" if case_name == "toward_source" else "turn_clockwise"}, "sentence": TOWARD_SOURCE_SENTENCE if case_name == "toward_source" else CLOCKWISE_SENTENCE}
	if case_name == "half_health": instance["at_half_health"] = {"dials": {"tiles": 2}, "sentence": HALF_HEALTH_SENTENCE}
	Rules.install(engine, state, instance)
	return state

static func run_state(state: Dictionary) -> Dictionary:
	var run: Dictionary = Run.new().create_new_run(Fixtures.FIXTURE_SEED, Store.default_data())
	var layout: Dictionary = {"name": "bos-01 proof", "coord": ROOM_COORD, "depth": PROOF_ROOM_DEPTH, "type": "combat", "element": "none", "grid": state["grid"], "player_start": state["player"]["pos"], "enemies": state["enemies"], "terrain": state.get("terrain", []), "traps": state.get("traps", []), "loot": []}
	run["rooms"]["1,0"] = {"coord": ROOM_COORD, "depth": PROOF_ROOM_DEPTH, "type": "combat", "element": "none", "revealed": true, "visited": true, "connections": [], "npcs": []}
	run.merge({"mode": "combat", "current_room": ROOM_COORD, "current_room_layout": layout, "combat_state": state, "notice": ""}, true)
	return run
