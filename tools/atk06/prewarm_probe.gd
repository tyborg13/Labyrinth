extends "res://tools/atk06/audit.gd"
## atk-09 hover-prewarm cost probe (proof tool; not a test, never in default groups).
## Same seeded walk as the audit, without its checks. At each idle decision point it
## replays, for every hero-movement destination, the steps pass_preview_prewarm.gd
## runs on the main thread (source, schedule, one enemy activation per step,
## summary) on the scene's own engine, before anything else has forecast those
## destinations. The work atk-09 adds is split off on the same states: its
## instrumented phase (pass_forecast_red_tiles) inside each step, and the record's
## result/summary fields timed again for the summary step.
## Run: audit.py run --script res://tools/atk06/prewarm_probe.gd ...; report: audit.py prewarm.
## ATK09_PROFILE=<point>:<x,y> also saves that point's real save and replays that
## destination three more times with every engine phase's time per step.
## Every later activation (here and in the at-rest forecast) also checks, after its
## timed step, that the red tiles' attack-only plan equals the full threat query's
## projected_attack on the same board (a proof check, not a test).

var profile: String = OS.get_environment("ATK09_PROFILE")

func _audit_decision_point() -> void:
	var engine: RefCounted = scene.get("_combat_engine")
	audited_state = (scene.get("_combat_state") as Dictionary).duplicate(true)
	audit_points += 1
	var point_id: String = "%d-%d" % [hunt_seed, audit_points]
	var rest: Dictionary = _probe(engine, INVALID, false, true)
	rest.merge({"kind": "rest_probe", "point": point_id})
	samples.store_line(JSON.stringify(rest))
	scene.call("_begin_player_movement_selection")
	if bool(scene.get("_player_movement_selected")):
		var tiles: Array[Vector2i]
		tiles.assign(scene.get("_player_movement_target_tiles"))
		var instrumented: bool = engine._runtime_performance_instrumentation_enabled
		engine.set_runtime_performance_instrumentation_enabled(true)
		for tile: Vector2i in tiles:
			var row: Dictionary = _probe(engine, tile)
			row.merge({"kind": "prewarm_probe", "point": point_id, "tile": str(tile)})
			samples.store_line(JSON.stringify(row))
			if profile == "%s:%d,%d" % [point_id, tile.x, tile.y]:
				_save_repro(point_id, audited_state)
				for run: int in range(3):
					var again: Dictionary = _probe(engine, tile, true)
					again.merge({"kind": "prewarm_profile", "point": point_id, "tile": str(tile), "run": run + 1})
					samples.store_line(JSON.stringify(again))
		engine.set_runtime_performance_instrumentation_enabled(instrumented)
		scene.call("_cancel_player_movement_selection")
	scene.set("_hovered_board_tile", INVALID)

# [phase, µs, of which atk-09 µs] for each prewarm step of one destination.
func _probe(engine: RefCounted, tile: Vector2i, detail: bool = false, at_rest: bool = false) -> Dictionary:
	var steps: Array = []
	var checks: Array = [0, []]
	var started: int = Time.get_ticks_usec()
	var source: Dictionary = scene.call("_pass_preview_source_state_for_tile", tile) if at_rest else scene.call("_pass_preview_source_state_for_tile", tile, true)
	steps.append(["source", Time.get_ticks_usec() - started, 0])
	if source.is_empty() or not engine.is_player_turn(source): return {"steps": steps, "checked": 0, "mismatches": []}
	started = Time.get_ticks_usec()
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(engine.finish_player_activation(source), true)
	steps.append(["schedule", Time.get_ticks_usec() - started, 0])
	while not bool(cursor.get("complete", false)):
		var red: int = _red_usec(engine)
		var phases: Dictionary = engine._runtime_performance_totals_usec.duplicate() if detail else {}
		var pre: Dictionary = (cursor["state"] as Dictionary).duplicate(true)
		var counts: Dictionary = (cursor.get("enemy_activations", {}) as Dictionary).duplicate()
		started = Time.get_ticks_usec()
		engine.advance_revealed_enemy_actions_preview(cursor)
		steps.append(["enemy", Time.get_ticks_usec() - started, _red_usec(engine) - red])
		if detail: steps.back().append(_phase_deltas(phases, engine._runtime_performance_totals_usec))
		_check_attack_plan(engine, pre, counts, cursor, checks)
	started = Time.get_ticks_usec()
	var summary: Dictionary = scene.call("_pass_preview_summary_for_phase_result", source, engine.revealed_enemy_actions_preview_result(cursor))
	var summary_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	RedTiles.summary_fields(RedTiles.result_fields(engine, cursor))
	steps.append(["summary", summary_usec, mini(summary_usec, Time.get_ticks_usec() - started)])
	return {"steps": steps, "later": not (summary.get("later_red_tiles", {}) as Dictionary).is_empty(), "checked": checks[0], "mismatches": checks[1]}

# After the timed step: if it was a foe's later activation, plan it again on the
# board it started from, both ways, and compare the tiles.
func _check_attack_plan(engine: RefCounted, pre: Dictionary, counts: Dictionary, cursor: Dictionary, checks: Array) -> void:
	var now: Dictionary = cursor.get("enemy_activations", {})
	for id: int in now:
		if int(now[id]) != int(counts.get(id, 0)) + 1 or int(now[id]) < 2: continue
		var state: Dictionary = engine._pop_next_actor(pre).get("state", pre)
		var index: int = engine._enemy_index_for_id(state, id)
		if index < 0: return
		var past_sight: bool = not engine.is_enemy_visible_to_player(state, engine._normalized_enemy(state["enemies"][index]))
		var narrow: Array = engine.enemy_planned_attack_tiles(state, index, past_sight)
		var full: Array = engine._compute_enemy_threat_tiles(state, index, past_sight).get("projected_attack", [])
		checks[0] = int(checks[0]) + 1
		if str(narrow) != str(full): (checks[1] as Array).append({"enemy": id, "narrow": str(narrow), "full": str(full)})
		return

# The engine phases that took the most time inside one step (they nest).
func _phase_deltas(before: Dictionary, after: Dictionary) -> Array:
	var deltas: Array = []
	for phase: String in after:
		var delta: int = int(after[phase]) - int(before.get(phase, 0))
		if delta >= 200: deltas.append([phase, delta])
	deltas.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return deltas.slice(0, 12)

func _red_usec(engine: RefCounted) -> int:
	return int(engine._runtime_performance_totals_usec.get("pass_forecast_red_tiles", 0))
