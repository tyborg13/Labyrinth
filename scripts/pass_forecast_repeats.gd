extends RefCounted
## atk-03 (director 2026-11-13): forecasts include repeat activations.
## A visible foe that acts again before the hero resolves its next move with the
## intent its previous activation rolled on this forecast copy, from the fight's
## saved generator, exactly as live play will roll it. The cursor owns its copy;
## the live state and generator are never touched.
##
## Foes hidden in the Umbra and new arrivals stay unknown. Their live turns also
## draw from the generator, so once one of them acts first the copy's generator
## no longer matches live play: a roll made after that point is not known either,
## and that repeat keeps the old "acts twice, unknown" disclosure.

static func known_repeat(cursor: Dictionary, enemy_id: int) -> bool:
	return bool((cursor.get("roll_known", {}) as Dictionary).get(enemy_id, false))

# Every actor the copy skips (hidden, newly arrived, or without an intent)
# would consume the live generator before any later roll.
static func note_skipped(cursor: Dictionary) -> void:
	cursor["rng_unknown"] = true

# Umbra-limited sources drop hidden foes from the queue entirely; a living
# hidden foe's activation that precedes this one has drawn from the live
# generator first. A dead foe's stale entry is skipped by live play unrolled.
static func note_hidden_before(cursor: Dictionary, state: Dictionary, entry: Dictionary) -> void:
	if bool(cursor.get("rng_unknown", false)): return
	var time: int = int(entry.get("time", 0))
	var seq: int = int(entry.get("seq", 0))
	for hidden: Dictionary in state.get("_pass_forecast_hidden_queue", []):
		if not bool(hidden.get("alive", true)): continue
		if int(hidden.get("time", 0)) < time or (int(hidden.get("time", 0)) == time and int(hidden.get("seq", 0)) < seq):
			cursor["rng_unknown"] = true
			return

# The PASS-loss subset defers intent rolls (combat_preview_known_losses.gd).
# A repeat needs every roll the live generator makes, so resolve the whole
# window again from the start with ordinary intent selection. Once per cursor.
static func restart_with_rolls(cursor: Dictionary) -> void:
	cursor["state"] = (cursor.get("initial_state", {}) as Dictionary).duplicate(true)
	cursor["steps"] = []
	cursor["player_turn_before_state"] = {}
	cursor["revealed_enemy_ids"] = {}
	cursor["repeated_enemy_names"] = []
	cursor["unrevealed_before_player"] = false
	cursor["choose_next_intents"] = true
	cursor["safety"] = 0
	cursor["complete"] = false
	for field: String in ["rng_unknown", "roll_known", "enemy_activations", "enemy_hits", "enemy_names", "unknown_repeat_ids"]:
		cursor.erase(field)

# A visible foe whose later move stays unknown keeps the "×2 ?" disclosure.
static func note_unknown_repeat(cursor: Dictionary, enemy_id: int) -> void:
	var unknown: Dictionary = cursor.get("unknown_repeat_ids", {})
	unknown[enemy_id] = true
	cursor["unknown_repeat_ids"] = unknown

static func hero_mark(state: Dictionary) -> Array:
	var player: Dictionary = state.get("player", {})
	return [int(player.get("hp", 0)), int(player.get("block", 0)), int(player.get("stoneskin", 0)),
		int((state.get("run_stats", {}) as Dictionary).get("damage_received", 0)), int(state.get("defiance_remaining", 0))]

# One resolved activation: count it, attribute any hero loss to its foe, and
# remember whether the roll it just made matches the live generator.
static func record(cursor: Dictionary, enemy_id: int, name: String, before: Array, after_state: Dictionary) -> void:
	var activations: Dictionary = cursor.get("enemy_activations", {})
	activations[enemy_id] = int(activations.get(enemy_id, 0)) + 1
	cursor["enemy_activations"] = activations
	var names: Dictionary = cursor.get("enemy_names", {})
	names[enemy_id] = name
	cursor["enemy_names"] = names
	var after: Array = hero_mark(after_state)
	if after[0] < before[0] or after[1] < before[1] or after[2] < before[2] or after[3] > before[3] or after[4] < before[4]:
		var hits: Dictionary = cursor.get("enemy_hits", {})
		hits[enemy_id] = true
		cursor["enemy_hits"] = hits
	var known: Dictionary = cursor.get("roll_known", {})
	known[enemy_id] = not bool(cursor.get("rng_unknown", false))
	cursor["roll_known"] = known

static func result_fields(cursor: Dictionary) -> Dictionary:
	return {"enemy_activations": cursor.get("enemy_activations", {}), "enemy_hits": cursor.get("enemy_hits", {}), "enemy_names": cursor.get("enemy_names", {}), "unknown_repeat_ids": cursor.get("unknown_repeat_ids", {})}

# Summary view, keyed like the rail and the discs ("enemy_<id>"). A counted
# repeat is a visible foe whose every activation in the window was simulated.
static func summary_fields(phase_result: Dictionary) -> Dictionary:
	var activations: Dictionary = {}
	var hits: Dictionary = {}
	var counted: Array[Dictionary]
	var names: Dictionary = phase_result.get("enemy_names", {})
	for id: int in phase_result.get("enemy_activations", {}):
		var count: int = int(phase_result["enemy_activations"][id])
		activations["enemy_%d" % id] = count
		if count >= 2 and not (phase_result.get("unknown_repeat_ids", {}) as Dictionary).has(id): counted.append({"key": "enemy_%d" % id, "name": str(names.get(id, "")), "count": count})
	for id: int in phase_result.get("enemy_hits", {}):
		hits["enemy_%d" % id] = true
	var unknown: Dictionary = {}
	for id: int in phase_result.get("unknown_repeat_ids", {}):
		unknown["enemy_%d" % id] = true
	return {"enemy_activations": activations, "enemy_hits": hits, "counted_repeats": counted, "unknown_repeat_keys": unknown}
