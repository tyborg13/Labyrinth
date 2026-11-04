extends RefCounted

static func decorate_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary, step: Dictionary) -> void:
	# These bespoke presentation steps lack the ordinary action's loss payload.
	# Keep analytics-only data separate so animation and saved combat are unchanged.
	if step.is_empty(): return
	match str(action.get("type", "")):
		"burrow", "erupt":
			step["analytics_fields"] = {
				"target_losses": engine._actor_target_losses(before, after),
				"enemy_losses": engine._enemy_target_losses(before, after),
				"terrain_losses": engine._terrain_target_losses(before, after),
				"triggered_traps": engine._triggered_traps_between(before, after),
			}
		"gain_charge":
			step["analytics_fields"] = {"amount": int(after["enemies"][index].get("charge", 0)) - int(before["enemies"][index].get("charge", 0))}
		"retaliate":
			step["analytics_fields"] = {
				"action_type": "retaliate",
				"amount": int(after["enemies"][index].get("retaliate", {}).get("amount", 0)) - int(before["enemies"][index].get("retaliate", {}).get("amount", 0)),
			}

# Compound actions carry their approach inside the attack step. Preserve the
# ordinary move event and its arrival losses before the attack's own outcome.
static func steps_for_events(phase_result: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for value: Variant in phase_result.get("steps", []):
		if not value is Dictionary: continue
		var step: Dictionary = value
		# Preliminary retreat legs (notably the Hoarder) can precede the ordinary
		# step decorator. Actor identity is stable across the resolved phase;
		# preserve the step's committed intent rather than reading a refreshed one.
		if str(step.get("enemy_type", "")).is_empty():
			for enemy: Dictionary in phase_result.get("state", {}).get("enemies", []):
				if str(step.get("actor_key", "")) != "enemy_%d" % int(enemy.get("id", -1)): continue
				step = step.duplicate(false)
				step["enemy_type"] = str(enemy.get("type", ""))
				step["ai_role"] = str(preload("res://scripts/game_data.gd").enemy_def(step["enemy_type"]).get("ai_profile", {}).get("role", ""))
				break
		if step.has("move_step"):
			var move: Dictionary = (step.get("move_step", {}) as Dictionary).duplicate(true)
			if not move.is_empty():
				for field: String in ["enemy_type", "ai_role", "intent_id"]:
					if step.has(field): move[field] = step[field]
				result.append(move)
		result.append(step)
	return result

static func status_events(phase_result: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary]
	for step_var: Variant in phase_result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		var kind: String = str(step.get("kind", ""))
		if kind not in ["status_damage", "status"]:
			continue
		if bool(step.get("boss_mechanic", false)) or bool(step.get("guardian_mechanic", false)) or bool(step.get("enemy_status_gain", false)) or str(step.get("action_type", "")) in ["gain_charge", "kindle"]:
			continue
		events.append({
			"event_type": "enemy_status_tick",
			"context": context,
			"payload": {
				"kind": kind,
				"actor_key": str(step.get("actor_key", "")),
				"actor_name": str(step.get("actor_name", "")),
				"label": str(step.get("label", "")),
				"amount": int(step.get("amount", 0)),
				"text": str(step.get("text", "")),
				"trigger": str(step.get("trigger", "turn_start")),
				"action_type": str(step.get("action_type", "")),
				"tile": step.get("tile", Vector2i(-1, -1))
			}
		})
		if step.has("reaction_after"):
			var payload: Dictionary = events.back()["payload"]
			for field: String in ["cascade", "target_losses", "enemy_losses", "terrain_losses"]: payload[field] = step.get(field, {} if field == "cascade" else [])
			if step.has("cascade_continuation"): payload["cascade_continuation"] = step["cascade_continuation"]
	return events


static func action_events(phase_result: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary]
	for step_var: Variant in steps_for_events(phase_result):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		var kind: String = str(step.get("kind", ""))
		if kind not in ["move", "melee", "ranged", "aoe", "push", "pull", "lightning_strikes", "block", "stoneskin", "heal", "summon", "surface", "burrow", "erupt"] and str(step.get("no_action_reason", "")).is_empty() and not (kind == "status" and (bool(step.get("boss_mechanic", false)) or bool(step.get("guardian_mechanic",false)) or bool(step.get("enemy_status_gain", false)) or str(step.get("action_type", "")) in ["gain_charge", "kindle"])):
			continue
		var path: Array[Vector2i] = tiles(step.get("path", []))
		events.append({
			"event_type": "enemy_action_resolved",
			"context": context,
			"payload": {
				"action_type": str(step.get("action_type", kind)),
				"presentation_kind": kind,
				"no_action_reason": str(step.get("no_action_reason", "")),
				"boss_mechanic": bool(step.get("boss_mechanic", false)),
				"guardian_mechanic": bool(step.get("guardian_mechanic", false)),
				"interrupted": bool(step.get("interrupted",false)),
				"declared_tiles": step.get("declared_tiles", []),
				"committed_direction": bool(step.get("committed_direction", false)),
				"committed_shape": str(step.get("committed_shape", "")),
				"element": str(step.get("element", "none")),
				"action_direction": step.get("action_direction", Vector2i.ZERO),
				"resolved_tiles": step.get("tiles", []),
				"enemy_type": str(step.get("enemy_type", "")),
				"ai_role": str(step.get("ai_role", "")),
				"intent_id": str(step.get("intent_id", "")),
				"actor_key": str(step.get("actor_key", "")),
				"actor_name": str(step.get("actor_name", "")),
				"label": str(step.get("label", "")),
				"from": step.get("from", step.get("tile", Vector2i(-1, -1))),
				"to": step.get("to", step.get("tile", Vector2i(-1, -1))),
				"path": path,
				"path_steps": maxi(0, path.size() - 1),
				"target_key": str(step.get("target_key", "")),
				"target_losses": (step.get("target_losses", []) as Array).duplicate(true),
				"enemy_losses": (step.get("enemy_losses", []) as Array).duplicate(true),
				"terrain_losses": (step.get("terrain_losses", []) as Array).duplicate(true),
				"triggered_traps": (step.get("triggered_traps", []) as Array).duplicate(true),
				"support_targets": (step.get("targets", []) as Array).duplicate(true),
			}
		})
		if str(step.get("action_type", kind)) == "summon_minions" or kind == "summon":
			events.back()["payload"]["granted_card_play"] = bool(step.get("granted_card_play", false))
		if step.has("amount") and (kind in ["block", "stoneskin", "heal"] or str(step.get("action_type", "")) == "kindle"):
			events.back()["payload"]["amount"] = int(step["amount"])
		events.back()["payload"].merge(step.get("analytics_fields", {}), true)
	return events


static func tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(values)
	return result

static func phase_events(phase: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary]
	# Preserve the resolver's interleaved payment/action/reaction/cascade order.
	for step: Variant in phase.get("steps", []):
		if not step is Dictionary: continue
		var one: Dictionary = {"steps": [step]}
		events.append_array(status_events(one, context))
		events.append_array(action_events(one, context))
	events.append_array(preload("res://scripts/summon_card_play_rules.gd").turn_start_events(phase, context))
	return events
