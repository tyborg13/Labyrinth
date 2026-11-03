extends RefCounted

## Legacy feedback carries the complete resolved snapshot before the dissolve
## plays its FIFO. Keep only pending Burst durability on that FIFO's owner.
const LOSS_FIELDS: Array = ["hp_loss", "block_loss", "stoneskin_loss"]
const DURABILITY_FIELDS: Array = ["hp", "block", "stoneskin"]
var _events: Array = []
var _baseline: int = 0
var _shown: int = 0
var _texts: Dictionary = {}
var _snapshot_shown: int = -1
var _snapshot_enemies_by_id: Dictionary = {}

func reset() -> void:
	_events = []
	_baseline = 0
	_shown = 0
	_texts.clear()
	_snapshot_shown = -1
	_snapshot_enemies_by_id.clear()

func sync_encounter(state: Dictionary, entering: bool) -> void:
	if state.is_empty(): return
	# A committed encounter journal is append-only. Its replacement after a
	# completed playback also identifies fresh encounter installs that bypass
	# room travel (debug/inspection fixtures), even with identical room data.
	var count: int = (state.get("death_burst_events", []) as Array).size()
	if entering or (_shown >= _events.size() and count < _events.size()): reset()

func prepare(before: Dictionary, after: Dictionary) -> void:
	var events: Array = after.get("death_burst_events", [])
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	# reset() runs on authoritative encounter entry, so journal deduplication
	# applies only to repeated owners inside that encounter.
	if events.size() <= baseline or events == _events: return
	_events = events.duplicate(true)
	_baseline = baseline
	_shown = baseline
	_texts.clear()
	_snapshot_shown = -1
	_snapshot_enemies_by_id.clear()

func display_state(state: Dictionary, presentation: Dictionary) -> Dictionary:
	if _events.is_empty() or _shown >= _events.size(): return state
	_shown = maxi(_shown, int(presentation.get("burst_playback_count", _baseline)))
	if _shown >= _events.size(): return state
	var snapshot: Dictionary = _events[_baseline]["before"] if _shown == _baseline else _events[_shown - 1]["after"]
	if _snapshot_shown != _shown:
		_snapshot_enemies_by_id = _enemies_by_id(snapshot)
		_snapshot_shown = _shown
	var result: Dictionary = state.duplicate(false)
	result["player"] = _held_durability(state.get("player", {}), snapshot.get("player", {}))
	var enemies: Array[Dictionary]
	for enemy: Dictionary in state.get("enemies", []):
		var source: Dictionary = _snapshot_enemies_by_id.get(int(enemy["id"]), {})
		enemies.append(_held_durability(enemy, source) if not source.is_empty() else enemy)
	result["enemies"] = enemies
	return result

func _held_durability(unit: Dictionary, source: Dictionary) -> Dictionary:
	var result: Dictionary = unit
	for field: String in DURABILITY_FIELDS:
		# Before contact, the incoming action can still show its before state.
		# Once a Burst starts, its snapshot owns durability until the next one.
		var value: int = maxi(int(unit.get(field, 0)), int(source.get(field, 0))) if _shown == _baseline else int(source.get(field, 0))
		if value == int(unit.get(field, 0)): continue
		if is_same(result, unit): result = unit.duplicate(false)
		result[field] = value
	return result

