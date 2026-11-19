extends "res://tools/perf134/probe.gd"
## Headless forecast receipts and stand-in timings on the strict capture fixtures.

const Cases = preload("res://tools/ptf07/forecast_cases.gd")
const Source = preload("res://scripts/pass_forecast_action_source.gd")
const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const ENCOUNTERS: Array = ["normal", "tharokh", "guardian", "warband", "umbra"]
const FRAME_LIMIT: int = 240
const FIXTURE_ANALYTICS_RUN: String = "perf140_fixture"
const FIXTURE_ANALYTICS_COMBAT: String = "perf140_fixture_c001"

var _receipts: Dictionary = {}
var _timings: Dictionary = {}

func _run() -> void:
	_output = _argument("--output=")
	if not _headless or _output.is_empty():
		_finish("PERF-140 requires headless Godot and --output=DIR.")
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	View.Settings.save_settings(settings)
	var bundle: String = _argument("--fixtures=")
	if not _argument("--prepare-fixtures=").is_empty():
		_prepare_fixtures(_argument("--prepare-fixtures="))
		_finish()
		return
	var archive: Variant = bytes_to_var(FileAccess.get_file_as_bytes(bundle)) if FileAccess.file_exists(bundle) else null
	if not archive is Dictionary or archive.get("schema") != FIXTURE_SCHEMA or archive.get("seed") != SEED or not archive.get("cases") is Dictionary:
		_finish("Expected a perf-134 fixture bundle supplied with --fixtures=PATH.")
		return
	_fixtures = archive["cases"]
	_make_canvas()
	for kind: String in ENCOUNTERS:
		if not await _open(kind): break
		await _encounter(kind)
		_scene.queue_free()
		await _wait_frames(2)
	_scene = preload("res://scripts/run_scene.gd").new()
	var engine: RefCounted = _scene._combat_engine
	for kind: String in Cases.CASES:
		var state: Dictionary = Cases.fixture(kind)
		_forecast("atk04/" + kind, state, engine.finish_player_activation(state), true)
		_forecast("atk04/" + kind + "/full", state, engine.finish_player_activation(state), false)
	_scene.free()
	_write("forecast-receipts.json", _receipts)
	_write("forecast-timings.json", _timings)
	print("PERF-140 PROBE: %d forecast receipts, %d encounters, %d errors" % [_receipts.size(), _timings.size(), _errors.size()])
	_finish()

