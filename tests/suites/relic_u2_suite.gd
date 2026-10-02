extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")

static func run(expect: Callable) -> void:
	_test_iron_buckler(expect)
	_test_combat_start(expect)
	_test_rubblewalker_greaves(expect)
	_test_hobnail_cleats(expect)
	_test_pitch_gloves(expect)
	_test_grounding_pin(expect)
	_test_leaden_pommel(expect)
	_test_fencers_gloves(expect)
	_test_duelist_whetstone(expect)
	_test_coffin_nails(expect)
	_test_briar_vambrace(expect)
	_test_flint_edge(expect)

static func room() -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String]
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 8 else "stone")
		grid.append(row)
	return {"name": "Common relics", "coord": Vector2i(1, 0), "type": "combat", "depth": 1, "grid": grid, "player_start": Vector2i(2, 4), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 100, "max_hp": 100}], "traps": [], "loot": []}

static func state(engine: RefCounted, relics: Array, cards: Array = []) -> Dictionary:
	var deck: Array = cards.duplicate()
	if deck.is_empty():
		deck = ["quick_stab", "brace", "overhead_smash", "iron_wheel"]
	var result: Dictionary = engine.create_combat(2202, room(), {"hp": 24, "max_hp": 24, "deck_cards": deck, "hand_size": deck.size(), "relics": relics})
	result["draw_per_turn"] = 0
	result["cards_per_turn"] = 10
	result["deck"]["hand"] = deck
	return result

static func _resume(value: Dictionary, expect: Callable) -> Dictionary:
	var previous_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u2_resume.save")
	var run_state: Dictionary = Run.new().create_new_run(2202, Store.default_data())
	run_state["mode"] = "combat"
	run_state["combat_state"] = value
	expect.call(Store.save_run_state(run_state), "U2 save should write production run format")
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {}) as Dictionary
	expect.call(loaded == value, "U2 combat state should survive save/resume exactly")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous_path)
	return loaded

static func _attack(engine: RefCounted, id: String, value: Dictionary, type: String = "melee") -> Dictionary:
	for action: Dictionary in engine.card_play_actions(id, value):
		if str(action.get("type", "")) == type:
			return action
	return {}

static func _forecast(engine: RefCounted, value: Dictionary, action: Dictionary, tile: Vector2i, expect: Callable) -> Dictionary:
	var before: Dictionary = value.duplicate(true)
	var preview: Dictionary = engine.surface_preview_for_player_action(value, action, tile).get("state", {}) as Dictionary
	expect.call(value == before, "U2 hover must not mutate live state")
	var committed: Dictionary = engine.apply_player_action(value, action, tile)
	expect.call(preview == committed, "U2 surface/damage/status forecast must equal commit: %s" % str(action.get("_card_id", action.get("type", ""))))
	return committed

static func _test_iron_buckler(expect: Callable) -> void:
	var engine := Combat.new()
	for previous: int in [0, 2, 8]:
		var value: Dictionary = state(engine, ["iron_buckler"])
		value["player"]["block"] = previous
		value = engine.prepare_next_player_turn(_resume(value, expect))
		expect.call(int(value["player"]["block"]) == mini(previous, 3), "Iron Buckler keeps only existing Block up to three")
	var plain: Dictionary = state(engine, [])
	plain["player"]["block"] = 8
	expect.call(int(engine.prepare_next_player_turn(plain)["player"]["block"]) == 0, "No Buckler resets Block normally")
	var buckler: Dictionary = state(engine, ["iron_buckler"], ["brace", "quick_stab"])
	buckler["deck"]["hand"] = ["brace"]
	buckler["deck"]["draw"] = ["quick_stab"]
	buckler = engine.apply_player_action(buckler, engine.card_play_actions("brace", buckler)[0])
	buckler = engine.finish_player_card(buckler, 0)
	expect.call((buckler["deck"]["hand"] as Array).is_empty(), "Iron Buckler no longer draws on defensive cards")

