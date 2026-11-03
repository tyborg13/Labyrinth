extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const Flurry = preload("res://tests/fixtures/dormant_flurry_cards.gd")
const CARD_IDS: Array = ["storm_salvo", "cinder_fusillade", "razor_gale", "blade_dance", "windlass_volley", "sawtooth_flurry"]
const SAVE_PATH: String = "user://flu_01_legacy_ids.save"
const SEED: int = 15114
const PLAYER_TILE := Vector2i(2, 4)
const TARGET_TILE := Vector2i(3, 4)
const TEST_HP: int = 100

static func run(expect: Callable) -> void:
	_test_shipped_pool(expect)
	test_dormant_engine(expect)
	_test_legacy_save_ids(expect)

static func room() -> Dictionary:
	return preload("res://tests/suites/relic_u2_suite.gd").room()

static func _test_shipped_pool(expect: Callable) -> void:
	for id: String in GameData.cards():
		var card: Dictionary = GameData.card_def(id)
		expect.call(not (GameData.cards()[id] as Dictionary).has("flurry"), "%s ships without a Flurry field" % id)
		for row: Array in Icons.rows_for_card(card):
			for token: Dictionary in row:
				expect.call(str(token.get("icon", "")) != "flurry", "%s has no Flurry token" % id)
		for entry: Dictionary in Icons.tooltip_entries_for_rows(Icons.rows_for_card(card)):
			expect.call(not str(entry.get("tooltip", "")).to_lower().contains("flurry"), "%s has no Flurry tooltip" % id)
	expect.call(Glossary.lookup("flurry").is_empty(), "Flurry has no glossary row")
	expect.call(not Icons.all_icon_keys().has("flurry"), "Flurry is excluded from the live icon inventory")
	expect.call(not Grimoire.entry_map().has("keyword:flurry"), "Flurry has no Grimoire entry")
	for entry: Dictionary in Grimoire.entry_map().values():
		for paragraph: String in entry.get("body", []):
			expect.call(not paragraph.to_lower().contains("flurry"), "Generated Grimoire copy has no Flurry: %s" % entry.get("id", ""))
	var crown: Dictionary = GameData.relics()["crown_of_surplus"]
	expect.call(str(crown["description"]).ends_with("@kw(rite|Rites) and @kw(item|Items) are excluded."), "Crown uses the decided exclusion copy")

static func expected_actions() -> Dictionary:
	return {
		"storm_salvo": [{"type": "ranged", "damage": 5, "range": 3, "chain": 2, "element": "lightning"}, {"type": "draw", "amount": 2}],
		# pol-42 (1abde7ccc), after the original Flurry retirement.
		"cinder_fusillade": [{"type": "ranged", "damage": 6, "range": 3, "surface": "fire", "element": "fire"}],
		"razor_gale": [{"type": "ranged", "damage": 4, "range": 3, "push": 2, "element": "air"}],
		"blade_dance": [{"type": "block", "amount": 4}, {"type": "melee", "damage": 7, "range": 1, "element": "none"}],
		"windlass_volley": [{"type": "aoe", "damage": 4, "range": 3, "pattern": [[0, 0], [1, 0]], "rotate": true, "element": "none"}],
		"sawtooth_flurry": [{"type": "melee", "damage": 5, "range": 1, "element": "none", "bleed": 2}]
	}

static func _printed_actions(card: Dictionary) -> Array:
	var actions: Array = (card.get("actions", []) as Array).duplicate(true)
	for action: Dictionary in actions:
		for key: String in action.keys():
			if key.begins_with("_"): action.erase(key)
	return actions

