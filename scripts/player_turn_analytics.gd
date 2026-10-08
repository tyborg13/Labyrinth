extends RefCounted

## Called only at the committed activation-end boundary, never by forecasts.
## Uses the existing progression outbox; no combat event stream or save cursor.
const ProgressionStore = preload("res://scripts/progression_store.gd")
const TempoRelicRules = preload("res://scripts/tempo_relic_rules.gd")
const GameData = preload("res://scripts/game_data.gd")

static func payload(engine: RefCounted, before: Dictionary, scheduled: Dictionary, end_reason: String) -> Dictionary:
	var effects: Array[Dictionary] = GameData.relic_effects_for_state(before)
	var plays_made: int = maxi(0, int(before.get("cards_played_this_turn", 0)) - int(before.get("plays_forfeited_this_turn", 0)))
	var waited: int = engine.base_plays_waited(before)
	var next_turn_eta: int = 0
	var enemies_before: int = 0
	# Include every queued enemy and its rail follow-up, without the HUD's
	# eight-entry truncation. Stop at the first scheduled hero entry.
	var limit: int = maxi(8, (scheduled.get("turn_queue", []) as Array).size() * 2 + 2)
	for entry: Dictionary in engine.current_turn_order(scheduled, limit):
		if str(entry.get("kind", "")) == "player":
			next_turn_eta = int(entry.get("time", 0)) - int(scheduled.get("initiative_clock", 0))
			break
		if str(entry.get("kind", "")) == "enemy":
			enemies_before += 1
	return {
		"end_reason": "frozen" if bool((before.get("player_turn_restrictions", {}) as Dictionary).get("frozen", false)) else end_reason,
		"plays_made": plays_made,
		"base_plays_waited": waited,
		"unused_bonus_plays": maxi(0, engine.cards_remaining_this_turn(before) + int(before.get("plays_forfeited_this_turn", 0)) - waited),
		"card_time": int(before.get("player_turn_time_spent", 0)),
		"wait_time": engine.pending_wait_time(before),
		"sundial_reduction": TempoRelicRules.full_turn_reduction(engine, before, effects),
		"borrowed_extra_turn": TempoRelicRules.extra_turn_available(before, effects, engine.cards_remaining_this_turn(before)),
		"next_turn_eta": next_turn_eta,
		"enemy_activations_before_next_turn": enemies_before,
	}

static func stage(engine: RefCounted, run_state: Dictionary, before: Dictionary, scheduled: Dictionary, end_reason: String, context: Dictionary, progression: Dictionary) -> Dictionary:
	var combat_id: String = str((before.get("analytics", {}) as Dictionary).get("combat_id", ""))
	if combat_id.is_empty() or not engine.is_player_turn(before) or engine.is_player_turn(scheduled):
		return run_state
	var actor: Dictionary = before.get("current_actor", {}) as Dictionary
	var key: String = "player_turn_ended|%s|%d|%d" % [combat_id, int(before.get("turn", 1)), int(actor.get("seq", 0))]
	var next_run: Dictionary = run_state.duplicate(true)
	var merged: Dictionary = ProgressionStore.merge_progression_analytics_outbox(next_run.get("progression", progression) as Dictionary, progression)
	next_run["progression"] = ProgressionStore.queue_progression_analytics_event(
		merged, "player_turn_ended", key, context, payload(engine, before, scheduled, end_reason)
	)
	return next_run
