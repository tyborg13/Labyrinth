extends RefCounted

## Relic pool U4. Data-driven tempo hooks; no GameData preload (it calls us).
## Combat dictionaries persist both the spent flags and the extra-turn Time debt.
const TempoRules = preload("res://scripts/tempo_rules.gd")
const DEBT_KEY := "tempo_turn_time_debt"

static func effect_of_type(effects: Array, effect_type: String) -> Dictionary:
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) == effect_type:
			return effect
	return {}

static func used(state: Dictionary, effect: Dictionary) -> bool:
	return bool((state.get("relic_flags", {}) as Dictionary).get("tempo_used:" + str(effect.get("relic_id", "")), false))

static func extra_turn_available(state: Dictionary, effects: Array, unused: int) -> bool:
	var effect: Dictionary = effect_of_type(effects, "unused_play_extra_turn")
	return unused > 0 and not effect.is_empty() and not used(state, effect)

static func full_turn_reduction(engine: RefCounted, state: Dictionary, effects: Array, plays_spent: int = 0) -> int:
	var effect: Dictionary = effect_of_type(effects, "full_turn_time_reduction")
	return int(effect.get("amount", 0)) if engine.base_plays_waited(state, plays_spent) == 0 else 0

static func next_turn_time(engine: RefCounted, state: Dictionary, effects: Array, extra_time: int = 0, plays_spent: int = 0) -> int:
	var unused: int = maxi(0, engine.cards_remaining_this_turn(state) - plays_spent)
	var clock: int = int(state.get("initiative_clock", 0))
	if extra_turn_available(state, effects, unused):
		return clock
	return clock + engine.player_base_initiative(state) + int(state.get(DEBT_KEY, 0)) + maxi(0, int(state.get("player_turn_time_spent", 0))) + extra_time + engine.pending_wait_time(state, plays_spent) - full_turn_reduction(engine, state, effects, plays_spent)

static func end_activation(engine: RefCounted, state: Dictionary, effects: Array, unused: int) -> Dictionary:
	if not extra_turn_available(state, effects, unused):
		var time: int = next_turn_time(engine, state, effects)
		state.erase(DEBT_KEY)
		return {"time": time, "immediate": false}
	var effect: Dictionary = effect_of_type(effects, "unused_play_extra_turn")
	var flags: Dictionary = (state.get("relic_flags", {}) as Dictionary).duplicate(true)
	flags["tempo_used:" + str(effect.get("relic_id", ""))] = true
	state["relic_flags"] = flags
	state[DEBT_KEY] = int(state.get(DEBT_KEY, 0)) + int(state.get("player_turn_time_spent", 0)) + engine.pending_wait_time(state) - full_turn_reduction(engine, state, effects)
	return {"time": int(state.get("initiative_clock", 0)), "immediate": true}

static func is_late(engine: RefCounted, state: Dictionary, enemy_id: int, effects: Array, extra_time: int = 0, plays_spent: int = 0) -> bool:
	if not engine.is_player_turn(state):
		return false
	# Actions carry the pending card's Time/slots before finish_player_card pays
	# them. Match its rail preview, but exclude Hourglass's immediate shortcut.
	var hero_time: int = int(state.get("initiative_clock", 0)) + engine.player_base_initiative(state) + int(state.get(DEBT_KEY, 0)) + maxi(0, int(state.get("player_turn_time_spent", 0))) + extra_time + engine.pending_wait_time(state, plays_spent) - full_turn_reduction(engine, state, effects, plays_spent)
	var enemy_time: int = 2147483647
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == enemy_id:
			enemy_time = mini(enemy_time, int(entry.get("time", 0)))
	if enemy_time == 2147483647:
		return false
	var delays: Dictionary = state.get("turn_order_preview_enemy_delays", {}) as Dictionary
	return enemy_time + int(delays.get(enemy_id, 0)) > hero_time

static func late_damage(engine: RefCounted, state: Dictionary, action: Dictionary, enemy_id: int, effects: Array) -> int:
	var effect: Dictionary = effect_of_type(effects, "damage_vs_late")
	if effect.is_empty() or action.has("_enemy_id") or str(action.get("type", "")) not in TempoRules.ATTACK_ACTION_TYPES or TempoRules.is_forced_movement_only(action):
		return 0
	return int(effect.get("amount", 0)) if is_late(engine, state, enemy_id, effects, int(action.get("_tempo_card_time", 0)), int(action.get("_tempo_plays_spent", 0))) else 0

static func follow_up_from_movement(state: Dictionary, effects: Array) -> bool:
	var effect: Dictionary = effect_of_type(effects, "movement_first_follow_up")
	return not effect.is_empty() and TempoRules.cards_finished(state) == 0 and TempoRules.tiles_moved(state) >= int(effect.get("tiles", 2))

static func card_surcharge(state: Dictionary, effects: Array) -> int:
	var effect: Dictionary = effect_of_type(effects, "later_card_time_surcharge")
	return int(effect.get("amount", 0)) if not effect.is_empty() and TempoRules.cards_finished(state) >= int(effect.get("after", 2)) else 0

static func modify_card(card: Dictionary, state: Dictionary, effects: Array, is_item: bool) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	var surcharge: int = card_surcharge(state, effects)
	if surcharge > 0:
		# Add after discounts/reserve. Keep the printed-cost clamp separate from
		# this surcharge, just as the existing Empower Time payment does.
		result["_tempo_time_surcharge"] = surcharge
		result["_tempo_time_surcharge_relic"] = str(effect_of_type(effects, "later_card_time_surcharge").get("relic_id", ""))
	var empower_effect: Dictionary = effect_of_type(effects, "grant_first_action_empower")
	if not empower_effect.is_empty() and not result.has("empower") and not result.has("rite") and not is_item and not bool(result.get("flurry", false)) and not (result.get("actions", []) as Array).is_empty():
		result["empower"] = {"cost": {"time": int(empower_effect.get("time", 3))}, "repeat_first": true}
	return result

static func finish_card(state: Dictionary, modifiers: Dictionary, effects: Array, paid_time: int, played_before: int) -> void:
	for effect: Dictionary in effects:
		match str(effect.get("type", "")):
			"high_time_quicken":
				if paid_time >= int(effect.get("min_time", 6)):
					TempoRules.gain_quicken(state, {"amount": int(effect.get("amount", 2))})
			"empower_quicken":
				if bool(modifiers.get("empowered", false)):
					TempoRules.gain_quicken(state, {"amount": int(effect.get("amount", 2))})
			"follow_up_next_card":
				if bool(modifiers.get("follow_up", false)):
					TempoRules.gain_quicken(state, {"amount": int(effect.get("quicken", 1))})
					TempoRules.gain_next_attack(state, {"damage": int(effect.get("damage", 2)), "card_scoped": true}, str(effect.get("source_name", "Echoing Blade")))
					# finish_player_card already incremented the finished-card counter.
					var buffs: Array = TempoRules.next_attack_buffs(state)
					(buffs.back() as Dictionary)["granted_at"] = played_before

static func stagger_overflow(engine: RefCounted, state: Dictionary, enemy_index: int, overflow: int, effects: Array) -> void:
	var effect: Dictionary = effect_of_type(effects, "stagger_overflow_damage")
	if effect.is_empty() or overflow <= 0:
		return
	var previous: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	state["damage_context"] = {"actor_kind": "player", "causal_owner": "player", "source_kind": "relic", "player_card": false, "relic_id": str(effect.get("relic_id", ""))}
	engine._damage_enemy(state, enemy_index, overflow, false, false)
	state["damage_context"] = previous