static func _test_legacy_save_ids(expect: Callable) -> void:
	var previous_path: String = Store._run_storage_path
	Store.set_run_storage_path(SAVE_PATH)
	Store.clear_saved_run()
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(SEED, room(), {"hp": TEST_HP, "max_hp": TEST_HP, "deck_cards": CARD_IDS, "hand_size": CARD_IDS.size(), "relics": []})
	state["deck"] = {"hand": CARD_IDS.duplicate(), "draw": ["brace", "brace", "brace"], "discard": [], "burned": []}
	state["player"] = {"pos": PLAYER_TILE, "hp": TEST_HP, "max_hp": TEST_HP, "block": 0, "stoneskin": 0}
	state["enemies"] = [{"id": 1, "type": "crawler", "pos": TARGET_TILE, "hp": TEST_HP, "max_hp": TEST_HP, "block": 0, "stoneskin": 0}]
	# Old saves store IDs rather than card definitions. Write that on-disk shape
	# directly, then use the production loader; no new-save normalization occurs.
	var old_run: Dictionary = Run.new().create_new_run(SEED, Store.default_data())
	old_run["mode"] = "combat"
	old_run["deck_cards"] = CARD_IDS.duplicate()
	old_run["combat_state"] = state
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	expect.call(file != null, "Legacy card-ID fixture can be written")
	if file == null:
		Store.set_run_storage_path(previous_path)
		return
	file.store_var(old_run, false)
	file.close()
	var loaded_run: Dictionary = Store.load_saved_run()
	expect.call(loaded_run.get("deck_cards", []) == CARD_IDS, "Legacy run retains all six card IDs")
	var loaded: Dictionary = loaded_run.get("combat_state", {})
	expect.call(loaded.get("deck", {}).get("hand", []) == CARD_IDS, "Legacy combat hand retains all six card IDs")
	var times: Array = [6, 4, 4, 4, 3, 3]
	var damage: Array = [5, 6, 4, 7, 4, 5]
	for index: int in range(CARD_IDS.size()):
		var id: String = str(CARD_IDS[index])
		var working: Dictionary = loaded.duplicate(true)
		working["deck"]["hand"] = [id]
		var card: Dictionary = combat.card_def(id, working)
		expect.call(JSON.parse_string(JSON.stringify(_printed_actions(card))) == JSON.parse_string(JSON.stringify(expected_actions()[id])), "%s loads its new printed actions" % id)
		expect.call(int(card.get("time", 0)) == times[index] and not card.has("flurry"), "%s loads its new one-play definition" % id)
		if id == "sawtooth_flurry": expect.call(card.get("name") == "Sawtooth Rake", "Legacy Sawtooth ID loads the new name")
		working = combat.prepare_player_card(working, 0)
		var actions: Array = combat.card_play_actions(id, working)
		expect.call(actions.size() == (expected_actions()[id] as Array).size(), "%s plays its sequence exactly once after resume" % id)
		expect.call(combat.card_plays_spent_for_actions(actions) == 1, "%s spends one play after resume" % id)
		for action: Dictionary in actions:
			working = combat.apply_player_action(working, action, TARGET_TILE)
		working = combat.finish_player_card(working, 0, combat.card_plays_spent_for_actions(actions))
		expect.call(int(working.get("player_turn_time_spent", 0)) == times[index], "%s pays the new Time once" % id)
		expect.call(combat.cards_remaining_this_turn(working) == 1, "%s leaves the other base Card Play" % id)
		expect.call(int(working["enemies"][0]["hp"]) == TEST_HP - GameData.fixed_point_amount(damage[index]), "%s resolves its new damage after resume" % id)
		match id:
			"storm_salvo": expect.call((working["deck"]["hand"] as Array).size() == 2, "Resumed Storm Salvo draws two")
			"cinder_fusillade": expect.call(BoardSurfaceRules.element_at(working, TARGET_TILE) == "fire", "Resumed Cinder Fusillade leaves Fire")
			"razor_gale": expect.call(working["enemies"][0]["pos"] == TARGET_TILE + Vector2i(2, 0), "Resumed Razor Gale pushes two")
			"blade_dance": expect.call(int(working["player"]["block"]) == GameData.fixed_point_amount(4), "Resumed Blade Dance gains four Block")
			"sawtooth_flurry": expect.call(int(working["enemies"][0].get("bleed", 0)) == GameData.fixed_point_amount(2), "Resumed Sawtooth Rake applies Bleed two")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous_path)

static func test_dormant_engine(expect: Callable) -> void:
	Flurry.install()
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(15111, room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": [Flurry.RANGED_ID],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [Flurry.RANGED_ID]
	deck["draw"] = []
	deck["discard"] = []
	state["deck"] = deck
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 2, "max_hp": 2, "block": 0, "stoneskin": 0},
		{"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	]
	var actions: Array = combat.card_play_actions(Flurry.RANGED_ID, state)
	expect.call(actions.size() == 2, "Flurry should repeat its full printed action package once for each of the two base card plays")
	expect.call(combat.card_plays_spent_for_actions(actions) == 2, "Repeated Flurry actions should preserve the snapshotted spend count")
	state = combat.apply_player_action(state, actions[0] as Dictionary, Vector2i(3, 4))
	state = combat.apply_player_action(state, actions[1] as Dictionary, Vector2i(4, 4))
	state = combat.finish_player_card(state, 0, combat.card_plays_spent_for_actions(actions))
	expect.call(int(state.get("cards_played_this_turn", 0)) == 2, "Flurry should spend every card play it snapshotted")
	expect.call(int(state.get("player_turn_time_spent", 0)) == 5, "Flurry should pay its top-level time cost only once")
	expect.call(combat.cards_remaining_this_turn(state) == 1, "A kill-granted play created during Flurry should remain available after the snapshotted plays are spent")
	expect.call(BoardSurfaceRules.element_at(state, Vector2i(3, 4)) == "fire" and BoardSurfaceRules.element_at(state, Vector2i(4, 4)) == "fire", "Each Flurry copy paints its actual target")
	expect.call(int(((state.get("enemies", []) as Array)[1] as Dictionary).get("hp", 0)) == 18, "Each Flurry copy should resolve its attack against the selected target")
	var bonus_state: Dictionary = state.duplicate(true)
	bonus_state["cards_played_this_turn"] = 0
	bonus_state["death_bonus_card_plays_this_turn"] = 0
	bonus_state["card_play_bonus_this_turn"] = 1
	var bonus_actions: Array = combat.card_play_actions(Flurry.RANGED_ID, bonus_state)
	expect.call(bonus_actions.size() == 3, "Card-play bonuses should directly increase every action in a later Flurry's repeat count")
	var cost_state: Dictionary = combat.create_combat(15113, room(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["glassbone_guard"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var cost_deck: Dictionary = (cost_state.get("deck", {}) as Dictionary).duplicate(true)
	cost_deck["hand"] = ["glassbone_guard"]
	cost_deck["draw"] = []
	cost_deck["discard"] = []
	cost_state["deck"] = cost_deck
	cost_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	cost_state = combat.finish_player_card(cost_state, 0, 2)
	expect.call(int((cost_state.get("player", {}) as Dictionary).get("hp", 0)) == 22, "A two-copy Flurry commit should pay a printed health cost for both copies")
	expect.call(int(cost_state.get("player_turn_time_spent", 0)) == 4, "A two-copy Flurry commit should still pay the printed Time only once")

	Flurry.remove()
