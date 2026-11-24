extends SceneTree

const Fixture = preload("res://tools/gfix49/roost_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const PassForecast = preload("res://scripts/pass_forecast_red_tiles.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const RulesView = preload("res://scripts/battlefield_rule_view.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const Arena = preload("res://tests/suites/battlefield_rules_suite.gd")
const Enemies = preload("res://tests/suites/en02_enemies_suite.gd")
const Warbands = preload("res://tests/suites/warband_suite.gd")
const Snares = preload("res://tests/suites/snare_suite.gd")
const CROSSING_DISTANCE: int = 2
const SAVE_PATH: String = "user://gfix49_legacy.save"

var _engine := Combat.new()
var _run := Run.new()
var _failures: int = 0
var _checks: int = 0

class Board extends Control:
	var combat_state: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run_witness")

func _run_witness() -> void:
	if OS.get_cmdline_user_args().has("--battlefield-suite"):
		Arena.run(_expect)
		_finish("BATTLEFIELD RULES SUITE")
		return
	var board := Board.new()
	var opening_run: Dictionary = Fixture.build(_run, _engine)
	var west: Dictionary = opening_run["combat_state"]
	var west_view: Dictionary = _preview(board, west)
	_expect(west_view["heading"] == Vector2i.RIGHT and west_view["board"] == Vector2i.RIGHT, "opening forecast and board wind face east")
	_record("roost_still", _pass(west), west_view["heading"])
	var tie: Dictionary = Fixture.build(_run, _engine, Fixture.TIE_OFFSET)["combat_state"]
	var tie_view: Dictionary = _preview(board, tie)
	_expect(tie_view["heading"] == Vector2i.RIGHT and tie_view["board"] == Vector2i.RIGHT, "diagonal tie favors the horizontal axis")
	_record("roost_tie", _pass(tie), tie_view["heading"])
	var east: Dictionary = _engine.apply_player_movement(west, Fixture.east(west))
	print("GFIX-49 ROOST WALK: hero=%s roc=%s before=%s after=%s" % [west["player"]["pos"], west["enemies"][0]["pos"], west_view["heading"], _preview(board, east)["heading"]])
	_expect(east["player"]["pos"] == Fixture.east(west), "normal movement reaches the east tile")
	_check_live(board, "walk", east)
	var pass_result: Dictionary = _pass(east)
	_expect(pass_result["steps"].size() == 1, "Pass commits exactly one Gust beat")
	if not pass_result["steps"].is_empty():
		var beat: Dictionary = pass_result["steps"][0]
		_expect(beat.get("action_direction") == Vector2i.LEFT, "committed beat goes west")
		var relative_moves: Array = Rules.Outcomes.project(_engine, beat["before"], beat["after"], false)["moves"]
		_expect(relative_moves.size() == east["enemies"].size() and relative_moves.all(func(move: Dictionary) -> bool: return move["to"] - move["from"] == Vector2i.LEFT), "hero and each unanchored helper move west by one tile")
		_expect(beat["before"]["enemies"][0]["pos"] == beat["after"]["enemies"][0]["pos"], "the Anchored Roc holds")
	_record("roost_walk", pass_result, _preview(board, east)["heading"])
	var blink: Dictionary = _engine.apply_player_action(west, {"type": "blink", "range": CROSSING_DISTANCE}, Fixture.east(west))
	_expect(blink["player"]["pos"] == Fixture.east(west), "Blink reaches the east tile")
	_check_live(board, "blink", blink)
	var swap: Dictionary = west.duplicate(true)
	swap["enemies"][1]["pos"] = Fixture.east(west)
	swap = _engine.apply_player_action(swap, {"type": "swap", "range": CROSSING_DISTANCE}, Fixture.east(west))
	_expect(swap["player"]["pos"] == Fixture.east(west) and swap["enemies"][1]["pos"] == west["player"]["pos"], "Swap exchanges the hero and a fledgling")
	_check_live(board, "swap", swap)
	var pushed: Dictionary = _engine._force_move_actor(west.duplicate(true), "player", -1, Vector2i.RIGHT, CROSSING_DISTANCE, {}, true)
	_expect(pushed["player"]["pos"] == Fixture.east(west), "ordinary forced movement pushes the hero east")
	_check_live(board, "push", pushed)
	_save_check(board, opening_run, east)
	board.free()
	_control_outcomes()
	_finish("WITNESS")

func _finish(label: String) -> void:
	print("GFIX-49 %s: %s (%d checks, %d failures)" % [label, "PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _preview(board: Board, state: Dictionary) -> Dictionary:
	board.combat_state = state
	var forecast: Dictionary = Rules.forecast(_engine, state)
	var wind: Dictionary = WindView.forecast(board)
	return {"heading": forecast.get("direction"), "board": wind.get("wind", {}).get("direction"), "moves": forecast.get("moves", []),
		"paths": wind.get("displacement_paths", []), "tiles": RulesView._due_tiles(state)}

func _check_live(board: Board, label: String, state: Dictionary) -> void:
	var view: Dictionary = _preview(board, state)
	_expect(view["heading"] == Vector2i.LEFT and view["board"] == Vector2i.LEFT, label + " refreshes forecast and board heading")
	var hero: Vector2i = state["player"]["pos"]
	_expect(view["paths"].any(func(path: Array) -> bool: return path == [hero, hero + Vector2i.LEFT]) and view["tiles"].has(hero), label + " refreshes the hero landing ghost and threat tile")
	_expect(view["moves"].any(func(move: Dictionary) -> bool: return move["actor_key"] == "player" and move["to"] == hero + Vector2i.LEFT), label + " projects the westward hero landing")
	_expect(PassForecast.schedule(_engine, state)["player"]["pos"] == hero + Vector2i.LEFT, label + " starts the Pass danger forecast from the westward landing")

func _pass(state: Dictionary) -> Dictionary:
	var steps: Array[Dictionary]
	var after: Dictionary = Committed.finish_player_activation_with_rule_steps(_engine, state.duplicate(true), steps)
	return {"after": after, "steps": steps}

func _save_check(board: Board, run: Dictionary, state: Dictionary) -> void:
	# Serialize the old eastbound lock and its legacy wind mirror mid-turn.
	var save: Dictionary = run.duplicate(true)
	var old: Dictionary = state.duplicate(true)
	old["battlefield_rule"]["locked_direction"] = Vector2i.RIGHT
	old["wind"]["direction"] = Vector2i.RIGHT
	save["combat_state"] = old
	Store.set_run_storage_path(SAVE_PATH)
	_expect(Store.save_run_state(save), "legacy-shaped checkpoint writes through the normal save API")
	var loaded: Dictionary = Store.load_checkpoint_for_resume()
	_expect(loaded.get("combat_state", {}).get("battlefield_rule", {}).get("locked_direction") == Vector2i.RIGHT, "Continue reads the old eastbound lock from disk")
	if not loaded.has("combat_state"): return
	var restored: Dictionary = _engine.normalize_player_movement_pool(loaded["combat_state"])
	_check_live(board, "loaded snapshot", restored)
	Wind.lock_legacy_intents(_engine, restored)
	_check_live(board, "legacy Continue", restored)
	var result: Dictionary = _pass(restored)
	_expect(not result["steps"].is_empty() and result["steps"][0].get("action_direction") == Vector2i.LEFT, "legacy Continue resolves west despite the saved eastbound lock")

func _control_outcomes() -> void:
	for mode: String in ["aimed", "toward_entry", "fixed:up", "fixed:right", "fixed:down", "fixed:left", "turn_clockwise"]:
		var state: Dictionary = Arena.battle(_engine)
		state["snare_entry"] = Vector2i(1, 5)
		var instance: Dictionary = Arena.rule("gust", {"tiles": 1, "direction": mode}, true)
		if mode == "aimed": instance["locked_direction"] = Vector2i.RIGHT
		Rules.install(_engine, state, instance)
		var forecast: Dictionary = Rules.forecast(_engine, state)
		var steps: Array[Dictionary]
		var after: Dictionary = Rules.fire(_engine, state, steps)
		_record(mode, {"forecast": forecast, "after": after, "steps": steps}, forecast.get("direction"))
	var herald: Dictionary = Enemies.fixture(_engine, "gale_herald")
	var stormcaller: Dictionary = Warbands.battle("air", 2)
	for state: Dictionary in [herald, stormcaller]:
		var enemy: Dictionary = state["enemies"][0]
		enemy["intent"] = _engine._surface_prepare_enemy_intent(state, enemy, Enemies.intent("gale_herald", "call_the_wind"))
		var called: Dictionary = Committed.enemy_turn(_engine, state, 0)
		var installed: Dictionary = called["state"]
		var forecast: Dictionary = Rules.forecast(_engine, installed)
		var steps: Array[Dictionary]
		var after: Dictionary = Rules.fire(_engine, installed, steps)
		var label: String = "gale_herald" if state == herald else "stormcaller"
		_expect(not steps.is_empty(), label + " control commits a Gust beat")
		_record(label, {"call": called["steps"], "forecast": forecast, "after": after, "steps": steps}, forecast.get("direction"))
	for biome: String in ["fire", "ice", "lightning", "air", "earth", "shadow"]:
		var state: Dictionary = Snares.battle(biome)
		var forecast: Dictionary = Rules.forecast(_engine, state)
		var after: Dictionary = Committed.advance_to_player(_engine, _pass(state)["after"])
		_record("snare_" + biome, {"forecast": forecast, "outcome": after}, forecast.get("direction"))

func _record(label: String, result: Dictionary, heading: Variant) -> void:
	print("GFIX-49 OUTCOME %s heading=%s sha256=%s" % [label, heading, var_to_bytes(result).hex_encode().sha256_text()])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("GFIX-49 FAIL: ", message)
