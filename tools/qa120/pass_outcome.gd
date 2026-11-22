extends RefCounted
## Adapt qa-99's loss accounting to a live Pass. The full resolver's replay
## supplies intermediate receipts, and its final board must match live state.
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Start = preload("res://scripts/pass_forecast_turn_start.gd")
const Statuses = preload("res://scripts/pass_forecast_statuses.gd")
const EnemyEvents = preload("res://scripts/enemy_action_analytics.gd")
const Oracle = preload("res://tools/qa120/oracle.gd")

static func replay(scene: Node, before: Dictionary) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var beats: Array[Dictionary]
	var scheduled: Dictionary = Committed.finish_player_activation_with_rule_steps(engine, before, beats)
	var phase: Dictionary = Committed.advance_to_player(engine, scheduled)
	var after: Dictionary = phase["state"]
	var pre_draw: Dictionary = phase.get("player_turn_before_state", {})
	var steps: Array = phase.get("steps", []).duplicate()
	steps.push_front({"target_losses": Start.player_losses(engine, before, scheduled)})
	var expired: int = 0
	if not pre_draw.is_empty():
		expired = Start.expired_block(engine, pre_draw, after)
		var kept: Dictionary = pre_draw.duplicate(true)
		kept["player"]["block"] = int(kept["player"].get("block", 0)) - expired
		steps.append({"target_losses": Start.player_losses(engine, kept, after)})
	var losses: Dictionary = scene._pass_preview_player_damage_losses(steps)
	for field: String in ["hp", "block", "stoneskin"]:
		losses[field] = maxi(int(losses[field]), int(before["player"].get(field, 0)) - int(after["player"].get(field, 0)) - (expired if field == "block" else 0))
	var events: Array = []
	for event: Dictionary in EnemyEvents.action_events(phase, {}):
		var payload: Dictionary = event["payload"]
		if not payload.get("target_losses", []).is_empty() or not payload.get("enemy_losses", []).is_empty():
			events.append(payload)
	var statuses: Dictionary = {}
	var pushes: Array = []
	var previous: Dictionary = before
	for step: Dictionary in beats + phase.get("steps", []):
		var next: Dictionary = step.get("after", step.get("state", {}))
		if next.is_empty() or not next.has("player"): continue
		_note_status(statuses, previous, next)
		_note_positions(pushes, previous, next, str(step.get("kind", "")))
		previous = next
	_note_status(statuses, previous, after)
	_note_positions(pushes, previous, after, "handoff")
	return {"state": after, "losses": losses, "statuses": statuses, "pushes": pushes, "events": events,
		"outcome": engine.combat_outcome(after)}

