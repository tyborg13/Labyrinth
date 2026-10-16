extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Profile = preload("res://scripts/progression_store.gd")
const List = preload("res://scripts/magic_deck_list.gd")
const EventRules = preload("res://scripts/event_rules.gd")
const TEST_SEED: int = 1016
const TEST_WALLET: int = 1000
const TEST_SHOP_COORD := Vector2i(2, 1)

static func shop_fixture(engine: RefCounted) -> Dictionary:
	var state: Dictionary = engine.create_new_run(TEST_SEED, Profile.default_data())
	state["current_room"] = TEST_SHOP_COORD
	state["rooms"]["2,1"] = {"coord": TEST_SHOP_COORD, "type": "scavenger", "depth": 2, "visited": true, "revealed": true, "cleared": true, "sealed": false}
	return engine.set_held_embers(state, TEST_WALLET)

static func run(expect: Callable) -> void:
	var engine := Run.new()
	unowned_purge_checks(engine, expect)
	_retired_paths(expect)
	var initial: Dictionary = engine.create_new_run(TEST_SEED, Profile.default_data())
	expect.call(initial["deck_cards"].size() == 16 and initial["attuned_magic_cards"] == Data.starting_magic_cards(), "Starting deck is still 16 cards with the six authored starter spells")
	var rewarded: Dictionary = engine.claim_card_reward(initial, "spark_dart")
	expect.call(rewarded["deck_cards"].has("spark_dart") and rewarded["deck_cards"].size() == 17 and rewarded["magic_inventory"].is_empty(), "Reward enters deck immediately without a reserve")
	expect.call(rewarded["notice"] == "Added Spark Dart to your deck.", "Reward notice uses director wording")
	var legacy: Dictionary = initial.duplicate(true)
	legacy.erase(Run.MAGIC_DECK_SAVE_VERSION_KEY)
	legacy["magic_inventory"] = ["spark_dart", "spark_dart", "frostbolt"]
	legacy["reward_cards"] = ["spark_dart", "spark_dart", "frostbolt"]
	var migrated: Dictionary = engine.repair_loaded_run_state(legacy)
	expect.call(migrated["attuned_magic_cards"].size() == 9 and migrated["attuned_magic_cards"].count("spark_dart") == 2 and migrated["magic_inventory"].is_empty(), "Migration transfers every reserve copy, including duplicates")
	expect.call(migrated[Run.MAGIC_DECK_SAVE_VERSION_KEY] == 1 and migrated["magic_deck_migration"]["reserve_copies_moved"] == 3, "Save logs magic ownership migration version and moved copies")
	var again: Dictionary = engine.repair_loaded_run_state(migrated)
	expect.call(again["attuned_magic_cards"] == migrated["attuned_magic_cards"] and again["magic_deck_migration"] == migrated["magic_deck_migration"], "Repeated loads never duplicate migrated spells or overwrite migration receipt")
	var state: Dictionary = shop_fixture(engine)
	state = engine.grant_magic_to_deck(state, "spark_dart")
	state = engine.grant_magic_to_reserve(state, "frostbolt")
	expect.call(state["deck_cards"].has("frostbolt"), "Legacy event grant entry point routes directly to deck")
	var offers: Array = engine.merchant_offer_ids(state, "scavenger")
	for offer: Variant in offers:
		if engine.merchant_item_kind(str(offer)) != "magic": continue
		var bought: Dictionary = engine.buy_merchant_item(state, "scavenger", str(offer))
		expect.call(bought["deck_cards"].has(offer) and bought["magic_inventory"].is_empty(), "Scavenger magic purchase goes directly into deck")
		break
	var purged: Dictionary = engine.purge_magic_card(state, "pale_spark", "scavenger")
	expect.call(purged["attuned_magic_cards"].count("pale_spark") == 1 and purged["deck_cards"].size() == state["deck_cards"].size() - 1, "Purge removes exactly one owned magic copy")
	expect.call(purged["notice"] == "Purged Pale Spark.", "Confirmed purge uses the approved notice")
	expect.call(engine.held_embers(purged) == TEST_WALLET - 50 and engine.scavenger_purge_price(purged) == 75 and purged["last_magic_purge"]["source"] == "scavenger", "First Scavenger purge costs 50 and next costs 75")
	purged = engine.purge_magic_card(purged, "pale_spark", "scavenger")
	expect.call(engine.held_embers(purged) == TEST_WALLET - 125 and engine.scavenger_purge_price(purged) == 100, "Second Scavenger purge costs 75 and next costs 100")
	var poor: Dictionary = engine.set_held_embers(state, 49)
	expect.call(engine.purge_magic_card(poor, "pale_spark", "scavenger") == poor, "Insufficient Embers cannot remove a spell or advance price")
	for id: String in ["quick_stab", "crimson_draught", "missing_card"]:
		var corrupt: Dictionary = state.duplicate(true)
		corrupt["attuned_magic_cards"].append(id)
		expect.call(engine.purge_magic_card(corrupt, id, "scavenger") == corrupt, "Gear, items, and unknown cards are never purgeable: " + id)
	var fire: Dictionary = state.duplicate(true)
	fire["mode"] = "campfire"
	fire["player_hp"] = 1
	var free: Dictionary = engine.purge_magic_card(fire, "spark_dart", "campfire")
	expect.call(free["mode"] == "room" and free["player_hp"] == 1 and engine.held_embers(free) == TEST_WALLET and free["last_magic_purge"]["price"] == 0, "Campfire Purge is free, grants no rest healing, and spends the Campfire choice")
	expect.call(engine.scavenger_purge_price(free) == 50, "Free Campfire purge never raises the first Scavenger price")
	var later_fire: Dictionary = purged.duplicate(true)
	later_fire["mode"] = "campfire"
	var later_free: Dictionary = engine.purge_magic_card(later_fire, "spark_dart", "campfire")
	expect.call(engine.scavenger_purge_price(later_free) == 100 and int(later_free.get("priced_magic_purges", 0)) == 2, "Campfire preserves the paid-only price progression after multiple Scavenger purges")
	expect.call(engine.purge_magic_card(free, "frostbolt", "campfire") == free, "Campfire cannot purge twice after consuming its choice")
	for mode: String in ["combat", "reward", "pre_battle"]:
		var locked: Dictionary = state.duplicate(true)
		locked["mode"] = mode
		expect.call(engine.purge_magic_card(locked, "spark_dart", "scavenger") == locked, "Scavenger purge is unavailable during " + mode)
	var none: Dictionary = state.duplicate(true)
	none["attuned_magic_cards"] = []
	none = engine.repair_loaded_run_state(none)
	expect.call(none["attuned_magic_cards"].is_empty() and none["deck_cards"].size() == 10, "Repair never fills purged magic back to six")
	var large: Dictionary = initial.duplicate(true)
	for _index: int in range(8): large = engine.grant_magic_to_deck(large, "spark_dart")
	large = engine._repair_equipment_state(large)
	expect.call(large["attuned_magic_cards"].size() == 14 and large["deck_cards"].size() == 24, "Compiled deck contains all 14 owned magic copies with no cap")
	var combat: Dictionary = engine.get("_combat_engine").create_combat(TEST_SEED, initial["current_room_layout"], engine._player_snapshot(large))
	var combat_cards: Array = []
	for pile: String in ["draw", "hand", "discard", "burned"]: combat_cards.append_array(combat["deck"].get(pile, []))
	var expected_cards: Array = large["deck_cards"].duplicate()
	combat_cards.sort()
	expected_cards.sort()
	expect.call(combat_cards == expected_cards and combat_cards.count("spark_dart") == 8, "Real combat piles contain every owned magic copy")
	var unsorted: Array = ["frostbolt", "spark_dart", "pale_spark", "dull_bolt", "pale_spark"]
	var sorted_entries: Array[Dictionary] = List.entries(unsorted)
	var sorted_keys: Array[String]
	for entry: Dictionary in sorted_entries:
		var id: String = str(entry["card_id"])
		sorted_keys.append("%s/%s/%s" % [Data.card_element(id), str(Data.card_def(id).get("name", id)), id])
	var expected_keys: Array[String] = sorted_keys.duplicate()
	expected_keys.sort()
	expect.call(sorted_keys == expected_keys, "Magic list sorts by element then name")
	var grouped: Array[Dictionary] = List.entries(large["attuned_magic_cards"])
	expect.call(grouped.size() == 4, "Magic list groups all copies of a spell into a single row")
	for entry: Dictionary in grouped:
		if entry["card_id"] == "spark_dart": expect.call(entry["count"] == 8, "Magic row retains exact duplicate count")
	_reference_copy(expect)

