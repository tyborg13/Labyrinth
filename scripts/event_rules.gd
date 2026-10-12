extends RefCounted
class_name EventRules

const GameData = preload("res://scripts/game_data.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const EFFECT_TYPES: Array = ["hp", "heal", "heal_percent", "max_hp", "embers", "relic", "card", "card_choice", "equipment", "reforge", "item", "lose_item", "transform_magic", "omen", "defiance", "scout", "reveal", "random"]
const REQUIREMENT_TYPES: Array = ["hp_above", "max_hp_above", "embers_at_least", "has_item", "has_equipment", "has_attuned_magic"]
const POOLS: Array = ["any", "earth", "fire", "air", "ice", "lightning", "shadow"]
const EMPTY_POOL_EMBERS: int = 40
static func art_path(id: String) -> String:
	return "res://assets/art/events/%s.png" % id

static func validate_data() -> Array[String]:
	var problems: Array[String]
	for id: String in GameData.omens():
		var omen: Dictionary = GameData.omen_def(id)
		if str(omen.get("name", "")).is_empty() or str(omen.get("description", "")).is_empty() or str(omen.get("kind", "")) not in ["blessing", "bane"] or int(omen.get("fights", 0)) < 1:
			problems.append("Invalid omen: %s" % id)
		if typeof(omen.get("effect")) != TYPE_DICTIONARY or str(omen.get("effect", {}).get("type", "")) not in Omens.EFFECT_TYPES:
			problems.append("Unknown omen effect: %s" % id)
		elif str(omen["effect"].get("type", "")) == "start_vision_turns" and (not omen["effect"].has("radius") or int(omen["effect"]["radius"]) < 0):
			problems.append("Invalid omen Vision radius: %s" % id)
	for id: String in GameData.events():
		var event: Dictionary = GameData.event_def(id)
		if str(event.get("title", "")).is_empty() or str(event.get("body", "")).is_empty() or str(event.get("body", "")).split(" ", false).size() > 70:
			problems.append("Invalid event text: %s" % id)
		if str(event.get("pool", "")) not in POOLS or not event.has("min_section") or not event.has("max_section") or int(event.get("min_section", -1)) < 0 or int(event.get("max_section", 6)) > 5 or int(event.get("min_section", 0)) > int(event.get("max_section", 0)) or float(event.get("weight", 0)) <= 0:
			problems.append("Invalid event selection: %s" % id)
		var choices: Array = event.get("choices", [])
		if choices.size() < 2 or choices.size() > 3: problems.append("Invalid choice count: %s" % id)
		var seen: Dictionary = {}
		for choice: Dictionary in choices:
			var choice_id: String = str(choice.get("id", ""))
			if choice_id.is_empty() or seen.has(choice_id) or str(choice.get("label", "")).is_empty() or str(choice.get("label", "")).length() > 28:
				problems.append("Invalid choice: %s.%s" % [id, choice_id])
			seen[choice_id] = true
			for requirement: Dictionary in choice.get("requires", []):
				if str(requirement.get("type", "")) not in REQUIREMENT_TYPES: problems.append("Unknown requirement: %s.%s" % [id, choice_id])
			_validate_effects(choice.get("effects", []), "%s.%s" % [id, choice_id], problems)
	return problems

static func _validate_effects(effects: Array, path: String, problems: Array[String]) -> void:
	for effect: Dictionary in effects:
		var type: String = str(effect.get("type", ""))
		if type not in EFFECT_TYPES: problems.append("Unknown effect: %s" % path)
		if type == "omen" and GameData.omen_def(str(effect.get("id", ""))).is_empty(): problems.append("Unknown omen: %s" % path)
		if type == "random":
			var total: float = 0
			for outcome: Dictionary in effect.get("outcomes", []):
				total += float(outcome.get("weight", 0))
				if float(outcome.get("weight", 0)) < 0: problems.append("Invalid random weight: %s" % path)
				_validate_effects(outcome.get("effects", []), path, problems)
			if not is_equal_approx(total, 100.0): problems.append("Random weights must sum to 100: %s" % path)

static func section_index(state: Dictionary) -> int:
	var room: Dictionary = Graph.room(state, state.get("current_room", Vector2i.ZERO))
	return int(room.get("section_index", clampi((maxi(1, int(room.get("depth", 1))) - 1) / 4, 0, 5)))

static func section_element(state: Dictionary) -> String:
	var index: int = section_index(state)
	var boss_id: String = str(Graph.section(state, index).get("boss_id", Bosses.boss_id_for_depth(int(state.get("seed", 0)), (index + 1) * 4)))
	return "shadow" if boss_id == Bosses.SHADOW_BOSS_ID else Bosses.element_for_boss(boss_id)

static func rng_for(state: Dictionary, purpose: String) -> RandomNumberGenerator:
	var coord: Vector2i = state.get("current_room", Vector2i.ZERO)
	var rng := RandomNumberGenerator.new()
	# Only ordered persistent inputs; no Dictionary hashes or iteration order.
	rng.seed = ("%d|%d,%d|%s" % [int(state.get("seed", 0)), coord.x, coord.y, purpose]).hash()
	return rng

static func select_event(state: Dictionary) -> String:
	var ids: Array = GameData.events().keys()
	ids.sort()
	var candidates: Array[String]
	var fallback: Array[String]
	var index: int = section_index(state)
	var element: String = section_element(state)
	for id: String in ids:
		if (state.get("seen_events", []) as Array).has(id): continue
		var event: Dictionary = GameData.event_def(id)
		if str(event["pool"]) == "any": fallback.append(id)
		if str(event["pool"]) in ["any", element] and index >= int(event["min_section"]) and index <= int(event["max_section"]): candidates.append(id)
	if candidates.is_empty(): candidates = fallback
	if candidates.is_empty(): return "lost_cartographer"
	var weights: Array = []
	for id: String in candidates: weights.append(float(GameData.event_def(id)["weight"]))
	return candidates[_weighted_index(rng_for(state, "event"), weights)]

static func enter_event(state: Dictionary, legacy: bool = false) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var room: Dictionary = Graph.room(next, next.get("current_room", Vector2i.ZERO))
	if room.is_empty() or bool(room.get("cleared", false)): return next
	if not room.has("event_id"): room["event_id"] = "lost_cartographer" if legacy else select_event(next)
	var id: String = str(room["event_id"])
	if not next.has("event_state") or str(next.get("event_state", {}).get("event_id", "")) != id:
		var outcomes: Array[Dictionary]
		next["event_state"] = {"event_id": id, "page": "choices", "choice_id": "", "result_text": "", "outcomes": outcomes}
	next["mode"] = "event"
	return next

static func current_id(state: Dictionary) -> String:
	return str((state.get("event_state", {}) as Dictionary).get("event_id", Graph.room(state, state.get("current_room", Vector2i.ZERO)).get("event_id", "lost_cartographer")))

static func choice_def(event_id: String, choice_id: String) -> Dictionary:
	for choice: Dictionary in GameData.event_def(event_id).get("choices", []):
		if str(choice.get("id", "")) == choice_id: return choice
	return {}

static func choice_available(state: Dictionary, event_id: String, choice_id: String) -> bool:
	return not choice_def(event_id, choice_id).is_empty() and choice_block_reason(state, event_id, choice_id).is_empty()

static func first_available_choice_id(state: Dictionary) -> String:
	var id: String = current_id(state)
	for choice: Dictionary in GameData.event_def(id).get("choices", []):
		if choice_available(state, id, str(choice["id"])): return str(choice["id"])
	return ""

static func choice_block_reason(state: Dictionary, event_id: String, choice_id: String) -> String:
	var choice: Dictionary = choice_def(event_id, choice_id)
	for requirement: Dictionary in choice.get("requires", []):
		var value: int = int(requirement.get("amount", 0))
		match str(requirement.get("type", "")):
			"hp_above":
				if int(state.get("player_hp", 0)) <= value: return "Requires more than %d Health." % value
			"max_hp_above":
				if int(state.get("player_max_hp", 0)) <= value: return "Requires more than %d max Health." % value
			"embers_at_least":
				if int(state.get("held_embers", state.get("unbanked_embers", 0))) < value: return "Requires %d Embers." % value
			"has_item":
				if _consumables(state.get("item_inventory", [])).is_empty() and _consumables(state.get("equipped_items", [])).is_empty(): return "Requires an item."
			"has_equipment":
				if str((state.get("equipped_equipment", {}) as Dictionary).get(str(requirement["slot"]), "")).is_empty(): return "Requires an equipped %s." % slot_name(str(requirement["slot"]))
			"has_attuned_magic":
				if _attuned_slots(state).is_empty(): return "Requires an attuned spell."
	var effects: Array = choice.get("effects", [])
	if effects.size() == 1 and str(effects[0].get("type", "")) == "reveal" and reveal_targets(state, int(effects[0]["hops"])).is_empty(): return "Nothing new to reveal."
	return ""

static func reveal_targets(state: Dictionary, hops: int) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var mysteries_only: bool = Graph.full_visibility(state, section_index(state))
	for coord: Vector2i in Graph.descendants(state, state.get("current_room", Vector2i.ZERO), hops):
		var room: Dictionary = Graph.room(state, coord)
		# I–V already expose topology: surveys identify the remaining mysteries.
		# VI and stored older layouts retain the original reveal horizon.
		if mysteries_only:
			if str(room.get("type", "")) == "mystery" and not bool(room.get("visited", false)) and not bool(room.get("scouted", false)):
				result.append(coord)
		elif not bool(room.get("revealed", false)): result.append(coord)
	return result

static func choose_event(state: Dictionary, choice_id: String, engine: RefCounted = null) -> Dictionary:
	if str(state.get("mode", "")) != "event": return state.duplicate(true)
	var next: Dictionary = enter_event(state, true)
	var event: Dictionary = next.get("event_state", {})
	var id: String = current_id(next)
	if str(event.get("page", "")) != "choices" or not choice_available(next, id, choice_id): return state.duplicate(true)
	if engine == null: engine = load("res://scripts/run_engine.gd").new()
	var choice: Dictionary = choice_def(id, choice_id)
	var resolution: Dictionary = apply_effects(next, choice.get("effects", []), rng_for(next, "choice|%s" % choice_id), engine)
	next = resolution["state"]
	event = next["event_state"]
	event["page"] = "result"
	event["choice_id"] = choice_id
	event["result_text"] = resolution.get("result_text", str(choice.get("result", "")))
	event["outcomes"] = resolution["outcomes"]
	if not (next.get("seen_events", []) as Array).has(id):
		var seen: Array = next.get("seen_events", []).duplicate()
		seen.append(id)
		next["seen_events"] = seen
	var embers: int = 0
	var reveals: Array[Vector2i]
	for outcome: Dictionary in event["outcomes"]:
		if str(outcome["type"]) == "embers": embers += int(outcome["amount"])
		if str(outcome["type"]) == "reveal": reveals.append_array(outcome.get("rooms", []))
	Graph.record_event(next, "map_event_resolved", {"room": next["current_room"], "choice": choice_id, "event_id": id, "choice_id": choice_id, "outcomes": event["outcomes"].duplicate(true), "embers": embers, "revealed_rooms": reveals})
	return next

static func continue_event(state: Dictionary) -> Dictionary:
	if str(state.get("mode", "")) != "event" or str(state.get("event_state", {}).get("page", "")) != "result": return state.duplicate(true)
	var next: Dictionary = state.duplicate(true)
	Graph.room(next, next["current_room"])["cleared"] = true
	next["mode"] = "room"
	for outcome: Dictionary in next["event_state"].get("outcomes", []):
		if str(outcome["type"]) != "card_choice" or (outcome.get("cards", []) as Array).is_empty(): continue
		next["pending_reward"] = {"kind": "event", "event_id": current_id(next), "cards": outcome["cards"].duplicate(), "heal_amount": 0, "skip_label": "Skip", "ember_amount": 0, "intro_pending": false}
		next["mode"] = "reward"
	next.erase("event_state")
	return next

static func apply_effects(state: Dictionary, effects: Array, rng: RandomNumberGenerator, engine: RefCounted = null) -> Dictionary:
	if engine == null: engine = load("res://scripts/run_engine.gd").new()
	var next: Dictionary = state.duplicate(true)
	var outcomes: Array[Dictionary]
	var result: Dictionary = {}
	for effect: Dictionary in effects:
		var type: String = str(effect["type"])
		var value: int = int(effect.get("amount", 0))
		match type:
			"hp", "heal", "heal_percent":
				var before: int = int(next["player_hp"])
				if type == "heal_percent": value = roundi(float(next["player_max_hp"]) * float(effect["percent"]) / 100.0)
				next["player_hp"] = clampi(before + value, 1, int(next["player_max_hp"]))
				outcomes.append({"type": type, "amount": int(next["player_hp"]) - before})
			"max_hp":
				var before: int = int(next["player_max_hp"])
				next["player_max_hp"] = maxi(1, before + value)
				var actual: int = int(next["player_max_hp"]) - before
				next["player_hp"] = mini(int(next["player_max_hp"]), int(next["player_hp"]) + maxi(0, actual))
				outcomes.append({"type": type, "amount": actual})
			"embers":
				var before: int = engine.held_embers(next)
				next = engine.add_held_embers(next, value) if value >= 0 else engine.spend_held_embers(next, -value)
				outcomes.append({"type": type, "amount": engine.held_embers(next) - before})
			"relic", "equipment":
				var id: String = _gear_or_relic(next, effect, rng, engine)
				if id.is_empty():
					next = engine.add_held_embers(next, EMPTY_POOL_EMBERS)
					outcomes.append({"type": "embers", "amount": EMPTY_POOL_EMBERS, "substitution_for": type})
				elif type == "relic":
					var pending: Variant = next.get("pending_relics", [])
					var mode: String = str(next.get("mode", ""))
					next["pending_relics"] = [id]
					next = engine.claim_relic(next, id)
					next["pending_relics"] = pending
					next["mode"] = mode
					outcomes.append({"type": type, "id": id})
				else:
					next = engine._apply_collected_equipment_to_owned_state(next, {"collected_equipment": [id]})
					outcomes.append({"type": type, "id": id})
			"card", "card_choice":
				var cards: Array[String] = _cards(next, effect, rng)
				if cards.is_empty():
					next = engine.add_held_embers(next, EMPTY_POOL_EMBERS)
					outcomes.append({"type": "embers", "amount": EMPTY_POOL_EMBERS, "substitution_for": type})
				elif type == "card_choice": outcomes.append({"type": type, "cards": cards})
				else:
					next = engine.grant_magic_to_reserve(next, cards[0])
					outcomes.append({"type": type, "id": cards[0]})
			"reforge":
				var slot: String = str(effect["slot"])
				var old: String = str(next.get("equipped_equipment", {}).get(slot, ""))
				if old.is_empty(): continue
				var old_rarity: String = str(GameData.equipment_def(old).get("rarity", "common"))
				var rarity: String = stepped_rarity(old_rarity, int(effect["rarity_step"]))
				var pool: Array[String]
				var rarities: Dictionary = {}
				for id: String in GameData.equipment():
					var gear: Dictionary = GameData.equipment_def(id)
					if id != old and str(gear.get("slot", "")) == slot:
						pool.append(id)
						rarities[id] = str(gear.get("rarity", "common"))
				var id: String = _pick_with_rarity_fallback(rng, pool, rarities, [rarity, old_rarity])
				if id.is_empty():
					next = engine.add_held_embers(next, EMPTY_POOL_EMBERS)
					outcomes.append({"type": "embers", "amount": EMPTY_POOL_EMBERS, "substitution_for": type})
					continue
				next["equipped_equipment"][slot] = id
				(next.get("equipment_grafts", {}) as Dictionary).erase(old)
				(next.get("equipment_grafts", {}) as Dictionary).erase(id)
				(next.get("collected_equipment", []) as Array).erase(old)
				if not (next.get("collected_equipment", []) as Array).has(id): next["collected_equipment"].append(id)
				(next.get("equipment_inventory", []) as Array).erase(id)
				outcomes.append({"type": type, "slot": slot, "from": old, "to": id})
			"item":
				for _index: int in range(int(effect["count"])):
					var id: String = _pick(rng, GameData.item_card_ids())
					if id.is_empty(): continue
					# Scavenger acquisition: items enter the pack, without auto-equipping.
					next["item_inventory"].append(id)
					next = engine._mark_loadout_unread(next, "equipment", id)
					outcomes.append({"type": type, "id": id})
			"lose_item":
				var key: String = "item_inventory" if not _consumables(next.get("item_inventory", [])).is_empty() else "equipped_items"
				var id: String = _pick(rng, _consumables(next.get(key, [])))
				if not id.is_empty():
					next[key].erase(id)
					outcomes.append({"type": type, "id": id})
			"transform_magic":
				var slots: Array[int] = _attuned_slots(next)
				for _index: int in range(mini(int(effect["count"]), slots.size())):
					var slot: int = slots.pop_at(rng.randi_range(0, slots.size() - 1))
					var old: String = str(next["attuned_magic_cards"][slot])
					var old_rarity: String = GameData.card_rarity(old)
					var rarity: String = stepped_rarity(old_rarity, int(effect["rarity_step"]))
					var pool: Array[String]
					var rarities: Dictionary = {}
					for tier: String in GameData.CARD_RARITY_TIERS:
						for id: String in _magic_pool("", tier):
							if id != old:
								pool.append(id)
								rarities[id] = tier
					var id: String = _pick_with_rarity_fallback(rng, pool, rarities, [rarity, old_rarity])
					if id.is_empty():
						outcomes.append({"type": "nothing_changed", "slot": slot, "from": old})
						continue
					next["attuned_magic_cards"][slot] = id
					var reward_index: int = (next.get("reward_cards", []) as Array).find(old)
					if reward_index >= 0: next["reward_cards"][reward_index] = id
					else: next["reward_cards"].append(id)
					next = engine._mark_loadout_unread(next, "magic", id)
					outcomes.append({"type": type, "slot": slot, "from": old, "to": id})
			"omen":
				next = Omens.add(next, str(effect["id"]))
				for active: Dictionary in Omens.active(next):
					if str(active["id"]) == str(effect["id"]): outcomes.append({"type": type, "id": effect["id"], "fights": active["fights_left"]})
			"defiance":
				next["event_defiance_bonus"] = int(next.get("event_defiance_bonus", 0)) + value
				next["defiance_capacity"] = engine.defiance_capacity(next) + value
				next["defiance_remaining"] = int(next.get("defiance_remaining", 0)) + value
				outcomes.append({"type": type, "amount": value})
			"scout":
				var section: Dictionary = Graph.section(next, section_index(next))
				if not section.is_empty(): section["scouts"] = int(section.get("scouts", 0)) + value
				outcomes.append({"type": type, "amount": value})
			"reveal":
				var targets: Array[Vector2i] = reveal_targets(next, int(effect["hops"]))
				for coord: Vector2i in targets:
					var room: Dictionary = Graph.room(next, coord)
					room["revealed"] = true
					room["map_outline"] = true
					# Survey grants knowledge through the event transaction, without
					# consuming Scouts, converting mysteries or emitting Scout uses.
					if Graph.modern(next) and str(room.get("type", "")) == "mystery": room["scouted"] = true
				outcomes.append({"type": type, "hops": effect["hops"], "rooms": targets})
			"random":
				var random_outcomes: Array = effect["outcomes"]
				var weights: Array = []
				for outcome: Dictionary in random_outcomes: weights.append(float(outcome["weight"]))
				var picked: Dictionary = random_outcomes[_weighted_index(rng, weights)]
				var nested: Dictionary = apply_effects(next, picked.get("effects", []), rng, engine)
				next = nested["state"]
				outcomes.append_array(nested["outcomes"])
				result["result_text"] = nested.get("result_text", str(picked.get("result", "")))
	next = engine._rebuild_deck_cards(next)
	next["notice"] = str(state.get("notice", ""))
	result["state"] = next
	result["outcomes"] = outcomes
	return result

static func stepped_rarity(rarity: String, step: int) -> String:
	return GameData.CARD_RARITY_TIERS[clampi(GameData.CARD_RARITY_TIERS.find(rarity) + step, 0, GameData.CARD_RARITY_TIERS.size() - 1)]

static func _gear_or_relic(state: Dictionary, effect: Dictionary, rng: RandomNumberGenerator, engine: RefCounted) -> String:
	var type: String = str(effect["type"])
	var eligible: Array[String]
	var rarity_by_id: Dictionary = {}
	var ids: Array = GameData.relic_ids() if type == "relic" else GameData.equipment().keys()
	for id: String in ids:
		var definition: Dictionary = GameData.relic_def(id) if type == "relic" else GameData.equipment_def(id)
		if type == "relic":
			if bool(definition.get("exclusive_guardian", false)) or not str(definition.get("exclusive_boss", "")).is_empty() or (state.get("relics", []) as Array).has(id): continue
		else:
			if engine._run_has_equipment(state, id) or (effect.has("slot") and str(definition.get("slot", "")) != str(effect["slot"])): continue
		eligible.append(id)
		rarity_by_id[id] = str(definition.get("rarity", "common"))
	for index: int in range(GameData.CARD_RARITY_TIERS.find(str(effect["rarity"])), -1, -1):
		var pool: Array[String]
		for id: String in eligible:
			if str(rarity_by_id[id]) == GameData.CARD_RARITY_TIERS[index]: pool.append(id)
		if not pool.is_empty(): return _pick(rng, pool)
	return _pick(rng, eligible)

static func _pick_with_rarity_fallback(rng: RandomNumberGenerator, eligible: Array[String], rarities: Dictionary, preferred: Array) -> String:
	for rarity: String in preferred:
		var pool: Array[String]
		for id: String in eligible:
			if str(rarities[id]) == rarity: pool.append(id)
		if not pool.is_empty(): return _pick(rng, pool)
	return _pick(rng, eligible)

static func _resolved_element(state: Dictionary, element: String) -> String:
	if element == "section": element = section_element(state)
	return "" if element in ["any", "shadow"] else element

static func _magic_pool(element: String, rarity: String) -> Array[String]:
	var pool: Array[String]
	for id: String in GameData.reward_card_pool_by_rarity(element, true).get(rarity, []): pool.append(id)
	pool.sort()
	return pool

static func _cards(state: Dictionary, effect: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var choices: Array[String]
	var type: String = str(effect["type"])
	var count: int = 1 if type == "card" else int(effect["count"])
	var element: String = _resolved_element(state, str(effect.get("element", "any")))
	var pool_by_rarity: Dictionary = {}
	if type == "card":
		for index: int in range(GameData.CARD_RARITY_TIERS.find(str(effect["rarity"])), -1, -1):
			var rarity: String = GameData.CARD_RARITY_TIERS[index]
			var pool: Array[String] = _magic_pool(element, rarity)
			if not pool.is_empty():
				pool_by_rarity[rarity] = pool
				break
	# A single-card fallback may use any rarity. Choice offers retain their floor.
	if pool_by_rarity.is_empty():
		for rarity: String in GameData.CARD_RARITY_TIERS:
			if type == "card_choice" and GameData.CARD_RARITY_TIERS.find(rarity) < GameData.CARD_RARITY_TIERS.find(str(effect.get("min_rarity", "common"))): continue
			var pool: Array[String] = _magic_pool(element, rarity)
			if not pool.is_empty(): pool_by_rarity[rarity] = pool
	while choices.size() < count and not pool_by_rarity.is_empty():
		var rarities: Array = pool_by_rarity.keys()
		rarities.sort()
		var weights: Array = []
		for rarity: String in rarities: weights.append(GameData.rarity_offer_weight(rarity))
		var rarity: String = rarities[_weighted_index(rng, weights)]
		var pool: Array[String] = pool_by_rarity[rarity]
		var card_weights: Array = []
		for id: String in pool: card_weights.append(GameData.reward_offer_weight(id))
		var index: int = _weighted_index(rng, card_weights)
		choices.append(pool[index])
		pool.remove_at(index)
		if pool.is_empty(): pool_by_rarity.erase(rarity)
	return choices

static func _weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0
	for value: Variant in weights: total += float(value)
	var roll: float = rng.randf() * total
	for index: int in range(weights.size()):
		roll -= float(weights[index])
		if roll < 0: return index
	return maxi(0, weights.size() - 1)

static func _pick(rng: RandomNumberGenerator, values: Array) -> String:
	var pool: Array = values.duplicate()
	pool.sort()
	return "" if pool.is_empty() else str(pool[rng.randi_range(0, pool.size() - 1)])

static func _consumables(values: Array) -> Array[String]:
	var result: Array[String]
	for id: String in values:
		if GameData.card_is_item(id): result.append(id)
	return result

static func _attuned_slots(state: Dictionary) -> Array[int]:
	var result: Array[int]
	var cards: Array = state.get("attuned_magic_cards", [])
	for index: int in range(cards.size()):
		if not str(cards[index]).is_empty() and not GameData.card_is_item(str(cards[index])) and not GameData.card_def(str(cards[index])).is_empty(): result.append(index)
	return result

static func slot_name(slot: String) -> String:
	return "armour" if slot == "armor" else slot

static func choice_effect_lines(state: Dictionary, event_id: String, choice_id: String) -> Array[String]:
	return effect_lines(state, choice_def(event_id, choice_id).get("effects", []))

static func effect_lines(state: Dictionary, effects: Array) -> Array[String]:
	var lines: Array[String]
	for effect: Dictionary in effects:
		var value: int = int(effect.get("amount", 0))
		var type: String = str(effect["type"])
		var rarity: String = str(effect.get("rarity", "")).capitalize()
		var element: String = _resolved_element(state, str(effect.get("element", "any"))).capitalize()
		if not element.is_empty(): element += " "
		match type:
			"hp": lines.append("Lose %d @icon(health)." % -value if value < 0 else "Heal %d @icon(health)." % value)
			"heal": lines.append("Heal %d @icon(health)." % value)
			"heal_percent": lines.append("Heal %d%% of your max @icon(health)." % int(effect["percent"]))
			"max_hp": lines.append("%s%d max @icon(health)." % ["+" if value >= 0 else "−", absi(value)])
			"embers": lines.append("Gain %d Embers." % value if value >= 0 else "Pay %d Embers." % -value)
			"relic": lines.append("Gain a random %s relic." % rarity)
			"card": lines.append("Gain a random %s %sspell." % [rarity, element])
			"card_choice":
				var tail: String = ", %s or better." % str(effect["min_rarity"]).capitalize() if effect.has("min_rarity") else "."
				lines.append("Choose 1 of %d %sspells%s" % [int(effect["count"]), element, tail])
			"equipment":
				var noun: String = slot_name(str(effect["slot"])) if effect.has("slot") else "piece of gear"
				lines.append("Gain %s %s %s." % ["random" if noun == "boots" else "a random", rarity, noun])
			"reforge":
				var slot: String = str(effect["slot"])
				var gear: Dictionary = GameData.equipment_def(str(state.get("equipped_equipment", {}).get(slot, "")))
				lines.append("Reforge your %s into a random %s one." % [slot_name(slot), stepped_rarity(str(gear.get("rarity", "common")), int(effect["rarity_step"])).capitalize()])
			"item": lines.append("Gain a random item." if int(effect["count"]) == 1 else "Gain %d random items." % int(effect["count"]))
			"lose_item": lines.append("Lose a random item.")
			"transform_magic":
				var count: int = int(effect["count"])
				lines.append("Transform a random spell into a higher rarity." if int(effect["rarity_step"]) == 1 else "Transform a random spell." if count == 1 else "Transform %d random spells." % count)
			"omen":
				var omen: Dictionary = GameData.omen_def(str(effect["id"]))
				lines.append("%s: %s. %s (%d fights)" % [str(omen["kind"]).capitalize(), omen["name"], omen["description"], int(omen["fights"])])
			"defiance": lines.append("Gain 1 @icon(defiance) for this run.")
			"scout": lines.append("+%d Scout." % value)
			"reveal": lines.append(("Reveal what the unknown rooms up to %d rooms ahead hold." if Graph.full_visibility(state, section_index(state)) else "Reveal the routes up to %d rooms ahead.") % int(effect["hops"]))
			"random":
				for outcome: Dictionary in effect["outcomes"]:
					var nested: Array[String] = effect_lines(state, outcome.get("effects", []))
					lines.append("%d%%: %s" % [int(outcome["weight"]), "Nothing." if nested.is_empty() else " ".join(nested)])
	return lines

static func outcome_lines(state: Dictionary) -> Array[String]:
	var lines: Array[String]
	for outcome: Dictionary in state.get("event_state", {}).get("outcomes", []):
		var type: String = str(outcome["type"])
		var value: int = int(outcome.get("amount", 0))
		match type:
			"hp": lines.append("Lost %d @icon(health)." % -value if value <= 0 else "Healed %d @icon(health)." % value)
			"heal", "heal_percent": lines.append("Healed %d @icon(health)." % value)
			"max_hp": lines.append("%s%d max @icon(health)." % ["+" if value >= 0 else "−", absi(value)])
			"embers":
				if outcome.has("substitution_for"): lines.append("Gained %d Embers instead." % value)
				else: lines.append("Gained %d Embers." % value if value >= 0 else "Paid %d Embers." % -value)
			"relic": lines.append("Gained %s." % str(GameData.relic_def(str(outcome["id"]))["name"]))
			"equipment": lines.append("Gained %s." % str(GameData.equipment_def(str(outcome["id"]))["name"]))
			"card", "item": lines.append("Gained %s." % str(GameData.card_def(str(outcome["id"]))["name"]))
			"card_choice": lines.append("Next: choose 1 of %d spells." % (outcome.get("cards", []) as Array).size())
			"lose_item": lines.append("Lost %s." % str(GameData.card_def(str(outcome["id"]))["name"]))
			"reforge": lines.append("%s became %s." % [GameData.equipment_def(str(outcome["from"]))["name"], GameData.equipment_def(str(outcome["to"]))["name"]])
			"transform_magic": lines.append("%s became %s." % [GameData.card_def(str(outcome["from"]))["name"], GameData.card_def(str(outcome["to"]))["name"]])
			"omen":
				var omen: Dictionary = GameData.omen_def(str(outcome["id"]))
				lines.append("%s: %s (%d fights)." % [str(omen["kind"]).capitalize(), omen["name"], int(outcome["fights"])])
			"defiance": lines.append("Gained 1 @icon(defiance) for this run.")
			"scout": lines.append("+%d Scout." % value)
			"reveal":
				var count: int = (outcome.get("rooms", []) as Array).size()
				if Graph.full_visibility(state, section_index(state)):
					lines.append("Revealed 1 unknown room." if count == 1 else "Revealed %d unknown rooms." % count)
				else: lines.append("Revealed %d rooms." % count)
			"nothing_changed": lines.append("Nothing changed.")
	return lines