static func _test_combat_start(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["tallow_candle", "grave_dirt", "waxen_effigy"])
	expect.call(int(value["player"]["stoneskin"]) == 4, "Grave Dirt opens combat with four Stoneskin")
	var sources: Array = value["umbra"]["light_sources"]
	expect.call(sources.size() == 1 and sources[0]["pos"] == Vector2i(2, 4) and int(sources[0]["radius"]) == 2 and int(sources[0]["remaining_activations"]) == 3, "Tallow Candle creates ordinary radius-two three-turn Light")
	var illusions: Array = value["illusions"]
	expect.call(illusions.size() == 1 and illusions[0]["pos"] == Vector2i(2, 3) and int(illusions[0]["hp"]) == 2, "Waxen Effigy picks the nearest legal tile, stable row-major tie")
	value = engine.prepare_next_player_turn(_resume(value, expect))
	expect.call(int(value["player"]["stoneskin"]) == 4 and (value["illusions"] as Array).size() == 1 and (value["umbra"]["light_sources"] as Array).size() == 1, "Combat opening relics never repeat at turn start/resume")
	value = engine.prepare_next_player_turn(value)
	value = engine.prepare_next_player_turn(value)
	expect.call((value["umbra"]["light_sources"] as Array).is_empty(), "Tallow Candle Light expires after three turns")
	var plain: Dictionary = state(engine, [])
	expect.call(int(plain["player"]["stoneskin"]) == 0 and (plain["illusions"] as Array).is_empty() and (plain["umbra"]["light_sources"] as Array).is_empty(), "Absent combat relics grant no opening resources")
	var blocked: Dictionary = room()
	for tile: Vector2i in [Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 5)]:
		blocked["grid"][tile.y][tile.x] = "wall"
	var no_tile: Dictionary = engine.create_combat(2202, blocked, {"hp": 24, "max_hp": 24, "relics": ["waxen_effigy"]})
	expect.call((no_tile["illusions"] as Array).is_empty(), "Waxen Effigy does nothing with all neighbors occupied/blocked")
	var footprint_room: Dictionary = room()
	footprint_room["enemies"][0]["pos"] = Vector2i(4, 3)
	footprint_room["enemies"][0]["footprint"] = Vector2i(2, 2)
	var big: Dictionary = engine.create_combat(2202, footprint_room, {"hp": 24, "max_hp": 24, "relics": ["waxen_effigy"]})
	expect.call(big["illusions"][0]["pos"] == Vector2i(3, 4), "Effigy distance uses the enemy footprint, not its anchor")
	var hidden_room: Dictionary = room()
	hidden_room["umbra_stage"] = "eclipse"
	hidden_room["enemies"][0]["pos"] = Vector2i(8, 4)
	var hidden: Dictionary = engine.create_combat(2202, hidden_room, {"hp": 24, "max_hp": 24, "relics": ["waxen_effigy"]})
	expect.call((hidden["illusions"] as Array).is_empty(), "Effigy cannot choose toward a hidden enemy")
	var terrain_room: Dictionary = room()
	terrain_room["terrain"] = [{"id": 1, "pos": Vector2i(2, 3), "hp": 5, "max_hp": 5, "kind": "outcrop"}]
	var terrain: Dictionary = engine.create_combat(2202, terrain_room, {"hp": 24, "max_hp": 24, "relics": ["waxen_effigy"]})
	expect.call(terrain["illusions"][0]["pos"] == Vector2i(1, 4), "Effigy cannot overlap living terrain")

static func _test_rubblewalker_greaves(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["rubblewalker_greaves"])
	Surface.place(value, Vector2i(2, 4), "rubble")
	Surface.place(value, Vector2i(2, 3), "rubble")
	var move: Dictionary = {"type": "move", "range": 2}
	expect.call(engine.valid_targets_for_player_action(value, move).has(Vector2i(2, 2)), "Greaves Move ignores Rubble on both path steps")
	var moved: Dictionary = _forecast(engine, value, move, Vector2i(2, 2), expect)
	expect.call(moved["player"]["pos"] == Vector2i(2, 2), "Greaves movement resolves the forecast endpoint")
	value = engine.prepare_next_player_turn(_resume(value, expect))
	expect.call(int(value["player"]["stoneskin"]) == 1, "Greaves grants one Stoneskin on Rubble at turn start")
	value = engine.prepare_next_player_turn(value)
	expect.call(int(value["player"]["stoneskin"]) == 2, "Greaves grants Stoneskin on each qualifying turn")
	var empty: Dictionary = engine.prepare_next_player_turn(state(engine, ["rubblewalker_greaves"]))
	expect.call(int(empty["player"]["stoneskin"]) == 0, "Greaves idle off Rubble")
	var plain: Dictionary = state(engine, [])
	Surface.place(plain, Vector2i(2, 4), "rubble")
	Surface.place(plain, Vector2i(2, 3), "rubble")
	expect.call(not engine.valid_targets_for_player_action(plain, move).has(Vector2i(2, 2)), "Without Greaves Rubble taxes Move")

