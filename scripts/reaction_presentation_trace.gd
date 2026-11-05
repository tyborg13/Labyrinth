extends RefCounted

# Opt-in, transient presentation data. Board snapshots never enter saved state
# or the append-only surface event stream.
# Only resolver-local scopes are deferred. Every gameplay field, including new
# actor/status/charge fields, travels without maintaining a second field schema.
const DEFERRED_FIELDS: Dictionary = {
	"damage_context": "The enclosing hit/death scope restores its caller's cause after owner capture.",
	"_surface_damage_batch": "The enclosing compound hit closes its synchronous damage batch after owner capture.",
	"_surface_pending_deaths": "The death flush drains this private queue after the causing hit is captured.",
	"_death_burst_queue": "The enclosing FIFO drains queued bursts after owner capture.",
	"_death_burst_running": "The enclosing FIFO clears its reentrancy guard after owner capture.",
	"death_burst_events": "The legacy burst journal is applied after explicit traced burst feedback to prevent replay.",
	"enemies[].death_burst_resolved": "The FIFO's per-enemy reentrancy guard is published after burst resolution, at turn cleanup.",
}

static func snapshot(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	for field: String in DEFERRED_FIELDS: result.erase(field)
	for enemy: Dictionary in result.get("enemies", []): enemy.erase("death_burst_resolved")
	return result

static func apply_snapshot(state: Dictionary, after: Dictionary, complete: bool = false) -> void:
	var deferred: Dictionary = {}
	if not complete:
		for field: String in DEFERRED_FIELDS:
			if state.has(field): deferred[field] = state[field]
	state.clear() # Erased flags, consumed charges and removed actors stay erased.
	state.merge(after.duplicate(true), true)
	state.merge(deferred, true)

# Turn cleanup (Bleed, next intent, RNG and restored resolver scopes) has no
# extra feedback beat. Ordinary turns keep their exact historical payloads.
static func complete_turn(result: Dictionary) -> Dictionary:
	var steps: Array = result.get("steps", [])
	var traced: bool = steps.any(func(step: Dictionary) -> bool: return (step.has("en03_after") and step.get("action_type", "") == "lightning_strikes") or step.has("reaction_after") or step.has("trace_state_after"))
	if not traced: return result
	var last: Dictionary = steps.back() if steps.back().get("kind", "") == "intent_refresh" else {"kind": "trace_state"}
	last["trace_state_after"] = (result["state"] as Dictionary).duplicate(true)
	last["trace_state_complete"] = true
	if last.get("kind", "") == "trace_state": steps.append(last)
	return result

static func capture(trace: Dictionary, state: Dictionary) -> Dictionary:
	return snapshot(state) if bool(trace.get("capture_reactions", false)) else {}

# The single owner capture rule: callers seal their work before entering the
# death flush (or the next reaction). Flush scopes seal their parent first.
# No owner may derive its board or losses from the flush's returned state.
static func capture_owner(engine: RefCounted, trace: Dictionary, before: Dictionary, state: Dictionary) -> Dictionary:
	if not bool(trace.get("capture_reactions", false)): return {}
	var owner: Dictionary = {"after": snapshot(state), "losses": losses(engine, before, state), "sequence": int(state.get("surface_event_sequence", 0))}
	owner["surface_events"] = engine._surface_events_since(before, state)
	# Optional test observer binds an opaque boundary ID to the raw resolver
	# state, independently of the serialized snapshot's contents. Never saved.
	if engine.has_meta("reaction_state_observer"):
		var observer: Callable = engine.get_meta("reaction_state_observer")
		owner["_resolver_boundary_id"] = observer.call(state)
	return owner

static func action_started(trace: Dictionary, state: Dictionary) -> void:
	if bool(trace.get("capture_reactions", false)): trace["action_before"] = snapshot(state)

static func action_finished(engine: RefCounted, trace: Dictionary, state: Dictionary) -> void:
	var owner: Dictionary = capture_owner(engine, trace, trace.get("action_before", {}), state)
	if not owner.is_empty():
		trace["action_after"] = owner["after"]
		if owner.has("_resolver_boundary_id"): trace["action_boundary_id"] = owner["_resolver_boundary_id"]

static func losses(engine: RefCounted, before: Dictionary, after: Dictionary) -> Dictionary:
	if before.is_empty(): return {}
	return {"target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after), "terrain_losses": engine._terrain_target_losses(before, after)}

static func reaction_finished(engine: RefCounted, trace: Dictionary, owner: Dictionary, state: Dictionary) -> void:
	if not bool(trace.get("capture_reactions", false)): return
	# The reaction journal is appended after losses are measured. Publish its
	# completed state on this same owner, without copying a snapshot into events.
	owner["after"] = snapshot(state)
	if engine.has_meta("reaction_state_observer"):
		var observer: Callable = engine.get_meta("reaction_state_observer")
		owner["_resolver_boundary_id"] = observer.call(state)
	var steps: Array = trace.get("reactions", [])
	steps.append(owner)
	trace["reactions"] = steps

# Scoped HP charges (Bleed, activation Fire) enter the same owner stack as
# arrivals and cascades. A synchronous flush seals the charge before its child.
static func charge_started(engine: RefCounted, state: Dictionary, trace: Dictionary, id: int) -> Dictionary:
	var scope: Dictionary = {"previous_trace": engine._surface_death_trace}
	engine._surface_death_trace = trace
	trace["capturing_payment"] = true
	trace["payment_events"] = []
	scope["previous_owner"] = cascade_begin(engine, state, {"action_type": "charge", "id": id, "tile": engine._surface_actor(state, "enemy", id).get("pos", Vector2i.ZERO)})
	return scope

static func charge_finished(engine: RefCounted, state: Dictionary, trace: Dictionary, scope: Dictionary) -> Array[Dictionary]:
	cascade_end(engine, state, scope["previous_owner"])
	trace["capturing_payment"] = false
	engine._surface_death_trace = scope["previous_trace"]
	var result: Array[Dictionary]
	result.append_array(trace["payment_events"])
	trace.erase("payment_events")
	return result

static func movement_started(engine: RefCounted, state: Dictionary, context: Dictionary) -> Dictionary:
	var previous: Dictionary = engine._surface_death_trace
	var trace: Dictionary = context.get("reaction_trace", {})
	if trace.is_empty(): return previous
	engine._surface_death_trace = trace # Arrival capture starts before the first tile.
	trace["capturing_movement"] = true
	trace["movement_cursor"] = state.duplicate(true)
	return previous

static func movement_finished(engine: RefCounted, context: Dictionary, previous: Dictionary) -> void:
	var trace: Dictionary = context.get("reaction_trace", {})
	if trace.is_empty(): return
	trace["capturing_movement"] = false
	trace.erase("movement_cursor")
	engine._surface_death_trace = previous

# A cursor follows the actual synchronous resolver, including recursive surface
# deaths. Entering a child first seals its parent's realized work; returning
# resumes the parent from the child's final board instead of counting it twice.
static func cascade_begin(engine: RefCounted, state: Dictionary, source: Dictionary) -> Dictionary:
	var trace: Dictionary = engine._surface_death_trace
	if trace.is_empty(): return {}
	seal_owner(engine, state)
	if engine.has_meta("reaction_begin_observer"):
		var observer: Callable = engine.get_meta("reaction_begin_observer")
		observer.call(state, source)
	var previous: Dictionary = trace.get("cascade_owner", {})
	trace["cascade_owner"] = source
	trace["cascade_cursor"] = snapshot(state)
	if bool(trace.get("capturing_movement", false)): trace["movement_cursor"] = state.duplicate(true)
	return previous

static func cascade_end(engine: RefCounted, state: Dictionary, previous: Dictionary) -> void:
	var trace: Dictionary = engine._surface_death_trace
	if trace.is_empty(): return
	if engine.has_meta("reaction_end_observer"):
		var observer: Callable = engine.get_meta("reaction_end_observer")
		observer.call(state, trace.get("cascade_owner", {}))
	seal_owner(engine, state)
	trace["cascade_owner"] = previous
	trace["cascade_cursor"] = snapshot(state)
	if bool(trace.get("capturing_movement", false)): trace["movement_cursor"] = state.duplicate(true)

static func seal_owner(engine: RefCounted, state: Dictionary) -> void:
	var trace: Dictionary = engine._surface_death_trace
	var owner: Dictionary = trace.get("cascade_owner", {})
	if owner.is_empty(): return
	var before: Dictionary = trace["cascade_cursor"]
	var captured: Dictionary = capture_owner(engine, trace, before, state)
	var after: Dictionary = captured["after"]
	if before == after: return
	var realized: Dictionary = captured["losses"]
	var stream_field: String = "payment_events" if bool(trace.get("capturing_payment", false)) else "movement_events" if bool(trace.get("capturing_movement", false)) else "cascades"
	var steps: Array = trace.get(stream_field, [])
	var full_before: Dictionary = trace.get("movement_cursor", {})
	var has_loss: bool = not realized["target_losses"].is_empty() or not realized["enemy_losses"].is_empty() or not realized["terrain_losses"].is_empty()
	# Nested non-damaging death bookkeeping must not split one burst into
	# duplicate effects. Its later Fire placement completes the same snapshot.
	if not steps.is_empty() and steps.back()["source"] == owner:
		var last: Dictionary = steps.back()
		last["after"] = after
		last["surface_events"].append_array(captured["surface_events"])
		if captured.has("_resolver_boundary_id"): last["_resolver_boundary_id"] = captured["_resolver_boundary_id"]
		if has_loss: last["bookkeeping"] = false
		if stream_field == "movement_events": last["state"] = state.duplicate(true)
		for field: String in ["target_losses", "enemy_losses", "terrain_losses"]:
			for loss: Dictionary in realized[field]:
				var existing: Array = (last["losses"][field] as Array).filter(func(value: Dictionary) -> bool: return value["key"] == loss["key"])
				if existing.is_empty(): last["losses"][field].append(loss)
				else:
					for amount: String in ["hp_loss", "block_loss", "stoneskin_loss", "amount"]: existing[0][amount] = int(existing[0].get(amount, 0)) + int(loss.get(amount, 0))
	else: # Any serialized state change has an owner, including spawn-only deaths.
		var entry: Dictionary = captured
		entry["source"] = owner.duplicate(true)
		entry["bookkeeping"] = not has_loss and str(owner["action_type"]) == "surface_death"
		if str(owner["action_type"]) == "death_burst":
			var started: Dictionary = trace.get("burst_started", {})
			entry["continuation"] = started.has(int(owner["id"]))
			entry["bookkeeping"] = bool(entry["continuation"]) and not has_loss
			started[int(owner["id"])] = true
			trace["burst_started"] = started
		if stream_field == "movement_events":
			entry["before"] = full_before
			entry["state"] = state.duplicate(true)
		steps.append(entry)
	trace[stream_field] = steps
	trace["cascade_cursor"] = after
	if stream_field == "movement_events": trace["movement_cursor"] = state.duplicate(true)
