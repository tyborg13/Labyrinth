extends RefCounted

const Rules = preload("res://scripts/depth_rules.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Store = preload("res://scripts/progression_store.gd")
const Score = preload("res://scripts/run_score_rules.gd")
const Overlay = preload("res://scripts/run_end_recap_overlay.gd")
const Events = preload("res://scripts/event_rules.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const Picker = preload("res://scripts/new_descent_panel.gd")
const PROOF_SEEDS := [307, 8821, 90429]
const FIXTURE_SEED: int = 307
const FIXTURE_TRAVEL_DIR: Vector2i = Vector2i(1, 0)
const FIXTURE_SPAWN_TILE: Vector2i = Vector2i(1, 1)
const FIXTURE_SPAWN_ID: int = 99
const FIXTURE_LETHAL_DAMAGE: int = 100000
const FIXTURE_REWARD_ROLL_COUNT: int = 200
const FIXTURE_ENEMY_BASE_HP: int = 13
const FIXTURE_TEARDOWN_FRAMES: int = 240
const FIXTURE_PURCHASE_BUDGET: int = 10000
const FIXTURE_ROOM_DEPTH: int = 6
const FIXTURE_BOSS_DEPTH: int = 8
# meta-03 proved depth-0 byte-identity against its unchanged task base (6f4bbacfb). After merge there is no
# pre-depth code path left, so these pin the integration state at 90823d36d+ (battle hashes re-pinned after fix-02
# removed run_seconds from combat state and en-03 added section enemies; run hashes unchanged). Re-pin only when an
# unrelated system changes combat creation; a depth change must never move them.
const DEPTH_ZERO_HASHES: Dictionary = {
	307: ["4c59082f194b4c6cb7147490442fb02e71fbbcd53edf642810e9f39286141e40", "34c9e338eb1849db9d67811486eac387383a61aecb9fbab77cf29a807b04b89b", "cc40c0f46c994c058234c2785da9bd3d089c8d773ab066cf204410306e32b786", "43f27f76786ad34f9593b3e0df136c92a2552b0fb94a717352451026e487817a"],
	8821: ["ec4191a9948648e2e9434647a60fbcf41a46694fb9a3d9e4040549792e5820a4", "fc979a8124e0175cf6985b2b8a5835cafeb8a14db8399e1cb02fa5070ebacc9e", "d4c4b8fdb68dc73f063d99cf5dc2781878f00c8ce928c47540d9dd61f8eaba69", "ecee41006a80b0ac148f1891a4954824d41746d6733eb1955d16e96737319b23"],
	90429: ["af6134e19f8fcbc86c815fde43e468acc00f9d21635871341cf5f646e0fee30f", "290cee1a34bd9e28eae7af1bbf86be6d6bb2828f36fb766234583fa7800cfdba", "86a274e9cba6a017d50082b84c0bbb3b2423d4b44d42b0cc9cfd922a204cca1a", "6db5509078f3b14b4db006413c86732c0325b13c0d79d2e51a3c3e77ec19354f"]
}
const PROFILE_PATH: String = "user://meta03-depth-suite-profile.json"
const SAVE_PATH: String = "user://meta03-depth-suite-run.save"

static func run(expect: Callable) -> void:
	var protected_data: String = FileAccess.get_file_as_string(Rules.DATA_PATH)
	_test_gates(expect)
	_test_zero_hashes(expect)
	_test_encounters(expect)
	_test_start_and_rewards(expect)
	_test_shop_prices(expect)
	_test_event_costs(expect)
	_test_progression_and_saves(expect)
	await _test_selection_save_failure(expect)
	await _test_picker(expect)
	expect.call(FileAccess.get_file_as_string(Rules.DATA_PATH) == protected_data, "Depth data remains protected and unchanged")
	print("Depth rules contracts: 20 level gates; 12 depth-zero hashes; encounter classes, costs, score, unlocks, saves, picker and analytics checked")
	print("Depth feedback contracts: all Guardian helpers; 30 px rows / 40 px columns / 17 px hint; session save failure; all Scavenger buy prices checked")

static func _at(depth: int) -> Dictionary:
	return {Rules.STATE_KEY: depth}

static func _profile(unlocked: int, selected: int = 0) -> Dictionary:
	var result: Dictionary = Store.default_data()
	result[Store.UMBRA_DEPTH_UNLOCKED_KEY] = unlocked
	result[Store.UMBRA_DEPTH_SELECTED_KEY] = selected
	return result

static func _value(level: int, depth: int) -> Variant:
	var state: Dictionary = _at(depth)
	match level:
		1: return Rules.guardian_weight(state, 10)
		2: return Rules.damage_bonus(state, {"type": "crawler"})
		3: return Rules.damage_bonus(state, {"type": "ashen_reaver"})
		4: return Rules.damage_bonus(state, {"type": "vyraketh"})
		5: return Rules.hearth_heal(state, 4)
		6: return Rules.start_hp(state, 24)
		7: return Rules.enemy_hp(state, {"type": "crawler"}, FIXTURE_ENEMY_BASE_HP)
		8: return Rules.enemy_hp(state, {"type": "ashen_reaver"}, FIXTURE_ENEMY_BASE_HP)
		9: return Rules.enemy_hp(state, {"type": "vyraketh"}, FIXTURE_ENEMY_BASE_HP)
		10: return str(Rules.modifier(state, "start_omen").get("omen", ""))
		11: return Rules.sight_radius(state, "fringe", 1, 6)
		12: return Rules.rarity_weight(state, "common", Data.rarity_offer_weight("common"))
		13: return Rules.dragon_embers(state, 30)
		14: return Rules.start_max_hp(state, 24)
		15: return [Rules.event_value(state, "hp", -3), Rules.event_value(state, "max_hp", -1), Rules.event_value(state, "embers", -42)]
		16: return Rules.shop_price(state, 175)
		17: return Rules.enemy_initiative(state, {"type": "crawler"}, 4)
		18: return Combat.FATIGUE_BASE_DAMAGE + Rules.amount(state, "fatigue_base_delta")
		19: return Rules.amount(state, "guardian_extra_helper")
		20: return [Rules.enemy_hp(state, {"type": "noctyrax"}, 100), Rules.damage_bonus(state, {"type": "noctyrax"})]
	return null

static func _test_gates(expect: Callable) -> void:
	var before: Array = [10, 0, 0, 0, 4, 24, 13, 13, 13, "", 6, Data.rarity_offer_weight("common"), 30, 24, [-3, -1, -42], 175, 4, 2, 0, [108, 2]]
	var after: Array = [16, 1, 2, 2, 3, 21, 15, 15, 15, "hunted", 5, 12, 23, 22, [-4, -2, -55], 195, 3, 3, 1, [135, 4]]
	var definitions: Array[Dictionary] = Rules.levels(20)
	expect.call(definitions.size() == 20, "The protected ladder has exactly 20 ordered levels")
	for level: int in range(1, 21):
		expect.call(int(definitions[level - 1]["depth"]) == level, "Level %d retains its authored number" % level)
		expect.call(_value(level, level - 1) == before[level - 1], "Modifier %d does not apply below its level" % level)
		expect.call(_value(level, level) == after[level - 1], "Modifier %d applies exactly at its level" % level)
	# Exceptions and interactions that a gate-only test cannot establish.
	expect.call(Rules.damage_bonus(_at(20), {"type": "lightning_wisp", "summoned": true}) == 0, "Ordinary summons receive no class bonus")
	expect.call(Rules.damage_bonus(_at(20), {"type": "lightning_wisp", "summoned": true, "guardian_helper": true}) == 2, "Summoned Guardian helpers use the Guardian class")
	expect.call(Rules.enemy_hp(_at(20), {"type": "lightning_wisp", "summoned": true}, 10) == 10, "Ordinary summons receive no HP modifier")
	for stage: String in ["clear", "eclipse"]:
		expect.call(Rules.sight_radius(_at(20), stage, 1, 6) == 6, "Sight leaves %s unchanged" % stage)
	expect.call(Rules.sight_radius(_at(20), "fringe", 0, 6) == 6 and Rules.sight_radius(_at(20), "heart", 1, 1) == 1, "Sight respects first-section exemption and floor one")
	expect.call(Rules.hearth_heal(_at(20), 1) == 1, "Hearth healing cannot drop below one")
	expect.call(Rules.shop_price(_at(0), 1) == 1, "Depth zero does not round legacy prices")
	for rarity: String in ["common", "rare", "epic", "legendary"]:
		expect.call(Rules.rarity_weight(_at(12), rarity, 99) == int({"common": 12, "rare": 7, "epic": 4, "legendary": 3}[rarity]), "Every authored reward rarity weight is used")

static func _test_zero_hashes(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	for seed: int in PROOF_SEEDS:
		var state: Dictionary = engine.create_new_run(seed, Store.default_data())
		expect.call(_digest(state) == DEPTH_ZERO_HASHES[seed][0], "Depth zero run hash matches pinned integration state: %d" % seed)
		var index: int = 1
		for type: String in ["combat", "guardian", "boss"]:
			for room: Dictionary in state["rooms"].values():
				if str(room["type"]) != type: continue
				var layout: Dictionary = engine._combat_layout_for_room(room, FIXTURE_TRAVEL_DIR, state)
				var battle: Dictionary = combat.create_combat(seed, layout, engine._player_snapshot(state))
				expect.call(_digest(battle) == DEPTH_ZERO_HASHES[seed][index], "Depth zero %s hash matches pinned integration state: %d" % [type, seed])
				index += 1
				break

static func _digest(state: Dictionary) -> String:
	return var_to_bytes(state).hex_encode().sha256_text()

static func _room(type: String, boss: String = "") -> Dictionary:
	return {"depth": FIXTURE_BOSS_DEPTH if type == "boss" else FIXTURE_ROOM_DEPTH, "coord": Vector2i(FIXTURE_BOSS_DEPTH, 0) if type == "boss" else Vector2i(FIXTURE_ROOM_DEPTH, 0), "type": type, "boss_id": boss, "element": "fire", "section_index": 1}

static func _test_encounters(expect: Callable) -> void:
	var generator := Rooms.new()
	var combat := Combat.new()
	var snapshot: Dictionary = {"hp": 24, "max_hp": 24, "deck_cards": ["quick_stab"]}
	for fixture: Array in [["combat", "", 2, 7], ["guardian", "vyraketh", 3, 8], ["boss", "vyraketh", 4, 9], ["boss", "noctyrax", 20, 20]]:
		var room: Dictionary = _room(fixture[0], fixture[1])
		var original: Dictionary = generator.generate_room(FIXTURE_SEED, room, FIXTURE_TRAVEL_DIR)
		for depth: int in [int(fixture[2]) - 1, int(fixture[2]), int(fixture[3]), 20]:
			room[Rules.STATE_KEY] = depth
			var layout: Dictionary = generator.generate_room(FIXTURE_SEED, room, FIXTURE_TRAVEL_DIR)
			var battle: Dictionary = combat.create_combat(FIXTURE_SEED, layout, snapshot)
			expect.call(Rules.depth(battle) == depth, "Combat retains its owning run depth")
			for index: int in range(original["enemies"].size()):
				var enemy: Dictionary = layout["enemies"][index]
				var original_enemy: Dictionary = original["enemies"][index]
				expect.call(int(enemy["max_hp"]) == Rules.enemy_hp(_at(depth), original_enemy, int(original_enemy["max_hp"])), "Generated HP applies after encounter scaling, including helpers and enrage")
				var base_intents: Array = combat._scaled_enemy_intents(Data.enemy_def(str(enemy["type"])).get("intents", []), int(room["depth"]))
				var scaled_intents: Array = combat._scaled_enemy_intents(Data.enemy_def(str(enemy["type"])).get("intents", []), int(room["depth"]), battle, enemy)
				for intent_index: int in range(base_intents.size()):
					for action_index: int in range(base_intents[intent_index]["actions"].size()):
						var base: Dictionary = base_intents[intent_index]["actions"][action_index]
						var scaled: Dictionary = scaled_intents[intent_index]["actions"][action_index]
						var damage: int = int(base.get("damage", 0))
						expect.call(int(scaled.get("damage", 0)) == damage + (Rules.damage_bonus(battle, enemy) if damage > 0 else 0), "Every damaging action has exactly one class bonus; support stays unchanged")
			var regular: Dictionary = {"type": "crawler"}
			var base_initiative: int = combat._enemy_base_initiative({"room_depth": 6}, regular)
			expect.call(combat._enemy_base_initiative(battle, regular) == Rules.enemy_initiative(battle, regular, base_initiative if int(room["depth"]) == 6 else combat._enemy_base_initiative({"room_depth": room["depth"]}, regular)), "Runtime base initiative uses the depth rule")
			expect.call(int(battle["deck"]["fatigue_base"]) == 2 + (1 if depth >= 18 else 0), "Runtime reshuffle fatigue starts at the authored base")
			var spawned: Dictionary = combat._spawned_enemy_entry(battle, "crawler", FIXTURE_SPAWN_ID, FIXTURE_SPAWN_TILE, false)
			expect.call(int(spawned["max_hp"]) == Rules.enemy_hp(battle, spawned, combat._scaled_enemy_max_hp("crawler", int(room["depth"]))), "Objective reinforcements use regular HP scaling")
	# Legal extra helpers are installed after authored Guardian placement.
	for boss: String in ["vyraketh", "iskaldra", "zekarion", "vaeloryx", "tharokh", "noctyrax"]:
		var room: Dictionary = _room("guardian", boss)
		room[Rules.STATE_KEY] = 18
		var before: Dictionary = generator.generate_room(FIXTURE_SEED, room, FIXTURE_TRAVEL_DIR)
		room[Rules.STATE_KEY] = 19
		var after: Dictionary = generator.generate_room(FIXTURE_SEED, room, FIXTURE_TRAVEL_DIR)
		var added: Dictionary = after["enemies"].back()
		var expected_type: String = "rime_whelp" if boss == "iskaldra" else "bell_tender" if boss == "zekarion" else str(preload("res://scripts/guardian_library.gd").for_boss(boss)["helpers"][0])
		expect.call(str(added["type"]) == expected_type and bool(added.get("guardian_helper", false)), "Depth 19 uses the director-approved extra helper type for %s" % boss)
		expect.call(after["enemies"].size() == before["enemies"].size() + 1, "Depth 19 adds one helper for %s" % boss)
		var positions: Dictionary = {after["player_start"]: true}
		for enemy: Dictionary in after["enemies"]:
			expect.call(not positions.has(enemy["pos"]) and preload("res://scripts/path_utils.gd").is_passable(after["grid"], enemy["pos"]), "Extra helpers occupy legal unoccupied tiles")
			positions[enemy["pos"]] = true
		var battle: Dictionary = combat.create_combat(FIXTURE_SEED, after, snapshot)
		var type: String = str(after["enemies"][1]["type"])
		var replacement: Dictionary = combat._spawned_enemy_entry(battle, type, FIXTURE_SPAWN_ID, FIXTURE_SPAWN_TILE, true)
		expect.call(bool(replacement.get("guardian_helper", false)) and int(replacement["max_hp"]) == Rules.enemy_hp(battle, replacement, combat._scaled_enemy_max_hp(type, 6)), "Guardian replacements retain Guardian HP despite being summoned")

static func _test_start_and_rewards(expect: Callable) -> void:
	var engine := Run.new()
	for depth: int in [5, 6, 9, 10, 13, 14, 20]:
		var state: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(20), true, depth)
		expect.call(int(state["player_max_hp"]) == (22 if depth >= 14 else 24), "Max HP delta applies only at run start")
		expect.call(int(state["player_hp"]) == (19 if depth >= 14 else 21 if depth >= 6 else 24), "Wounded start rounds up after max HP delta")
		expect.call(Omens.active(state).size() == (1 if depth >= 10 else 0), "Starting Hunted is gated")
		if depth >= 10:
			expect.call(Omens.active(state)[0]["id"] == "hunted" and int(Omens.active(state)[0]["fights_left"]) == int(Data.omen_def("hunted")["fights"]), "Hunted uses its default authored fights")
		state["player_hp"] = 1
		expect.call(int(engine.leave_campfire(state, Run.CAMPFIRE_LINGER_HEAL)["player_hp"]) == 4, "Hearth linger runtime heals three at depth five and above")
	var base: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	var modified: Dictionary = base.duplicate(true)
	modified[Rules.STATE_KEY] = 12
	var rng := RandomNumberGenerator.new()
	var reference := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	reference.seed = FIXTURE_SEED
	var pools: Dictionary = {"common": ["a"], "rare": ["b"], "epic": ["c"], "legendary": ["d"]}
	for _index: int in range(FIXTURE_REWARD_ROLL_COUNT):
		var roll: int = reference.randi_range(1, 26)
		var expected: String = "common" if roll <= 12 else "rare" if roll <= 19 else "epic" if roll <= 23 else "legendary"
		expect.call(engine._draw_card_reward_rarity(rng, pools, modified) == expected, "Combat reward RNG uses the replacement weights")
	var buy: int = engine.merchant_buy_cost("scavenger", "quick_stab", _at(16))
	var original_buy: int = engine.merchant_buy_cost("scavenger", "quick_stab")
	expect.call(buy == Rules.cost_percent(original_buy, 110), "Scavenger buy API rounds up to a multiple of five")
	expect.call(engine.merchant_sell_value("scavenger", "quick_stab") == maxi(1, roundi(original_buy * Run.MERCHANT_SELL_VALUE_RATIO)), "Scavenger sell prices retain the original base")
	# Award both dragon components through their live ownership boundaries.
	for depth: int in [12, 13]:
		var state: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(20), true, depth)
		var room: Dictionary = _room("boss", "vyraketh")
		state["rooms"][Graph.key(room["coord"])] = room
		state["current_room"] = room["coord"]
		var layout: Dictionary = engine._combat_layout_for_room(room, FIXTURE_TRAVEL_DIR, state)
		var combat := Combat.new()
		var battle: Dictionary = combat.create_combat(FIXTURE_SEED, layout, engine._player_snapshot(state))
		battle = combat._damage_enemy(battle, 0, FIXTURE_LETHAL_DAMAGE)
		expect.call(int(battle["room_embers"]) == (60 if depth >= 13 else 80), "Dragon death reward uses the depth percentage once")
		var finished: Dictionary = engine.finish_combat(state, battle)
		expect.call(int(finished["pending_reward"]["ember_amount"]) == (83 if depth >= 13 else 110), "Dragon reward and victory bonus total use half-up rounding")
		var replay: Dictionary = engine.finish_combat(finished, battle)
		expect.call(engine.held_embers(replay) == engine.held_embers(finished), "Dragon depth rewards remain idempotent")

	# Opposing Ember omens can coexist. For Noctyrax: 120 × 150% × 50%
	# is 90; at Depth 13 the combined (90 + 30) × 75% must be 90,
	# rather than independently rounding 67.5 and 22.5 upward to 91.
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(20), true, 13)
	state = Omens.add(Omens.add(state, "ember_tithe"), "tithe_of_ash")
	var room: Dictionary = _room("boss", "noctyrax")
	state["rooms"][Graph.key(room["coord"])] = room
	state["current_room"] = room["coord"]
	var layout: Dictionary = engine._combat_layout_for_room(room, FIXTURE_TRAVEL_DIR, state)
	var combat := Combat.new()
	var battle: Dictionary = combat.create_combat(FIXTURE_SEED, layout, engine._player_snapshot(state))
	battle = combat._damage_enemy(battle, 0, FIXTURE_LETHAL_DAMAGE)
	var dragon_death: int = int(battle["room_embers"])
	expect.call(dragon_death == 68, "Compound Ember omens retain the immediately presented half-up dragon death reward")
	for index: int in range(1, battle["enemies"].size()): battle = combat._damage_enemy(battle, index, FIXTURE_LETHAL_DAMAGE)
	var non_dragon_rewards: int = int(battle["room_embers"]) - dragon_death
	var finished: Dictionary = engine.finish_combat(state, battle)
	expect.call(int(finished["pending_reward"]["ember_amount"]) - non_dragon_rewards == 90, "Dragon kill plus victory bonus round half up as one combined amount with compound omens")

