extends SceneTree

const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Snapshots = preload("res://scripts/analytics_snapshots.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const Events = preload("res://scripts/event_rules.gd")
const Books = preload("res://scripts/grimoire_library.gd")
const Search = preload("res://scripts/grimoire_search.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Generator = preload("res://scripts/room_generator.gd")
const PreviewBuilder = preload("res://scripts/item_preview_builders.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const ShopFixture = preload("res://tests/suites/magic_deck_suite.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const FIXTURE_SEED: int = 90211
const CART_SEED: int = 382
const FIRST_DROP_SEED_COUNT: int = 200
const FALLBACK_REVIEW_SEED: int = 4
const FALLBACK_FIRST_FIGHT := Vector2i(1, 1)
const FALLBACK_SECOND_FIGHT := Vector2i(0, -1)
const FALLBACK_ROLL_SALT: int = 1201
const CART_FIRST_FIGHT: Vector2i = Vector2i(1, 0)
const CART_SECOND_FIGHT: Vector2i = Vector2i(-1, 1)
const ROLL_SCAN_LIMIT: int = 256
const STORE_PATH: String = "user://gear_02_rules.save"
const ANALYTICS_DIR: String = "user://gear_02_analytics"
const STARTER_DECK: Array[String] = Array([
	"quick_stab", "whirlwind_slash", "bloody_lunge", "brace", "guarded_step",
	"patch_up", "shadow_step", "sidestep_slash", "hamstring_shot",
	"pale_spark", "dull_bolt", "waning_pulse", "buffet"
], TYPE_STRING, "", null)
const ADJACENT_TILES: Array[Vector2i] = Array([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT], TYPE_VECTOR2I, "", null)

class BlockedOpeningRun extends Run:
	var block_equipment_pickup: bool = true

	func _combat_layout_for_room(room: Dictionary, travel_dir: Vector2i, run_state: Dictionary) -> Dictionary:
		var layout: Dictionary = super._combat_layout_for_room(room, travel_dir, run_state)
		if block_equipment_pickup:
			layout["loot"] = layout["loot"].filter(func(loot: Dictionary) -> bool: return loot["kind"] != "equipment")
		return layout

var _expectations: int = 0
var _failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Store.set_run_storage_path(STORE_PATH)
	var engine := Run.new()
	var run: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	_test_starter(run)
	_test_rolls(engine, run)
	_test_ordinary_drop_pools(engine, run)
	_test_seeded_first_drops(engine)
	_test_opening_fight(engine, run)
	_test_blocked_pickup()
	_test_trinket_fallback(engine, run)
	_test_trinket_fallback_once(engine)
	_test_lantern(engine, run)
	_test_guardian_award_analytics(engine, run)
	_test_lantern_pools(engine)
	_test_lantern_grimoire()
	_test_existing_save(engine, run)
	print("GEAR-02 RULES: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _expectations, _failures])
	quit(0 if _failures == 0 else 1)

func _test_starter(run: Dictionary) -> void:
	_expect(run["deck_cards"] == STARTER_DECK, "New run compiles the 13 approved cards in order")
	_expect(run["equipped_equipment"]["trinket"] == "" and not run["collected_equipment"].has(Data.UMBRA_REWARD_EQUIPMENT_ID), "New run starts without the Lantern")
	var snapshot: Dictionary = Snapshots.run_started(run, run["progression"])
	_expect(snapshot["starting_deck"] == STARTER_DECK and snapshot["starting_deck_hash"] == JSON.stringify(STARTER_DECK).sha256_text(), "Run-start analytics carries the exact deck and its hash")
	_expect(not Data.card_def("quick_stab").has("follow_up") and _action("quick_stab", 0)["damage"] == 6, "Quick Stab deals 6 with no Follow-up")
	_expect(_action("whirlwind_slash", 0)["damage"] == 8 and _hits_adjacent_tiles(_action("whirlwind_slash", 0)), "Whirlwind Slash hits all four adjacent tiles for 8")
	_expect(not Data.card_def("bloody_lunge").has("empower") and _action("bloody_lunge", 0)["range"] == 2 and _action("bloody_lunge", 1)["damage"] == 9, "Bloody Lunge moves 2 and strikes for 9 with no Empower")
	_expect(_action("brace", 0)["amount"] == 6, "Brace still gives 6 Block")
	_expect(Data.card_def("guarded_step")["actions"].size() == 2 and _action("guarded_step", 0)["range"] == 2 and _action("guarded_step", 1)["amount"] == 5, "Guarded Step moves 2 and gives 5 Block with no Card Play")
	_expect(not Data.card_def("patch_up")["burn"] and Data.card_def("patch_up")["actions"] == [{"type": "block", "amount": 8}], "Patch Up gives 8 Block with no Heal or Exhaust")
	_expect(Data.card_def("shadow_step")["time"] == 2 and Data.card_def("shadow_step")["actions"].size() == 1 and _action("shadow_step", 0)["type"] == "move" and _action("shadow_step", 0)["range"] == 4, "Shadow Step moves 4 at 2 Time with no Blink or Draw")
	_expect(_action("hamstring_shot", 0)["range"] == 2 and _action("hamstring_shot", 1)["damage"] == 3 and _action("hamstring_shot", 1)["push"] == 1 and not _action("hamstring_shot", 1).has("immobilize"), "Low Sweep moves 2, strikes for 3 and Pushes 1")
	_expect(_action("waning_pulse", 0)["damage"] == 3 and _action("waning_pulse", 0)["push"] == 1 and _hits_adjacent_tiles(_action("waning_pulse", 0)), "Waning Pulse hits all adjacent tiles for 3 and Pushes 1")
	_expect(Data.card_element("buffet") == "air" and _action("buffet", 0)["amount"] == 2, "Existing Buffet replaces Lantern Shot")
	for card_id: String in STARTER_DECK:
		var definition: Dictionary = Data.card_def(card_id)
		_expect(not definition["burn"] and definition["health_cost"] == 0 and not definition.has("empower") and not definition.has("follow_up"), "%s uses only opening rules" % card_id)

func _test_rolls(engine: RefCounted, run: Dictionary) -> void:
	var state: Dictionary = run.duplicate(true)
	var room: Dictionary = {"type": "combat", "section_index": 0}
	var section_one_rate: int = Run.SECTION_ONE_EQUIPMENT_DROP_PERCENT
	for target: int in [37, 38, section_one_rate - 1, section_one_rate]:
		room["coord"] = _coord_for_roll(engine, int(state["seed"]), target)
		state[Run.FIRST_COMBAT_WON_KEY] = false
		_expect(not engine._equipment_drop_for_room(state, room).is_empty(), "First-fight reserve overrides roll %d" % target)
		state[Run.FIRST_COMBAT_WON_KEY] = true
		var first_section: bool = not engine._equipment_drop_for_room(state, room).is_empty()
		_expect(first_section == (target < section_one_rate), "Section I boundary at roll %d" % target)
		room["section_index"] = 1
		var second_section: bool = not engine._equipment_drop_for_room(state, room).is_empty()
		_expect(second_section == (target < 38), "Section II boundary at roll %d" % target)
		room["section_index"] = 0
	state["equipment_drop_misses"] = Run.EQUIPMENT_DROP_PITY_MISSES
	_expect(not engine._equipment_drop_for_room(state, room).is_empty(), "Two misses preserve the pity drop")
	room["cleared"] = true
	_expect(engine._equipment_drop_for_room(state, room).is_empty(), "Cleared rooms remain ineligible")
	room["cleared"] = false
	room["type"] = "guardian"
	_expect(engine._equipment_drop_for_room(state, room).is_empty(), "Guardians remain ineligible")
	_expect(not engine._available_equipment_drop_ids(state).has(Data.UMBRA_REWARD_EQUIPMENT_ID), "Random drops exclude the fixed Umbra reward")
	_expect(not engine._available_merchant_equipment_ids(state).has(Data.UMBRA_REWARD_EQUIPMENT_ID), "Random merchant stock excludes the fixed Umbra reward")

func _test_seeded_first_drops(engine: RefCounted) -> void:
	for seed_value: int in range(FIRST_DROP_SEED_COUNT):
		var run: Dictionary = engine.create_new_run(seed_value, Store.default_data())
		var coord: Vector2i = _first_combat_room(engine, run)
		var entered: Dictionary = engine.move_to_room(run, coord)
		var pickups: Array = _equipment_pickups(entered["combat_state"])
		_expect(_is_single_non_trinket_pickup(pickups), "Seed %d places one non-trinket in its opening fight" % seed_value)
		var selected: String = engine._equipment_drop_for_room(run, engine.room_metadata(run, coord))
		_expect(pickups.size() == 1 and pickups[0]["equipment_id"] == selected, "Seed %d reselects the same opening gear" % seed_value)

func _test_ordinary_drop_pools(engine: RefCounted, run: Dictionary) -> void:
	var state: Dictionary = run.duplicate(true)
	state[Run.FIRST_COMBAT_WON_KEY] = true
	for section_index: int in [0, 1]:
		var trinket_found: bool = false
		for x: int in range(ROLL_SCAN_LIMIT):
			var room: Dictionary = {"type": "combat", "section_index": section_index, "coord": Vector2i(x, 0)}
			var selected: String = engine._equipment_drop_for_room(state, room)
			if Data.equipment_slot(selected) == "trinket":
				trinket_found = true
				break
		_expect(trinket_found, "Ordinary Section %d drops can still select a trinket from the full pool" % (section_index + 1))

func _test_opening_fight(engine: RefCounted, run: Dictionary) -> void:
	var coord: Vector2i = _first_combat_room(engine, run)
	var prepared: Dictionary = engine.move_to_pre_battle(run, coord)
	var entered: Dictionary = engine.begin_pre_battle_combat(prepared)
	var battle: Dictionary = entered["combat_state"]
	var pickups: Array = _equipment_pickups(battle)
	_expect(_is_single_non_trinket_pickup(pickups), "Real first-fight board has exactly one non-trinket pickup")
	if pickups.size() == 1:
		var start_record: Dictionary = Snapshots.combat_started(Combat.new(), engine, entered, battle, "test")
		_expect(start_record["equipment_drops"] == [pickups[0]["equipment_id"]], "Combat-start analytics records the guaranteed pickup from the board")
	_expect(entered["equipment_drop_misses"] == 0 and not entered[Run.FIRST_COMBAT_WON_KEY], "Placing the pickup resets pity but leaves the first win pending")
	var defeated: Dictionary = battle.duplicate(true)
	defeated["player"]["hp"] = 0
	var loss: Dictionary = engine.finish_combat(entered, defeated)
	_expect(loss["mode"] == "defeat" and not loss[Run.FIRST_COMBAT_WON_KEY], "Defeat leaves the first-win guarantee pending")
	var victory: Dictionary = engine.finish_combat(entered, _won_battle(battle))
	_expect(victory["mode"] == "reward" and victory[Run.FIRST_COMBAT_WON_KEY], "Winning spends the guarantee and opens the normal reward")
	var resolved_loot: Array = _equipment_pickups(victory["pending_reward"]["board_state"])
	_expect(resolved_loot.size() == 1 and resolved_loot[0]["resolution"] == "missed", "Unclaimed opening gear still resolves through the ordinary missed-pickup flow")
	var claimed_battle: Dictionary = _won_battle(battle)
	_equipment_pickups(claimed_battle)[0]["claimed"] = true
	_expect(engine.finish_combat(entered, claimed_battle)[Run.FIRST_COMBAT_WON_KEY], "Claimed pickup still fulfills the first-win reserve")
	_expect(Store.save_run_state(victory), "First victory writes a save")
	var resumed: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	_expect(resumed[Run.FIRST_COMBAT_WON_KEY], "First win survives save and resume")

	var guided_run: Dictionary = Guided.mark_run_eligible(run)
	var guided: Dictionary = engine.move_to_room(guided_run, coord)["combat_state"]
	var guided_prepared: Dictionary = engine.move_to_pre_battle(guided_run, coord)
	var guided_dossier: Dictionary = engine.begin_pre_battle_combat(guided_prepared)["combat_state"]
	pickups = _equipment_pickups(guided)
	_expect(Guided.is_authored(guided) and pickups.size() == 1, "Authored tutorial retains one reserved pickup")
	_expect(_is_single_non_trinket_pickup(pickups), "Authored tutorial places a non-trinket")
	_expect(pickups == _equipment_pickups(guided_dossier), "Direct entry and dossier commit produce the same tutorial pickup")
	if pickups.size() == 1:
		_expect(pickups[0]["pos"] != Guided.move_tile(guided), "Tutorial pickup stays off the scripted movement destination")

func _test_lantern(engine: RefCounted, run: Dictionary) -> void:
	var coord: Vector2i = _first_combat_room(engine, run)
	var entered: Dictionary = engine.move_to_room(run, coord)
	var battle: Dictionary = _won_battle(entered["combat_state"])
	battle["umbra"]["stage"] = Combat.UMBRA_STAGE_CLEAR
	var item: String = Data.UMBRA_REWARD_EQUIPMENT_ID
	var clear_win: Dictionary = engine.finish_combat(entered, battle)
	_expect(not clear_win["equipment_inventory"].has(item), "Clear combat never grants the Lantern")
	battle["umbra"]["stage"] = Combat.UMBRA_STAGE_FRINGE
	var first_umbra_win: Dictionary = engine.finish_combat(entered, battle)
	_expect(first_umbra_win["equipment_inventory"].count(item) == 1 and first_umbra_win["collected_equipment"].has(item), "Even an opening fight in Umbra grants the Lantern on victory")
	var combat_engine := Combat.new()
	var board: Dictionary = first_umbra_win["pending_reward"]["board_state"]
	_expect(Snapshots.combat_ended(combat_engine, board, "card_play")["collected_equipment"].count(item) == 1, "Lantern appears once in combat_ended.collected_equipment")
	_expect(Snapshots.reward_offered(engine, first_umbra_win, "card_play").get("awarded_equipment", []) == [item], "Combat reward offer attributes the Lantern")
	_expect(engine.loadout_unread_ids(first_umbra_win, "equipment").has(item) and not first_umbra_win["deck_cards"].has("lantern_shot"), "Award uses the normal inventory and notification before equipping")
	_expect(Store.save_run_state(first_umbra_win), "The fixed award writes a save")
	var resumed: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	_expect(resumed[Run.UMBRA_LANTERN_REWARD_KEY] and resumed["equipment_inventory"].count(item) == 1, "Lantern ownership and receipt survive save/resume")
	var equipped: Dictionary = engine.equip_equipment(engine.skip_reward_for_heal(resumed), item)
	_expect(equipped["equipped_equipment"]["trinket"] == item and equipped["deck_cards"].count("lantern_shot") == 1, "Normal equip flow activates Lantern Shot exactly once")
	var shop: Dictionary = ShopFixture.shop_fixture(engine)
	for key: String in ["equipment_inventory", "collected_equipment", Run.UMBRA_LANTERN_REWARD_KEY]:
		shop[key] = resumed[key]
	var sold: Dictionary = engine.sell_merchant_item(shop, Run.MERCHANT_SCAVENGER, item)
	_expect(not sold["equipment_inventory"].has(item) and sold[Run.UMBRA_LANTERN_REWARD_KEY], "Selling the Lantern retains the permanent award receipt")
	_expect(Store.save_run_state(sold), "Sold Lantern receipt writes a save")
	var sold_resumed: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	_expect(sold_resumed[Run.UMBRA_LANTERN_REWARD_KEY] and not engine.merchant_offer_ids(sold_resumed, Run.MERCHANT_SCAVENGER).has(item), "A saved sale keeps the receipt and the Lantern out of merchant stock")
	var later: Dictionary = entered.duplicate(true)
	later[Run.FIRST_COMBAT_WON_KEY] = true
	_expect(engine.finish_combat(later, battle)["equipment_inventory"].count(item) == 1, "Earlier clear victories leave the first Umbra award available")
	later[Run.UMBRA_LANTERN_REWARD_KEY] = true
	_expect(not engine.finish_combat(later, battle)["equipment_inventory"].has(item), "A later Umbra win cannot reissue a sold Lantern")
	entered["equipped_equipment"]["trinket"] = item
	var already_owned: Dictionary = engine.finish_combat(entered, battle)
	_expect(not already_owned["equipment_inventory"].has(item), "A run already wearing the Lantern skips the duplicate")

func _test_existing_save(engine: RefCounted, run: Dictionary) -> void:
	var legacy: Dictionary = run.duplicate(true)
	var equipped: Dictionary = Data.starting_equipped_equipment(true)
	var deck: Array = Data.compile_deck_cards(equipped, Data.starting_magic_cards(true))
	legacy.erase(Run.FIRST_COMBAT_WON_KEY)
	legacy.erase(Run.RunDeck.STARTER_BUFFET_SLOT_KEY)
	legacy["equipped_equipment"] = equipped
	legacy["collected_equipment"] = equipped.values()
	legacy["attuned_magic_cards"] = Data.starting_magic_cards(true)
	legacy["deck_cards"] = deck
	legacy.erase(Books.UNLOCKED_KEY)
	legacy.erase(Books.UNREAD_KEY)
	_expect(Store.save_run_state(legacy), "Pre-gear-02 save writes")
	var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	for keyword: String in ["keyword:follow_up", "keyword:empower", "keyword:blink"]:
		_expect(Books.entry_ids_for_run_state(loaded).has(keyword), "Legacy starter cards discover " + keyword)
		_expect(loaded[Books.UNLOCKED_KEY].has(keyword), "Continuing without discovery receipts unlocks legacy " + keyword)
		_expect(not Books.entry_ids_for_run_state(run).has(keyword), "The current starter does not discover " + keyword)
	_expect(loaded["deck_cards"] == deck and loaded["equipped_equipment"] == equipped, "Old save retains all 16 cards and equipped gear")
	_expect(not loaded.has(Run.RunDeck.STARTER_BUFFET_SLOT_KEY), "Release-era saves skip gear-02 Buffet repair")
	var coord: Vector2i = _first_combat_room(engine, loaded)
	var entered: Dictionary = engine.move_to_room(loaded, coord)
	var combat: Dictionary = entered["combat_state"]
	for keyword: String in ["keyword:follow_up", "keyword:empower", "keyword:blink"]:
		_expect(Books.entry_ids_for_combat_state(combat).has(keyword), "Legacy combat deck discovers " + keyword)
	_expect(Data.card_def_for_progression("quick_stab", combat).has("follow_up") and Data.card_def_for_progression("patch_up", combat)["burn"], "Old runs resolve the old printed card mechanics in combat")
	var legacy_hand: Dictionary = combat.duplicate(true)
	legacy_hand["deck"]["hand"] = ["bloody_lunge"]
	var combat_engine := Combat.new()
	var empowered: Dictionary = combat_engine.prepare_player_card(legacy_hand, 0, "empower")
	_expect(combat_engine.card_play_actions("bloody_lunge", empowered)[1]["damage"] == 13, "Bloody Lunge still resolves legacy Empower for 13 damage")
	var victory: Dictionary = _won_battle(combat)
	victory["umbra"]["stage"] = Combat.UMBRA_STAGE_FRINGE
	var after: Dictionary = engine.finish_combat(entered, victory)
	_expect(after["deck_cards"] == deck and after["equipped_equipment"] == equipped and not after["equipment_inventory"].has(Data.UMBRA_REWARD_EQUIPMENT_ID), "Older saves wearing the Lantern get no duplicate from Umbra")
	_test_resumed_display(run, loaded, combat)

func _test_resumed_display(fresh: Dictionary, resumed: Dictionary, combat: Dictionary) -> void:
	Bindings.reset_cache()
	var builder := PreviewBuilder.new()
	builder.use_run_display = true
	builder.state = resumed
	for id: String in Data.LegacyStarterCards.DEFINITIONS:
		var expected: Dictionary = Data.card_def_for_progression(id, resumed)
		var modern: Dictionary = Data.card_def_for_progression(id, fresh)
		_expect(_display_projection(id, fresh)["card"] == modern, "%s displays the new rules before resume" % id)
		var legacy_projection: Dictionary = _display_projection(id, resumed)
		_expect(legacy_projection["card"] == expected and legacy_projection["display"] == Display.for_card(id, resumed, expected), "%s resumed face and tooltip agree with its definition after a new-run cache hit" % id)
		_expect(builder.card_definition(id) == expected, "%s inspection keyword panels use the same resumed definition" % id)
		_expect(_display_projection(id, combat)["card"] == Data.card_def_for_progression(id, combat), "%s combat display agrees with its resumed play definition" % id)
		Bindings.reset_cache()
		_display_projection(id, resumed)
		_expect(_display_projection(id, fresh)["card"] == modern, "%s new-run display stays current after a legacy cache hit" % id)

func _display_projection(id: String, state: Dictionary) -> Dictionary:
	return Bindings.projection(Bindings.context(state), id, Callable(), null, Display.for_card)

func _test_blocked_pickup() -> void:
	var engine := BlockedOpeningRun.new()
	var run: Dictionary = engine.create_new_run(CART_SEED, Store.default_data())
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	_expect(Generator.new().equipment_pickup([["stone"]], "iron_cleaver", rng, {Vector2i.ZERO: true}).is_empty(), "A fully occupied floor cannot place equipment")
	var dry_coord: Vector2i = _coord_for_roll(engine, CART_SEED, Run.SECTION_ONE_EQUIPMENT_DROP_PERCENT)
	var dry_room: Dictionary = {"type": "combat", "section_index": 0, "coord": dry_coord}
	var direct: Dictionary = engine.move_to_room(run, CART_FIRST_FIGHT)
	var dossier: Dictionary = engine.begin_pre_battle_combat(engine.move_to_pre_battle(run, CART_FIRST_FIGHT))
	engine.block_equipment_pickup = false
	for entered: Dictionary in [direct, dossier]:
		_expect(_equipment_pickups(entered["combat_state"]).is_empty(), "The opening board refuses the gear pickup")
		_expect(entered["equipment_drop_misses"] == run["equipment_drop_misses"], "A failed opening placement leaves pity untouched")
		var won: Dictionary = engine.finish_combat(entered, _won_battle(entered["combat_state"]))
		_expect(not won[Run.FIRST_COMBAT_WON_KEY] and not engine._equipment_drop_for_room(won, dry_room).is_empty(), "Victory with no opening pickup leaves the guarantee pending even on a dry roll")
		var retry: Dictionary = engine.move_to_room(engine.skip_reward_for_heal(won), CART_SECOND_FIGHT)
		var battle: Dictionary = retry["combat_state"]
		_expect(_is_single_non_trinket_pickup(_equipment_pickups(battle)), "The next fight after a refused pickup places one non-trinket")
		_expect(engine.finish_combat(retry, _won_battle(battle))[Run.FIRST_COMBAT_WON_KEY], "Winning the next fight fulfills the guarantee")

func _test_trinket_fallback(engine: RefCounted, run: Dictionary) -> void:
	var state: Dictionary = run.duplicate(true)
	for id: String in engine._available_equipment_drop_ids(run):
		if Data.equipment_slot(id) != "trinket":
			state["collected_equipment"].append(id)
	var coord: Vector2i = _first_combat_room(engine, state)
	var room: Dictionary = engine.room_metadata(state, coord)
	var selected: String = engine._equipment_drop_for_room(state, room)
	_expect(Data.equipment_slot(selected) == "trinket", "With all non-trinkets collected, the reserve falls back to the ordinary pool")
	var entered: Dictionary = engine.move_to_room(state, coord)
	var pickups: Array = _equipment_pickups(entered["combat_state"])
	_expect(pickups.size() == 1 and pickups[0]["equipment_id"] == selected, "The fallback trinket is placed on the board")
	_expect(Store.save_run_state(entered), "Combat with a fallback pickup writes a save")
	var resumed: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	var battle: Dictionary = resumed["combat_state"]
	_expect(_equipment_pickups(battle) == pickups and not resumed[Run.FIRST_COMBAT_WON_KEY], "Resume preserves the fallback pickup and the pending guarantee")
	var won: Dictionary = engine.finish_combat(resumed, _won_battle(battle))
	_expect(won[Run.FIRST_COMBAT_WON_KEY], "A placed trinket fulfills the guarantee on victory when the non-trinket pool is empty")
	state["collected_equipment"].append_array(engine._available_equipment_drop_ids(state))
	_expect(engine._equipment_drop_for_room(state, room).is_empty(), "When the ordinary pool is also exhausted there is no drop")

func _test_trinket_fallback_once(engine: RefCounted) -> void:
	var state: Dictionary = engine.create_new_run(FALLBACK_REVIEW_SEED, Store.default_data())
	for id: String in engine._available_equipment_drop_ids(state):
		if Data.equipment_slot(id) != "trinket":
			state["collected_equipment"].append(id)
	for coord: Vector2i in [FALLBACK_FIRST_FIGHT, FALLBACK_SECOND_FIGHT]:
		var roll: int = engine._coord_hash(FALLBACK_REVIEW_SEED, coord, FALLBACK_ROLL_SALT) % 100
		_expect(roll >= Run.SECTION_ONE_EQUIPMENT_DROP_PERCENT, "Review room %s fails the ordinary equipment roll at %d" % [coord, roll])
	var entered: Dictionary = engine.move_to_room(state, FALLBACK_FIRST_FIGHT)
	var first: Array = _equipment_pickups(entered["combat_state"])
	_expect(first.size() == 1 and Data.equipment_slot(first[0]["equipment_id"]) == "trinket", "Reserve forces a fallback trinket on the first dry roll")
	var won: Dictionary = engine.finish_combat(entered, _won_battle(entered["combat_state"]))
	var after_reward: Dictionary = engine.skip_reward_for_heal(won)
	var later: Dictionary = engine.move_to_room(after_reward, FALLBACK_SECOND_FIGHT)
	var second: Array = _equipment_pickups(later["combat_state"])
	_expect(won[Run.FIRST_COMBAT_WON_KEY] and second.is_empty(),
		"Winning with the fallback resolves the reserve and the second dry room drops no gear (first %s, second %s)" % [first, second])

func _test_guardian_award_analytics(engine: RefCounted, run: Dictionary) -> void:
	var first: Dictionary = engine.move_to_room(run, Vector2i(1, -1))
	var cleared: Dictionary = engine.skip_reward_for_heal(engine.finish_combat(first, _won_battle(first["combat_state"])))
	var event: Dictionary = engine.move_to_room(cleared, Vector2i(2, -2))
	var resolved: Dictionary = Events.continue_event(Events.choose_event(event, Events.first_available_choice_id(event), engine))
	var guardian: Dictionary = engine.move_to_room(resolved, Vector2i(0, 2))
	var battle: Dictionary = _won_battle(guardian["combat_state"])
	var victory: Dictionary = engine.finish_combat(guardian, battle)
	var lantern: String = Data.UMBRA_REWARD_EQUIPMENT_ID
	_expect(victory["mode"] == "treasure" and victory["equipment_inventory"].has(lantern), "The real first Umbra Guardian grants the Lantern with the trophy")
	_expect(Snapshots.reward_offered(engine, victory, "card_play").get("awarded_equipment", []) == [lantern], "Guardian reward offer attributes the Lantern")
	Snapshots.stage_combat_end(Combat.new(), engine, victory, battle, "card_play")
	var outbox: Array = Store.progression_analytics_outbox(victory["progression"])
	var payload: Dictionary = outbox.back()["payload"]
	_expect(payload["collected_equipment"].count(lantern) == 1, "Staged combat_ended includes the Lantern when the transition board has no inventory award")
	_expect(payload.get("awarded_equipment", []) == [lantern], "Staged combat_ended attributes the Lantern to the victory")
	Analytics.set_storage_dir(ANALYTICS_DIR)
	Analytics.clear_storage()
	var scene := RunSceneScript.new()
	scene.set("_run_state", victory)
	scene.call("_analytics_log_combat_ended", battle, "card_play")
	scene.call("_analytics_log_reward_offered", battle, "card_play")
	var rows: Array[Dictionary] = Analytics.load_all_events()
	_expect(rows.size() == 2, "Live Guardian transition emits the two expected analytics records")
	if rows.size() == 2:
		_expect(rows[0]["event_type"] == "combat_ended" and rows[0]["payload"]["collected_equipment"].count(lantern) == 1, "Live combat_ended logs precisely one Lantern")
		_expect(rows[1]["event_type"] == "reward_offered" and rows[1]["payload"].get("awarded_equipment", []) == [lantern], "Live reward_offered attributes the Lantern")
	scene.free()

func _test_lantern_pools(engine: RefCounted) -> void:
	var run: Dictionary = engine.create_new_run(CART_SEED, Store.default_data())
	for coord: Vector2i in [CART_FIRST_FIGHT, CART_SECOND_FIGHT]:
		var entered: Dictionary = engine.move_to_room(run, coord)
		run = engine.skip_reward_for_heal(engine.finish_combat(entered, _won_battle(entered["combat_state"])))
	run = engine.move_to_room(run, Vector2i(2, 0))
	_expect(Events.current_id(run) == "tinkers_cart", "Seed 382 arrives at the real Tinker's Cart before Umbra")
	var item: String = Data.UMBRA_REWARD_EQUIPMENT_ID
	_expect(not Events.choose_event(run, "steal", engine)["equipment_inventory"].has(item), "Tinker's Cart cannot award the Lantern before Umbra")
	run[Run.UMBRA_LANTERN_REWARD_KEY] = true
	_expect(not Events.choose_event(run, "steal", engine)["equipment_inventory"].has(item), "Tinker's Cart cannot reissue the Lantern after it leaves inventory")
	run.erase(Run.FIRST_COMBAT_WON_KEY)
	_expect(not engine._available_merchant_equipment_ids(run).has(item), "A resumed merchant pool excludes the fixed Lantern reward")
	var stale_boon: Dictionary = {Boons.STATE_KEY: {"offers": [{"boon": "heirloom", "item": item}]}}
	_expect(Boons.available_offers(stale_boon).is_empty(), "A saved heirloom offer cannot reintroduce the Lantern")
	for gear: String in Data.equipment_ids():
		if gear != item: run["equipment_inventory"].append(gear)
	run["equipped_equipment"]["trinket"] = "bone_dice"
	var reforge: Array = [{"type": "reforge", "slot": "trinket", "rarity_step": 1}]
	var result: Dictionary = Events.apply_effects(run, reforge, Events.rng_for(run, "choice|reforge"), engine)
	_expect(result["state"]["equipped_equipment"]["trinket"] == "bone_dice", "A reforge with no eligible replacement keeps the existing trinket")

func _test_lantern_grimoire() -> void:
	var entry: Dictionary = Books.entry_def(Books.equipment_card_entry_id("lantern_shot"))
	_expect(not Data.card_def("lantern_shot").get("starter", false), "Lantern Shot loses starter classification")
	_expect(not entry.is_empty() and Search.search([entry], [], "starter").is_empty(), "Grimoire lists Lantern Shot as gear without matching a starter search")

func _coord_for_roll(engine: RefCounted, seed_value: int, target: int) -> Vector2i:
	for x: int in range(ROLL_SCAN_LIMIT):
		var coord := Vector2i(x, 0)
		if engine._coord_hash(seed_value, coord, 1201) % 100 == target:
			return coord
	_expect(false, "Coordinate roll fixture reaches %d" % target)
	return Vector2i.ZERO

func _first_combat_room(engine: RefCounted, run: Dictionary) -> Vector2i:
	for coord: Vector2i in engine.available_moves(run):
		if engine.room_metadata(run, coord)["type"] == "combat":
			return coord
	_expect(false, "The start fixture has a direct combat destination")
	return Vector2i.ZERO

func _equipment_pickups(battle: Dictionary) -> Array:
	return (battle["loot"] as Array).filter(func(loot: Dictionary) -> bool: return loot["kind"] == "equipment")

func _is_single_non_trinket_pickup(pickups: Array) -> bool:
	return pickups.size() == 1 and Data.equipment_slot(pickups[0]["equipment_id"]) in ["weapon", "offhand", "armor", "boots"]

func _won_battle(battle: Dictionary) -> Dictionary:
	var won: Dictionary = battle.duplicate(true)
	for enemy: Dictionary in won["enemies"]: enemy["hp"] = 0
	return won

func _action(card_id: String, index: int) -> Dictionary:
	return Data.card_def(card_id)["actions"][index]

func _hits_adjacent_tiles(action: Dictionary) -> bool:
	var tiles: Array[Vector2i]
	for offset: Array in action["pattern"]:
		tiles.append(Vector2i(int(offset[0]), int(offset[1])))
	return action["range"] == 0 and tiles == ADJACENT_TILES

func _expect(condition: bool, message: String) -> void:
	_expectations += 1
	if condition: return
	_failures += 1
	push_error(message)