static func _reference_copy(expect: Callable) -> void:
	var glossary = preload("res://scripts/glossary.gd")
	expect.call(glossary.definition("loadout") == "The menu for your gear, magic, items and skills. Gear, magic and items form your deck.", "Closest glossary entry uses the director's exact deck and Purge explanation")
	expect.call(EventRules.MAGIC_REQUIREMENT_COPY == "Requires a spell in your deck.", "Empty spell requirement uses approved copy")
	var obsolete := RegEx.new()
	obsolete.compile("(?i)attun|(?:reserve|learned) magic|magic.*reserve|magic cards.*learned|(?:six|6) magic slots")
	for path: String in ["res://data/glossary.json", "res://data/grimoire.json"]:
		var text: String = FileAccess.get_file_as_string(path)
		expect.call(obsolete.search(text) == null, "Reference copy contains no obsolete magic loadout instructions: " + path)
	var grimoire = preload("res://scripts/grimoire_library.gd")
	for entry: Dictionary in grimoire.entries():
		for line: String in entry.get("body", []):
			expect.call(obsolete.search(line) == null, "Generated Grimoire copy contains no obsolete magic loadout instructions: " + str(entry["id"]))
	expect.call(" ".join(grimoire.entry_def(grimoire.character_entry_id("scavenger")).get("body", [])).contains("Purchased magic goes straight into your deck."), "Generated Scavenger entry uses the director's purchase copy")