static func _test_hobnail_cleats(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["hobnail_cleats"])
	Surface.place(value, Vector2i(2, 3), "ice")
	value = _forecast(engine, value, {"type": "move", "range": 1}, Vector2i(2, 3), expect)
	expect.call(not bool(value["player"].get("chilled", false)), "Cleats prevent Ice entry Chill")
	value = engine.prepare_next_player_turn(_resume(value, expect))
	expect.call(not bool(value["player"].get("chilled", false)), "Cleats prevent Ice turn-start Chill")
	value["player"]["pos"] = Vector2i(2, 4)
	Surface.place(value, Vector2i(2, 4), "ice")
	var ice: Dictionary = {"type": "melee", "range": 1, "damage": 3, "element": "ice", "_card_action_types": ["melee"]}
	var modifiers: Array = engine.damage_modifiers_for_player_action(value, ice)
	var accurate_tooltip: bool = false
	for modifier: Dictionary in modifiers:
		accurate_tooltip = accurate_tooltip or (str(modifier.get("source", "")) == "Hobnail Cleats" and str(modifier.get("detail", "")).contains("Ice"))
	expect.call(accurate_tooltip, "Cleats damage tooltip states its actual Ice condition")
	var hit: Dictionary = _forecast(engine, value, ice, Vector2i(3, 4), expect)
	expect.call(int(hit["enemies"][0]["hp"]) == 95, "Cleats Ice attack gains two damage on Ice")
	ice["element"] = "fire"
	expect.call(int(_forecast(engine, value, ice, Vector2i(3, 4), expect)["enemies"][0]["hp"]) == 97, "Cleats idle on non-Ice attacks")
	Surface.remove(value, Vector2i(2, 4), "ice")
	ice["element"] = "ice"
	expect.call(int(_forecast(engine, value, ice, Vector2i(3, 4), expect)["enemies"][0]["hp"]) == 97, "Cleats idle off Ice")
	var plain: Dictionary = state(engine, [])
	Surface.place(plain, Vector2i(2, 3), "ice")
	expect.call(bool(engine.apply_player_action(plain, {"type": "move", "range": 1}, Vector2i(2, 3))["player"].get("chilled", false)), "Ice still Chills without Cleats")

static func _test_pitch_gloves(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["pitch_gloves"])
	Surface.place(value, Vector2i(2, 3), "fire", {"actor_kind": "enemy"})
	value = _forecast(engine, value, {"type": "move", "range": 1}, Vector2i(2, 3), expect)
	expect.call(int(value["player"]["hp"]) == 23, "Pitch Gloves reduce Fire entry damage by one")
	value = engine.prepare_next_player_turn(value)
	expect.call(int(value["player"]["hp"]) == 21, "Pitch Gloves reduce Fire start damage by one")
	for owner: String in ["player", "enemy", "trap"]:
		var enemy_fire: Dictionary = state(engine, ["pitch_gloves"])
		Surface.place(enemy_fire, Vector2i(3, 4), "fire", {"actor_kind": owner})
		enemy_fire = _resume(enemy_fire, expect)
		engine._surface_contact(enemy_fire, "enemy", 1, engine.INVALID_TILE, true)
		expect.call(int(enemy_fire["enemies"][0]["hp"]) == (96 if owner == "player" else 97), "Pitch Gloves respect Fire ownership: %s" % owner)
	var plain: Dictionary = state(engine, [])
	Surface.place(plain, Vector2i(2, 3), "fire", {"actor_kind": "player"})
	expect.call(int(_forecast(engine, plain, {"type": "move", "range": 1}, Vector2i(2, 3), expect)["player"]["hp"]) == 22, "No Gloves means ordinary Fire damage")
	var direct: Dictionary = state(engine, ["pitch_gloves"])
	expect.call(int(_forecast(engine, direct, {"type": "melee", "range": 1, "damage": 3, "element": "fire"}, Vector2i(3, 4), expect)["enemies"][0]["hp"]) == 97, "Pitch Gloves never amplify direct Fire hits")
	var mixed: Dictionary = state(engine, ["pitch_gloves"])
	mixed["enemies"][0]["footprint"] = Vector2i(1, 2)
	Surface.place(mixed, Vector2i(3, 4), "fire", {"actor_kind": "enemy"})
	Surface.place(mixed, Vector2i(3, 5), "fire", {"actor_kind": "player"})
	engine._surface_contact(mixed, "enemy", 1, engine.INVALID_TILE, true)
	expect.call(int(mixed["enemies"][0]["hp"]) == 96, "Owned Fire under a large footprint gets its bonus once, independent of tile order")
	var rite_rules = preload("res://scripts/rite_rules.gd")
	expect.call(rite_rules.surface_tile_damage(Data.relic_effects_for_state(direct), "fire", "player", 1) == 0, "Pitch Gloves Fire reduction clamps at zero")