static func _test_shop_prices(expect: Callable) -> void:
	var engine := Run.new()
	var source: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(20), true, 0)
	var room: Dictionary = {}
	for candidate: Dictionary in source["rooms"].values():
		if str(candidate["type"]) == Run.MERCHANT_SCAVENGER:
			room = candidate
			break
	expect.call(not room.is_empty(), "Shop regression fixture contains a Scavenger")
	if room.is_empty(): return
	source["current_room"] = room["coord"]
	source = engine.set_held_embers(source, FIXTURE_PURCHASE_BUDGET)
	var buyable: Array = engine._available_merchant_equipment_ids(source)
	buyable.append_array(engine._available_merchant_magic_ids(source))
	buyable.append_array(engine._available_merchant_item_ids())
	var shop := Shop.new()
	shop.set("_run_engine", engine)
	for depth: int in [0, 13, 16]:
		for item_id: String in buyable:
			var state: Dictionary = source.duplicate(true)
			if depth > 0: state[Rules.STATE_KEY] = depth
			state["rooms"][Graph.key(room["coord"])][Run.MERCHANT_STOCK_KEY] = [item_id]
			shop.set("_run_state", state)
			var base_price: int = engine.merchant_buy_cost(Run.MERCHANT_SCAVENGER, item_id)
			var expected: int = Rules.shop_price(state, base_price)
			var tag: Control = shop._price_tag(item_id, false)
			var tooltip: String = shop._offer_tooltip(item_id, false, true)
			var bought: Dictionary = engine.buy_merchant_item(state, Run.MERCHANT_SCAVENGER, item_id)
			var paid: int = engine.held_embers(state) - engine.held_embers(bought)
			expect.call(int(tag.get("amount")) == paid and paid == expected, "Depth %d displayed and charged prices match for %s" % [depth, item_id])
			expect.call(tooltip.contains("Price: %d embers" % paid), "Shop tooltip displays the charged buy price")
			expect.call(shop._item_price(item_id, true) == engine.merchant_sell_value(Run.MERCHANT_SCAVENGER, item_id), "Depth modifiers never change shop sell prices")
			if depth in [0, 13]: expect.call(paid == base_price, "Protected shop modifier remains gated below depth sixteen")
			state = engine.set_held_embers(state, paid - 1)
			shop.set("_run_state", state)
			expect.call(not shop._offer_is_affordable(item_id, false), "Buy affordability uses the charged depth price")
			tag.free()
	shop.free()
	print("Depth shop price regression: %d buyable items x depths 0, 13, 16" % buyable.size())

