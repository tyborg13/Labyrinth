extends RefCounted

const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Illusions = preload("res://scripts/illusion_card_rules.gd")
const Trace = preload("res://scripts/reaction_presentation_trace.gd")
const LOSS_FIELDS: Array = ["hp_loss", "block_loss", "stoneskin_loss"]

static func _probe_boundary(step: Dictionary, owner: Dictionary) -> void:
	if owner.has("_resolver_boundary_id"): step["_resolver_boundary_id"] = owner["_resolver_boundary_id"]

# Traced compound actions keep the existing Bleed rules, but present each
# payment at the boundary that charged it. Ordinary actions retain their payloads.
static func pay_bleed(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var before: Dictionary = state.duplicate(true)
	var trace: Dictionary = context["reaction_trace"]
	var scope: Dictionary = Trace.charge_started(engine, state, trace, int(state["enemies"][index]["id"]))
	var payments: Array[Dictionary]
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, action, payments)
	var entries: Array[Dictionary] = Trace.charge_finished(engine, state, trace, scope)
	var moving: bool = engine._enemy_action_is_movement(action)
	var ordered: Array[Dictionary]
	if not payments.is_empty():
		var header: Dictionary = payments[0].duplicate(true)
		header["traced_bleed"] = true
		ordered = charge_steps(engine, before, state, entries, header)
		trace["bleed_paid"] = true
	if moving: bleed_steps.append_array(ordered)
	elif not ordered.is_empty(): trace["attack_bleed_steps"] = ordered
	if not payments.is_empty() and engine._enemy_cannot_continue_after_bleed(state, index): context["bleed_stopped"] = true
	if not moving and not payments.is_empty(): context["attack_before"] = state.duplicate(true)
	return state

static func traced_intent(_intent: Dictionary) -> bool:
	# Tether and Mirror were the only compound tracing adapters.
	return false