static func _test_grounding_pin(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["grounding_pin"])
	value["enemies"].append({"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 100, "max_hp": 100})
	var attack: Dictionary = {"type": "melee", "range": 1, "damage": 3}
	var idle: Dictionary = _forecast(engine, value, attack, Vector2i(3, 4), expect)
	expect.call(int(idle["enemies"][1]["hp"]) == 100, "Grounding Pin needs Electrified")
	Surface.place(value, Vector2i(3, 4), "electrified", {"actor_kind": "enemy"})
	var chained: Dictionary = _forecast(engine, value, attack, Vector2i(3, 4), expect)
	expect.call(int(chained["enemies"][1]["hp"]) == 97, "Grounding Pin supplies native Chain one on any Electrified owner")
	var shove: Dictionary = {"type": "push", "range": 1, "damage": 0, "amount": 1}
	expect.call(int((engine._action_with_target_state_relic_modifiers(value, shove, 0) as Dictionary).get("chain", 0)) == 0, "Grounding Pin does not turn a zero-damage shove into a Chain attack")
	var area: Dictionary = {"type": "aoe", "range": 1, "damage": 3, "pattern": [[0, 0]]}
	expect.call(int(_forecast(engine, value, area, Vector2i(3, 4), expect)["enemies"][1]["hp"]) == 100, "Grounding Pin never adds Chain to an area attack")
	value["enemies"][0]["footprint"] = Vector2i(1, 2)
	Surface.remove(value, Vector2i(3, 4), "electrified")
	Surface.place(value, Vector2i(3, 5), "electrified")
	expect.call(int(_forecast(engine, value, attack, Vector2i(3, 4), expect)["enemies"][1]["hp"]) == 97, "Grounding Pin reads any target footprint tile")

static func _test_leaden_pommel(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["leaden_pommel"])
	var heavy: Dictionary = _attack(engine, "overhead_smash", value)
	var printed: Dictionary = _attack(engine, "overhead_smash", {})
	expect.call(int(heavy.get("stagger", 0)) == int(printed.get("stagger", 0)) + 1, "Leaden Pommel adds to printed Stagger on heavy attacks")
	var light: Dictionary = _attack(engine, "quick_stab", value)
	expect.call(int(light.get("stagger", 0)) == int(_attack(engine, "quick_stab", {}).get("stagger", 0)), "Leaden Pommel idle below five Time")
	expect.call(int(_attack(engine, "butcher_chop", value).get("stagger", 0)) == 1, "Leaden Pommel includes the exact five-Time boundary")
	expect.call(int(_attack(engine, "tectonic_maul", value).get("stagger", 0)) == 4, "Leaden Pommel stacks with printed Stagger three")
	var hit: Dictionary = _forecast(engine, value, heavy, Vector2i(3, 4), expect)
	expect.call(int(hit["enemies"][0].get("stagger_this_turn", hit["enemies"][0].get("stagger", 0))) >= 0 and hit["turn_queue"] != value["turn_queue"], "Pommel delays the target initiative in forecast and commit")
	var dragon: Dictionary = state(engine, ["leaden_pommel"])
	dragon["enemies"][0]["type"] = "vyraketh"
	var before: int = engine._apply_stagger_to_enemy(dragon, 1, 4)
	expect.call(before == 2, "Normal dragon halving applies to added Stagger")
	expect.call(engine._apply_stagger_to_enemy(dragon, 1, 20) <= 4, "Normal per-activation Stagger limit applies")

static func _test_fencers_gloves(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["fencers_gloves"], ["brace", "overhead_smash", "quick_stab"])
	var base: int = engine.card_time_cost("overhead_smash", {})
	expect.call(engine.card_time_cost("overhead_smash", value) == base, "Fencer's Gloves idle on the first card")
	value = engine.finish_player_card(value, 0)
	value = _resume(value, expect)
	expect.call(engine.card_time_cost("overhead_smash", value) == base - 1, "Fencer's Gloves hand Time discount survives resume after one card")
	var time_before: int = int(value["player_turn_time_spent"])
	value = engine.finish_player_card(value, 0)
	expect.call(int(value["player_turn_time_spent"]) - time_before == base - 1, "Fencer's Gloves pays the forecast discounted Time")
	expect.call(engine.card_time_cost("overhead_smash", value) == base, "Fencer's Gloves idle on the third card")
	value = engine.prepare_next_player_turn(_resume(value, expect))
	expect.call(engine.card_time_cost("overhead_smash", value) == base, "Fencer's Gloves resets next turn")
	var flurry: Dictionary = state(engine, ["fencers_gloves"], ["blade_dance", "overhead_smash"])
	flurry["cards_per_turn"] = 3
	var repeats: Array = engine.card_play_actions("blade_dance", flurry)
	for action: Dictionary in repeats:
		flurry = engine.apply_player_action(flurry, action, Vector2i(3, 4))
	flurry = engine.finish_player_card(flurry, 0, engine.card_plays_spent_for_actions(repeats))
	flurry["card_play_bonus_this_turn"] = 1
	expect.call(engine.card_time_cost("overhead_smash", flurry) == base - 1, "Flurry's repeated plays count as one card for Gloves")
	flurry["turn_flags"]["quicken_pending"] = 99
	expect.call(engine.card_time_cost("overhead_smash", flurry) == 1, "Gloves stack with Quicken and clamp at one Time")

static func _test_duelist_whetstone(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["duelist_whetstone"])
	var attack: Dictionary = _attack(engine, "sidestep_slash", value)
	var base: int = engine.final_damage_for_player_action(state(engine, []), attack)
	expect.call(engine.final_damage_for_player_action(value, attack) == base, "Duelist Whetstone idle before moving")
	for count: int in [1, 3, 8]:
		value["turn_flags"]["tiles_moved"] = count
		var hit: Dictionary = _forecast(engine, value, attack, Vector2i(3, 4), expect)
		expect.call(100 - int(hit["enemies"][0]["hp"]) == base + mini(count, 3), "Whetstone uses moved tiles and caps at three")
	var plain: Dictionary = _attack(engine, "quick_stab", value)
	expect.call(engine.final_damage_for_player_action(value, plain) == engine.final_damage_for_player_action(state(engine, []), plain), "Whetstone needs a Move or Blink on the same card")
	value = _resume(value, expect)
	expect.call(engine.final_damage_for_player_action(value, attack) == base + 3, "Whetstone tiles-moved bonus survives resume")
	value = engine.prepare_next_player_turn(value)
	expect.call(engine.final_damage_for_player_action(value, attack) == base, "Whetstone tiles reset next turn")
	var moving: Dictionary = state(engine, ["duelist_whetstone"])
	moving["enemies"][0]["pos"] = Vector2i(3, 2)
	var actions: Array = engine.card_play_actions("sidestep_slash", moving)
	moving = _forecast(engine, moving, actions[0], Vector2i(2, 2), expect)
	var after_move: Dictionary = _forecast(engine, moving, actions[1], Vector2i(3, 2), expect)
	expect.call(int(after_move["enemies"][0]["hp"]) == 100 - base - 2, "Earlier Move on the same card supplies Whetstone damage")
	var independent: Dictionary = state(engine, ["duelist_whetstone"])
	independent["enemies"][0]["pos"] = Vector2i(3, 2)
	independent = engine.apply_player_movement(independent, Vector2i(2, 2))
	expect.call(engine.final_damage_for_player_action(independent, attack) == base + 2, "Independent movement supplies Whetstone damage")

static func _test_coffin_nails(expect: Callable) -> void:
	var engine := Combat.new()
	for setup: Dictionary in [{"block": 3, "stoneskin": 0, "damage": 3, "bleed": 1}, {"block": 2, "stoneskin": 0, "damage": 3, "bleed": 0}, {"block": 0, "stoneskin": 3, "damage": 3, "bleed": 0}, {"block": 3, "stoneskin": 0, "damage": 0, "bleed": 0}, {"block": 1, "stoneskin": 2, "damage": 3, "bleed": 1}]:
		var value: Dictionary = state(engine, ["coffin_nails"])
		value["player"]["block"] = setup["block"]
		value["player"]["stoneskin"] = setup["stoneskin"]
		value = _resume(value, expect)
		engine._resolve_board_attack(value, {"type": "ranged", "range": 3, "damage": setup["damage"]}, Vector2i(2, 4), "enemy", 1)
		expect.call(int(value["enemies"][0].get("bleed", 0)) == int(setup["bleed"]), "Coffin Nails needs no health loss and actual Block absorption: %s" % str(setup))
	var value: Dictionary = state(engine, ["coffin_nails"])
	value["player"]["block"] = 20
	engine._resolve_board_attack(value, {"type": "aoe", "damage": 3, "range": 1, "pattern": [[0, 0], [0, 0], [0, 1]]}, Vector2i(2, 4), "enemy", 1)
	expect.call(int(value["enemies"][0].get("bleed", 0)) == 1, "Coffin Nails triggers once even if attack tiles repeat")
	var rescued: Dictionary = state(engine, ["coffin_nails"])
	rescued["player"]["hp"] = 1
	rescued["player"]["block"] = 1
	rescued["defiance_capacity"] = 1
	rescued["defiance_remaining"] = 1
	engine._resolve_board_attack(rescued, {"type": "melee", "range": 1, "damage": 4}, Vector2i(2, 4), "enemy", 1)
	expect.call(int(rescued.get("defiance_remaining", 1)) == 0 and int(rescued["enemies"][0].get("bleed", 0)) == 0, "Defiance recovery cannot masquerade as a fully blocked hit")
	var player_attack: Dictionary = _attack(engine, "quick_stab", value)
	expect.call(int((engine._resolved_surface_action(value, player_attack) as Dictionary).get("bleed", 0)) == 0, "Coffin Nails no longer adds Bleed to hero attacks")

static func _test_briar_vambrace(expect: Callable) -> void:
	var engine := Combat.new()
	var value: Dictionary = state(engine, ["briar_vambrace"], ["brace", "brace"])
	var block: Dictionary = engine.card_play_actions("brace", value)[0]
	value = _forecast(engine, value, block, engine.INVALID_TILE, expect)
	expect.call(int(value.get("retaliate", {}).get("amount", 0)) == 1, "Briar Vambrace grants Retaliate with actual card Block")
	value = _resume(value, expect)
	value = engine.apply_player_action(value, block)
	expect.call(int(value.get("retaliate", {}).get("amount", 0)) == 1, "Briar Vambrace triggers only once per card across resumed actions")
	value = engine.finish_player_card(value, 0)
	value = engine.apply_player_action(value, block)
	expect.call(int(value.get("retaliate", {}).get("amount", 0)) == 2, "Separate Block cards stack Briar Retaliate")
	value = engine.prepare_next_player_turn(_resume(value, expect))
	expect.call(not value.has("retaliate"), "Briar Retaliate expires at next turn start")
	var empty: Dictionary = state(engine, ["briar_vambrace"])
	empty = engine.apply_player_action(empty, {"type": "block", "amount": 0, "_card_id": "brace"})
	empty = engine.apply_player_action(empty, {"type": "stoneskin", "amount": 2, "_card_id": "brace"})
	expect.call(not empty.has("retaliate"), "Briar idle on zero Block or Stoneskin")
	var plain: Dictionary = state(engine, [])
	expect.call(not engine.apply_player_action(plain, block).has("retaliate"), "Block without Briar gives no Retaliate")
	var reward: Dictionary = state(engine, ["briar_vambrace"])
	Surface.place(reward, Vector2i(2, 4), "rubble")
	reward = _forecast(engine, reward, {"type": "consume_surface", "surface": "rubble", "range": 0, "_card_id": "brace", "rewards": [{"type": "block", "amount": 2}, {"type": "block", "amount": 2}]}, engine.INVALID_TILE, expect)
	expect.call(int(reward.get("retaliate", {}).get("amount", 0)) == 1, "Briar counts actual Block from nested card action rewards once")
	var flurry: Dictionary = state(engine, ["briar_vambrace"], ["blade_dance"])
	flurry["cards_per_turn"] = 3
	for action: Dictionary in engine.card_play_actions("blade_dance", flurry):
		flurry = engine.apply_player_action(flurry, action, Vector2i(3, 4))
	expect.call(int(flurry.get("retaliate", {}).get("amount", 0)) == 1, "Briar grants once across actual Flurry Block repetitions")

static func _test_flint_edge(expect: Callable) -> void:
	var engine := Combat.new()
	for surface: String in ["fire", "ice", "electrified", "rubble", ""]:
		var value: Dictionary = state(engine, ["flint_edge"])
		if not surface.is_empty():
			Surface.place(value, Vector2i(3, 4), surface)
		value["enemies"][0]["chilled"] = surface == "ice"
		var attack: Dictionary = {"type": "melee", "range": 1, "damage": 3, "element": "ice"}
		var hit: Dictionary = _forecast(engine, value, attack, Vector2i(3, 4), expect)
		var consumes: bool = surface in ["fire", "ice", "electrified"]
		expect.call(int(hit["enemies"][0]["hp"]) == (94 if consumes else 97), "Flint Edge consumes elemental fuel before damage: %s" % surface)
		expect.call(Surface.element_at(hit, Vector2i(3, 4)).is_empty(), "Flint Edge forecast shows consumed elemental tile")
		expect.call(int(hit["enemies"][0].get("freeze", 0)) == 0, "Flint Edge consumed Ice cannot Freeze")
		if surface == "rubble":
			expect.call(Surface.has_rubble(hit, Vector2i(3, 4)), "Flint Edge preserves Rubble")
	var ranged: Dictionary = state(engine, ["flint_edge"])
	Surface.place(ranged, Vector2i(3, 4), "fire")
	var hit: Dictionary = _forecast(engine, ranged, {"type": "ranged", "range": 3, "damage": 3}, Vector2i(3, 4), expect)
	expect.call(int(hit["enemies"][0]["hp"]) == 97 and Surface.has_surface(hit, Vector2i(3, 4), "fire"), "Flint Edge idle on ranged attacks")
	var big: Dictionary = state(engine, ["flint_edge"])
	big["enemies"][0]["footprint"] = Vector2i(1, 2)
	Surface.place(big, Vector2i(3, 4), "ice")
	Surface.place(big, Vector2i(3, 5), "ice")
	big["enemies"][0]["chilled"] = true
	hit = _forecast(engine, big, {"type": "melee", "range": 1, "damage": 3, "element": "ice"}, Vector2i(3, 4), expect)
	expect.call(Surface.has_surface(hit, Vector2i(3, 5), "ice") and int(hit["enemies"][0].get("freeze", 0)) == 0, "Flint Edge consumes only selected footprint tile and suppresses Freeze")
	var chain: Dictionary = state(engine, ["flint_edge"])
	chain["enemies"].append({"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 100, "max_hp": 100})
	Surface.place(chain, Vector2i(3, 4), "fire")
	Surface.place(chain, Vector2i(4, 4), "fire")
	hit = _forecast(engine, chain, {"type": "melee", "range": 1, "damage": 3, "chain": 1}, Vector2i(3, 4), expect)
	expect.call(int(hit["enemies"][0]["hp"]) == 94 and int(hit["enemies"][1]["hp"]) == 97 and Surface.has_surface(hit, Vector2i(4, 4), "fire"), "Flint Edge consumes and boosts only the primary target, never Chain side hits")
	var conduction: Dictionary = state(engine, ["flint_edge", "coalheart_crucible"])
	conduction["enemies"].append({"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 100, "max_hp": 100})
	Surface.place(conduction, Vector2i(3, 4), "fire")
	Surface.place(conduction, Vector2i(4, 4), "electrified")
	hit = _forecast(engine, conduction, {"type": "melee", "range": 1, "damage": 3, "element": "lightning"}, Vector2i(3, 4), expect)
	expect.call(int(hit["enemies"][0]["hp"]) == 94 and int(hit["enemies"][1]["hp"]) == 100, "Flint's spent Fire cannot also bridge conduction")
	var absent: Dictionary = state(engine, [])
	Surface.place(absent, Vector2i(3, 4), "fire")
	hit = _forecast(engine, absent, {"type": "melee", "range": 1, "damage": 3}, Vector2i(3, 4), expect)
	expect.call(int(hit["enemies"][0]["hp"]) == 97 and Surface.has_surface(hit, Vector2i(3, 4), "fire"), "Melee without Flint neither consumes nor gains damage")