static func _test_event_costs(expect: Callable) -> void:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(20), true, 15)
	state["held_embers"] = 100
	state["unbanked_embers"] = 100
	var effects: Array = [{"type": "hp", "amount": -3}, {"type": "max_hp", "amount": -1}, {"type": "embers", "amount": -42}]
	var result: Dictionary = Events.apply_effects(state, effects, Events.rng_for(state, "depth-test"), engine)
	expect.call(int(result["outcomes"][0]["amount"]) == -4 and int(result["outcomes"][1]["amount"]) == -2 and int(result["outcomes"][2]["amount"]) == -55, "Event runtime scales only the three authored negative cost types")
	var lines: Array[String] = Events.effect_lines(state, effects)
	expect.call(lines[0] == "Lose 4 @icon(health)." and lines[1] == "−2 max @icon(health)." and lines[2] == "Pay 55 Embers.", "Event previews show the exact scaled costs")
	var benefit: Dictionary = Events.apply_effects(state, [{"type": "hp", "amount": 1}, {"type": "max_hp", "amount": 1}, {"type": "embers", "amount": 42}], Events.rng_for(state, "benefits"), engine)
	expect.call(int(benefit["outcomes"][1]["amount"]) == 1 and int(benefit["outcomes"][2]["amount"]) == 42, "Event benefits stay unchanged")
	for type: String in ["hp_above", "max_hp_above", "embers_at_least"]:
		expect.call(Rules.event_requirement(state, type, 42) == (55 if type == "embers_at_least" else 43), "Event eligibility uses the same scaled %s threshold" % type)
	# Exercise the real choice eligibility rather than only arithmetic helpers.
	for id: String in Data.events():
		for choice: Dictionary in Data.event_def(id).get("choices", []):
			for requirement: Dictionary in choice.get("requires", []):
				var type: String = str(requirement["type"])
				if type != "embers_at_least": continue
				var required: int = Rules.event_requirement(state, type, int(requirement["amount"]))
				state["held_embers"] = required - 1
				expect.call(Events.choice_block_reason(state, id, str(choice["id"])) == "Requires %d Embers." % required, "Live event eligibility blocks one Ember below the scaled payment")
				state["held_embers"] = required
	var nested: Array[String] = Events.effect_lines(state, [{"type": "random", "outcomes": [{"weight": 100, "effects": effects}]}])
	expect.call(nested[0].contains("Pay 55 Embers."), "Nested random-event cost previews scale once")