static func charge_steps(engine: RefCounted, before: Dictionary, after: Dictionary, entries: Array[Dictionary], header: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		if entry["source"]["action_type"] != "charge":
			result.append(_cascade_step(engine, entry))
			continue
		var step: Dictionary = header.duplicate(true)
		for field: String in ["enemies_after", "player_after", "surfaces_after", "death_burst_events_after"]: step.erase(field)
		step["reaction_after"] = entry["after"]
		_probe_boundary(step, entry)
		step.merge(entry["losses"], true)
		var victims: Array[Dictionary]
		victims.append_array(step["enemy_losses"])
		victims.append_array(step["target_losses"])
		step["impact_actor_keys"] = engine._target_loss_keys(victims)
		step["traced_charge"] = true
		step["amount"] = 0
		for loss: Dictionary in step["enemy_losses"]:
			if loss["key"] == step["actor_key"]: step["amount"] += int(loss.get("hp_loss", 0))
		step["surface_events"] = engine._surface_events_since(before, after).filter(func(event: Dictionary) -> bool: return int(event.get("sequence", 0)) <= int(entry["sequence"]))
		result.append(step)
	return result

static func separate_movement(context: Dictionary) -> bool:
	return has_arrival_cascade(context) or bool(context.get("reaction_trace", {}).get("bleed_paid", false))

static func before_attack_steps(engine: RefCounted, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = arrival_steps(engine, context)
	result.append_array(context.get("reaction_trace", {}).get("attack_bleed_steps", []))
	return result

static func action_state(after: Dictionary, context: Dictionary) -> Dictionary:
	return context.get("reaction_trace", {}).get("action_after", after)

# Remove every reaction victim's realized loss, rather than dropping all losses
# on reacting units: a beam-triggered collision still belongs to the beam.
static func enemy_losses(engine: RefCounted, before: Dictionary, after: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var reactions: Array[Dictionary]
	for reaction: Dictionary in context.get("reaction_trace", {}).get("reactions", []):
		reactions.append_array(reaction["losses"]["enemy_losses"])
	for cascade: Dictionary in context.get("reaction_trace", {}).get("cascades", []):
		reactions.append_array(cascade["losses"]["enemy_losses"])
	for loss: Dictionary in engine._enemy_target_losses(before, after):
		for event: Dictionary in reactions:
			if str(event.get("key", "")) != str(loss["key"]): continue
			for field: String in LOSS_FIELDS:
				loss[field] = maxi(0, int(loss.get(field, 0)) - int(event.get(field, 0)))
		loss["amount"] = int(loss["hp_loss"]) + int(loss["block_loss"]) + int(loss["stoneskin_loss"])
		if int(loss["amount"]) > 0: result.append(loss)
	return result

static func attack_snapshot(after: Dictionary, context: Dictionary) -> Dictionary:
	return Trace.snapshot(action_state(after, context))

static func presentation_steps(engine: RefCounted, before: Dictionary, after: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = Retaliate.presentation_steps(engine, before, after)
	result.append_array(Illusions.presentation_steps(engine, before, after))
	# Surface-event sequence is the actual resolution order, including multiple
	# retorts on one illusion. Untraced mechanics retain their existing payloads.
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(_event(a).get("sequence", 0)) < int(_event(b).get("sequence", 0)))
	for step: Dictionary in result:
		for reaction: Dictionary in context.get("reaction_trace", {}).get("reactions", []):
			if int(_event(step).get("sequence", -1)) != int(reaction["sequence"]): continue
			for field: String in ["enemy_after", "enemies_after", "player_after", "surfaces_after"]: step.erase(field)
			step["reaction_after"] = reaction["after"].duplicate(true)
			_probe_boundary(step, reaction)
			step.merge(reaction["losses"].duplicate(true), true)
			var losses: Array[Dictionary]
			losses.append_array(step["target_losses"])
			losses.append_array(step["enemy_losses"])
			step["kind"] = "status_damage" if not losses.is_empty() or not step["terrain_losses"].is_empty() else "status"
			step["impact_actor_keys"] = engine._target_loss_keys(losses)
			step["tile"] = engine._surface_actor(reaction["after"], "enemy", int(_event(step).get("enemy_id", -1))).get("pos", step["tile"])
	result.append_array(_cascade_steps(engine, context))
	# Legacy reaction steps carry complete actor snapshots. Keep their Burst
	# journal on that same owner; explicit traced cascades already present it.
	if not result.is_empty() and not result.any(func(step: Dictionary) -> bool: return step.has("reaction_after") or step.has("cascade")):
		capture_legacy_bursts(result.back(), before, after)
	return result

static func has_arrival_cascade(context: Dictionary) -> bool:
	for entry: Dictionary in context.get("reaction_trace", {}).get("movement_events", []):
		if str(entry["source"]["action_type"]) != "move": return true
	return false

static func arrival_steps(engine: RefCounted, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if not separate_movement(context): return result
	for entry: Dictionary in context.get("reaction_trace", {}).get("movement_events", []):
		if str(entry["source"]["action_type"]) != "move":
			result.append(_cascade_step(engine, entry))
			continue
		var id: int = int(entry["source"]["id"])
		var before: Dictionary = entry["before"]
		var after: Dictionary = entry["state"]
		var index: int = engine._enemy_index_for_id(before, id)
		var from: Vector2i = before["enemies"][index]["pos"]
		var to: Vector2i = after["enemies"][index]["pos"]
		var step: Dictionary = engine._enemy_action_step_base(before, after, index, {"type": "move_toward"}, {"resolved_path": engine._vector2i_values([from, to])})
		if step.is_empty():
			# An arrival may resume at the same tile after a synchronous burst.
			step = {"kind": "status_damage", "action_type": "arrival", "actor_key": "enemy_%d" % id, "tile": to}
		step["reaction_after"] = entry["after"].duplicate(true)
		_probe_boundary(step, entry)
		step.merge(entry["losses"].duplicate(true), true)
		step["traced_arrival"] = true
		result.append(step)
	return result

static func _cascade_steps(engine: RefCounted, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for cascade: Dictionary in context.get("reaction_trace", {}).get("cascades", []): result.append(_cascade_step(engine, cascade))
	return result

static func _cascade_step(engine: RefCounted, cascade: Dictionary) -> Dictionary:
	var source: Dictionary = cascade["source"]
	var step: Dictionary = {"kind": "status" if bool(cascade.get("bookkeeping", false)) else "status_damage", "action_type": source["action_type"], "trigger": "deferred_death", "actor_key": "enemy_%d" % int(source["id"]), "tile": source["tile"], "cascade": source.duplicate(true), "reaction_after": cascade["after"].duplicate(true), "cascade_continuation": bool(cascade.get("continuation", false)), "cascade_bookkeeping": bool(cascade.get("bookkeeping", false))}
	_probe_boundary(step, cascade)
	step.merge(cascade["losses"].duplicate(true), true)
	var victims: Array[Dictionary]
	victims.append_array(step["target_losses"])
	victims.append_array(step["enemy_losses"])
	step["impact_actor_keys"] = engine._target_loss_keys(victims)
	return step

static func _event(step: Dictionary) -> Dictionary:
	return step.get("retaliate", step.get("illusion_retort", {}))

static func floating_texts(scene: Control, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = scene._floating_texts_for_target_losses(step.get("enemy_losses", []))
	result.append_array(scene._floating_texts_for_target_losses(step.get("target_losses", [])))
	result.append_array(scene._floating_texts_for_terrain_losses(step.get("terrain_losses", [])))
	return result

static func capture_legacy_bursts(step: Dictionary, before: Dictionary, after: Dictionary) -> void:
	if (after.get("death_burst_events", []) as Array).size() > (before.get("death_burst_events", []) as Array).size():
		step["death_burst_events_after"] = (after["death_burst_events"] as Array).duplicate(true)
