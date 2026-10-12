extends RefCounted
const Events = preload("res://scripts/event_rules.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Store = preload("res://scripts/progression_store.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const EventPanel = preload("res://scripts/event_view.gd")
const TEST_SEED: int = 421
const SELECTION_SEEDS: int = 24
const EVENTS_PER_SECTION: int = 2

static func run(expect: Callable) -> void:
	var engine := Run.new()
	expect.call(Events.validate_data().is_empty(), "Authored event data validates: %s" % str(Events.validate_data()))
	expect.call(Data.events().size() == 27 and Data.omens().size() == 11, "All 27 events and 11 omens load")
	expect.call(Events.art_path("bloodletters_basin") == "res://assets/art/events/bloodletters_basin.png", "Art has one derived accessor and may be missing")
	_validation(expect)
	_selection(engine, expect)
	_requirements(engine, expect)
	_effects(engine, expect)
	_previews(engine, expect)
	_result_rows(engine, expect)
	_replacement_fallbacks(engine, expect)
	_omens(engine, expect)
	_persistence_and_rewards(engine, expect)
	_edges(engine, expect)
	_ui(engine, expect)

static func _event_state(engine: RefCounted, id: String = "lost_cartographer") -> Dictionary:
	var state: Dictionary = engine.create_new_run(TEST_SEED, Store.default_data())
	for room: Dictionary in state["rooms"].values():
		if str(room.get("type", "")) != "event": continue
		state["current_room"] = room["coord"]
		room["event_id"] = id
		state["mode"] = "event"
		return Events.enter_event(state)
	return {}

static func _apply(engine: RefCounted, state: Dictionary, effects: Array, purpose: String = "test") -> Dictionary:
	return Events.apply_effects(state, effects, Events.rng_for(state, purpose), engine)

static func _validation(expect: Callable) -> void:
	var event: Dictionary = Data.event_def("bloodletters_basin")
	var original: Dictionary = event.duplicate(true)
	event["pool"] = "unknown"
	event["min_section"] = -1
	event["max_section"] = 6
	event["weight"] = 0
	event["body"] = "word ".repeat(71)
	event["choices"][0]["label"] = "a".repeat(29)
	event["choices"][1]["id"] = event["choices"][0]["id"]
	event["choices"][0]["requires"].append({"type": "unknown"})
	event["choices"][0]["effects"].append({"type": "omen", "id": "unknown"})
	event["choices"][1]["effects"][0]["outcomes"][0]["weight"] = 49
	expect.call(Events.validate_data().size() >= 7, "Validator rejects bounds, pools, text, ids, requirements, omen references and random totals")
	event.clear()
	event.merge(original)
	var omen: Dictionary = Data.omen_def("dread")
	var original_omen: Dictionary = omen.duplicate(true)
	omen["fights"] = 0
	omen["kind"] = "unknown"
	omen["effect"]["type"] = "unknown"
	expect.call(Events.validate_data().size() == 2, "Validator rejects invalid omen metadata and effects")
	omen.clear()
	omen.merge(original_omen)
	var vision: Dictionary = Data.omen_def("lantern_sight")["effect"]
	var radius: int = int(vision["radius"])
	vision.erase("radius")
	expect.call(not Events.validate_data().is_empty(), "Vision omens must author their radius")
	vision["radius"] = radius
	expect.call(Events.validate_data().is_empty(), "Validation fixtures restore protected catalog in memory")

static func _selection(engine: RefCounted, expect: Callable) -> void:
	var coverage: Dictionary = {}
	for seed: int in range(1, SELECTION_SEEDS + 1):
		var state: Dictionary = engine.create_new_run(seed, Store.default_data())
		state["seen_events"] = []
		for index: int in range(6):
			for visit: int in range(EVENTS_PER_SECTION):
				var coord := Vector2i(index * 4 + 1, visit)
				state["rooms"][Graph.key(coord)] = {"coord": coord, "type": "event", "section_index": index}
				state["current_room"] = coord
				var id: String = Events.select_event(state)
				expect.call(id == Events.select_event(state), "Selection repeats exactly for the same seed and room")
				expect.call(not state["seen_events"].has(id), "A six-section run never repeats an unseen selection")
				var definition: Dictionary = Data.event_def(id)
				expect.call(str(definition["pool"]) in ["any", Events.section_element(state)] and index >= int(definition["min_section"]) and index <= int(definition["max_section"]), "Selection respects section bounds and boss element")
				coverage[id] = true
				var entered: Dictionary = Events.enter_event(state)
				expect.call(entered["seen_events"] == state["seen_events"], "Entry never marks an event seen")
				entered["seed"] = seed + 999
				expect.call(Events.enter_event(entered)["event_state"]["event_id"] == id, "Persisted event id survives entry and changed RNG inputs")
				state["seen_events"].append(id)
	expect.call(coverage.size() == 27, "At least 20 seeds exercise all 27 authored events across six sections")
	var state: Dictionary = _event_state(engine)
	var definitions: Dictionary = Data.events()
	var original: Dictionary = definitions.duplicate(true)
	var selected: String = Events.select_event(state)
	var ids: Array = definitions.keys()
	ids.reverse()
	definitions.clear()
	for id: String in ids: definitions[id] = original[id]
	expect.call(Events.select_event(state) == selected, "Dictionary insertion order cannot change selection")
	definitions.clear()
	definitions.merge(original)
	state["seen_events"] = []
	for id: String in definitions:
		if id != "lost_cartographer": state["seen_events"].append(id)
	state["current_room"] = Graph.section(state, 5)["boss"]
	expect.call(Events.select_event(state) == "lost_cartographer", "Any unseen fallback ignores section bounds")
	state["seen_events"].append("lost_cartographer")
	expect.call(Events.select_event(state) == "lost_cartographer", "Exhausted pools fall back to legacy Cartographer")

static func _requirements(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	var fixtures: Array = [
		[{"type": "hp_above", "amount": 5}, "player_hp", 5, 6, "Requires more than 5 Health."],
		[{"type": "max_hp_above", "amount": 8}, "player_max_hp", 8, 9, "Requires more than 8 max Health."],
		[{"type": "embers_at_least", "amount": 50}, "held_embers", 49, 50, "Requires 50 Embers."],
		[{"type": "has_item"}, "item_inventory", [], ["crimson_draught"], "Requires an item."],
		[{"type": "has_attuned_magic"}, "attuned_magic_cards", [], ["pale_spark"], "Requires an attuned spell."]
	]
	Data.events()["test_requirements"] = {"choices": [{"id": "choice", "requires": [], "effects": []}]}
	var choice: Dictionary = Data.event_def("test_requirements")["choices"][0]
	for fixture: Array in fixtures:
		choice["requires"] = [fixture[0]]
		state[fixture[1]] = fixture[2]
		expect.call(not Events.choice_available(state, "test_requirements", "choice") and Events.choice_block_reason(state, "test_requirements", "choice") == fixture[4], "Requirement blocks at its boundary with exact copy")
		state[fixture[1]] = fixture[3]
		expect.call(Events.choice_available(state, "test_requirements", "choice"), "Each requirement admits a valid choice")
	for slot: String in Data.EQUIPMENT_SLOTS:
		choice["requires"] = [{"type": "has_equipment", "slot": slot}]
		state["equipped_equipment"][slot] = ""
		expect.call(Events.choice_block_reason(state, "test_requirements", "choice") == "Requires an equipped %s." % Events.slot_name(slot), "Equipment requirements use the authored slot names")
		state["equipped_equipment"][slot] = Data.STARTING_EQUIPMENT_BY_SLOT[slot]
		expect.call(Events.choice_available(state, "test_requirements", "choice"), "Equipped pieces satisfy each slot requirement")
	choice["requires"] = [{"type": "has_item"}]
	state["item_inventory"] = []
	state["equipped_items"] = ["crimson_draught"]
	expect.call(Events.choice_available(state, "test_requirements", "choice"), "Equipped consumables satisfy has_item")
	Data.events().erase("test_requirements")
	state = _event_state(engine)
	for room: Dictionary in state["rooms"].values(): room["revealed"] = true
	expect.call(not Events.choice_available(state, "lost_cartographer", "survey") and Events.choice_block_reason(state, "lost_cartographer", "survey") == "Nothing new to reveal.", "An empty reveal-only choice stays listed but unavailable")
	expect.call(not Events.choice_available(state, "lost_cartographer", "unknown"), "Unknown choice ids are rejected")

static func _effects(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	var original: Dictionary = state.duplicate(true)
	var result: Dictionary = _apply(engine, state, [{"type": "hp", "amount": -999}, {"type": "heal", "amount": 2}, {"type": "heal_percent", "percent": 25}])
	expect.call(int(result["state"]["player_hp"]) == 9 and result["outcomes"][0] == {"type": "hp", "amount": -23}, "HP costs stop at one and ordered healing uses rounded max HP")
	expect.call(state == original, "Effects are atomic and leave input untouched")
	result = _apply(engine, state, [{"type": "max_hp", "amount": 3}, {"type": "max_hp", "amount": -5}])
	expect.call(result["state"]["player_max_hp"] == 22 and result["state"]["player_hp"] == 22, "Max HP raises current health then clamps on reductions")
	result = _apply(engine, state, [{"type": "max_hp", "amount": -999}, {"type": "heal", "amount": 999}])
	expect.call(result["state"]["player_max_hp"] == 1 and result["state"]["player_hp"] == 1, "Max HP has a one-health floor and healing cap")
	result = _apply(engine, state, [{"type": "embers", "amount": 60}, {"type": "embers", "amount": -25}])
	expect.call(result["state"]["held_embers"] == 35 and result["state"]["unbanked_embers"] == 35 and result["state"]["progression"] == state["progression"], "Embers preserve held/unbanked semantics without banking")
	for rarity: String in Data.CARD_RARITY_TIERS:
		result = _apply(engine, state, [{"type": "relic", "rarity": rarity}])
		var id: String = result["outcomes"][0].get("id", "")
		var definition: Dictionary = Data.relic_def(id)
		expect.call(not id.is_empty() and str(definition.get("rarity")) == rarity and not definition.get("exclusive_guardian", false) and str(definition.get("exclusive_boss", "")).is_empty(), "Relics are unowned offerable pieces of the requested rarity")
		var bonus: int = Data.stat_bonus_from_relics([id], "max_hp")
		expect.call(result["state"]["player_max_hp"] == state["player_max_hp"] + bonus and result["state"]["player_hp"] == state["player_hp"] + bonus, "Event relic max-HP bonuses use claim_relic")
		result = _apply(engine, state, [{"type": "equipment", "rarity": rarity, "slot": "weapon"}])
		id = result["outcomes"][0].get("id", "")
		expect.call(not id.is_empty() and str(Data.equipment_def(id).get("slot")) == "weapon" and result["state"]["equipment_inventory"].has(id) and engine.loadout_asset_is_new(result["state"], "equipment", id), "Gear enters the pack with NEW/unread acquisition")
	var exhausted: Dictionary = state.duplicate(true)
	exhausted["relics"] = Data.relic_ids()
	exhausted["equipment_inventory"] = Data.equipment().keys()
	for type: String in ["relic", "equipment"]:
		result = _apply(engine, exhausted, [{"type": type, "rarity": "legendary"}])
		expect.call(result["outcomes"] == [{"type": "embers", "amount": 40, "substitution_for": type}], "Empty %s pool records the 40-Ember substitution: %s" % [type, str(result["outcomes"])])
	for type: String in ["relic", "equipment"]:
		var fallback: Dictionary = state.duplicate(true)
		var ids: Array = Data.relics().keys() if type == "relic" else Data.equipment().keys()
		var owned: Array = []
		for id: String in ids:
			var definition: Dictionary = Data.relic_def(id) if type == "relic" else Data.equipment_def(id)
			if str(definition.get("rarity")) != "common": owned.append(id)
		fallback["relics" if type == "relic" else "equipment_inventory"] = owned
		result = _apply(engine, fallback, [{"type": type, "rarity": "legendary"}])
		var id: String = result["outcomes"][0].get("id", "")
		var definition: Dictionary = Data.relic_def(id) if type == "relic" else Data.equipment_def(id)
		expect.call(str(definition.get("rarity")) == "common", "Unavailable rarity falls through lower tiers")
	for element: String in ["any", "section", "fire", "ice", "earth", "air", "lightning"]:
		result = _apply(engine, state, [{"type": "card", "rarity": "rare", "element": element}])
		var id: String = result["outcomes"][0]["id"]
		expect.call(result["state"]["magic_inventory"].has(id) and engine.loadout_asset_is_new(result["state"], "magic", id) and Data.card_rarity(id) == "rare", "Magic grants enter the reserve marked NEW")
		expect.call(element == "any" or Data.card_element(id) == (Events.section_element(state) if element == "section" else element), "Magic rewards resolve element filters")
	result = _apply(engine, state, [{"type": "card_choice", "count": 3, "element": "fire", "min_rarity": "rare"}])
	var cards: Array = result["outcomes"][0]["cards"]
	expect.call(cards.size() == 3 and cards[0] != cards[1] and cards[1] != cards[2] and cards[0] != cards[2], "Event card offers contain three distinct cards")
	for id: String in cards: expect.call(Data.card_element(id) == "fire" and Data.CARD_RARITY_TIERS.find(Data.card_rarity(id)) >= 1, "Card-choice minimum rarity is enforced")
	var old_weapon: String = state["equipped_equipment"]["weapon"]
	state["equipment_grafts"] = {old_weapon: {"index": 0, "cards": ["quick_stab"]}}
	result = _apply(engine, state, [{"type": "reforge", "slot": "weapon", "rarity_step": 1}])
	var new_weapon: String = result["state"]["equipped_equipment"]["weapon"]
	expect.call(new_weapon != old_weapon and Data.equipment_def(new_weapon).get("rarity") == "rare" and not result["state"]["equipment_grafts"].has(old_weapon) and not result["state"]["equipment_inventory"].has(old_weapon), "Reforge destroys the old gear and graft and equips a higher-rarity replacement")
	expect.call(result["state"]["deck_cards"] == Data.compile_deck_cards(result["state"]["equipped_equipment"], result["state"]["attuned_magic_cards"], result["state"]["equipped_items"], result["state"]), "Reforge rebuilds the compiled deck")
	result = _apply(engine, state, [{"type": "item", "count": 3}, {"type": "lose_item"}])
	expect.call(result["state"]["item_inventory"].size() == 2 and result["outcomes"].size() == 4, "Items acquire through pack rules and lose_item removes one pack copy")
	state["equipped_items"] = ["crimson_draught"]
	result = _apply(engine, state, [{"type": "lose_item"}])
	expect.call(result["state"]["equipped_items"].is_empty(), "lose_item uses equipped items when the pack is empty")
	state["attuned_magic_cards"] = ["pale_spark", "pale_spark"]
	result = _apply(engine, state, [{"type": "transform_magic", "count": 3, "rarity_step": 1}])
	expect.call(result["outcomes"].size() == 2 and result["state"]["attuned_magic_cards"].size() == 2, "Transform preserves attuned slots and uses fewer when fewer exist")
	for outcome: Dictionary in result["outcomes"]:
		expect.call(outcome["from"] != outcome["to"] and Data.card_rarity(outcome["to"]) == "rare", "Transform records from-to and raises rarity")
	var progression_before: Dictionary = state["progression"].duplicate(true)
	result = _apply(engine, state, [{"type": "defiance", "amount": 1}, {"type": "scout", "amount": 2}, {"type": "omen", "id": "hunted"}, {"type": "reveal", "hops": 4}])
	var next: Dictionary = result["state"]
	expect.call(next["defiance_capacity"] == state["defiance_capacity"] + 1 and next["defiance_remaining"] == state["defiance_remaining"] + 1 and next["progression"] == progression_before, "Event Defiance belongs only to this run")
	expect.call(engine.repair_loaded_run_state(next)["defiance_capacity"] == next["defiance_capacity"], "Run Defiance survives load repair")
	expect.call(Graph.section(next, Events.section_index(next))["scouts"] == Graph.section(state, Events.section_index(state))["scouts"] + 2, "Scout only increases current-section uses")
	expect.call(Omens.active(next).size() == 1 and not result["outcomes"].back()["rooms"].is_empty(), "Omen and survey effects record concrete outcomes")
	var random_effect: Array = Events.choice_def("bloodletters_basin", "reach")["effects"]
	expect.call(_apply(engine, state, random_effect) == _apply(engine, state, random_effect), "Random outcomes are seeded and reproduce atomically")
	var seen_random: Dictionary = {}
	for seed: int in range(32):
		state["seed"] = seed
		var randomized: Dictionary = _apply(engine, state, random_effect)
		seen_random[randomized["outcomes"][0]["type"]] = true
	expect.call(seen_random.size() == 2, "Both random branches are reachable")
	expect.call(Events.stepped_rarity("legendary", 1) == "legendary", "Rarity upgrades cap at Legendary")

static func _previews(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	expect.call(Events.choice_effect_lines(state, "bloodletters_basin", "bleed") == _strings(["Lose 5 @icon(health).", "Gain a random Rare relic."]), "Basin bleed exact preview strings")
	expect.call(Events.choice_effect_lines(state, "bloodletters_basin", "reach") == _strings(["50%: Gain a random Common relic.", "50%: Lose 3 @icon(health)."]), "Basin reach exact random previews")
	expect.call(Events.choice_effect_lines(state, "ember_usurer", "borrow") == _strings(["Gain 100 Embers.", "Bane: Tithe of Ash. Enemies drop 50% fewer Embers. (3 fights)"]), "Usurer exact previews include authored omen values")
	expect.call(Events.choice_effect_lines(state, "abandoned_forge", "weapon") == _strings(["Reforge your weapon into a random Rare one.", "Lose 3 @icon(health)."]), "Forge exact preview resolves equipped rarity")
	expect.call(Events.choice_effect_lines(state, "mirror_of_skins", "trade") == _strings(["Transform 3 random spells."]), "Mirror exact plural preview")
	expect.call(Events.effect_lines(state, [{"type": "max_hp", "amount": -4}, {"type": "random", "outcomes": [{"weight": 100, "effects": []}]}]) == _strings(["−4 max @icon(health).", "100%: Nothing."]), "Preview uses U+2212 minus and empty-outcome copy")

static func _result_rows(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	state["event_state"]["outcomes"] = [
		{"type": "hp", "amount": -5}, {"type": "heal", "amount": 3}, {"type": "heal_percent", "amount": 6},
		{"type": "max_hp", "amount": 3}, {"type": "max_hp", "amount": -4},
		{"type": "embers", "amount": 30}, {"type": "embers", "amount": -25},
		{"type": "relic", "id": "iron_lung"}, {"type": "equipment", "id": "training_sword"},
		{"type": "card", "id": "guiding_flare"}, {"type": "card_choice", "cards": ["guiding_flare", "inferno_ritual", "cinder_bloom"]},
		{"type": "item", "id": "crimson_draught"}, {"type": "item", "id": "bone_ward_charm"}, {"type": "lose_item", "id": "crimson_draught"},
		{"type": "reforge", "from": "training_sword", "to": "duelist_rapier"},
		{"type": "transform_magic", "from": "guiding_flare", "to": "inferno_ritual"},
		{"type": "omen", "id": "ember_ward", "fights": 3}, {"type": "omen", "id": "hunted", "fights": 2},
		{"type": "defiance", "amount": 1}, {"type": "scout", "amount": 2},
		{"type": "reveal", "rooms": [Vector2i(1, 0), Vector2i(2, 0)]},
		{"type": "embers", "amount": 40, "substitution_for": "relic"}, {"type": "nothing_changed"}
	]
	var expected: Array[String] = _strings([
		"Lost 5 @icon(health).", "Healed 3 @icon(health).", "Healed 6 @icon(health).",
		"+3 max @icon(health).", "−4 max @icon(health).", "Gained 30 Embers.", "Paid 25 Embers.",
		"Gained %s." % Data.relic_def("iron_lung")["name"], "Gained %s." % Data.equipment_def("training_sword")["name"],
		"Gained %s." % Data.card_def("guiding_flare")["name"], "Next: choose 1 of 3 spells.",
		"Gained %s." % Data.card_def("crimson_draught")["name"], "Gained %s." % Data.card_def("bone_ward_charm")["name"],
		"Lost %s." % Data.card_def("crimson_draught")["name"],
		"%s became %s." % [Data.equipment_def("training_sword")["name"], Data.equipment_def("duelist_rapier")["name"]],
		"%s became %s." % [Data.card_def("guiding_flare")["name"], Data.card_def("inferno_ritual")["name"]],
		"Blessing: Ember Ward (3 fights).", "Bane: Hunted (2 fights).", "Gained 1 @icon(defiance) for this run.",
		"+2 Scout.", "Revealed 2 rooms.", "Gained 40 Embers instead.", "Nothing changed."
	])
	expect.call(Events.outcome_lines(state) == expected, "Every concrete outcome uses the exact director-authored past-tense result template")
	var healed: Dictionary = _apply(engine, state, [{"type": "hp", "amount": -1}, {"type": "heal_percent", "percent": 25}, {"type": "heal", "amount": 8}])
	healed["state"]["event_state"]["outcomes"] = healed["outcomes"]
	expect.call(Events.outcome_lines(healed["state"]) == _strings(["Lost 1 @icon(health).", "Healed 1 @icon(health).", "Healed 0 @icon(health)."]), "Healing result rows report the actual capped amount, including zero healing")
	var fixtures: Array = [
		["weapon", "Gain a random Common weapon."], ["offhand", "Gain a random Common offhand."],
		["armor", "Gain a random Common armour."], ["boots", "Gain random Common boots."],
		["trinket", "Gain a random Common trinket."]
	]
	for fixture: Array in fixtures:
		expect.call(Events.effect_lines(state, [{"type": "equipment", "rarity": "common", "slot": fixture[0]}]) == _strings([fixture[1]]), "Equipment preview respects the noun phrase for each slot")
	expect.call(Events.effect_lines(state, [{"type": "equipment", "rarity": "rare"}]) == _strings(["Gain a random Rare piece of gear."]), "Unslotted gear retains its approved preview")
	expect.call(Events.first_available_choice_id(_event_state(engine, "bloodletters_basin")) == "bleed", "Traversal selects the first authored choice when available")
	state = _event_state(engine, "bloodletters_basin")
	state["player_hp"] = 5
	expect.call(Events.first_available_choice_id(state) == "reach", "Traversal skips unavailable choices without changing their order")

static func _replacement_fallbacks(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	var original_gear: Dictionary = Data.equipment().duplicate(true)
	var old: String = str(state["equipped_equipment"]["weapon"])
	for fixture: Array in [["iron_cleaver", "common"], ["grave_greatsword", "epic"], ["", ""]]:
		var catalog: Dictionary = Data.equipment()
		catalog.clear()
		for id: String in original_gear:
			if str(original_gear[id].get("slot", "")) != "weapon" or id in [old, str(fixture[0])]: catalog[id] = original_gear[id]
		state["equipment_grafts"] = {old: {"index": 0, "cards": ["quick_stab"]}}
		var result: Dictionary = _apply(engine, state, [{"type": "reforge", "slot": "weapon", "rarity_step": 1}])
		if str(fixture[0]).is_empty():
			expect.call(result["state"]["equipped_equipment"] == state["equipped_equipment"] and result["state"]["equipment_grafts"] == state["equipment_grafts"], "An empty reforge pool preserves the old piece and its grafts")
			expect.call(result["outcomes"] == [{"type": "embers", "amount": 40, "substitution_for": "reforge"}] and result["state"]["held_embers"] == state["held_embers"] + 40, "Empty reforge grants and records the approved 40-Ember substitution")
		else:
			expect.call(result["state"]["equipped_equipment"]["weapon"] == fixture[0] and Data.equipment_def(str(fixture[0]))["rarity"] == fixture[1], "Reforge falls back to the old rarity, then any different same-slot piece")
		catalog.clear()
		catalog.merge(original_gear)
	var original_cards: Dictionary = Data.cards().duplicate(true)
	var magic_ids: Array[String]
	var pools: Dictionary = Data.reward_card_pool_by_rarity("", true)
	for rarity: String in Data.CARD_RARITY_TIERS:
		for id: String in pools[rarity]: magic_ids.append(id)
	var common: String = "guiding_flare"
	var alternate_common: String = "cinder_bloom"
	var epic: String = str(Data.reward_card_pool_by_rarity("fire", true)["epic"][0])
	state["attuned_magic_cards"] = [common]
	for fixture: Array in [[[common, alternate_common], alternate_common], [[common, epic], epic], [[common], ""]]:
		_retain_magic(original_cards, magic_ids, fixture[0])
		var result: Dictionary = _apply(engine, state, [{"type": "transform_magic", "count": 1, "rarity_step": 1}])
		if str(fixture[1]).is_empty():
			expect.call(result["state"]["attuned_magic_cards"] == state["attuned_magic_cards"] and result["outcomes"][0]["type"] == "nothing_changed", "An empty transform pool leaves its slot unchanged")
			result["state"]["event_state"]["outcomes"] = result["outcomes"]
			expect.call(Events.outcome_lines(result["state"]) == _strings(["Nothing changed."]), "Empty transform reports the exact no-change row")
		else:
			expect.call(result["state"]["attuned_magic_cards"][0] == fixture[1] and result["outcomes"][0]["from"] == common and result["outcomes"][0]["to"] == fixture[1], "Transform falls back to same rarity, then any different reward spell")
		Data.cards().clear()
		Data.cards().merge(original_cards)
	for fixture: Array in [[[common], "rare", common], [[epic], "common", epic], [[], "legendary", ""]]:
		_retain_magic(original_cards, magic_ids, fixture[0])
		var result: Dictionary = _apply(engine, state, [{"type": "card", "rarity": fixture[1], "element": "fire"}])
		if str(fixture[2]).is_empty():
			expect.call(result["outcomes"] == [{"type": "embers", "amount": 40, "substitution_for": "card"}] and result["state"]["held_embers"] == state["held_embers"] + 40, "An empty card pool grants the approved 40-Ember substitution")
		else:
			expect.call(result["outcomes"][0]["id"] == fixture[2] and result["state"]["magic_inventory"].has(fixture[2]), "Card grants fall back to lower rarity, then any available rarity")
		Data.cards().clear()
		Data.cards().merge(original_cards)
	expect.call(Data.equipment() == original_gear and Data.cards() == original_cards, "Fallback tests restore all catalogs without editing protected data")

static func _retain_magic(original: Dictionary, magic_ids: Array[String], retained: Array) -> void:
	var catalog: Dictionary = Data.cards()
	catalog.clear()
	for id: String in original:
		if not magic_ids.has(id) or retained.has(id): catalog[id] = original[id]

static func _omens(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	state = Omens.add(state, "hunted")
	state = Omens.tick(state)
	state = Omens.add(state, "hunted")
	expect.call(state["omens"].size() == 1 and state["omens"][0]["fights_left"] == 2, "Omen refresh extends duration without stacking")
	state["omens"][0]["fights_left"] = 4
	expect.call(Omens.add(state, "hunted")["omens"][0]["fights_left"] == 4, "Refresh never shortens a longer active omen")
	state = Omens.tick(Omens.tick(Omens.add(_event_state(engine), "hunted")))
	expect.call(Omens.active(state).is_empty() and state["map_events"].back()["type"] == "omen_expired", "Finished fights tick and emit expiration through the outbox")
	var combat := Combat.new()
	var generator := Rooms.new()
	var room: Dictionary = {"coord": Vector2i(1, 2), "type": "combat", "depth": 1, "element": "fire", "connections": []}
	var layout: Dictionary = generator.generate_room(TEST_SEED, room, Vector2i.ZERO)
	var base: Dictionary = combat.create_combat(TEST_SEED, layout, engine._player_snapshot(_event_state(engine)))
	var empty_snapshot: Dictionary = engine._player_snapshot(_event_state(engine))
	empty_snapshot.erase("omens")
	expect.call(base == combat.create_combat(TEST_SEED, layout, empty_snapshot), "No-omen combat state is byte-identical to an absent omen field")
	for id: String in Data.omens():
		state = Omens.add(_event_state(engine), id)
		var created: Dictionary = combat.create_combat(TEST_SEED, layout, engine._player_snapshot(state))
		var effect: Dictionary = Data.omen_def(id)["effect"]
		var amount: int = int(effect.get("amount", 0))
		match str(effect["type"]):
			"start_block": expect.call(created["player"]["block"] == base["player"]["block"] + amount, "Ward starts with authored Block")
			"start_stoneskin": expect.call(created["player"]["stoneskin"] == base["player"]["stoneskin"] + amount, "Vow starts with authored Stoneskin")
			"start_expose":
				expect.call(created["player"]["expose"] == amount, "Dread starts with Expose")
				var hit: Dictionary = combat._damage_player(created.duplicate(true), 2, false)
				expect.call(hit["player"]["hp"] == created["player"]["hp"] - 2 - amount and hit["player"]["expose"] == 0, "Player Expose increases exactly the next hit")
			"start_vision_turns":
				expect.call(created["umbra"]["vision_bonus_activations"] == amount and created["umbra"]["vision_bonus"] == int(effect["radius"]), "Lantern Sight applies the authored Vision radius and duration")
				var visible: Dictionary = created.duplicate(true)
				visible["umbra"]["stage"] = "heart"
				var without_vision: Dictionary = visible.duplicate(true)
				without_vision["umbra"]["vision_bonus"] = 0
				expect.call(combat.effective_umbra_radius(visible) == combat.effective_umbra_radius(without_vision) + int(effect["radius"]), "Lantern Sight expands the actual Umbra visibility radius")
			"first_turn_card_plays":
				expect.call(combat.cards_remaining_this_turn(created) == combat.cards_remaining_this_turn(base) + amount and combat.pending_wait_time(created) == combat.pending_wait_time(base), "Omen bonus plays never increase Wait")
				var next_turn: Dictionary = combat.prepare_next_player_turn(created)
				expect.call(combat.cards_remaining_this_turn(next_turn) == int(base["cards_per_turn"]), "Bonus plays end after the first activation")
			"first_turn_movement":
				expect.call(combat.player_movement_remaining(created) == maxi(0, combat.player_movement_remaining(base) + amount), "Leaden Limbs changes only first-activation movement")
				expect.call(combat.player_movement_capacity(combat.prepare_next_player_turn(created)) == combat.player_movement_capacity(base), "Movement capacity returns on second activation")
			"start_on_fire": expect.call(Surfaces.element_at(created, created["player"]["pos"]) == "fire", "Kindled places Fire on the starting tile")
			"umbra_stage_delta": expect.call(combat.umbra_stage_index(created["umbra"]["stage"]) == combat.umbra_stage_index(base["umbra"]["stage"]) + amount, "Dark omen shifts starting Umbra by its authored stage delta")
			"ember_drop_percent":
				expect.call(Omens.ember_drop(created, 5) == int(floor(5.0 * amount / 100.0 + 0.5)), "Ember modifiers round half up")
				var dead: Dictionary = created["enemies"][0].duplicate(true)
				var enemy_value: int = int(Data.enemy_def(dead["type"]).get("reward_embers", 0))
				var damaged: Dictionary = combat._damage_enemy(created.duplicate(true), 0, 9999, true)
				expect.call(damaged["room_embers"] == Omens.ember_drop(created, enemy_value), "Enemy deaths use omen-adjusted Ember rewards")
			"extra_enemies":
				var hunted_room: Dictionary = room.duplicate(true)
				hunted_room["omen_extra_enemies"] = amount
				var hunted_layout: Dictionary = generator.generate_room(TEST_SEED, hunted_room, Vector2i.ZERO)
				expect.call(hunted_layout["enemies"].size() == layout["enemies"].size() + 1, "Hunted adds exactly one standard-room enemy")
				var hunted_combat: Dictionary = combat.create_combat(TEST_SEED, hunted_layout, engine._player_snapshot(state))
				expect.call(hunted_combat["enemies"].size() == base["enemies"].size() + 1, "The dossier and created combat contain Hunted's extra enemy")
				var last: Dictionary = hunted_layout["enemies"].back()
				expect.call(last["pos"] != hunted_layout["player_start"] and not (layout["enemies"] as Array).any(func(entry: Dictionary) -> bool: return entry["pos"] == last["pos"]), "Extra enemy occupies a legal free tile")
	for type: String in ["guardian", "boss"]:
		var special: Dictionary = room.duplicate(true)
		special["type"] = type
		special["boss_id"] = "vyraketh"
		var normal: Dictionary = generator.generate_room(TEST_SEED, special, Vector2i.ZERO)
		special["omen_extra_enemies"] = 1
		expect.call(generator.generate_room(TEST_SEED, special, Vector2i.ZERO) == normal, "Hunted does not alter Guardian or boss layouts")
	state = Omens.add(Omens.add(_event_state(engine), "ember_tithe"), "tithe_of_ash")
	expect.call(Omens.ember_drop(state, 10) == 8, "Multiple Ember omens multiply before half-up rounding")
	layout["umbra_stage"] = "heart"
	var capped: Dictionary = combat.create_combat(TEST_SEED, layout, engine._player_snapshot(Omens.add(_event_state(engine), "deepening_dark")))
	expect.call(capped["umbra"]["stage"] == "heart", "Omen darkness never advances to boss-only Eclipse")
	state = Omens.add(_event_state(engine), "hunted")
	state["current_room"] = room["coord"]
	state["rooms"][Graph.key(room["coord"])] = room.duplicate(true)
	state["mode"] = "combat"
	var finished: Dictionary = base.duplicate(true)
	for enemy: Dictionary in finished["enemies"]: enemy["hp"] = 0
	var after: Dictionary = engine.finish_combat(state, finished)
	expect.call(after["omens"][0]["fights_left"] == 1, "Run completion ticks omens on victory")
	expect.call(engine.finish_combat(after, finished)["omens"][0]["fights_left"] == 1, "Repeated finish cannot tick an omen twice")
	finished = base.duplicate(true)
	finished["objective"] = {"type": Objectives.REACH_EXIT, "exits": [{"target_tile": finished["player"]["pos"]}]}
	after = engine.finish_combat(state, finished)
	expect.call(after["omens"][0]["fights_left"] == 1, "Reach Exit completion ticks omens")
	finished["player"]["hp"] = 0
	after = engine.finish_combat(state, finished)
	expect.call(after["omens"][0]["fights_left"] == 1, "A defeated combat also ends its omen duration")

static func _persistence_and_rewards(engine: RefCounted, expect: Callable) -> void:
	Store.set_run_storage_path("user://event_rules_test.save")
	var state: Dictionary = _event_state(engine, "bloodletters_basin")
	expect.call(Store.save_run_state(state), "Choice page saves in production format")
	var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(loaded["event_state"] == state["event_state"] and Events.current_id(loaded) == "bloodletters_basin", "Choices page and persisted event id resume")
	var chosen: Dictionary = engine.resolve_map_event(loaded, "bleed")
	expect.call(chosen["mode"] == "event" and chosen["event_state"]["page"] == "result" and chosen["seen_events"].has("bloodletters_basin"), "Choosing commits a result and marks the event seen")
	expect.call(engine.resolve_map_event(chosen, "bleed") == chosen, "Choice effects cannot be applied twice")
	var receipt: Dictionary = chosen["map_events"].back()["payload"]
	expect.call(receipt["event_id"] == "bloodletters_basin" and receipt["choice_id"] == "bleed" and receipt["outcomes"] == chosen["event_state"]["outcomes"], "Analytics carries event, choice and concrete outcomes")
	expect.call(Store.save_run_state(chosen), "Result page saves")
	loaded = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(loaded["event_state"] == chosen["event_state"] and loaded["relics"] == chosen["relics"] and loaded["player_hp"] == chosen["player_hp"], "Result save resumes without replaying costs or grants")
	var continued: Dictionary = engine.resolve_map_event(loaded, "continue")
	expect.call(continued["mode"] == "room" and not continued.has("event_state") and Graph.room(continued, continued["current_room"])["cleared"], "Continue clears the room and releases the map flow")
	state = _event_state(engine)
	state.erase("event_state")
	Graph.room(state, state["current_room"]).erase("event_id")
	expect.call(Events.current_id(engine.repair_loaded_run_state(state)) == "lost_cartographer", "Legacy mid-event saves resume Cartographer")
	for choice_id: String in ["embers", "survey"]:
		expect.call(engine.resolve_map_event(state, choice_id)["event_state"]["choice_id"] == choice_id, "Legacy Cartographer choice ids remain accepted")
	for action: String in ["claim", "skip"]:
		state = engine.resolve_map_event(_event_state(engine, "moth_library"), "search")
		continued = engine.resolve_map_event(state, "continue")
		expect.call(continued["mode"] == "reward" and continued["pending_reward"]["kind"] == "event" and continued["pending_reward"]["skip_label"] == "Skip" and continued["pending_reward"]["heal_amount"] == 0, "Card choice follows result through the existing reward state")
		var card: String = continued["pending_reward"]["cards"][0]
		expect.call(Store.save_run_state(continued) and Store.load_saved_run()["pending_reward"] == continued["pending_reward"], "Event card chooser saves its exact cards")
		if action == "claim":
			var claimed: Dictionary = engine.claim_card_reward(continued, card)
			expect.call(claimed["mode"] == "room" and claimed["magic_inventory"].has(card) and engine.loadout_asset_is_new(claimed, "magic", card), "Claim goes to reserve then room")
			expect.call(engine.claim_card_reward(continued, "unknown") == continued, "Event reward claims must belong to the offer")
		else:
			var skipped: Dictionary = engine.skip_reward_for_heal(continued, card)
			expect.call(skipped["mode"] == "room" and skipped["player_hp"] == continued["player_hp"] and skipped["magic_inventory"] == continued["magic_inventory"], "Event skip grants no card or healing")
	Store.clear_saved_run()

static func _edges(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _event_state(engine)
	for type: String in ["relic", "equipment"]:
		var owned: Array = []
		var ids: Array = Data.relic_ids() if type == "relic" else Data.equipment().keys()
		for id: String in ids:
			var definition: Dictionary = Data.relic_def(id) if type == "relic" else Data.equipment_def(id)
			if str(definition.get("rarity")) != "legendary": owned.append(id)
		var exhausted: Dictionary = state.duplicate(true)
		exhausted["relics" if type == "relic" else "equipment_inventory"] = owned
		var result: Dictionary = _apply(engine, exhausted, [{"type": type, "rarity": "rare"}])
		var id: String = result["outcomes"][0]["id"]
		var definition: Dictionary = Data.relic_def(id) if type == "relic" else Data.equipment_def(id)
		expect.call(str(definition.get("rarity")) == "legendary", "Rarity fallback reaches any offerable when all lower tiers are owned")
	var converted: Dictionary = _apply(engine, state, [{"type": "transform_magic", "count": 1, "rarity_step": 0}])
	expect.call(converted["outcomes"].size() == 1 and Data.card_rarity(converted["outcomes"][0]["from"]) == Data.card_rarity(converted["outcomes"][0]["to"]), "Step-zero transformation preserves rarity while changing a spell")
	var combat := Combat.new()
	var room: Dictionary = {}
	for node: Dictionary in state["rooms"].values():
		if str(node.get("type")) == "combat":
			room = node
			break
	state["current_room"] = room["coord"]
	state["mode"] = "pre_battle"
	var ordinary: Dictionary = engine.prepare_pre_battle_combat(state)
	var hunted: Dictionary = engine.prepare_pre_battle_combat(Omens.add(state, "hunted"))
	expect.call(hunted["layout"]["enemies"].size() == ordinary["layout"]["enemies"].size() + 1 and hunted["combat_state"]["enemies"].size() == ordinary["combat_state"]["enemies"].size() + 1, "RunEngine prepares Hunted's extra enemy for the dossier and actual encounter")
	var raw: Dictionary = hunted["combat_state"].duplicate(true)
	var no_fire: Dictionary = raw.duplicate(true)
	no_fire["player"]["pos"] = Vector2i(-1, -1)
	Omens.start_combat(combat, no_fire, Omens.add(state, "kindled"))
	expect.call(Surfaces.element_at(no_fire, Vector2i(-1, -1)).is_empty(), "Kindled ignores tiles which cannot hold Fire")
	var snapshot: Dictionary = engine._player_snapshot(state)
	Data.omens()["test_plays_floor"] = {"name": "fixture", "kind": "bane", "fights": 1, "description": "fixture", "effect": {"type": "first_turn_card_plays", "amount": -99}}
	Data.omens()["test_move_floor"] = {"name": "fixture", "kind": "bane", "fights": 1, "description": "fixture", "effect": {"type": "first_turn_movement", "amount": -99}}
	snapshot = Omens.add(Omens.add(snapshot, "test_plays_floor"), "test_move_floor")
	var restricted: Dictionary = combat.create_combat(TEST_SEED, ordinary["layout"], snapshot)
	expect.call(combat.cards_remaining_this_turn(restricted) == 1 and combat.player_movement_remaining(restricted) == 0, "First-activation omen modifiers respect play and movement floors")
	Data.omens().erase("test_plays_floor")
	Data.omens().erase("test_move_floor")
	for kind: String in ["guardian", "boss"]:
		var special: Dictionary = state.duplicate(true)
		Graph.room(special, special["current_room"])["type"] = kind
		Graph.room(special, special["current_room"])["boss_id"] = "vyraketh"
		special = Omens.add(special, "hunted")
		special["mode"] = "combat"
		var won: Dictionary = ordinary["combat_state"].duplicate(true)
		won["room_type"] = kind
		won["objective"] = {"type": Objectives.KILL_ALL}
		for enemy: Dictionary in won["enemies"]: enemy["hp"] = 0
		expect.call(engine.finish_combat(special, won)["omens"][0]["fights_left"] == 1, "Guardian and boss finishes tick omens through the same boundary")
	# Reuse the existing valid Last Door profile fixture, retaining its skill path.
	var skills = preload("res://tests/suites/skill_run_suite.gd")
	var retreat: Dictionary = skills._new_run(engine, ["last_door"])
	retreat = skills._set_current_room(retreat, Vector2i(1, 0), "combat")
	retreat["mode"] = "combat"
	retreat["skill_state"]["previous_room"] = Vector2i.ZERO
	retreat = Omens.add(retreat, "hunted")
	var after: Dictionary = engine.finish_combat(retreat, skills._combat_result(Vector2i(1, 0), "combat", false))
	expect.call(after["mode"] == "room" and after["current_room"] == Vector2i.ZERO and after["omens"][0]["fights_left"] == 1, "Last Door retreat finishes one fight and ticks the active omen")
	var legacy: Dictionary = engine.create_new_run(TEST_SEED, Store.default_data(), false)
	legacy["rooms"][Graph.key(Vector2i.ZERO)]["type"] = "event"
	legacy["rooms"][Graph.key(Vector2i.ZERO)]["cleared"] = false
	legacy["mode"] = "event"
	var repaired: Dictionary = engine.repair_loaded_run_state(legacy)
	expect.call(not Graph.enabled(repaired) and Events.current_id(repaired) == "lost_cartographer", "Circular-map legacy event saves retain their map and resume Cartographer")

static func _ui(engine: RefCounted, expect: Callable) -> void:
	var view := EventPanel.new()
	Engine.get_main_loop().root.add_child(view)
	var state: Dictionary = _event_state(engine, "bloodletters_basin")
	state["player_hp"] = 5
	view.present(state, true)
	expect.call(view.choices.size() == 3 and not view.choices[0].available and view.choices[0].tooltip_text == "Requires more than 5 Health.", "Illustrated event UI keeps unavailable choices with exact reasons")
	view.present(engine.resolve_map_event(state, "leave"), true)
	expect.call(view.choices.is_empty() and view.continue_button != null and view.continue_button.text == "Continue", "Illustrated event result page exposes Continue")
	view.free()

static func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values: result.append(str(value))
	return result
