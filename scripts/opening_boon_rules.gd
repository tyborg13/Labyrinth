extends RefCounted

## Rolled once at creation. No repair/load path rolls offers for older saves or
## a run in which the awakening happens later. Transactions validate every
## secondary choice before applying any cost or consuming the one run choice.
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Elements = preload("res://scripts/element_data.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const STATE_KEY: String = "opening_boon"
const EVENTS_KEY: String = "opening_boon_events"
const HEIRLOOM_END_KEY: String = "heirloom_end"
const DATA_PATH: String = "res://data/opening_boons.json"
const ELEMENT_TERMS: Dictionary = {
	"fire": "@kw(element_fire)", "ice": "@kw(element_ice)",
	"lightning": "@kw(element_lightning)", "air": "@kw(element_air)",
	"earth": "@kw(element_earth)"
}
static var _definitions: Dictionary = {}

static func definitions() -> Dictionary:
	if _definitions.is_empty(): _definitions = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	return _definitions

static func initialize(state: Dictionary) -> void:
	state[HEIRLOOM_END_KEY] = {"done": false}
	var profile: Dictionary = state.get("progression", {})
	if not Store.emaciated_services_unlocked(profile) or int(state.get("run_index", 0)) <= 1 or Tutorial.is_active(profile): return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"])
	var offers: Array[Dictionary]
	var columns: Array = definitions()["columns"]
	for index: int in range(columns.size()):
		var candidates: Array[Dictionary]
		if index == 0 and not Store.heirloom(profile).is_empty():
			candidates.append({"boon": "heirloom", "item": Store.heirloom(profile)})
		else:
			for id: String in columns[index]["boons"]:
				var rolled: Dictionary = roll(id, state, rng)
				if not rolled.is_empty(): candidates.append(rolled)
		if candidates.is_empty(): return
		var selected: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		selected["column"] = columns[index]["label"]
		offers.append(selected)
	state[STATE_KEY] = {"offers": offers, "resolved": false, "offered": false}

static func spell_pool(rarity: String, element: String = "") -> Array[String]:
	var result: Array[String]
	var gear_cards: Dictionary = {}
	for equipment: Dictionary in Data.equipment().values():
		for card: String in equipment.get("cards", []): gear_cards[card] = true
	for id: String in Data.cards():
		var card: Dictionary = Data.cards()[id]
		if not bool(card.get("reward_pool", true)) or bool(card.get("retired", false)) or bool(card.get("starter", false)) or gear_cards.has(id) or Data.card_is_item(id): continue
		if Data.card_rarity(id) != rarity or (not element.is_empty() and Data.card_element(id) != element): continue
		result.append(id)
	result.sort()
	return result

static func equipment_pool(state: Dictionary) -> Dictionary:
	var slots: Dictionary = {}
	var starters: Dictionary = Data.starting_equipped_equipment()
	for id: String in Data.equipment_ids():
		if str(Data.equipment_def(id).get("rarity", "common")) != str(definitions()["boons"]["armory"]["rarity"]) or bool(Data.equipment_def(id).get("starter", false)): continue
		var slot: String = Data.equipment_slot(id)
		if not starters.has(slot) or state.get("equipped_equipment", {}).get(slot, "") != starters[slot]: continue
		if not slots.has(slot): slots[slot] = []
		slots[slot].append(id)
	return slots

static func relic_pool(rarity: String, state: Dictionary) -> Array[String]:
	var result: Array[String]
	for id: String in Data.relic_ids():
		var relic: Dictionary = Data.relic_def(id)
		if str(relic.get("rarity", "common")) != rarity or bool(relic.get("exclusive_guardian", false)) or not str(relic.get("exclusive_boss", "")).is_empty() or (state.get("relics", []) as Array).has(id): continue
		result.append(id)
	result.sort()
	return result

static func _draw(pool: Array[String], count: int, rng: RandomNumberGenerator) -> Array[String]:
	var remaining: Array[String] = pool.duplicate()
	var result: Array[String]
	while result.size() < count and not remaining.is_empty():
		var index: int = rng.randi_range(0, remaining.size() - 1)
		result.append(remaining[index])
		remaining.remove_at(index)
	return result

static func roll(id: String, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var spec: Dictionary = definitions()["boons"][id]
	var result: Dictionary = {"boon": id}
	match id:
		"elemental_gift", "focus":
			var elements: Array[String]
			for element: String in Elements.all_elements():
				if spell_pool(str(spec["rarity"]), element).size() >= int(spec["count"]): elements.append(element)
			if elements.is_empty(): return {}
			result["element"] = elements[rng.randi_range(0, elements.size() - 1)]
			result["spells"] = _draw(spell_pool(str(spec["rarity"]), result["element"]), int(spec["count"]), rng)
		"blood_price":
			var pool: Array[String] = spell_pool(str(spec["rarity"]))
			if pool.size() < int(spec["count"]): return {}
			result["spells"] = _draw(pool, int(spec["count"]), rng)
		"armory":
			var slots: Dictionary = equipment_pool(state)
			var keys: Array = slots.keys()
			keys.sort()
			if keys.is_empty(): return {}
			result["slot"] = keys[rng.randi_range(0, keys.size() - 1)]
			var pool: Array = slots[result["slot"]]
			result["item"] = pool[rng.randi_range(0, pool.size() - 1)]
			result["starter"] = state.get("equipped_equipment", {}).get(result["slot"], "")
		"trinket", "pawned_light":
			var pool: Array[String] = relic_pool(str(spec["rarity"]), state)
			if pool.is_empty(): return {}
			result["relic"] = pool[rng.randi_range(0, pool.size() - 1)]
	return result

static func pending(state: Dictionary) -> bool:
	return not (state.get(STATE_KEY, {}) as Dictionary).is_empty() and not bool(state[STATE_KEY].get("resolved", false)) and not bool(state.get("guided_combat_scenario_eligible", false))

static func offer(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if not pending(next) or str(next.get("mode", "")) != "room": return next
	if not bool(next[STATE_KEY].get("offered", false)):
		next[STATE_KEY]["offered"] = true
		_event(next, "run_start_boon_offered", {"columns": definitions()["columns"].map(func(column: Dictionary) -> String: return str(column["label"])), "rolled_contents": next[STATE_KEY]["offers"].duplicate(true)})
	return next

static func starter_spells(state: Dictionary) -> Array[String]:
	var available: Array = (state.get("attuned_magic_cards", []) as Array).duplicate()
	var result: Array[String]
	for id: String in Data.starting_magic_cards():
		if available.has(id):
			result.append(id)
			available.erase(id)
	return result

static func choose(engine: RefCounted, state: Dictionary, id: String, choices: Array = []) -> Dictionary:
	if not pending(state) or not engine.can_speak_to_emaciated_man(state): return state.duplicate(true)
	var selected: Dictionary = {}
	for row: Dictionary in state[STATE_KEY]["offers"]:
		if str(row["boon"]) == id: selected = row
	if not id.is_empty() and selected.is_empty(): return state.duplicate(true)
	var spec: Dictionary = definitions()["boons"].get(id, {})
	if id in ["elemental_gift", "blood_price"]:
		if choices.size() != 1 or not (selected.get("spells", []) as Array).has(choices[0]): return state.duplicate(true)
	elif id == "purge":
		var remaining: Array[String] = starter_spells(state)
		if choices.size() != int(spec["count"]): return state.duplicate(true)
		for choice: String in choices:
			if not remaining.has(choice): return state.duplicate(true)
			remaining.erase(choice)
	elif not choices.is_empty(): return state.duplicate(true)
	var next: Dictionary = state.duplicate(true)
	match id:
		"elemental_gift", "blood_price":
			next = engine.grant_magic_to_deck(next, str(choices[0]))
			if id == "blood_price":
				next["player_max_hp"] = maxi(1, int(next["player_max_hp"]) + int(spec["max_hp"]))
				next["player_hp"] = mini(int(next["player_hp"]), int(next["player_max_hp"]))
		"armory", "heirloom":
			var item: String = str(selected["item"])
			if Data.equipment_def(item).is_empty(): return state.duplicate(true)
			var slot: String = Data.equipment_slot(item)
			var old: String = str(next["equipped_equipment"].get(slot, ""))
			if id == "armory" and (old != str(selected.get("starter", "")) or old != str(Data.starting_equipped_equipment().get(slot, ""))): return state.duplicate(true)
			next["equipped_equipment"][slot] = item
			next["equipment_inventory"].erase(old)
			next["collected_equipment"].erase(old)
			if not next["collected_equipment"].has(item): next["collected_equipment"].append(item)
			# Neither the outgoing starter nor any graft/upgrade instance returns.
			(next.get("equipment_grafts", {}) as Dictionary).erase(item)
			(next.get("equipment_grafts", {}) as Dictionary).erase(old)
			if id == "heirloom": next["progression"] = Store.take_heirloom(next["progression"], item)
		"purge", "focus":
			var removals: Array = choices if id == "purge" else starter_spells(next)
			for card: String in removals: next["attuned_magic_cards"].erase(card)
			if id == "focus":
				for card: String in selected["spells"]: next = engine.grant_magic_to_deck(next, card)
		"vitality":
			next["player_max_hp"] = int(next["player_max_hp"]) + int(spec["max_hp"])
			next["player_hp"] = mini(int(next["player_max_hp"]), int(next["player_hp"]) + int(spec["current_hp"]))
		"trinket", "pawned_light":
			next["pending_relics"] = [selected["relic"]]
			next = engine.claim_relic(next, str(selected["relic"]))
			if id == "pawned_light": next["player_hp"] = ceili(float(next["player_max_hp"]) * float(spec["hp_fraction"]))
		"debt":
			next = engine.set_held_embers(next, engine.held_embers(next) + int(spec["embers"]))
			next["boon_debt"] = {"pending": true}
	next["deck_cards"] = Data.compile_deck_cards(next["equipped_equipment"], next["attuned_magic_cards"], next.get("equipped_items", []), next)
	next[STATE_KEY]["resolved"] = true
	next[STATE_KEY]["chosen"] = id
	next[STATE_KEY]["choices"] = choices.duplicate()
	_event(next, "run_start_boon_chosen", {"boon": id, "content": selected.duplicate(true), "choices": choices.duplicate(), "declined": id.is_empty()})
	return next

static func enter_scavenger(state: Dictionary) -> void:
	var debt: Dictionary = state.get("boon_debt", {})
	if bool(debt.get("pending", false)):
		debt["pending"] = false
		debt["room"] = state.get("current_room", Vector2i.ZERO)
		state["boon_debt"] = debt

static func price(state: Dictionary, base: int) -> int:
	var debt: Dictionary = state.get("boon_debt", {})
	if debt.has("room") and debt["room"] == state.get("current_room", Vector2i.ZERO):
		return ceili(float(base) * float(definitions()["boons"]["debt"]["price_multiplier"]))
	return base

static func heirloom_prompt_pending(state: Dictionary) -> bool:
	return state.has(HEIRLOOM_END_KEY) and str(state.get("mode", "")) in ["victory", "defeat"] and not bool(state.get("debug_boss_run", false)) and not bool((state.get(HEIRLOOM_END_KEY, {}) as Dictionary).get("done", false))

static func leave_heirloom(state: Dictionary, item: String) -> Dictionary:
	if not heirloom_prompt_pending(state) or (state.get(HEIRLOOM_END_KEY, {}) as Dictionary).has("item"): return state.duplicate(true)
	if not item.is_empty() and not (state.get("equipped_equipment", {}) as Dictionary).values().has(item): return state.duplicate(true)
	var next: Dictionary = state.duplicate(true)
	next["progression"] = Store.leave_heirloom(next.get("progression", {}), item)
	next[HEIRLOOM_END_KEY] = {"item": item, "done": item.is_empty()}
	_event(next, "heirloom_left", {"item": item, "none": item.is_empty()})
	return next

static func _event(state: Dictionary, type: String, payload: Dictionary) -> void:
	if not state.has(EVENTS_KEY): state[EVENTS_KEY] = []
	state[EVENTS_KEY].append({"type": type, "payload": payload})

static func text(row: Dictionary) -> String:
	var value: String = str(definitions()["boons"][row["boon"]]["text"])
	value = value.replace("<Relic effect>", str(Data.relic_def(str(row.get("relic", ""))).get("description", "")))
	value = value.replace("<Element>", str(ELEMENT_TERMS.get(str(row.get("element", "")), "")))
	value = value.replace("<Item>", str(Data.equipment_def(str(row.get("item", ""))).get("name", "")))
	value = value.replace("<starter piece>", str(Data.equipment_def(str(row.get("starter", ""))).get("name", "")))
	return value.replace("<Relic>", str(Data.relic_def(str(row.get("relic", ""))).get("name", "")))
