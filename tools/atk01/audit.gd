extends "res://tools/run_hunt.gd"
## atk-01 forecast truth audit (proof tool; not a test, never in default groups).
## A seeded run-hunt plays real fights through the production scene. At every idle
## player decision point it reads the exact forecasts the UI would show (PASS now,
## every hero-movement destination, the stay-put tile) and the at-rest red danger
## flag on each compact intent disc, then resolves the same choice for real on a
## copy through the committed path (CommittedBattlefieldRules), one activation at
## a time, until the player's next turn starts. Nothing here writes game state.
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const INVALID := Vector2i(-1, -1)
const REPRO_LIMIT: int = 400
const FLAG_REPRO_LIMIT: int = 100

var samples: FileAccess
var audited_state: Dictionary = {}
var audit_points: int = 0
var audit_checks: int = 0
var repro_saved: int = 0
var disclosed_saved: int = 0
var flag_saved: int = 0
var audit_usec: int = 0
var fight_ids: Dictionary = {}

func _start() -> void:
	samples = FileAccess.open(output.path_join("samples.jsonl"), FileAccess.WRITE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("repro")))
	await super._start()

# Warband rooms are rare on a random route. ATK01_WARBAND=<biome>:<tier> enters
# the production-built Warband room the certified inspection fixture uses
# (tools/warband_inspection.gd) once the scene settles, then plays on as usual.
var warband_pending: String = OS.get_environment("ATK01_WARBAND")

func _enter_warband() -> void:
	var parts: PackedStringArray = warband_pending.split(":")
	warband_pending = ""
	var options: Dictionary = {"warband_biome": parts[0], "warband_tier": int(parts[1]) if parts.size() > 1 else 2, "warband_case": "encounter"}
	var state: Dictionary = preload("res://tools/warband_inspection.gd").build(scene.get("_run_engine"), scene.get("_combat_engine"), scene.get("_run_state"), options)
	scene.call("_load_run_state", state)
	_apply_hunt_health()
	settle_frames = SETTLE_FRAMES
	_emit("warband_entered", {"options": options})

func _tick() -> void:
	if not warband_pending.is_empty() and not busy and is_instance_valid(scene) and settle_frames <= 0 and not bool(scene.get("_animation_lock")) and str((scene.get("_run_state") as Dictionary).get("mode", "")) == "room" and not bool(scene.get("_dialogue_active")) and not scene.get("_opening_boon_flow").active():
		_enter_warband()
		return
	if _audit_ready():
		var started: int = Time.get_ticks_usec()
		_audit_decision_point()
		audit_usec += Time.get_ticks_usec() - started
	super._tick()

func _finish(outcome: String) -> void:
	if samples != null:
		samples.store_line(JSON.stringify({"kind": "audit_totals", "decision_points": audit_points, "checks": audit_checks, "fights": fight_ids.size(), "repro_saved": repro_saved, "audit_seconds": float(audit_usec) / 1000000.0, "outcome": outcome}))
		samples.flush()
	await super._finish(outcome)

func _audit_ready() -> bool:
	if finished or busy or policy == null or not is_instance_valid(scene): return false
	if bool(scene.get("_animation_lock")) or settle_frames > 0: return false
	var run: Dictionary = scene.get("_run_state")
	if str(run.get("mode", "")) != "combat" or bool(scene.get("_dialogue_active")): return false
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	if state.is_empty() or not engine.is_player_turn(state) or not engine.combat_outcome(state).is_empty(): return false
	if int(scene.get("_selected_card_index")) >= 0 or bool(scene.get("_player_movement_selected")): return false
	if scene.get("_surface_aim").active() or policy.browsing(scene): return false
	if state == audited_state: return false
	# The same idle combat offers the policy is about to choose among.
	for offer: Dictionary in policy.offers(scene):
		if str(offer.get("kind", "")) == "pass": return true
	return false

# --- one decision point -------------------------------------------------------