static func _note_status(gains: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var old: Dictionary = Statuses.mark(before)
	var now: Dictionary = Statuses.mark(after)
	for field: String in now:
		if now[field] > old[field]: gains[field] = int(gains.get(field, 0)) + now[field] - old[field]

static func _note_positions(moves: Array, before: Dictionary, after: Dictionary, kind: String) -> void:
	var old: Dictionary = board_state(before)
	var now: Dictionary = board_state(after)
	for actor: String in now:
		var unit: Dictionary = now[actor]
		if old.has(actor) and old[actor]["pos"] != unit["pos"]:
			moves.append({"actor": actor, "from": old[actor]["pos"], "to": unit["pos"], "step": kind})

static func board_state(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	var result: Dictionary = {"player": _unit(state.get("player", {}))}
	for group: String in ["enemies", "allies", "illusions"]:
		for unit: Dictionary in state.get(group, []):
			result["%s_%s" % [group, unit.get("id", unit.get("key", ""))]] = _unit(unit)
	return result

static func _unit(unit: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ["hp", "block", "stoneskin", "pos"] + Statuses.FIELDS:
		result[field] = unit.get(field, 0)
	return result

static func terminal_receipt(directory: String) -> Dictionary:
	# RunScene clears combat_state at a terminal checkpoint. Its append-only
	# analytics still have the committed end and the last boundary's actions.
	var files: PackedStringArray = DirAccess.get_files_at(directory)
	files.sort()
	var receipt: Dictionary = {}
	for entry: String in files:
		if not entry.begins_with("events-") or not entry.ends_with(".jsonl"): continue
		var stream: FileAccess = FileAccess.open(directory.path_join(entry), FileAccess.READ)
		if stream == null: continue
		while not stream.eof_reached():
			var line: String = stream.get_line()
			if line.is_empty(): continue
			var decoder := JSON.new()
			if decoder.parse(line) != OK or not decoder.data is Dictionary: continue
			var event: Dictionary = decoder.data
			var payload: Dictionary = event.get("payload", {})
			match event.get("event_type"):
				"player_turn_ended": receipt = {"reason": payload.get("end_reason"), "losses": {}, "deaths": []}
				"enemy_action_resolved":
					if receipt.is_empty(): continue
					for loss: Dictionary in payload.get("target_losses", []):
						if loss.get("kind") != "player": continue
						for field: String in ["hp", "block", "stoneskin"]:
							var key: String = field + "_loss"
							receipt["losses"][field] = int(receipt["losses"].get(field, 0)) + int(loss.get(key, 0))
				"surface_event":
					if not receipt.is_empty() and payload.get("kind") == "actor_death": receipt["deaths"].append(payload)
				"combat_ended":
					if receipt.get("reason") == "pass" and payload.get("reason") == "enemy_round":
						receipt["terminal"] = payload
	return receipt if receipt.has("terminal") else {}

static func examine(summary: Dictionary, shown: Dictionary, resolved: Dictionary, live: Dictionary, terminal: Dictionary) -> Dictionary:
	var result: Dictionary = {"issues": {}, "checks": []}
	var replay_board: Dictionary = board_state(resolved["state"])
	var actual: Dictionary = board_state(live)
	if not actual.is_empty():
		result["checks"].append("pass_replay_vs_live")
		Oracle.compare(result, "resolved.live_board", replay_board, actual)
	elif not terminal.is_empty():
		result["checks"].append("pass_terminal_live_receipt")
		Oracle.compare(result, "resolved.terminal_health", replay_board["player"]["hp"], terminal["terminal"]["remaining_player_hp"])
		Oracle.compare(result, "resolved.terminal_outcome", resolved["outcome"], terminal["terminal"]["outcome"])
	else:
		result["checks"].append("pass_live_receipt_unavailable")
	var partial: bool = summary.is_empty() or summary.get("umbra_unknown_before_player", false) or summary.get("unrevealed_before_player", false) or summary.get("forecast_limit_reached", false) or summary.get("unseen_ground_crossed", false)
	result["checks"].append("pass_disclosed_minimum" if partial else "pass_exact_total")
	for field: String in ["hp", "block", "stoneskin"]:
		var loss: int = int(resolved["losses"][field])
		var key: String = field + "_loss"
		if summary.has(key) and (not partial or int(summary[key]) > loss):
			Oracle.compare(result, "resolved.forecast_" + field, loss, summary[key])
		if shown.has(key) and (not partial or int(shown[key]) > loss):
			Oracle.compare(result, "resolved.shown_" + field, loss, shown[key])
	if not partial:
		Oracle.compare(result, "resolved.projected_hp", replay_board["player"]["hp"], summary.get("projected_hp"))
		Oracle.compare(result, "resolved.defeat", resolved["outcome"] == "defeat", summary.get("defeat"))
		Oracle.compare(result, "resolved.status_gains", resolved["statuses"], summary.get("status_gains", {}))
	result["outcome"] = {"known_horizon": not partial, "before_and_after_verified": not actual.is_empty(),
		"forecast": Oracle.summary_numbers(summary), "shown": Oracle.summary_numbers(shown),
		"losses": resolved["losses"], "statuses": resolved["statuses"], "positions": resolved["pushes"],
		"outcome": resolved["outcome"], "resolved_board": replay_board, "live_board": actual, "live_terminal": terminal}
	if not result["issues"].is_empty() or not terminal.is_empty(): result["outcome"]["action_receipts"] = resolved["events"]
	return result
