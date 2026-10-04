extends RefCounted

## Defense, health-payment and Exhaust relics. No GameData preload: card
## definitions use this helper too. Combat hooks pass their engine/effects.
## Contract: spec/card_keywords_wave3.md, relic overhaul U5.
const Rites = preload("res://scripts/rite_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const LAST_EXHAUST_KEY := "last_exhausted_card"

static func effects_of_type(effects: Array, kind: String) -> Array[Dictionary]:
	return Rites.effects_of_type(effects, kind)

static func has_effect(effects: Array, kind: String) -> bool:
	return not effects_of_type(effects, kind).is_empty()

static func free_rite(card: Dictionary, effects: Array) -> bool:
	return Rites.is_rite_card(card) and has_effect(effects, "rite_no_card_play")

static func suppress_card_block(action: Dictionary, effects: Array) -> Dictionary:
	if not has_effect(effects, "prevent_card_block"):
		return action
	var result: Dictionary = action.duplicate(true)
	_suppress_block_in_place(result)
	return result

# Conditional schemas can nest rewards arbitrarily; inspect every container.
static func _suppress_block_in_place(value: Variant) -> void:
	if value is Array:
		for child: Variant in value: _suppress_block_in_place(child)
	elif value is Dictionary:
		var fields: Dictionary = value
		if str(fields.get("type", "")) == "block":
			fields["amount"] = 0
			var bonus: Dictionary = fields.get("surface_bonus", {}) as Dictionary
			if bonus.has("amount"): bonus["amount"] = 0
		if fields.has("block_per_tile"): fields["block_per_tile"] = 0
		for child: Variant in fields.values(): _suppress_block_in_place(child)

static func modify_card(card: Dictionary, effects: Array) -> Dictionary:
	if not has_effect(effects, "prevent_card_block"):
		return card
	var result: Dictionary = card.duplicate(true)
	var actions: Array = []
	for action: Dictionary in result.get("actions", []):
		actions.append(suppress_card_block(action, effects))
	result["actions"] = actions
	# Keyword modifications happen later. Suppress their Block gains as well so
	# the face, Empower segment and appended conditional rewards remain honest.
	for keyword: String in ["empower", "follow_up"]:
		if typeof(result.get(keyword, null)) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = result[keyword]
		for mod: Dictionary in spec.get("mods", []):
			var index: int = int(mod.get("action", -1))
			if index < 0 or index >= actions.size():
				continue
			for operation: String in ["add", "set"]:
				var fields: Dictionary = mod.get(operation, {}) as Dictionary
				if str((actions[index] as Dictionary).get("type", "")) == "block" and fields.has("amount"):
					fields["amount"] = 0
				if fields.has("block_per_tile"):
					fields["block_per_tile"] = 0
		var appended: Array = []
		for action: Dictionary in spec.get("append", []):
			appended.append(suppress_card_block(action, effects))
		spec["append"] = appended
	return result

static func pay_health_cost(engine: RefCounted, state: Dictionary, amount: int, source_name: String = "card") -> Dictionary:
	var cost: int = maxi(0, amount)
	var skin_spent: int = 0
	var player: Dictionary = engine._normalized_player(state.get("player", {}))
	for effect: Dictionary in effects_of_type(engine._relic_effects(state), "health_cost_stoneskin"):
		var rate: int = maxi(1, int(effect.get("stoneskin_per_health", 2)))
		var paid: int = mini(cost, int(player.get("stoneskin", 0)) / rate)
		skin_spent += paid * rate
		player["stoneskin"] = int(player.get("stoneskin", 0)) - paid * rate
		cost -= paid
	state["player"] = player
	if cost > 0:
		state = engine._lose_player_health(state, cost, true, false, "card_health_cost")
	if skin_spent > 0:
		engine._log(state, "Paid %d health and %d Stoneskin for %s." % [cost, skin_spent, source_name])
	elif source_name.begins_with("Empower "):
		engine._log(state, "Paid %d health to Empower %s." % [cost, source_name.trim_prefix("Empower ")])
	else:
		engine._log(state, "Paid %d health for %s." % [cost, source_name])
	return state

static func after_health_loss(engine: RefCounted, state: Dictionary, hp_lost: int) -> void:
	if hp_lost <= 0 or not engine.is_player_turn(state) or bool(state.get("player_turn_ending", false)):
		return
	for effect: Dictionary in effects_of_type(engine._relic_effects(state), "health_loss_next_attack"):
		var key: String = str(effect.get("relic_id", ""))
		var buffs: Array = Tempo.next_attack_buffs(state).duplicate(true)
		var existing: Dictionary = {}
		for buff: Dictionary in buffs:
			if str(buff.get("health_loss_relic", "")) == key:
				existing = buff
				break
		var bonus: int = hp_lost * int(effect.get("damage_per_health", 2))
		var cap: int = int(effect.get("max_damage", 8))
		if existing.is_empty():
			Tempo.gain_next_attack(state, {"damage": mini(cap, bonus), "immediate": true}, engine._relic_effect_source_name(effect))
			buffs = Tempo.next_attack_buffs(state).duplicate(true)
			(buffs.back() as Dictionary)["health_loss_relic"] = key
		else:
			existing["damage"] = mini(cap, int(existing.get("damage", 0)) + bonus)
		Tempo._set_flag(state, Tempo.NEXT_ATTACK_KEY, buffs)

static func after_retaliate(engine: RefCounted, state: Dictionary, hp_lost: int) -> Dictionary:
	for effect: Dictionary in effects_of_type(engine._relic_effects(state), "retaliate_health_block"):
		if hp_lost > 0:
			state = engine._apply_relic_rewards(state, [{"type": "block", "amount": hp_lost, "_runtime_amount": true}], effect)
	return state

static func opening_hand(engine: RefCounted, state: Dictionary) -> Dictionary:
	if not has_effect(engine._relic_effects(state), "opening_hand_rite"):
		return state
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	var hand: Array = deck.get("hand", []) as Array
	for id: Variant in hand:
		if Rites.is_rite_card(engine.card_def(str(id), state)):
			return state
	if hand.is_empty():
		return state
	var draw: Array = deck.get("draw", []) as Array
	# The engine draws from the back; do not sort or reshuffle the other cards.
	for index: int in range(draw.size() - 1, -1, -1):
		if Rites.is_rite_card(engine.card_def(str(draw[index]), state)):
			var last_drawn: Variant = hand.back()
			hand[hand.size() - 1] = draw[index]
			draw[index] = last_drawn
			state["deck"] = deck
			break
	return state

static func after_exhaust(engine: RefCounted, state: Dictionary, card_id: String, time_paid: int) -> Dictionary:
	var burned: Array = (state.get("deck", {}) as Dictionary).get("burned", []) as Array
	state[LAST_EXHAUST_KEY] = {"card_id": card_id, "pile_index": burned.size() - 1, "returned": false}
	if time_paid <= 0: return state
	for effect: Dictionary in effects_of_type(engine._relic_effects(state), "exhaust_time_stoneskin"):
		state = engine._apply_relic_rewards(state, [{"type": "stoneskin", "amount": mini(maxi(0, time_paid), int(effect.get("max_amount", 5))), "_runtime_amount": true}], effect)
	return state

static func card_heals(card: Dictionary) -> bool:
	if _actions_heal(card.get("actions", []) as Array):
		return true
	for keyword: String in ["empower", "follow_up"]:
		var spec: Dictionary = card.get(keyword, {}) as Dictionary
		if _actions_heal(spec.get("append", []) as Array):
			return true
		for mod: Dictionary in spec.get("mods", []):
			if str((mod.get("set", {}) as Dictionary).get("type", "")) == "heal":
				return true
	return false

static func _actions_heal(actions: Array) -> bool:
	for action: Dictionary in actions:
		if str(action.get("type", "")) == "heal" or _actions_heal(action.get("rewards", []) as Array):
			return true
	return false

static func player_turn_start(engine: RefCounted, state: Dictionary) -> Dictionary:
	for effect: Dictionary in engine._relic_effects(state):
		match str(effect.get("type", "")):
			"turn_start_active_rite_block":
				if not Rites.active_rites(state).is_empty():
					state = engine._apply_relic_rewards(state, [{"type": "block", "amount": Rites.active_rites(state).size() * int(effect.get("amount", 2))}], effect)
			"turn_start_return_exhaust":
				if not engine._relic_once_available(state, effect, "return_exhaust", ""):
					continue
				engine._mark_relic_once(state, effect, "return_exhaust", "")
				var record: Dictionary = state.get(LAST_EXHAUST_KEY, {}) as Dictionary
				if record.is_empty() or bool(record.get("returned", false)):
					continue
				var id: String = str(record.get("card_id", ""))
				var card: Dictionary = engine.card_def(id, state)
				if Rites.is_rite_card(card) or card_heals(card):
					continue
				var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
				var burned: Array = deck.get("burned", []) as Array
				var index: int = int(record.get("pile_index", -1))
				if index < 0 or index >= burned.size() or str(burned[index]) != id:
					continue
				burned.remove_at(index)
				var hand: Array = deck.get("hand", []) as Array
				if hand.size() < engine.MAX_HAND_SIZE:
					hand.append(id)
					deck["draw_revision"] = int(deck.get("draw_revision", 0)) + 1
				else:
					(deck.get("draw", []) as Array).append(id)
				state["deck"] = deck
				record["returned"] = true
	return state