static func _test_progression_and_saves(expect: Callable) -> void:
	var engine := Run.new()
	var profile: Dictionary = Store.default_data()
	expect.call(Store.unlocked_umbra_depth(profile) == 0 and Store.selected_umbra_depth(profile) == 0, "Legacy profile has no unlock and selects zero")
	for depth: int in range(21):
		var state: Dictionary = {Rules.STATE_KEY: depth, "mode": "victory", "run_stats": {"rooms_explored": 1, "dragons_slain": ["noctyrax"], "run_seconds": 3600}, "relics": ["a", "b", "c", "d"]}
		var recorded: Dictionary = Store.record_run_result(profile, "depth-escape-%d" % depth, Overlay.result_stats(state))
		profile = recorded["data"]
		expect.call(Store.unlocked_umbra_depth(profile) == mini(20, depth + 1), "Escape at max depth %d unlocks exactly the next depth" % depth)
		var replay: Dictionary = Store.record_run_result(profile, "depth-escape-%d" % depth, Overlay.result_stats(state))
		expect.call(not bool(replay["recorded"]) and Store.unlocked_umbra_depth(replay["data"]) == Store.unlocked_umbra_depth(profile), "Terminal replay never increments the unlock")
		expect.call(Store.depth_best_scores(profile).has(str(depth)), "Profile retains a best score for depth %d" % depth)
	expect.call(Store.deepest_umbra_escape(profile) == 20, "Escaping depth twenty records the deepest escape after the cap")
	var older: Dictionary = {Rules.STATE_KEY: 2, "mode": "victory", "run_stats": {"dragons_slain": ["noctyrax"]}}
	var unchanged: Dictionary = Store.record_run_result(_profile(5), "lower-escape", Overlay.result_stats(older))["data"]
	expect.call(Store.unlocked_umbra_depth(unchanged) == 5, "Escapes below the unlocked maximum do not advance it")
	for outcome: String in ["defeat", "embrace"]:
		older["mode"] = outcome
		expect.call(Store.unlocked_umbra_depth(Store.record_run_result(_profile(2), outcome, Overlay.result_stats(older))["data"]) == 2, "Only escape unlocks; %s does not" % outcome)
	older["mode"] = "victory"
	older["run_stats"] = {}
	expect.call(Store.unlocked_umbra_depth(Store.record_run_result(_profile(2), "debug-boss", Overlay.result_stats(older))["data"]) == 2, "A debug victory without Noctyrax does not unlock")
	var scored_state: Dictionary = {"run_stats": {"rooms_explored": 1, "max_single_hit": 20}}
	var base_score: int = int(Score.score(scored_state, "defeat")["total"])
	for depth: int in [0, 1, 3, 20]:
		scored_state[Rules.STATE_KEY] = depth
		var score: Dictionary = Score.score(scored_state, "defeat")
		expect.call(int(score["total"]) == base_score + floori(base_score * depth * 0.05 + 0.5), "Score multiplies the complete final total including feats")
		if depth > 0:
			var row: Dictionary = score["lines"].back()
			expect.call(row["label"] == "Umbra Depth %d" % depth and row["detail"] == "+%d%%" % (depth * 5) and int(row["points"]) == int(score["total"]) - base_score, "Depth score is the last base row before feats")
		var model: Dictionary = Overlay.build_model(scored_state, profile, "defeat", 0)
		expect.call(str(model["eyebrow"]).contains("Umbra Depth") == (depth > 0), "Run-end depth line appears only above zero")
	var previous_profile: String = Store._storage_path
	var previous_run: String = Store._run_storage_path
	Store.set_storage_path(PROFILE_PATH)
	Store.set_run_storage_path(SAVE_PATH)
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(3, 3))
	expect.call(Store.save_data(state["progression"]) and Store.save_run_state(state), "Depth profile and run save successfully")
	var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(Rules.depth(loaded) == 3 and Store.selected_umbra_depth(Store.load_data()) == 3, "Save/load retains the immutable run depth and remembered picker depth")
	loaded = engine.apply_progression_update(loaded, _profile(20, 1))
	expect.call(Rules.depth(loaded) == 3, "Changing the profile selection never changes an active run")
	var old: Dictionary = engine.create_new_run(FIXTURE_SEED, _profile(3, 3), true, 0)
	expect.call(Store.save_run_state(old) and Rules.depth(engine.repair_loaded_run_state(Store.load_saved_run())) == 0, "Old saves without umbra_depth load as zero despite a nonzero profile selection")
	old[Rules.STATE_KEY] = 20
	expect.call(Rules.depth(engine.repair_loaded_run_state(old)) == 3, "Edited stored run depth clamps to the unlocked maximum")
	expect.call(Store.selected_umbra_depth(_profile(3, 20)) == 3, "Edited picker selection clamps to unlocked")
	Store.clear_saved_run()
	Store.set_storage_path(previous_profile)
	Store.set_run_storage_path(previous_run)