func _encounter(kind: String) -> void:
	var engine: RefCounted = _scene._combat_engine
	var committed: Dictionary = _scene._combat_state
	# Match the input bytes even though each RunScene resumes in a separate
	# isolated namespace. Keep the analytics structure and receipts intact.
	var analytics: Dictionary = committed.get("analytics", {})
	if analytics.has("run_id"): analytics["run_id"] = FIXTURE_ANALYTICS_RUN
	if analytics.has("combat_id"): analytics["combat_id"] = FIXTURE_ANALYTICS_COMBAT
	_scene._mark_combat_preview_state_changed()
	var source: Dictionary = Source.rest_source(_scene, committed)
	var scheduled: Dictionary = RedTiles.schedule(engine, source)
	var measurements: Dictionary = {}
	engine.set_runtime_performance_instrumentation_enabled(true)
	measurements["rest"] = _forecast(kind + "/rest", source, scheduled, true)
	_forecast(kind + "/rest/full", committed, engine.finish_player_activation(committed), false)
	if kind in ["normal", "tharokh"]:
		_scene._cancel_committed_hand_queries()
		var generation: int = _scene._committed_hand_query_generation
		engine.clear_runtime_performance_instrumentation_snapshot()
		_scene._stage_hover_refresh.prepare_forecast(_scene, committed, generation)
		var ready_frames: int = 0
		while _scene._committed_hand_query_forecast.is_empty() and ready_frames < FRAME_LIMIT:
			await process_frame
			ready_frames += 1
		var warmed: Dictionary = _scene._committed_hand_query_forecast
		if warmed.is_empty():
			_errors.append(kind + ": committed forecast did not become ready")
		else:
			_receipts[kind + "/committed_warm"] = {"result": _digest(warmed["result"]), "steps": _digest(warmed["result"]["steps"])}
		measurements["committed_ready_frames"] = ready_frames
		measurements["committed_sections"] = engine.runtime_performance_instrumentation_snapshot()
	engine.clear_runtime_performance_instrumentation_snapshot()
	if await _select_card():
		var warm: RefCounted = _scene._pass_preview_prewarm
		for frame: int in range(FRAME_LIMIT):
			if warm.done: break
			await process_frame
		if not warm.done or warm.frames <= 0: _errors.append(kind + ": target forecasts did not prewarm")
		measurements["prewarm_frames"] = warm.frames
		measurements["warm_sections"] = engine.runtime_performance_instrumentation_snapshot()
		for tile: Vector2i in _targets():
			var target: Dictionary = _scene._pass_preview_source_state_for_tile(tile, true)
			if not engine.is_player_turn(target): continue
			_forecast("%s/target/%s" % [kind, tile], target, RedTiles.schedule(engine, target), true)
	engine.clear_runtime_performance_instrumentation_snapshot()
	var badges: RefCounted = preload("res://scripts/intent_badges.gd").new()
	for focus: String in ["", "enemy_1", "enemy_2"]:
		var known: Callable = _scene._surface_preview_information_state.bind(committed, committed)
		var presentation: Dictionary = badges.presentation_for_state(engine, committed, committed, focus, known)
		_receipts["%s/badges/%s" % [kind, focus]] = {"result": _digest(presentation)}
	measurements["badge_sections"] = engine.runtime_performance_instrumentation_snapshot()
	_timings[kind] = measurements
	# Use an actual committed transition to sample a new intent/RNG horizon,
	# including any battlefield beat, death or newly announced marks.
	var after: Dictionary = Committed.advance_to_player(engine, Committed.finish_player_activation(engine, committed))["state"]
	if engine.combat_outcome(after) == "":
		var next_source: Dictionary = Source.rest_source(_scene, after)
		_forecast(kind + "/next_turn", next_source, RedTiles.schedule(engine, next_source), true)

func _forecast(key: String, source: Dictionary, scheduled: Dictionary, losses_only: bool) -> Dictionary:
	var engine: RefCounted = _scene._combat_engine
	var before: String = _digest(scheduled)
	engine.clear_runtime_performance_instrumentation_snapshot()
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, losses_only)
	var slices: Array[int] = preload("res://scripts/typed_arrays.gd").integers([])
	while not bool(cursor["complete"]):
		var started: int = Time.get_ticks_usec()
		engine.advance_revealed_enemy_actions_preview(cursor)
		slices.append(Time.get_ticks_usec() - started)
	var sections: Dictionary = engine.runtime_performance_instrumentation_snapshot()
	var result: Dictionary = engine.revealed_enemy_actions_preview_result(cursor)
	var receipt: Dictionary = {
		"input": before, "result": _digest(result), "state": _digest(result["state"]),
		"steps": _digest(result["steps"]), "step_count": result["steps"].size(),
	}
	if losses_only: receipt["pass_summary"] = _digest(_scene._pass_preview_summary_for_phase_result(source, result))
	_receipts[key] = receipt
	var foreground: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, losses_only)
	var resumed: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, losses_only)
	engine.advance_revealed_enemy_actions_preview(resumed)
	var finished: Dictionary = engine.finish_revealed_enemy_actions_preview(resumed)
	if _digest(foreground) != receipt["result"] or _digest(finished) != receipt["result"] or _digest(scheduled) != before:
		_errors.append(key + ": synchronous and sliced forecasts differ or the input changed")
	return {"advance_usec": slices, "sections": sections}

func _digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _write(name: String, rows: Dictionary) -> void:
	var file := FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file == null: _errors.append("Could not write " + name)
	else: file.store_string(JSON.stringify(rows, "\t") + "\n")
