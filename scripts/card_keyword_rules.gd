extends RefCounted

# Card keywords owned outside the combat engine's large resolver: Follow-up,
# Empower, Stagger, and the per-hit state/scale bonuses. The engine calls these
# helpers at fixed points so previews, the hand display and resolution share one
# rule. Rules and UI contract: spec/card_keywords.md.

const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const TempoRelicRules = preload("res://scripts/tempo_relic_rules.gd")

const PLAY_MODIFIERS_KEY: String = "card_play_modifiers"
const FOLLOW_UP_FLAG: String = "_follow_up_active"
const EMPOWERED_FLAG: String = "_empowered"
const KEYWORD_APPENDED_FLAG: String = "_keyword_appended"
const STAGGER_TURN_CAP: int = 6
const STAGGER_TURN_FLAG: String = "stagger_applied"
const STAGGER_PENDING_KEY: String = "stagger_pending"
const STAGGER_TOTAL_KEY: String = "stagger_applied_total"
const TILES_MOVED_TURN_FLAG: String = "tiles_moved"
const PREVIEW_DELAYS_KEY: String = "turn_order_preview_enemy_delays"
const STATE_BONUS_FIELDS: Array = ["damage", "stagger"]

# ---------------------------------------------------------------- Follow-up / Empower

# Cheap pre-check on the shared data cache (no copy) for hot preview paths.
static func card_id_may_have_keywords(card_id: String) -> bool:
	var raw: Dictionary = GameData.cards().get(card_id, {}) as Dictionary
	if bool(raw.get("retired", false)):
		raw = GameData.cards().get(str(raw.get("replacement_id", "")), {}) as Dictionary
	return raw.has("follow_up") or raw.has("empower")

static func has_follow_up(card: Dictionary) -> bool:
	return _keyword_spec_present(card.get("follow_up", null))

static func has_empower(card: Dictionary) -> bool:
	return _keyword_spec_present(card.get("empower", null))

static func _keyword_spec_present(spec: Variant) -> bool:
	if typeof(spec) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = spec
	return bool(dict.get("repeat_first", false)) or not (dict.get("mods", []) as Array).is_empty() or not (dict.get("append", []) as Array).is_empty()

# The card that is starting counts only cards finished earlier this activation:
# cards_played_this_turn increments in finish_player_card, never mid-card.
static func follow_up_condition_met(state: Dictionary) -> bool:
	if int(state.get("cards_played_this_turn", 0)) <= 0 and not TempoRelicRules.follow_up_from_movement(state, GameData.relic_effects_for_state(state)):
		return false
	var actor: Variant = state.get("current_actor", {})
	return typeof(actor) != TYPE_DICTIONARY or str((actor as Dictionary).get("kind", "player")) == "player"

static func stamp_card_start(state: Dictionary, card_id: String, card: Dictionary, empowered: bool) -> void:
	if card_id.is_empty() or not (has_follow_up(card) or has_empower(card)):
		state.erase(PLAY_MODIFIERS_KEY)
		return
	state[PLAY_MODIFIERS_KEY] = {
		"card_id": card_id,
		"follow_up": has_follow_up(card) and follow_up_condition_met(state),
		"empowered": empowered and has_empower(card),
	}

static func play_modifiers(state: Dictionary, card_id: String, card: Dictionary) -> Dictionary:
	var stamped: Variant = state.get(PLAY_MODIFIERS_KEY, {})
	if typeof(stamped) == TYPE_DICTIONARY and not card_id.is_empty() and str((stamped as Dictionary).get("card_id", "")) == card_id:
		return {
			"follow_up": bool((stamped as Dictionary).get("follow_up", false)) and has_follow_up(card),
			"empowered": bool((stamped as Dictionary).get("empowered", false)) and has_empower(card),
		}
	return {"follow_up": has_follow_up(card) and follow_up_condition_met(state), "empowered": false}

static func actions_for_play(card: Dictionary, card_id: String, state: Dictionary) -> Array:
	return actions_with_modifiers(card, play_modifiers(state, card_id, card))

# Mods index the printed action list. Follow-up applies before Empower; both use
# the state captured at the card's start, so Flurry repeats share one result.
static func actions_with_modifiers(card: Dictionary, modifiers: Dictionary) -> Array:
	var actions: Array = (card.get("actions", []) as Array).duplicate(true)
	var printed_count: int = actions.size()
	if bool(modifiers.get("follow_up", false)) and has_follow_up(card):
		actions = _apply_keyword_spec(actions, card.get("follow_up", {}) as Dictionary, printed_count, "Follow-up", FOLLOW_UP_FLAG)
	if bool(modifiers.get("empowered", false)) and has_empower(card):
		actions = _apply_keyword_spec(actions, card.get("empower", {}) as Dictionary, printed_count, "Empower", EMPOWERED_FLAG)
	if bool(modifiers.get("empowered", false)) and bool((card.get("empower", {}) as Dictionary).get("repeat_first", false)) and not actions.is_empty():
		var repeated: Dictionary = (actions[0] as Dictionary).duplicate(true)
		(actions[0] as Dictionary)["_empower_repeat_available"] = true
		repeated["_empower_repeat_first"] = true
		repeated[KEYWORD_APPENDED_FLAG] = "Empower"
		# Existing Flurry reuse path supplies the original target and skips a
		# now-illegal repeat. Insert before later printed/Follow-up actions.
		repeated["reuse_previous_target"] = true
		actions.insert(1, repeated)
	return actions