static func _test_selection_save_failure(expect: Callable) -> void:
	var previous_profile: String = Store._storage_path
	var previous_run: String = Store._run_storage_path
	var previous_depth: int = Store._session_umbra_depth
	var previous_failure: bool = Store._session_depth_save_failed
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root_metadata: Dictionary = {}
	for key: String in ["labyrinth_resume_saved_run", "labyrinth_debug_boss_run", "labyrinth_performance_probe_seed"]:
		if tree.root.has_meta(key):
			root_metadata[key] = tree.root.get_meta(key)
			tree.root.remove_meta(key)
	tree.root.set_meta("labyrinth_performance_probe_seed", FIXTURE_SEED)
	Store.set_storage_path(PROFILE_PATH)
	Store.set_run_storage_path(SAVE_PATH)
	Store.clear_saved_run()
	Store._session_umbra_depth = -1
	Store._session_depth_save_failed = false
	expect.call(Store.save_data(_profile(20, 0)), "Save-failure fixture has a readable profile")
	var blocked_temp: String = Store._profile_temp_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_temp))
	var marker: String = blocked_temp.path_join("keep")
	var file := FileAccess.open(marker, FileAccess.WRITE)
	file.store_string("selection write failure fixture")
	file.close()
	Store.remember_umbra_depth(Store.load_data(), 2)
	Store.remember_umbra_depth(Store.load_data(), 3)
	expect.call(Store.selected_umbra_depth(Store.load_data()) == 0 and Store.session_umbra_depth(Store.load_data()) == 3, "Failed selection writes retain the choice in session memory")
	expect.call(Store._session_depth_save_failed, "Repeated selection failures share one logged failure episode")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set("_defer_initial_run_presentation", true)
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var state: Dictionary = scene.get("_run_state")
	expect.call(Rules.depth(state) == 3 and str(state.get("mode", "")) == "room", "Production starts at the chosen depth despite preference-save failure")
	expect.call(Rules.depth(Store.load_saved_run()) == 3, "The chosen descent remains durable in its run save")
	expect.call(str(state.get("notice", "")) == "", "Preference-save failure adds no player-facing message")
	for _frame: int in range(FIXTURE_TEARDOWN_FRAMES):
		await tree.process_frame
		if not bool(scene.get("_pile_dialog_pool_warm_scheduled")): break
	await tree.process_frame
	await tree.process_frame
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_temp))
	Store.clear_saved_run()
	Store.set_storage_path(previous_profile)
	Store.set_run_storage_path(previous_run)
	Store._session_umbra_depth = previous_depth
	Store._session_depth_save_failed = previous_failure
	tree.root.remove_meta("labyrinth_performance_probe_seed")
	for key: String in root_metadata: tree.root.set_meta(key, root_metadata[key])
	await tree.process_frame

