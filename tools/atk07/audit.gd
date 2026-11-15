extends "res://tools/atk01/audit.gd"
## atk-07 audit (proof tool; not a test, never in default groups). The atk-01
## forecast truth audit, unchanged except for the real resolution: when the
## committed live path reaches a hero turn that Freeze skips, it plays that turn
## as live play does (PASS with nothing played, through the committed path) and
## keeps resolving until a hero turn the player can act on. So "actual" is the
## whole span the player gives up by ending this turn. Each check also records
## how many turns the real span skipped, how many the forecast says it skips,
## and (PASS only) the at-rest discs with the forecast marks applied.
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const FROZEN_REPRO_LIMIT: int = 60
var frozen_saved: int = 0

func _check(engine: RefCounted, committed: Dictionary, mode: String, tile: Vector2i, point_id: String) -> Dictionary:
	var result: Dictionary = super._check(engine, committed, mode, tile, point_id)
	var trace: Dictionary = result.get("actual_trace", {})
	result["frozen_actual"] = int(trace.get("frozen_turns", 0))
	# The same hovered tile's summary (a cache hit): what the panel shows.
	var summary: Dictionary = scene.call("_pass_preview_summary")
	result["skipped_forecast"] = int(summary.get("skipped_turns", 0))
	if mode == "pass":
		var presentation: Dictionary = (scene.get("board_view") as Control).get("presentation")
		var applied: Dictionary = Discs.apply(presentation.get("threats_at_rest", {}), scene.get("_rest_pass_disc_marks"), int(scene.get("_combat_preview_revision")), true)
		var discs: Array = []
		for badge: Dictionary in applied.get("badges", []):
			discs.append({"key": str(badge.get("key", "")), "danger": bool(badge.get("danger", false)), "repeats": int(badge.get("repeats", 0))})
		result["discs"] = discs
	if (int(result["frozen_actual"]) > 0 or int(result["skipped_forecast"]) > 0) and frozen_saved < FROZEN_REPRO_LIMIT and not result.has("repro"):
		frozen_saved += 1
		result["repro"] = _save_repro(point_id, committed)
	return result

# RunScene._resolve_enemy_round, repeated through every turn Freeze skips.
func _actual_trace(engine: RefCounted, committed: Dictionary, state: Dictionary) -> Dictionary:
	var trace: Dictionary = _new_trace()
	var phase: Dictionary = state
	var frozen_turns: int = 0
	if state != committed: _add_slice(trace, ["move", 0, false], _hero(committed), _hero(state))
	var safety: int = 0
	while engine.combat_outcome(phase).is_empty() and engine.is_player_turn(phase):
		var scheduled: Dictionary = Committed.finish_player_activation(engine, phase)
		_add_slice(trace, ["turn_end", 0, false], _hero(phase), _hero(scheduled))
		phase = scheduled
		var reached: bool = false
		while engine.combat_outcome(phase).is_empty() and safety < 100:
			safety += 1
			var actor: Array = _peek_actor(engine, phase)
			var before: Dictionary = _hero(phase)
			var slice: Dictionary = Committed.advance_one_activation(engine, phase, false)
			phase = slice.get("state", phase)
			_add_slice(trace, actor, before, _hero(phase))
			if bool(slice.get("complete", false)):
				reached = true
				break
		if not reached or not engine.combat_outcome(phase).is_empty(): break
		if not bool((phase.get("player_turn_restrictions", {}) as Dictionary).get("frozen", false)): break
		frozen_turns += 1
	trace["frozen_turns"] = frozen_turns
	trace["tile"] = (phase.get("player", {}) as Dictionary).get("pos", INVALID)
	trace["outcome"] = engine.combat_outcome(phase)
	return trace
