extends SceneTree

const Cases = preload("res://tools/ptf08/forecast_cases.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Forecast = preload("res://scripts/pass_forecast_red_tiles.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const Source = preload("res://scripts/pass_forecast_action_source.gd")
const TEST_BLOCK: int = 12
const TEST_FREEZE: int = 1
const LATE_ENEMY_TIME: int = 100

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var engine: RefCounted = scene._combat_engine
	for kind: String in ["expiry", "frozen_expiry", "hit"]:
		var state: Dictionary = _block_state(kind)
		var result: Dictionary = _forecast(scene, state)
		var live_scheduled: Dictionary = Committed.finish_player_activation(engine, state)
		var live: Dictionary = Committed.advance_to_player(engine, live_scheduled)
		var boundary: Dictionary = live["player_turn_before_state"]
		var expected: int = TEST_BLOCK - int(boundary["player"]["block"])
		if kind == "hit":
			_check(expected > 0 and expected < TEST_BLOCK, "hit removes part of the starting Block")
		else:
			_check(expected == 0, kind + " reaches the first hero turn with untouched Block")
		_check(int(engine.prepare_next_player_turn(boundary)["player"]["block"]) == 0, kind + " remaining Block expires in live preparation")
		if kind == "frozen_expiry":
			_check(int(result["summary"]["skipped_turns"]) == 1, "frozen expiry crosses two turn-start boundaries")
		var rows: String = result["rows"]
		var actual: int = int(result["summary"]["block_loss"])
		print("GFIX13 %s: starting_block=%d live_enemy_loss=%d forecast_block_loss=%d rows=%s" % [kind, TEST_BLOCK, expected, actual, rows.replace("\n", " | ")])
		_check(actual == expected, kind + " summary counts only enemy Block loss")
		_check(rows.contains("block:−%d" % expected) if expected > 0 else not rows.contains("block:"), kind + " panel Block row matches live enemy loss")
		var entries: Array = result["summary"]["entries"]
		var block_entries: Array = entries.filter(func(entry: Dictionary) -> bool: return entry["name"] == "PassPreviewBlockLoss")
		_check(block_entries.size() == (1 if expected > 0 else 0), kind + " Pass loss entries match the Block row")
	var snare: Dictionary = _snare_run(scene)["combat_state"]
	_check_snare(scene, snare, true)
	snare["cards_played_this_turn"] = snare["cards_per_turn"]
	_check_snare(scene, snare, false)
	_check_frozen_snare(scene)
	scene.free()
	print("GFIX13 PASS TRUTH: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _check_snare(scene: Node, snare: Dictionary, acts_first: bool) -> void:
	var engine: RefCounted = scene._combat_engine
	var result: Dictionary = _forecast(scene, snare)
	var live_scheduled: Dictionary = Committed.finish_player_activation(engine, snare)
	var hunters: Array = live_scheduled["enemies"].filter(func(enemy: Dictionary) -> bool: return bool(enemy.get("snare_hunter", false)))
	_check(live_scheduled["enemies"].size() == snare["enemies"].size() + 1 and hunters.size() == 1, "Earth Snare spawns one hunter during Pass")
	if not hunters.is_empty():
		_check(engine.is_enemy_visible_to_player(snare, hunters[0]), "Earth Snare arrival is visible")
		var hunter_key: String = "enemy_%d" % int(hunters[0]["id"])
		_check(result["summary"]["enemy_activations"].has(hunter_key) == acts_first, "Earth Snare hunter activation matches the fixture's clock")
	var live: Dictionary = Committed.advance_to_player(engine, live_scheduled)
	var live_loss: int = int(snare["player"]["hp"]) - int(live["state"]["player"]["hp"])
	var summary: Dictionary = result["summary"]
	var rows: String = result["rows"]
	print("GFIX13 earth_snare: hunters=%d live_health_loss=%d forecast_health_loss=%d new_arrival=%s rows=%s" % [hunters.size(), live_loss, int(summary["hp_loss"]), str(summary["new_arrival_before_player"]), rows.replace("\n", " | ")])
	_check(int(summary["hp_loss"]) == live_loss, "Earth Snare preserves the correct Pass loss")
	_check(rows.count("turn_clock:?") == (1 if acts_first else 0), "Earth Snare clock row matches the hunter's initiative")
	_check(rows.contains("Safe") != acts_first, "Earth Snare is Safe when the hunter waits and the total is zero")
	var tooltip: String = scene._pass_preview_tooltip(summary)
	_check(tooltip.contains("A new enemy acts before you.") == acts_first, "Earth Snare narration matches the fixture's clock")

func _check_frozen_snare(scene: Node) -> void:
	var state: Dictionary = _snare_run(scene)["combat_state"]
	# Defer the first spawn until preparation clears the prior round's pending bit.
	state["objective"]["enemy_round_pending"] = true
	state["player"]["freeze"] = TEST_FREEZE
	var engine: RefCounted = scene._combat_engine
	var first: Dictionary = Committed.finish_player_activation(engine, state)
	var skipped: Dictionary = Committed.advance_to_player(engine, first)["state"]
	var second: Dictionary = Committed.finish_player_activation(engine, skipped)
	var live: Dictionary = Committed.advance_to_player(engine, second)
	var hunter_keys: Array[String]
	for enemy: Dictionary in second["enemies"]:
		if bool(enemy.get("snare_hunter", false)): hunter_keys.append("enemy_%d" % int(enemy["id"]))
	var acts_first: bool = live["steps"].any(func(step: Dictionary) -> bool:
		return step.get("kind") == "intent" and hunter_keys.has(step.get("actor_key", "")))
	var result: Dictionary = _forecast(scene, state)
	_check(first["objective"]["hunters_spawned"] == 0 and hunter_keys.size() == 1, "Earth Snare hunter spawns at the skipped turn's end")
	_check(int(result["summary"]["skipped_turns"]) == 1, "Earth Snare forecast crosses one Freeze-skipped turn")
	_check(bool(result["summary"]["new_arrival_before_player"]) == acts_first, "Earth Snare skipped span uses the live hunter's initiative")
	_check(result["rows"].contains("turn_clock:?") == acts_first, "Earth Snare skipped span clock row matches live initiative")
	_check(int(result["summary"]["hp_loss"]) == int(state["player"]["hp"]) - int(live["state"]["player"]["hp"]), "Earth Snare skipped span keeps the live Health total")
	print("GFIX13 frozen_earth_snare: hunters=%d acts_first=%s rows=%s" % [hunter_keys.size(), acts_first, result["rows"].replace("\n", " | ")])

func _block_state(kind: String) -> Dictionary:
	var state: Dictionary = Cases.fixture("danger" if kind == "hit" else "safe")
	state["player"]["block"] = TEST_BLOCK
	if kind == "frozen_expiry":
		state["player"]["freeze"] = TEST_FREEZE
		state["turn_queue"][0]["time"] = LATE_ENEMY_TIME
	return state

func _snare_run(scene: Node) -> Dictionary:
	var run_engine := preload("res://scripts/run_engine.gd").new()
	var run: Dictionary = run_engine.create_new_run(Snare.FIXTURE_SEED, preload("res://scripts/progression_store.gd").default_data())
	return Snare.build(run_engine, scene._combat_engine, run, {"snare_biome": "earth"})

func _forecast(scene: Node, state: Dictionary) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var source: Dictionary = Source.rest_source(scene, state)
	var scheduled: Dictionary = Forecast.schedule(engine, source)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	var summary: Dictionary = scene._pass_preview_summary_for_phase_result(source, phase)
	return {"summary": summary, "rows": Rows.text(scene, summary)}

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)