static func _test_picker(expect: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var picker := Picker.new()
	picker.configure(_profile(12), 3)
	tree.root.add_child(picker)
	await tree.process_frame
	await tree.process_frame
	expect.call(picker.get_node("DepthDialog").size == Vector2(860, 780), "Picker uses the approved panel dimensions")
	expect.call(picker.find_child("ModifierText3", true, false).get("text") == Rules.levels(3)[2]["text"], "Picker displays protected text verbatim")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	expect.call(picker.handle_input(key) and picker.selected_depth == 4, "Keyboard Right advances the selected depth")
	(picker.find_child("DepthNext", true, false) as Button).pressed.emit()
	expect.call(picker.selected_depth == 5, "Native mouse-button activation advances depth")
	(picker.find_child("DepthPrevious", true, false) as Button).pressed.emit()
	expect.call(picker.selected_depth == 4, "Native mouse-button activation decreases depth")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	expect.call(picker.handle_input(pad) and picker.selected_depth == 3, "Controller LB decreases the selected depth")
	var activated: Array[int]
	picker.begin_requested.connect(func(value: int) -> void: activated.append(value))
	key.keycode = KEY_ENTER
	picker.handle_input(key)
	pad.button_index = JOY_BUTTON_A
	picker.handle_input(pad)
	expect.call(activated.size() == 2 and activated[0] == 3 and activated[1] == 3, "Enter and controller A begin the chosen depth")
	var cancelled: Array[bool]
	picker.back_requested.connect(func() -> void: cancelled.append(true))
	key.keycode = KEY_ESCAPE
	picker.handle_input(key)
	pad.button_index = JOY_BUTTON_B
	picker.handle_input(pad)
	expect.call(cancelled.size() == 2, "Esc and controller B back out")
	picker.configure(_profile(12), 12)
	expect.call(picker.find_child("DepthNext", true, false).get("disabled"), "Arrow at unlocked maximum is locked")
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	picker.handle_input(pad)
	expect.call(picker.selected_depth == 12, "RB cannot enter a locked depth")
	picker.configure(_profile(12), 0)
	expect.call(picker.find_child("DepthPrevious", true, false).get("disabled") and picker.find_child("DepthZeroRule", true, false).get("text") == "The Umbra as you first knew it.", "Zero depth has its single approved line and a locked left arrow")
	for depth: int in [3, 10, 12, 20]:
		picker.configure(_profile(20), depth)
		await tree.process_frame
		await tree.process_frame
		for level: Dictionary in Rules.levels(depth):
			var label: Label = picker.find_child("ModifierText%d" % int(level["depth"]), true, false)
			expect.call(label.get_theme_font_size("font_size") == (19 if depth > 10 else 21), "Picker keeps the specified modifier type sizes")
			var number: Label = picker.find_child("ModifierNumber%d" % int(level["depth"]), true, false)
			expect.call(number.get_theme_font_size("font_size") == 15 and number.get_theme_color("font_color") == preload("res://scripts/ui_palette.gd").TEXT_3, "Dense numbers retain UI 15 px TEXT_3")
			if depth > 10:
				expect.call(is_equal_approx(number.position.y, float((int(level["depth"]) - 1) % 10) * 30), "Dense rows use exactly 30 px pitch")
		if depth > 10:
			var first: Label = picker.find_child("ModifierText1", true, false)
			var second: Label = picker.find_child("ModifierText11", true, false)
			expect.call(is_equal_approx(second.position.x - first.position.x - first.size.x - 44, 40), "Dense columns use exactly 40 px gap")
		var hint: Label = picker.find_child("DepthUnlockHint", true, false)
		expect.call(hint.get_theme_font_size("font_size") == 17 and hint.get_theme_color("font_color") == preload("res://scripts/ui_palette.gd").TEXT_3, "Unlock hint uses Text 17 px TEXT_3")
	picker.queue_free()
	await tree.process_frame
	_test_analytics(expect)

static func _test_analytics(expect: Callable) -> void:
	var script = load("res://scripts/run_scene.gd")
	var scene: Control = script.new()
	var state: Dictionary = {Rules.STATE_KEY: 3, "seed": 307, "analytics": {"run_id": "meta03-analytics"}}
	var context: Dictionary = scene._analytics_context_from_states(state)
	expect.call(int(context["depth"]) == 3 and int(scene._analytics_context_from_states({})["depth"]) == 0, "Live run analytics context carries additive depth with a zero fallback")
	expect.call(int(Score.analytics_context(state)["depth"]) == 3, "Durable run-scored analytics carry the same depth")
	var previous_dir: String = Analytics.storage_dir()
	Analytics.set_storage_dir("user://meta03-depth-suite-analytics")
	Analytics.clear_storage()
	scene.set("_run_state", state)
	scene.set("_analytics_store", Analytics.new())
	scene._analytics_log_run_started()
	scene._analytics_log_run_ended("defeat")
	var events: Array[Dictionary] = Analytics.load_all_events()
	expect.call(events.size() == 2, "Depth start/end append exactly two local analytics records")
	for event: Dictionary in events:
		expect.call(int(event["payload"]["depth"]) == 3, "Run start/end JSONL payloads carry depth")
	Analytics.set_storage_dir(previous_dir)
	scene.free()