static func _enemies_by_id(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in state.get("enemies", []): result[int(enemy["id"])] = enemy
	return result

func hold_pending_deaths(state: Dictionary, presentation: Dictionary) -> Dictionary:
	if _events.is_empty() or _shown >= _events.size() or not presentation.has("death_animation_units"): return presentation
	var result: Dictionary = presentation.duplicate(false)
	var deaths: Array[Dictionary]
	var enemies_by_id: Dictionary = _enemies_by_id(state)
	for unit: Dictionary in presentation["death_animation_units"]:
		var hp: int = int(state.get("player", {}).get("hp", 0)) if str(unit.get("role", "")) == "player" else 0
		if str(unit.get("role", "")) != "player": hp = int(enemies_by_id.get(int(unit.get("id", -2)), {}).get("hp", 0))
		if hp <= 0: deaths.append(unit)
	result["death_animation_units"] = deaths
	return result

func floating_texts(scene: Node, event: Dictionary) -> Array:
	var id: int = int(event["id"])
	if not _texts.has(id): _texts[id] = scene._player_action_floating_texts(event["before"], event["after"])
	return _texts[id]

func status_step(engine: RefCounted, step: Dictionary) -> Dictionary:
	return without_burst_losses(engine, step, {"death_burst_events": _events.slice(0, _baseline)}, {"death_burst_events": step["death_burst_events_after"]})

func finish_resolved_slice(scene: Node, state: Dictionary, resolved: Dictionary) -> void:
	if (resolved.get("death_burst_events", []) as Array).size() <= (state.get("death_burst_events", []) as Array).size(): return
	# Non-Gust battlefield beats (notably Upheaval displacement) can resolve
	# after the final action without emitting their own animation step. Present
	# only the journal suffix that no step has consumed, on the existing clock.
	var before: Dictionary = state.duplicate(true)
	prepare(before, resolved)
	await scene._animate_enemy_loss_feedback_between_states(before, resolved)
	await scene._animate_turn_order_alongside_defeats(before, resolved)
	state.clear()
	state.merge(resolved.duplicate(true), true)
	scene._render_board_state(state, {})

static func steps_for_playback(engine: RefCounted, before: Dictionary, steps: Array, resolved: Dictionary = {}) -> Array:
	var events: Array = resolved.get("death_burst_events", [])
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var owns_journal: bool = steps.any(func(step: Dictionary) -> bool: return step.has("death_burst_events_after") or step.has("cascade"))
	if not owns_journal and events.size() <= baseline: return steps
	var result: Array = steps.duplicate(true)
	if not owns_journal:
		# Ordinary surface/trap deaths have no reaction step. The slice's real
		# journal supplies the missing presentation owner without changing rules,
		# serialized action payloads or analytics.
		for step: Dictionary in result:
			var owns_death: bool = (step.get("surface_events", []) as Array).any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "actor_death" and int(event.get("id", -1)) == int(events[baseline]["id"]))
			if not owns_death: continue
			step["death_burst_events_after"] = events
			step["burst_snapshot_after"] = events.back()["after"]
			var clean: Dictionary = without_burst_losses(engine, step, before, resolved)
			step.merge(clean, true)
			break
	var prior: Array = before.get("death_burst_events", [])
	for index: int in range(result.size()):
		var owner: Dictionary = result[index]
		if not owner.has("death_burst_events_after"): continue
		var after: Dictionary = {"death_burst_events": owner["death_burst_events_after"]}
		# Legacy Bleed is already settled when the canceled action is applied.
		# Legacy Retaliate follows the attack whose totals include its Bursts.
		# Keep the original step and clock; change only its already-owned losses.
		var direction: int = 1 if str(owner.get("label", "")) == "Bleed" else -1
		if owner.has("burst_snapshot_after"):
			prior = owner["death_burst_events_after"]
			continue
		var candidate: int = index + direction
		while candidate >= 0 and candidate < result.size():
			var step: Dictionary = result[candidate]
			if str(step.get("kind", "")) in ["intent", "intent_refresh", "intent_callout"] or step.has("death_burst_events_after"): break
			if str(step.get("actor_key", "")) == str(owner.get("actor_key", "")) and str(step.get("kind", "")) in ["move", "melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]:
				result[candidate] = without_burst_losses(engine, step, {"death_burst_events": prior}, after)
				break
			candidate += direction
		prior = owner["death_burst_events_after"]
	return result

static func before_bursts(before: Dictionary, after: Dictionary) -> Dictionary:
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var events: Array = after.get("death_burst_events", [])
	if events.size() <= baseline: return after
	var result: Dictionary = after.duplicate(false)
	result.merge(events[baseline]["before"], true)
	return result

## Action/status loss totals can span synchronous Bursts. Their journal already
## owns those losses; subtract them from feedback, never from resolved state.
static func without_burst_losses(engine: RefCounted, step: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var baseline: int = (before.get("death_burst_events", []) as Array).size()
	var events: Array = after.get("death_burst_events", [])
	if step.is_empty() or events.size() <= baseline: return step
	var paid: Dictionary = {}
	for index: int in range(baseline, events.size()):
		var event: Dictionary = events[index]
		var losses: Array[Dictionary] = engine._actor_target_losses(event["before"], event["after"])
		losses.append_array(engine._enemy_target_losses(event["before"], event["after"]))
		for loss: Dictionary in losses:
			var key: String = str(loss["key"])
			if not paid.has(key): paid[key] = {}
			for field: String in LOSS_FIELDS: paid[key][field] = int(paid[key].get(field, 0)) + int(loss.get(field, 0))
	var result: Dictionary = step.duplicate(true)
	for group: String in ["target_losses", "enemy_losses"]:
		if not result.has(group): continue
		var remaining: Array[Dictionary]
		for loss: Dictionary in result[group]:
			loss["amount"] = 0
			for field: String in LOSS_FIELDS:
				loss[field] = maxi(0, int(loss.get(field, 0)) - int(paid.get(str(loss["key"]), {}).get(field, 0)))
				loss["amount"] += int(loss[field])
			if int(loss["amount"]) > 0: remaining.append(loss)
		result[group] = remaining
	for field: String in LOSS_FIELDS:
		if result.has(field): result[field] = maxi(0, int(result[field]) - int(paid.get("player", {}).get(field, 0)))
	return result
