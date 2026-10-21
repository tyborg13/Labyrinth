extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const GameData = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const MapPanelScript = preload("res://scripts/section_map_panel.gd")
const Elements = preload("res://scripts/element_data.gd")
const PlacementRegressions = preload("res://tests/helpers/special_placement_regressions.gd")
const SEED_COUNT: int = 64
const REWARD_SEED_COUNT: int = 64
const RARITY_FLOOR_TEST_SEED: int = 7
const DOOR_TEST_TILE: Vector2i = Vector2i(1, 1)
const PITY_TEST_MISSES: int = 1
const DEFERRED_TEST_SEED: int = 1
const DEFERRED_TEST_CARD: String = "guiding_flare"

static func run(expect: Callable) -> void:
	PlacementRegressions.run(expect)
	_test_golden(expect)
	for seed_value: int in range(SEED_COUNT):
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		var again: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(again)
		expect.call(state == again and state["section_map_layout_revision"] == Graph.LAYOUT_REVISION, "The current map revision is deterministic")
		for index: int in range(6): _test_section(state, index, expect)
	_test_future_placement(expect)
	_test_rewards_and_resume(expect)
	_test_deferred_special_rewards(expect)
	_test_reward_floor(expect)
	_test_names(expect)
	_test_door_names(expect)
	print("SPX revision 6 maps: checked 64 seeds x 6 sections, exhaustive routes")

static func _test_golden(expect: Callable) -> void:
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/spx_legacy_graphs.json"))
	for id: String in hashes:
		var parts: PackedStringArray = id.split(":")
		var state: Dictionary = {"seed": int(parts[1]), "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": int(parts[0])}
		Graph.initialize(state)
		expect.call(var_to_str(state).sha256_text() == hashes[id], "Golden graph is unchanged for revision/seed " + id)
	print("SPX legacy golden graphs: checked 9 seeds across revisions 3–5")