func _audit_decision_point() -> void:
	var engine: RefCounted = scene.get("_combat_engine")
	var committed: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	audited_state = committed
	audit_points += 1
	var context: Dictionary = _audit_context(engine, committed)
	fight_ids[context["fight"]] = true
	var point_id: String = "%d-%d" % [hunt_seed, audit_points]
	# (a) PASS now: the PASS button's own summary and source snapshot.
	scene.set("_hovered_board_tile", INVALID)
	# atk-03: were the discs' PASS-forecast marks ready before this audit asked?
	var marks_ready: bool = int((scene.get("_rest_pass_disc_marks") as Dictionary).get("revision", -1)) == int(scene.get("_combat_preview_revision"))
	var pass_check: Dictionary = _check(engine, committed, "pass", INVALID, point_id)
	var actual_pass: Dictionary = pass_check["actual_trace"]
	pass_check.erase("actual_trace")
	_emit_sample(context, pass_check)
	# Red danger flags on the at-rest compact discs, hero on its own tile.
	var presentation: Dictionary = (scene.get("board_view") as Control).get("presentation")
	var badges: Array = (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", [])
	var flags: Array = []
	for badge: Dictionary in badges:
		var key: String = str(badge.get("key", ""))
		var hits: Dictionary = (actual_pass["by_actor"] as Dictionary).get(key, {})
		var first: Dictionary = (actual_pass["first_by_actor"] as Dictionary).get(key, {})
		flags.append({"key": key, "danger": bool(badge.get("danger", false)), "acting": bool(badge.get("acting", false)), "cancelled": bool(badge.get("cancelled", false)), "order": str(badge.get("order", "")), "icon": str(badge.get("icon", "")), "number": str(badge.get("number", "")),
			"type": _enemy_type(committed, key), "hit_any": _loss_total(hits) > 0, "hit_hp": int(hits.get("hp", 0)) > 0, "hit_first": _loss_total(first) > 0, "activations": int(actual_pass["activations"].get(key, 0))})
	var marks: Dictionary = scene.get("_rest_pass_disc_marks")
	var stale: bool = preload("res://scripts/pass_forecast_discs.gd").stale(presentation.get("threats_at_rest", {}), marks, int(scene.get("_combat_preview_revision")))
	var flag_row: Dictionary = {"kind": "flags", "point": point_id, "badges_present": presentation.has("threats_at_rest"), "flags": flags, "marks_ready_before": marks_ready, "discs_stale": stale}
	for flag: Dictionary in flags:
		if bool(flag["danger"]) != bool(flag["hit_any"]) and flag_saved < FLAG_REPRO_LIMIT and repro_saved < REPRO_LIMIT:
			flag_saved += 1
			flag_row["repro"] = _save_repro(point_id, committed)
			break
	_emit_sample(context, flag_row)
	# (b) Move first: every destination the movement selection lets you preview.
	scene.call("_begin_player_movement_selection")
	if bool(scene.get("_player_movement_selected")):
		var hero: Vector2i = committed["player"]["pos"]
		var tiles: Array[Vector2i]
		tiles.assign(scene.get("_player_movement_target_tiles"))
		tiles.append(hero)
		for tile: Vector2i in tiles:
			scene.set("_hovered_board_tile", tile)
			var check: Dictionary = _check(engine, committed, "stay" if tile == hero else "move", tile, point_id)
			check.erase("actual_trace")
			_emit_sample(context, check)
		scene.call("_cancel_player_movement_selection")
	scene.set("_hovered_board_tile", INVALID)

func _check(engine: RefCounted, committed: Dictionary, mode: String, tile: Vector2i, point_id: String) -> Dictionary:
	audit_checks += 1
	var t0: int = Time.get_ticks_usec()
	var summary: Dictionary = scene.call("_pass_preview_summary")
	var ui_usec: int = Time.get_ticks_usec() - t0
	var source: Dictionary = scene.call("_pass_preview_source_state_for_tile", tile)
	var forecast: Dictionary = _forecast_trace(engine, committed, source)
	var replica: Dictionary = scene.call("_pass_preview_summary_for_phase_result", source, forecast["phase_result"])
	var moved: Dictionary = committed
	var resolved: bool = true
	if mode == "move":
		moved = engine.apply_player_movement(committed, tile)
		Committed.accept(engine, moved)
		resolved = bool((moved.get("last_player_movement", {}) as Dictionary).get("resolved", false))
	var actual: Dictionary = _actual_trace(engine, committed, moved)
	var shown: Dictionary = _shown(summary)
	var disclosed: bool = bool(summary.get("unrevealed_before_player", false)) or bool(summary.get("umbra_unknown_before_player", false)) or bool(summary.get("forecast_limit_reached", false)) or bool(summary.get("terminal_unknown", false))
	var result: Dictionary = {
		"kind": "check", "mode": mode, "point": point_id, "tile": str(tile), "resolved": resolved,
		"ui_usec": ui_usec, "summary_empty": summary.is_empty(),
		"replica_matches_ui": _summary_core(replica) == _summary_core(summary),
		"shown": shown, "disclosed": disclosed,
		"repeated": summary.get("repeated_enemy_names", []), "counted": summary.get("counted_repeats", []), "restarted": bool(forecast.get("restarted", false)), "unrevealed": bool(summary.get("unrevealed_before_player", false)),
		"umbra_unknown": bool(summary.get("umbra_unknown_before_player", false)), "limit": bool(summary.get("forecast_limit_reached", false)),
		"forecast_sim": {"hp": forecast["hp"], "block": forecast["block"], "stoneskin": forecast["stoneskin"], "tile": str(forecast["tile"]), "outcome": forecast["outcome"], "sources": forecast["sources"], "slices": forecast["slices"]},
		"actual": {"hp": actual["hp"], "block": actual["block"], "stoneskin": actual["stoneskin"], "tile": str(actual["tile"]), "outcome": actual["outcome"], "sources": actual["sources"], "slices": actual["slices"], "activations": actual["activations"]},
	}
	result["mismatch"] = {
		"hp": shown["hp"] != actual["hp"],
		"block": shown["block"] != actual["block"],
		"stoneskin": shown["stoneskin"] != actual["stoneskin"],
		"death": shown["defeat"] != (actual["outcome"] == "defeat"),
		"tile": forecast["tile"] != actual["tile"],
		"sources": forecast["sources"] != actual["sources"],
	}
	result["actual_trace"] = actual
	var any_mismatch: bool = false
	for measure: String in result["mismatch"]:
		if bool(result["mismatch"][measure]): any_mismatch = true
	# Diagnostic only: the same simulation with nothing hidden. When it agrees
	# with reality, the UI forecast differed only by what the Umbra hides.
	if any_mismatch and not disclosed:
		var raw: Dictionary = committed if mode != "move" else engine.surface_preview_for_player_action(committed, engine.player_movement_action(committed), tile, true)["state"]
		var seen_all: Dictionary = _forecast_trace(engine, committed, raw)
		result["omniscient_matches_actual"] = [seen_all["hp"], seen_all["block"], seen_all["stoneskin"], seen_all["tile"], seen_all["outcome"]] == [actual["hp"], actual["block"], actual["stoneskin"], actual["tile"], actual["outcome"]]
		# The information filter itself changed the simulated outcome.
		result["umbra_filter_changed_forecast"] = [seen_all["hp"], seen_all["block"], seen_all["stoneskin"], seen_all["tile"], seen_all["outcome"], seen_all["slices"].size()] != [forecast["hp"], forecast["block"], forecast["stoneskin"], forecast["tile"], forecast["outcome"], forecast["slices"].size()]
	if any_mismatch and repro_saved < REPRO_LIMIT and (not disclosed or disclosed_saved < 10):
		if disclosed: disclosed_saved += 1
		result["repro"] = _save_repro(point_id, committed)
	return result

# Exactly what the PASS panel tells the player (pass_forecast_focus_tooltip rows):
# Health row + Fatigue row, Block row, Stoneskin row, and DEFEAT.
func _shown(summary: Dictionary) -> Dictionary:
	var rows: Dictionary = preload("res://scripts/pass_forecast_focus_tooltip.gd").row_losses(summary)
	return {"hp": int(summary.get("hp_loss", 0)), "row_health": int(rows["health"]), "fatigue": int(rows["fatigue"]), "block": int(rows["block"]), "stoneskin": int(rows["stoneskin"]), "defeat": bool(summary.get("defeat", false)), "tone": str(summary.get("tone", "")), "defiance": int(summary.get("defiance_spent", 0))}

func _summary_core(summary: Dictionary) -> Array:
	return [int(summary.get("hp_loss", 0)), int(summary.get("block_loss", 0)), int(summary.get("stoneskin_loss", 0)), bool(summary.get("defeat", false)), str(summary.get("tone", "")), bool(summary.get("unrevealed_before_player", false)), bool(summary.get("umbra_unknown_before_player", false))]

# --- forecast replica: the same cursor the UI runs, one actor per slice --------

func _forecast_trace(engine: RefCounted, committed: Dictionary, source: Dictionary) -> Dictionary:
	var trace: Dictionary = _new_trace()
	if source.is_empty() or not engine.is_player_turn(source):
		trace["phase_result"] = {}
		return trace
	# A destination forecast covers the walk itself ("move there, then end").
	if source.get("player", {}).get("pos", INVALID) != committed["player"]["pos"] or int(source.get("_pass_forecast_source_hp", -1)) >= 0:
		_add_slice(trace, ["move", 0, false], _hero(committed), _hero(source))
	var scheduled: Dictionary = engine.finish_player_activation(source)
	_add_slice(trace, ["turn_end", 0, false], _hero(source), _hero(scheduled))
	var prefix: Array = (trace["slices"] as Array).duplicate(true)
	var cursor: Dictionary = engine.begin_revealed_enemy_actions_preview(scheduled, true)
	while not bool(cursor.get("complete", false)):
		var state: Dictionary = cursor["state"]
		var actor: Array = _peek_actor(engine, state)
		var before: Dictionary = _hero(state)
		var rolling: bool = bool(cursor.get("choose_next_intents", true))
		engine.advance_revealed_enemy_actions_preview(cursor)
		# atk-03: a repeat in the deferred-roll subset restarts the window with
		# ordinary intent rolls; the replica restarts its trace with it.
		if not rolling and bool(cursor.get("choose_next_intents", false)):
			trace = _new_trace()
			for slice: Dictionary in prefix:
				(trace["slices"] as Array).append(slice.duplicate(true))
				trace["counts"][slice["actor"]] = 1
				for field: String in ["hp", "block", "stoneskin"]: trace[field] = int(trace[field]) + int(slice[field])
			trace["restarted"] = true
			continue
		_add_slice(trace, actor, before, _hero(cursor["state"]))
	var phase_result: Dictionary = engine.revealed_enemy_actions_preview_result(cursor)
	var after: Dictionary = phase_result.get("state", {})
	trace["phase_result"] = phase_result
	trace["tile"] = (after.get("player", {}) as Dictionary).get("pos", INVALID)
	trace["outcome"] = engine.combat_outcome(after)
	return trace

# --- actual: the committed live path (RunScene._resolve_enemy_round) -------------

func _actual_trace(engine: RefCounted, committed: Dictionary, state: Dictionary) -> Dictionary:
	var trace: Dictionary = _new_trace()
	var phase: Dictionary = state
	if state != committed: _add_slice(trace, ["move", 0, false], _hero(committed), _hero(state))
	if engine.combat_outcome(phase).is_empty() and engine.is_player_turn(phase):
		var scheduled: Dictionary = Committed.finish_player_activation(engine, phase)
		_add_slice(trace, ["turn_end", 0, false], _hero(phase), _hero(scheduled))
		phase = scheduled
		var safety: int = 0
		while engine.combat_outcome(phase).is_empty() and safety < 100:
			safety += 1
			var actor: Array = _peek_actor(engine, phase)
			var before: Dictionary = _hero(phase)
			var slice: Dictionary = Committed.advance_one_activation(engine, phase, false)
			phase = slice.get("state", phase)
			_add_slice(trace, actor, before, _hero(phase))
			if bool(slice.get("complete", false)): break
	trace["tile"] = (phase.get("player", {}) as Dictionary).get("pos", INVALID)
	trace["outcome"] = engine.combat_outcome(phase)
	return trace

func _new_trace() -> Dictionary:
	return {"hp": 0, "block": 0, "stoneskin": 0, "slices": [], "sources": [], "by_actor": {}, "first_by_actor": {}, "activations": {}, "counts": {}, "tile": INVALID, "outcome": ""}

func _peek_actor(engine: RefCounted, state: Dictionary) -> Array:
	var probe: Dictionary = state.duplicate(true)
	var popped: Dictionary = engine._pop_next_actor(probe)
	var entry: Dictionary = popped.get("entry", {})
	var spawned: bool = not (popped.get("reinforcement_steps", []) as Array).is_empty()
	if entry.is_empty() or str(entry.get("kind", "")) == "player": return ["turn_start", 0, spawned]
	if str(entry.get("kind", "")) == "enemy": return ["enemy_%d" % int(entry.get("enemy_id", -1)), int(entry.get("enemy_id", -1)), spawned]
	return [str(entry.get("kind", "other")), 0, spawned]

func _hero(state: Dictionary) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	return {"hp": int(player.get("hp", 0)), "block": int(player.get("block", 0)), "stoneskin": int(player.get("stoneskin", 0)), "pos": player.get("pos", INVALID), "received": int((state.get("run_stats", {}) as Dictionary).get("damage_received", 0))}

func _add_slice(trace: Dictionary, entry: Array, before: Dictionary, after: Dictionary) -> void:
	var actor: String = entry[0]
	var counts: Dictionary = trace["counts"]
	counts[actor] = int(counts.get(actor, 0)) + 1
	var gross: int = maxi(maxi(0, before["hp"] - after["hp"]), after["received"] - before["received"])
	var loss: Dictionary = {"hp": gross, "block": maxi(0, before["block"] - after["block"]), "stoneskin": maxi(0, before["stoneskin"] - after["stoneskin"])}
	var moved: bool = before["pos"] != after["pos"]
	(trace["slices"] as Array).append({"actor": actor, "n": int(counts[actor]), "hp": loss["hp"], "block": loss["block"], "stoneskin": loss["stoneskin"], "from": str(before["pos"]), "to": str(after["pos"]), "moved": moved, "spawn": bool(entry[2])})
	if actor.begins_with("enemy_"): trace["activations"][actor] = int(counts[actor])
	for field: String in ["hp", "block", "stoneskin"]: trace[field] = int(trace[field]) + int(loss[field])
	if _loss_total(loss) <= 0: return
	var by: Dictionary = trace["by_actor"]
	var total: Dictionary = by.get(actor, {"hp": 0, "block": 0, "stoneskin": 0})
	for field: String in ["hp", "block", "stoneskin"]: total[field] = int(total[field]) + int(loss[field])
	by[actor] = total
	if int(counts[actor]) == 1: trace["first_by_actor"][actor] = loss
	if actor.begins_with("enemy_") and not (trace["sources"] as Array).has(actor):
		(trace["sources"] as Array).append(actor)
		(trace["sources"] as Array).sort()

func _loss_total(loss: Dictionary) -> int:
	return int(loss.get("hp", 0)) + int(loss.get("block", 0)) + int(loss.get("stoneskin", 0))

# --- context and evidence ---------------------------------------------------------

func _audit_context(engine: RefCounted, state: Dictionary) -> Dictionary:
	var base: Dictionary = _context()
	var run: Dictionary = scene.get("_run_state")
	var room: Dictionary = base.get("room_metadata", {})
	var enemies: Array = []
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		enemies.append({"key": "enemy_%d" % int(enemy.get("id", -1)), "type": str(enemy.get("type", "")), "pos": str(enemy.get("pos", INVALID)), "hp": int(enemy.get("hp", 0)), "visible": engine.is_enemy_visible_to_player(state, enemy), "intent": str((enemy.get("intent", {}) as Dictionary).get("id", (enemy.get("intent", {}) as Dictionary).get("name", "")))})
	return {"seed": hunt_seed, "decision": decision, "section": base["section"], "room": base["room"], "room_kind": base["room_kind"], "biome": str(room.get("biome", state.get("biome", ""))), "element": str(room.get("element", "")),
		"fight": "%d:%s" % [hunt_seed, base["room"]], "turn": int(state.get("turn", 0)), "hero_tile": str(state["player"]["pos"]), "hero_hp": int(state["player"].get("hp", 0)),
		"hero_block": int(state["player"].get("block", 0)), "hero_stoneskin": int(state["player"].get("stoneskin", 0)), "objective": str((state.get("objective", {}) as Dictionary).get("type", "")),
		"special": str((state.get("objective", {}) as Dictionary).get("special_type", "")), "umbra_limited": engine.effective_umbra_radius(state) < engine.UMBRA_UNLIMITED_RADIUS,
		"battlefield_rule": str((state.get("battlefield_rule", {}) as Dictionary).get("rule", "")), "enemies": enemies, "run_hp": int(run.get("player_hp", 0))}

func _enemy_type(state: Dictionary, key: String) -> String:
	for enemy: Dictionary in state.get("enemies", []):
		if "enemy_%d" % int(enemy.get("id", -1)) == key: return str(enemy.get("type", ""))
	return ""

# A real save at this decision point (the production persistence path), plus the
# committed combat snapshot for a headless reproduction.
func _save_repro(point_id: String, committed: Dictionary) -> String:
	var directory: String = output.path_join("repro").path_join(point_id)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)): return directory
	repro_saved += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	scene.call("_save_run_progress")
	for name: String in ["run.save", "progression.json"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(output.path_join(name)), ProjectSettings.globalize_path(directory.path_join(name)))
	var file := FileAccess.open(directory.path_join("combat_state.txt"), FileAccess.WRITE)
	file.store_string(var_to_str(committed))
	file.close()
	return directory

func _emit_sample(context: Dictionary, row: Dictionary) -> void:
	var line: Dictionary = row.duplicate(false)
	line["context"] = context
	samples.store_line(JSON.stringify(line))
