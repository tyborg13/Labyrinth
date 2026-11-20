extends RefCounted
## atk-07 (director 2026-11-14): every forecast covers the time until the player
## can next act. When the PASS-loss copy reaches a hero entry where the hero is
## Frozen, it plays that turn exactly as live play does: the turn start has
## already consumed Freeze (pass_forecast_turn_start.gd, production order), and
## the hero passes with nothing played through the same activation end live
## PASS uses. The cursor then keeps simulating, with the same atk-03 repeat
## handling, up to the next hero entry where the hero can act. Consecutive
## frozen turns keep that ceiling for spans without measurable progress.
## Only the cursor's own copy changes; the live state and generator never do.

# Preloaded, not global class names: exported packs may lack the class cache.
const TurnStart = preload("res://scripts/pass_forecast_turn_start.gd")
const Unseen = preload("res://scripts/pass_forecast_unseen_ground.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const ACTIVATION_CEILING: int = 100

# Called right after the PASS-loss cursor completed a hero turn start.
static func continue_span(engine: RefCounted, cursor: Dictionary) -> void:
	var state: Dictionary = cursor.get("state", {}) as Dictionary
	if state.is_empty() or engine.combat_outcome(state) != "": return
	# Only production preparation decides Freeze (the compact draw-only path
	# never runs with Freeze pending and keeps the source turn's restrictions).
	if str(cursor.get("turn_start_path", "")) != "full": return
	if not bool((state.get("player_turn_restrictions", {}) as Dictionary).get("frozen", false)): return
	_credit_visible_frostbite_progress(cursor, state)
	if int(cursor.get("safety", 0)) >= ACTIVATION_CEILING:
		cursor["unrevealed_before_player"] = true
		cursor["forecast_limit_reached"] = true
		return
	# Live play: PASS on the frozen turn (RunScene._resolve_enemy_round through
	# CommittedBattlefieldRules.finish_player_activation).
	Unseen.track_boundary_arrivals(cursor["player_turn_before_state"], state)
	var scheduled: Dictionary = preload("res://scripts/pass_forecast_red_tiles.gd").schedule(engine, state, Committed.callback(engine))
	# The skipped turn's own activation end keeps a receipt, like the first one.
	(cursor["steps"] as Array).append({"kind": "pass_skipped_turn_end", "target_losses": TurnStart.player_losses(engine, state, scheduled)})
	Unseen.note(cursor, state, scheduled, [])
	# The summary still reconciles against the starting Block after this
	# boundary is replaced. Carry its expiry forward separately from hits.
	var expired: int = TurnStart.expired_block(engine, cursor["player_turn_before_state"], state)
	if expired > 0:
		cursor["skipped_turn_expired_block"] = int(cursor.get("skipped_turn_expired_block", 0)) + expired
	cursor["skipped_turns"] = int(cursor.get("skipped_turns", 0)) + 1
	# Foes hidden in the Umbra and due before this later hero entry act in the span.
	for entry: Dictionary in scheduled.get("turn_queue", []):
		if str(entry.get("kind", "")) == "player":
			cursor["span_boundary"] = {"time": int(entry.get("time", 0)), "seq": int(entry.get("seq", 0))}
			break
	cursor["state"] = scheduled
	cursor["player_turn_before_state"] = {}
	cursor["complete"] = engine.combat_outcome(scheduled) != ""

# Live Frostbite can repeatedly freeze a hero who never leaves Ice. If the
# visible sequence keeps taking Health, keep simulating to its actual end.
# Each renewal requires a strict new minimum, so it is bounded by the starting
# Health even if healing or Defiance can restore it along the way.
static func _credit_visible_frostbite_progress(cursor: Dictionary, state: Dictionary) -> void:
	if str(state.get("battlefield_rule", {}).get("rule", "")) != "frostbite": return
	if bool(cursor.get("unrevealed_before_player", false)) or bool(cursor.get("unseen_ground_crossed", false)) or bool(cursor.get("rng_unknown", false)): return
	var initial: Dictionary = cursor.get("initial_state", {})
	if not initial.get("_pass_forecast_hidden_queue", []).is_empty(): return
	var minimum: int = int(cursor.get("least_frozen_health", initial.get("player", {}).get("hp", 0)))
	var hp: int = int(state["player"]["hp"])
	if hp >= minimum: return
	cursor["least_frozen_health"] = hp
	cursor["safety"] = 0

static func result_fields(cursor: Dictionary) -> Dictionary:
	var result: Dictionary = {"skipped_turns": int(cursor.get("skipped_turns", 0)), "span_boundary": cursor.get("span_boundary", {})}
	if cursor.has("skipped_turn_expired_block"):
		result["skipped_turn_expired_block"] = cursor["skipped_turn_expired_block"]
	return result