static func _test_section(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var specials: Array[Vector2i]
	var types: Dictionary = {}
	for node: Dictionary in state["rooms"].values():
		if int(node["section_index"]) != index: continue
		if str(node["type"]) != "special": continue
		var coord: Vector2i = node["coord"]
		specials.append(coord)
		expect.call(not types.has(node["special_type"]), "Special types are distinct within a section")
		types[node["special_type"]] = true
		expect.call(node["special_type"] in Specials.enabled_types(), "Only enabled special types spawn")
		expect.call(node["special_variant"] == Bosses.element_for_boss(info["boss_id"]), "Special variant is the section dragon biome")
		expect.call(int(node["map_step"]) >= 3 and int(node["map_step"]) <= int(info["room_count"]) - 2, "Special step bounds")
		expect.call(not node.has("mystery_type") and not node.get("was_mystery", false), "Special never replaces a mystery or its hidden combat")
		expect.call(Graph._is_fight(node), "Special counts toward every route fight budget")
		for other: Dictionary in state["rooms"].values():
			for edge: Dictionary in other["connections"]:
				if edge["coord"] == coord or other["coord"] == coord:
					expect.call(str(other["type"]) != "guardian" and str(Graph.room(state, edge["coord"])["type"]) != "guardian", "No edge joins a Guardian and special")
		if index == 5: expect.call(node.get("map_landmark", false), "Section VI special is a landmark through fog")
	expect.call(specials.size() in [1, 2], "The enabled catalog retains the authored one/two special section budget")
	for coord: Vector2i in specials:
		var special: Dictionary = Graph.room(state, coord)
		if special["special_type"] == "umbral_snare": expect.call(special["connections"].size() >= 2, "Snare placement requires at least two outgoing exits")
	var routes: Array[Dictionary]
	_walk_routes(state, info["entry"], index, 0, 0, 0, 0, routes)
	var empty_route: bool = false
	var hit_routes: int = 0
	var guardian_routes: int = 0
	for route: Dictionary in routes:
		expect.call(int(route["specials"]) <= 2, "Every recombined route has at most two specials")
		empty_route = empty_route or int(route["specials"]) == 0
		hit_routes += int(int(route["specials"]) > 0)
		guardian_routes += int(int(route["guardians"]) > 0)
		var budget: int = Graph.FIGHT_COUNTS[index] - 1
		# Revision 7 webs let a route run two fights under the target (map-03).
		var slack: int = Graph.V7_FIGHT_SLACK if bool(info.get("scroll", false)) else 1
		expect.call(int(route["fights"]) >= budget - slack and int(route["fights"]) <= budget + 1, "Special substitution preserves route fight budgets")
		expect.call(int(route["guardians"]) <= 1 and int(route["services"]) >= 1, "Guardian and non-fight service route rules are preserved")
	expect.call(empty_route and hit_routes > 0, "A section has both special and special-free routes")
	expect.call(guardian_routes > 0 and guardian_routes < routes.size(), "Guardian and Guardian-free routes are preserved")
	if specials.size() >= 2: expect.call(hit_routes >= 2, "Multiple specials cover at least two complete routes")

static func _walk_routes(state: Dictionary, coord: Vector2i, index: int, fights: int, specials: int, guardians: int, services: int, result: Array[Dictionary]) -> void:
	var node: Dictionary = Graph.room(state, coord)
	if str(node["type"]) == "boss":
		result.append({"fights": fights, "specials": specials, "guardians": guardians, "services": services})
		return
	fights += int(Graph._is_fight(node))
	specials += int(str(node["type"]) == "special")
	guardians += int(str(node["type"]) == "guardian")
	services += int(Graph._is_service(node))
	for edge: Dictionary in node["connections"]:
		if int(Graph.room(state, edge["coord"])["section_index"]) == index:
			_walk_routes(state, edge["coord"], index, fights, specials, guardians, services, result)

static func _test_future_placement(expect: Callable) -> void:
	var data: Dictionary = Specials.catalog()
	for type: String in data["types"]: data["types"][type]["enabled"] = true
	var seen_counts: Dictionary = {}
	var seen_types: Dictionary = {}
	for seed_value: int in range(SEED_COUNT):
		for index: int in range(6):
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
			var count: int = Graph.ROOM_COUNTS[index]
			var layout: Dictionary = Graph._section_layout_v5(rng, seed_value, index)
			var before: Dictionary = layout.duplicate(true)
			var selected: Dictionary = {}
			expect.call(Specials.place(layout, rng, count, "earth", data), "Future enabled types have a bounded legal placement")
			for cell: Vector2i in layout["order"]:
				if str(layout["nodes"][cell]["type"]) != "special":
					expect.call(layout["nodes"][cell] == before["nodes"][cell], "Placement preserves every unconverted node including mysteries")
					continue
				var type: String = layout["nodes"][cell]["special_type"]
				selected[cell] = type
				seen_types[type] = true
				expect.call(str(before["nodes"][cell]["type"]) == "combat", "Only rolled standard combat converts")
				expect.call(cell.x >= int(data["placement"]["first_step"]) and cell.x <= count - int(data["placement"]["last_step_from_boss"]), "Future placement independently meets step bounds")
				var exits: int = 0
				for _child: Vector2i in before["children"].get(cell, []): exits += 1
				expect.call(exits >= int(data["placement"]["min_outgoing_edges"].get(type, 0)), "Future placement independently meets outgoing-edge requirement: " + type)
				for neighbor: Vector2i in before["children"].get(cell, []) + before["parents"].get(cell, []):
					expect.call(before["nodes"][neighbor]["type"] != "guardian", "Future placement independently avoids Guardian adjacency")
			seen_counts[selected.size()] = true
			expect.call(selected.size() <= 3 and selected.values().size() == _unique(selected.values()).size(), "Future counts are capped and types remain distinct")
			# Independent exhaustive enumeration, not the production DP validator.
			var routes: Array[int]
			for lane: int in layout["rows"][1]: _layout_routes(layout, Vector2i(1, lane), selected, 0, routes)
			var hits: int = 0
			for value: int in routes:
				expect.call(value <= 2, "Every future recombined route respects the special cap")
				hits += int(value > 0)
			expect.call(routes.has(0) and (selected.size() < 2 or hits >= 2), "Future placements preserve bypass and multi-route coverage")
	expect.call(seen_counts.has(2) and seen_counts.has(3) and seen_types.size() == 4, "Future test seam exercises both weighted counts and every type, without enabling production content")
	var fallback: Dictionary = Graph._fallback_layout(12, Graph.FIGHT_COUNTS[5] - 1)
	var fallback_rng := RandomNumberGenerator.new()
	fallback_rng.seed = 1
	expect.call(Specials.place(fallback, fallback_rng, 12, "shadow"), "Deterministic fallback supports the production enabled catalog")

static func _layout_routes(layout: Dictionary, cell: Vector2i, selected: Dictionary, tally: int, routes: Array[int]) -> void:
	tally += int(selected.has(cell))
	var children: Array = layout["children"].get(cell, [])
	if children.is_empty(): routes.append(tally)
	for child: Vector2i in children: _layout_routes(layout, child, selected, tally, routes)

static func _unique(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values: result[value] = true
	return result

static func special_entry(engine: RunEngineScript, seed_value: int = 83, revision: int = 0) -> Dictionary:
	var state: Dictionary = engine.create_new_run(seed_value, Progression.default_data())
	if revision > 0:
		# Seeded fixtures authored on an older map keep it, as saved runs do.
		state["section_map_layout_revision"] = revision
		Graph.initialize(state)
	for node: Dictionary in state["rooms"].values():
		if node["type"] != "special" or node.get("special_type", "") != "warband" or int(node["section_index"]) != 0: continue
		for parent: Dictionary in state["rooms"].values():
			for edge: Dictionary in parent["connections"]:
				if edge["coord"] != node["coord"]: continue
				state["current_room"] = parent["coord"]
				parent["cleared"] = true
				state["mode"] = "room"
				return {"state": state, "destination": node["coord"]}
	return {}

static func _test_rewards_and_resume(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var fixture: Dictionary = special_entry(engine)
	fixture["state"]["equipment_drop_misses"] = PITY_TEST_MISSES
	var state: Dictionary = engine.move_to_pre_battle(fixture["state"], fixture["destination"])
	expect.call(state["mode"] == "pre_battle", "Special entry uses normal pre-battle flow")
	expect.call(int(state["equipment_drop_misses"]) == PITY_TEST_MISSES, "Pre-battle begins with a positive equipment miss count")
	var entered_room: Dictionary = engine.room_metadata(state, state["current_room"])
	expect.call(entered_room.has("special_type") and entered_room.has("special_variant"), "Combat analytics can read both persisted room context fields")
	var prepared: Dictionary = engine.prepare_pre_battle_combat(state)
	expect.call(engine.prepared_pre_battle_matches_input(prepared, state), "Special preview does not mutate its input or invalidate preparation")
	state = engine.begin_pre_battle_combat(state, prepared)
	expect.call(state["mode"] == "combat" and not state["combat_state"]["enemies"].is_empty(), "Special enters a populated room layout")
	var room: Dictionary = Graph.room(state, state["current_room"])
	var base: int = Specials.starting_embers(prepared["layout"])
	expect.call(room.get("special_starting_reward_embers", -1) == base, "Starting roster Ember sum is saved before enemies die or flee")
	expect.call(engine._layout_has_equipment_drop(prepared["layout"]) and state["equipment_drop_misses"] == 0, "Warband equipment is present and resets pity as a normal drop")
	Progression.set_run_storage_path("user://spx-special.save")
	expect.call(Progression.save_run_state(state), "Special combat saves")
	var loaded: Dictionary = engine.repair_loaded_run_state(Progression.load_saved_run())
	expect.call(loaded["rooms"] == state["rooms"] and loaded["map_sections"] == state["map_sections"], "Special fields and exact graph survive save/load repair")
	Progression.clear_saved_run()
	Progression.set_run_storage_path(Progression.DEFAULT_RUN_STORAGE_PATH)
	var combat: Dictionary = loaded["combat_state"].duplicate(true)
	combat["objective"] = {"type": "kill_all"}
	for enemy: Dictionary in combat["enemies"]: enemy["hp"] = 0
	combat["room_embers"] = 777
	var result: Dictionary = engine.finish_combat(loaded, combat)
	var expected: int = Omens.ember_drop(combat, int(floor(base * 1.5 + 0.5)))
	expect.call(result["mode"] == "reward" and result["pending_reward"]["cards"].size() == 4, "Special victory offers exactly four choices")
	expect.call(result["pending_reward"]["ember_amount"] == expected and int(result["held_embers"]) - int(loaded["held_embers"]) == expected, "Special pays 1.5x starting roster in place of per-kill earnings")
	expect.call((result.get("pending_relics", []) as Array).is_empty(), "Special never offers a relic")
	expect.call(engine.finish_combat(result, combat) == result, "Special rewards cannot be granted twice")
	combat["objective"]["goal_met"] = false
	var failed: Dictionary = engine.finish_combat(loaded, combat)
	expect.call(failed["pending_reward"]["cards"].size() == 3 and failed["pending_reward"]["ember_amount"] == 777, "Failed goal receives ordinary cards and per-kill Embers")
	var direct: Dictionary = engine.move_to_room(fixture["state"], fixture["destination"])
	expect.call(direct["mode"] == "combat" and Graph.room(direct, direct["current_room"]).has("special_starting_reward_embers"), "Direct entry captures the same starting roster metadata")
	expect.call(int(fixture["state"]["equipment_drop_misses"]) == PITY_TEST_MISSES and int(direct["equipment_drop_misses"]) == 0, "Direct entry resets positive equipment pity after its guaranteed drop")
	expect.call(engine._layout_has_equipment_drop(direct["combat_state"]), "Direct entry's combat snapshot contains the guaranteed equipment drop")
	var total: int = Specials.starting_embers({"enemies": [{"type": "warden", "reward_embers": 7}, {"type": "warden", "reward_embers": 2}]})
	expect.call(total == 9, "Explicit starting enemy rewards take precedence over catalog defaults")
	for omen_id: String in GameData.omens():
		var omen_state: Dictionary = Omens.add({}, omen_id)
		if Omens.ember_drop(omen_state, 30) == 30: continue
		expect.call(Specials.reward_embers({"special_starting_reward_embers": 20}, omen_state) == Omens.ember_drop(omen_state, 30), "Special Ember multiplier retains ordinary omen scaling")
	print("SPX equipment pity regression: positive misses reset through pre-battle and direct entry")

static func _test_deferred_special_rewards(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var fixture: Dictionary = special_entry(engine, DEFERRED_TEST_SEED, 6)
	var state: Dictionary = engine.move_to_room(fixture["state"], fixture["destination"])
	var room: Dictionary = Graph.room(state, state["current_room"])
	expect.call(room["element"] == Elements.LIGHTNING, "Seed 1 reproduces an off-element deferral in its first Warband")
	var combat: Dictionary = state["combat_state"].duplicate(true)
	combat["objective"] = {"type": "kill_all"}
	for enemy: Dictionary in combat["enemies"]: enemy["hp"] = 0
	state[RunEngineScript.SKILL_STATE_KEY]["pending_card"] = DEFERRED_TEST_CARD
	var result: Dictionary = engine.finish_combat(state, combat)
	var cards: Array = result["pending_reward"]["cards"]
	expect.call(cards.size() == 4 and cards[2] == DEFERRED_TEST_CARD, "finish_combat puts an off-element deferral in the general slot")
	for slot: int in [0, 1, 3]:
		expect.call(GameData.card_element(cards[slot]) == Elements.LIGHTNING, "finish_combat preserves all three Lightning slots after deferral")
	expect.call(result[RunEngineScript.SKILL_STATE_KEY]["pending_card"].is_empty(), "Special reward consumes its pending deferral")
	# Find a deterministic offer where the general slot held the only Rare+.
	# Replacing it with a Common must reroll the last elemental slot, while
	# keeping the deferred card. This exercises finish_combat, not just helpers.
	room["special_goal_met"] = true
	var floor_witness: bool = false
	for reward_seed: int in range(REWARD_SEED_COUNT):
		state["seed"] = reward_seed
		var ordinary: Array[String] = engine._generate_card_rewards(state, state["current_room"])
		if GameData.card_rarity(ordinary[2]) == "common": continue
		if GameData.card_rarity(ordinary[0]) != "common" or GameData.card_rarity(ordinary[1]) != "common" or GameData.card_rarity(ordinary[3]) != "common": continue
		floor_witness = true
		result = engine.finish_combat(state, combat)
		cards = result["pending_reward"]["cards"]
		expect.call(cards[2] == DEFERRED_TEST_CARD, "Rare-floor repair retains the off-element deferred card in its general slot")
		expect.call(GameData.card_rarity(cards[3]) in ["rare", "epic", "legendary"] and GameData.card_element(cards[3]) == Elements.LIGHTNING, "finish_combat reapplies the Rare floor in the last Lightning slot after deferral")
		break
	expect.call(floor_witness, "Deferred integration includes a general-only Rare witness")
	print("SPX deferred reward regression: seed 1 keeps three Lightning slots; general-only Rare floor repaired")

static func _test_reward_floor(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var fixture: Dictionary = special_entry(engine)
	var state: Dictionary = fixture["state"]
	var coord: Vector2i = fixture["destination"]
	var room: Dictionary = Graph.room(state, coord)
	var elements: Array[String]
	elements.assign(Elements.ORDER)
	elements.append(Elements.NONE)
	for element: String in elements:
		room["element"] = element
		var filter: String = element if Elements.is_elemental(element) else ""
		var deferred_id: String = GameData.reward_card_pool_by_rarity(filter, true)["common"][0]
		var general_off_element: bool = false
		for seed_value: int in range(REWARD_SEED_COUNT):
			state["seed"] = seed_value
			room["special_goal_met"] = false
			var standard: Array[String] = engine._generate_card_rewards(state, coord)
			room["special_goal_met"] = true
			var choices: Array[String] = engine._generate_card_rewards(state, coord)
			expect.call(choices.size() == 4 and _unique(choices).size() == 4, "Special offers four distinct cards: " + element)
			expect.call(choices.slice(0, 3) == standard, "Special preserves ordinary first three slots: " + element)
			if Elements.is_elemental(element):
				for slot: int in [0, 1, 3]:
					expect.call(GameData.card_element(choices[slot]) == element, "Three special slots use the room element: " + element)
			general_off_element = general_off_element or GameData.card_element(choices[2]) != element
			var rare: bool = false
			for id: String in choices: rare = rare or GameData.card_rarity(id) in ["rare", "epic", "legendary"]
			expect.call(rare, "Every special offer includes Rare or better: " + element)
			var deferred: Array[String] = engine._generate_card_rewards(state, coord, 991, [], deferred_id)
			expect.call(deferred.has(deferred_id) and _unique(deferred).size() == 4, "Special generation retains its Common deferral without duplicates: " + element)
			var deferred_rare: bool = false
			for id: String in deferred: deferred_rare = deferred_rare or GameData.card_rarity(id) in ["rare", "epic", "legendary"]
			expect.call(deferred_rare, "Special generation retains the Rare floor after a Common deferral: " + element)
			if Elements.is_elemental(element):
				for slot: int in [0, 1, 3]:
					expect.call(GameData.card_element(deferred[slot]) == element, "Same-element deferral retains each elemental slot: " + element)
			expect.call(not engine._equipment_drop_for_room(state, room).is_empty(), "Equipment is forced even when the ordinary drop roll misses")
		expect.call(general_off_element, "General special slot is not restricted to the room element: " + element)
		_test_forced_floor(engine, state, element, expect)
	print("SPX special reward filters: checked 64 seeds x 6 room elements; forced Rare floor in each filter")

static func _test_forced_floor(engine: RunEngineScript, state: Dictionary, element: String, expect: Callable) -> void:
	var filter: String = element if Elements.is_elemental(element) else ""
	var pool: Array = GameData.reward_card_pool_by_rarity(filter, true)["common"]
	var common: Array[String]
	common.assign(pool.slice(0, 3))
	# Slot 2 remains the ordinary general offer. The added elemental/general
	# slot is last, so the rarity floor may change only slot 3.
	for id: String in GameData.reward_card_pool_by_rarity("", true)["common"]:
		if not common.has(id):
			common.insert(2, id)
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = RARITY_FLOOR_TEST_SEED
	var forced: Array[String] = engine._special_rarity_floor(rng, common.duplicate(), [], state, filter)
	expect.call(forced.slice(0, 3) == common.slice(0, 3) and GameData.card_rarity(forced[3]) in ["rare", "epic", "legendary"], "An all-common roll rerolls only the last element slot, or last neutral slot, at Rare or better: " + element)
	if Elements.is_elemental(element):
		expect.call(GameData.card_element(forced[3]) == element, "Forced Rare offer retains the room's element filter: " + element)
	var excluded: Array[String]
	excluded.assign(GameData.reward_card_pool_by_rarity(filter, true)["rare"])
	rng.seed = RARITY_FLOOR_TEST_SEED
	var unblocked: Array[String] = engine._special_rarity_floor(rng, common.duplicate(), excluded, state, filter)
	expect.call(not excluded.has(unblocked[3]) and GameData.card_rarity(unblocked[3]) in ["epic", "legendary"], "Rarity floor respects excluded cards in the same element filter: " + element)

static func _test_names(expect: Callable) -> void:
	var room: Dictionary = {"type": "special", "special_type": "warband", "special_variant": "air", "revealed": true}
	expect.call(Specials.display_name(room) == "Warband · The Stormcaller", "Warband title reads the approved captain variant")
	expect.call(Specials.tooltip_line(room) == "Kill the captain and the rest flee.", "Tooltip reads the protected catalog")
	for type: String in Specials.catalog()["types"]:
		room["special_type"] = type
		expect.call(Icons.icon_id_for_room(room) == "special_" + type and not Icons.icon_path("special_" + type).is_empty(), "Every special owns its exact approved emblem")
		var imported: Texture2D = load(Icons.icon_path("special_" + type)) as Texture2D
		expect.call(imported != null and imported.get_size() == Vector2(1024, 1024), "Approved emblem imports load through Godot’s real resource loader")
		var staged: Texture2D = load("res://spec/peer_benchmark/staged/spx/emblems/" + type + ".png") as Texture2D
		expect.call(staged != null and staged.get_size() == Vector2(1024, 1024), "Director-staged emblem sidecars load through Godot’s real resource loader")
	var panel := MapPanelScript.new()
	room["special_type"] = "warband"
	room["coord"] = Vector2i.ZERO
	panel.run_state = {"rooms": {"0,0": room}, "current_room": Vector2i.ZERO}
	expect.call(panel.room_description(Vector2i.ZERO) == "Warband · The Stormcaller\nKill the captain and the rest flee.\nCurrent room", "Tooltip orders title, type line, and ordinary state")
	panel.free()

static func _test_door_names(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var fixture: Dictionary = special_entry(engine)
	var state: Dictionary = fixture["state"]
	var coord: Vector2i = fixture["destination"]
	var room: Dictionary = Graph.room(state, coord)
	var scene: Control = load("res://scripts/run_scene.gd").new()
	scene.set("_run_state", state)
	scene.set("_hovered_board_tile", DOOR_TEST_TILE)
	scene.set("_exit_destinations_by_tile", {DOOR_TEST_TILE: coord})
	for type: String in Specials.catalog()["types"]:
		room["special_type"] = type
		expect.call(scene.call("_room_hover_hint") == "%s %d" % [Specials.display_name(room), room["depth"]], "Physical door uses the library's special name: " + type)
	room["type"] = "combat"
	room["element"] = Elements.FIRE
	expect.call(scene.call("_room_hover_hint") == "Fire Combat %d" % room["depth"], "Ordinary door label retains its element, type and depth")
	scene.set("_hovered_board_tile", Vector2i(-1, -1))
	expect.call(scene.call("_room_hover_hint").is_empty(), "Leaving a physical door clears its label")
	scene.free()