static func unowned_purge_checks(engine: RefCounted, expect: Callable) -> void:
	var before: Dictionary = shop_fixture(engine)
	var after: Dictionary = engine.purge_magic_card(before, "frostbolt", "scavenger")
	expect.call(after["attuned_magic_cards"] == before["attuned_magic_cards"] and after["deck_cards"] == before["deck_cards"], "Unowned valid spell cannot change magic ownership or compiled deck")
	expect.call(engine.held_embers(after) == engine.held_embers(before), "Unowned valid spell cannot charge Embers")
	for field: String in ["magic_purges_this_run", "priced_magic_purges"]:
		expect.call(int(after.get(field, 0)) == int(before.get(field, 0)), "Unowned valid spell cannot advance " + field)
	expect.call(after == before, "Rejected unowned spell preserves the entire untouched shop fixture")

static func _retired_paths(expect: Callable) -> void:
	var engine_source: String = FileAccess.get_file_as_string("res://scripts/run_engine.gd")
	var sale_start: int = engine_source.find("func sell_merchant_item(")
	var sale_end: int = engine_source.find("\nfunc ", sale_start + 1)
	var sale_body: String = engine_source.substr(sale_start, sale_end - sale_start)
	expect.call(not sale_body.contains("MERCHANT_ITEM_KIND_MAGIC:"), "Retired reserve-magic sale branch is absent")
	var scene: Script = load("res://scripts/run_scene.gd")
	var names: Array[String]
	for method: Dictionary in scene.get_script_method_list(): names.append(str(method["name"]))
	expect.call(not names.has("_build_magic_card_proxy_panel"), "Retired magic proxy builder is absent")
	expect.call(names.has("_animate_magic_proxy_to_rect") and names.has("_build_loadout_card_proxy_panel"), "Shared item proxy geometry and animation remain available")