static func _apply_keyword_spec(actions: Array, spec: Dictionary, printed_count: int, source: String, flag: String) -> Array:
	var result: Array = actions.duplicate(true)
	for mod_var: Variant in spec.get("mods", []):
		if typeof(mod_var) != TYPE_DICTIONARY:
			continue
		var mod: Dictionary = mod_var
		var index: int = int(mod.get("action", -1))
		if index < 0 or index >= mini(printed_count, result.size()) or typeof(result[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (result[index] as Dictionary).duplicate(true)
		var added: Dictionary = mod.get("add", {}) as Dictionary
		for field_var: Variant in added.keys():
			var field: String = str(field_var)
			var before: Variant = action.get(field, 0)
			action[field] = int(before) + int(added[field_var])
			_record_modifier(action, source, field, before, action[field])
		var assigned: Dictionary = mod.get("set", {}) as Dictionary
		for field_var: Variant in assigned.keys():
			var field: String = str(field_var)
			var before: Variant = action.get(field, null)
			var value: Variant = assigned[field_var]
			action[field] = (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else value
			_record_modifier(action, source, field, before, action[field])
		result[index] = action
	var template: Dictionary = result[0] as Dictionary if not result.is_empty() and typeof(result[0]) == TYPE_DICTIONARY else {}
	for appended_var: Variant in spec.get("append", []):
		if typeof(appended_var) != TYPE_DICTIONARY:
			continue
		var appended: Dictionary = (appended_var as Dictionary).duplicate(true)
		for tag: String in ["_card_element", "_card_action_types"]:
			if template.has(tag) and not appended.has(tag):
				appended[tag] = template[tag].duplicate(true) if typeof(template[tag]) == TYPE_ARRAY else template[tag]
		_record_modifier(appended, source, "_action", null, str(appended.get("type", "")))
		appended[KEYWORD_APPENDED_FLAG] = source
		result.append(appended)
	for index: int in range(result.size()):
		if typeof(result[index]) == TYPE_DICTIONARY:
			(result[index] as Dictionary)[flag] = true
	return result

static func _record_modifier(action: Dictionary, source: String, field: String, before: Variant, after: Variant) -> void:
	var by_field: Dictionary = (action.get("_modifiers", {}) as Dictionary).duplicate(true) if typeof(action.get("_modifiers", {})) == TYPE_DICTIONARY else {}
	var entries: Array = (by_field.get(field, []) as Array).duplicate(true) if typeof(by_field.get(field, [])) == TYPE_ARRAY else []
	var amount: int = 0
	if typeof(before) in [TYPE_INT, TYPE_FLOAT] and typeof(after) in [TYPE_INT, TYPE_FLOAT]:
		amount = int(after) - int(before)
	elif before == null and typeof(after) in [TYPE_INT, TYPE_FLOAT]:
		amount = int(after)
	entries.append({
		"source": source,
		"amount": amount,
		"label": "%+d" % amount if amount != 0 else "",
		"field": field,
		"before": before,
		"after": after,
	})
	by_field[field] = entries
	action["_modifiers"] = by_field

static func empower_cost(card: Dictionary) -> Dictionary:
	if not has_empower(card):
		return {}
	return ((card.get("empower", {}) as Dictionary).get("cost", {}) as Dictionary).duplicate(true)

static func empower_cost_label(cost: Dictionary) -> String:
	if bool(cost.get("exhaust", false)):
		return "Exhaust"
	if int(cost.get("health", 0)) > 0:
		return "%d HP" % int(cost.get("health", 0))
	if int(cost.get("time", 0)) > 0:
		return "+%d Time" % int(cost.get("time", 0))
	return ""

static func empower_payment(state: Dictionary, card_id: String, card: Dictionary) -> Dictionary:
	if not bool(play_modifiers(state, card_id, card).get("empowered", false)):
		return {}
	var cost: Dictionary = empower_cost(card)
	return {
		"time": maxi(0, int(cost.get("time", 0))),
		"health": maxi(0, int(cost.get("health", 0))),
		"exhaust": bool(cost.get("exhaust", false)),
	}

static func empower_time_surcharge(state: Dictionary, card_id: String, card: Dictionary) -> int:
	return int(empower_payment(state, card_id, card).get("time", 0))

static func play_summary(card: Dictionary, before_state: Dictionary, resolved_state: Dictionary, actions: Array) -> Dictionary:
	var follow_up_active: bool = false
	var empowered: bool = false
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		follow_up_active = follow_up_active or bool((action_var as Dictionary).get(FOLLOW_UP_FLAG, false))
		empowered = empowered or bool((action_var as Dictionary).get(EMPOWERED_FLAG, false))
	return {
		"follow_up_active": follow_up_active,
		"empowered": empowered,
		"empower_cost": empower_cost(card) if empowered else null,
		"stagger_applied": maxi(0, int(resolved_state.get(STAGGER_TOTAL_KEY, 0)) - int(before_state.get(STAGGER_TOTAL_KEY, 0))),
	}

# ---------------------------------------------------------------- Stagger

static func stagger_delay(enemy_type: String, amount: int, applied_this_turn: int) -> int:
	var delay: int = maxi(0, amount)
	if DragonBossLibrary.is_dragon_boss_id(enemy_type):
		delay = int(delay / 2)
	return clampi(delay, 0, maxi(0, STAGGER_TURN_CAP - maxi(0, applied_this_turn)))

static func stagger_applied_this_turn(state: Dictionary, enemy_id: int) -> int:
	var applied: Dictionary = (state.get("turn_flags", {}) as Dictionary).get(STAGGER_TURN_FLAG, {}) as Dictionary
	return int(applied.get(str(enemy_id), 0))

# Returns the delay actually added. Only the enemy's next queued turn moves; the
# initiative clock never changes. An unqueued enemy (the current actor) keeps the
# delay until it is next scheduled.
static func apply_stagger(engine: RefCounted, state: Dictionary, enemy_id: int, amount: int) -> int:
	if amount <= 0:
		return 0
	var enemy_index: int = engine._enemy_index_for_id(state, enemy_id)
	if enemy_index < 0:
		return 0
	var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index] as Dictionary
	if int(enemy.get("hp", 0)) <= 0:
		return 0
	var delay: int = stagger_delay(str(enemy.get("type", "")), amount, stagger_applied_this_turn(state, enemy_id))
	var before_cap: int = maxi(0, amount)
	if DragonBossLibrary.is_dragon_boss_id(str(enemy.get("type", ""))):
		before_cap = int(before_cap / 2)
	TempoRelicRules.stagger_overflow(engine, state, enemy_index, before_cap - delay, GameData.relic_effects_for_state(state))
	if delay <= 0:
		return 0
	var flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	var applied: Dictionary = (flags.get(STAGGER_TURN_FLAG, {}) as Dictionary).duplicate(true)
	applied[str(enemy_id)] = int(applied.get(str(enemy_id), 0)) + delay
	flags[STAGGER_TURN_FLAG] = applied
	state["turn_flags"] = flags
	state[STAGGER_TOTAL_KEY] = int(state.get(STAGGER_TOTAL_KEY, 0)) + delay
	var queue: Array = (state.get("turn_queue", []) as Array).duplicate(true)
	var target_index: int = -1
	for index: int in range(queue.size()):
		if typeof(queue[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = queue[index]
		if str(entry.get("kind", "")) != "enemy" or int(entry.get("enemy_id", -1)) != enemy_id:
			continue
		if target_index < 0 or int(entry.get("time", 0)) < int((queue[target_index] as Dictionary).get("time", 0)):
			target_index = index
	if target_index >= 0:
		var delayed: Dictionary = (queue[target_index] as Dictionary).duplicate(true)
		delayed["time"] = int(delayed.get("time", 0)) + delay
		delayed["seq"] = engine._claim_activation_seq(state)
		queue[target_index] = delayed
		state["turn_queue"] = engine._sorted_turn_queue(queue)
	else:
		var pending: Dictionary = (state.get(STAGGER_PENDING_KEY, {}) as Dictionary).duplicate(true)
		pending[str(enemy_id)] = int(pending.get(str(enemy_id), 0)) + delay
		state[STAGGER_PENDING_KEY] = pending
	engine._log(state, "%s is staggered by %d." % [engine._enemy_display_name(enemy), delay])
	return delay

static func consume_pending_stagger(state: Dictionary, entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "")) != "enemy":
		return entry
	var pending: Dictionary = state.get(STAGGER_PENDING_KEY, {}) as Dictionary
	var key: String = str(int(entry.get("enemy_id", -1)))
	if not pending.has(key):
		return entry
	var delayed: Dictionary = entry.duplicate(true)
	delayed["time"] = int(delayed.get("time", 0)) + maxi(0, int(pending.get(key, 0)))
	var remaining: Dictionary = pending.duplicate(true)
	remaining.erase(key)
	if remaining.is_empty():
		state.erase(STAGGER_PENDING_KEY)
	else:
		state[STAGGER_PENDING_KEY] = remaining
	return delayed

static func stagger_delays_between(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var before: Dictionary = (before_state.get("turn_flags", {}) as Dictionary).get(STAGGER_TURN_FLAG, {}) as Dictionary
	var after: Dictionary = (after_state.get("turn_flags", {}) as Dictionary).get(STAGGER_TURN_FLAG, {}) as Dictionary
	var result: Dictionary = {}
	for key_var: Variant in after.keys():
		var delta: int = int(after[key_var]) - int(before.get(key_var, 0))
		if delta != 0:
			result[int(str(key_var))] = delta
	return result

# Transient turn-order projection only: the committed queue is untouched.
static func queue_with_preview_delays(queue: Array, delays: Dictionary) -> Array:
	var result: Array = queue.duplicate(true)
	var delayed_ids: Dictionary = {}
	for index: int in range(result.size()):
		if typeof(result[index]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = result[index]
		var enemy_id: int = int(entry.get("enemy_id", -1))
		if str(entry.get("kind", "")) != "enemy" or delayed_ids.has(enemy_id) or not delays.has(enemy_id):
			continue
		delayed_ids[enemy_id] = true
		entry["time"] = int(entry.get("time", 0)) + int(delays[enemy_id])
		entry["stagger_preview"] = int(delays[enemy_id])
	return result

# ---------------------------------------------------------------- State and scale bonuses

static func state_condition_met(engine: RefCounted, state: Dictionary, condition: String, enemy_index: int) -> bool:
	var enemies: Array = state.get("enemies", [])
	if enemy_index < 0 or enemy_index >= enemies.size():
		return false
	var enemy: Dictionary = engine._normalized_enemy(enemies[enemy_index] as Dictionary)
	match condition:
		"light":
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				if engine._light_source_covers_tile(state, tile):
					return true
			return false
		"frozen":
			return int(enemy.get("freeze", 0)) > 0
		"half_hp":
			return int(enemy.get("hp", 0)) * 2 <= int(enemy.get("max_hp", 1))
	return false

# Evaluated per hit against the target, before that hit's damage lands.
static func action_with_state_bonus(engine: RefCounted, state: Dictionary, action: Dictionary, enemy_index: int) -> Dictionary:
	var bonuses: Variant = action.get("state_bonus", [])
	if typeof(bonuses) != TYPE_ARRAY or (bonuses as Array).is_empty():
		return action
	var resolved: Dictionary = action.duplicate(true)
	for bonus_var: Variant in bonuses:
		if typeof(bonus_var) != TYPE_DICTIONARY:
			continue
		var bonus: Dictionary = bonus_var
		if not state_condition_met(engine, state, str(bonus.get("state", "")), enemy_index):
			continue
		for field: String in STATE_BONUS_FIELDS:
			if bonus.has(field):
				resolved[field] = int(resolved.get(field, 0)) + int(bonus[field])
	return resolved

static func tiles_moved_this_turn(state: Dictionary) -> int:
	return int((state.get("turn_flags", {}) as Dictionary).get(TILES_MOVED_TURN_FLAG, 0))

static func record_tiles_moved(state: Dictionary, tiles: int) -> void:
	if tiles <= 0:
		return
	var flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	flags[TILES_MOVED_TURN_FLAG] = int(flags.get(TILES_MOVED_TURN_FLAG, 0)) + tiles
	state["turn_flags"] = flags

static func scale_bonus_damage(state: Dictionary, action: Dictionary) -> int:
	var bonus: Variant = action.get("scale_bonus", {})
	if typeof(bonus) != TYPE_DICTIONARY or (bonus as Dictionary).is_empty():
		return 0
	var spec: Dictionary = bonus
	var count: int = 0
	match str(spec.get("per", "")):
		"stoneskin":
			count = int((state.get("player", {}) as Dictionary).get("stoneskin", 0))
		"tiles_moved":
			count = tiles_moved_this_turn(state)
	var amount: int = maxi(0, count) * int(spec.get("damage", 1))
	if spec.has("max"):
		amount = mini(amount, maxi(0, int(spec.get("max", 0))))
	return maxi(0, amount)

static func scale_bonus_modifier(state: Dictionary, action: Dictionary) -> Dictionary:
	var amount: int = scale_bonus_damage(state, action)
	if amount <= 0:
		return {}
	var spec: Dictionary = action.get("scale_bonus", {}) as Dictionary
	var per: String = str(spec.get("per", ""))
	return {
		"source": "Stoneskin" if per == "stoneskin" else "Tiles moved",
		"kind": "keyword",
		"amount": amount,
		"detail": "+%d each (max %d)" % [int(spec.get("damage", 1)), int(spec.get("max", 0))]
	}
