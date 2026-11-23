extends SceneTree

const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Elements = preload("res://scripts/element_data.gd")
const Deck = preload("res://scripts/run_deck.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Snapshots = preload("res://scripts/analytics_snapshots.gd")
const Skills = preload("res://tests/suites/skill_run_suite.gd")
const Fixture = preload("res://tests/helpers/deck_element_reward_fixture.gd")
const GuardianInspection = preload("res://tools/guardian_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Events = preload("res://scripts/event_rules.gd")
const BattlefieldItems = preload("res://scripts/battlefield_item_rules.gd")
const ShopFixture = preload("res://tests/suites/magic_deck_suite.gd")

const FIXTURE_ROOM := Vector2i(1, 0)
const REWARD_SEED_COUNT: int = 64
const LEGACY_OFFERS: Array[String] = Array(["gust_step", "dust_devil", Fixture.ICE_CARD], TYPE_STRING, "", null)
const BUFFET: String = "buffet"
const LAMPLIGHTER_ROOM := Vector2i(22, -19)
const LAMPLIGHTER_REWARD_SEED: int = 9590
const FIREBOMB: String = "pitch_firebomb"
const STORM_JAR: String = "storm_jar"
const NEWEST_BUFFET_MIRROR_SEED: int = 5
const OPENING_BUFFET_MIRROR_SEED: int = 11

var failures: int = 0
var engine := Run.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_test_deck_element()
	_test_starter_buffet()
	_test_slots()
	_test_enhanced_and_reroll()
	_test_save_resume_and_analytics()
	_test_deferred_keeps_deck_match()
	_test_lamplighter_reroll_exclusions()
	_test_stow_duplicate_item()
	_test_equipped_donation()
	_test_pack_sale()
	_test_defeat_item_replacement()
	_test_mirror_duplicate()
	_test_early_gear_save()
	_test_early_starter_after_shatter_or_purge()
	print("DECK ELEMENT REWARDS: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _test_deck_element() -> void:
	var state: Dictionary = engine.create_new_run(Fixture.SEED, Progression.default_data())
	_check(Deck.element(state).is_empty(), "The opening loadout gives the deck no reward element")
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state["equipment_inventory"].append(Fixture.FIRE_GEAR)
	state = engine.equip_equipment(state, Fixture.FIRE_GEAR)
	_check(state["deck_cards"].has(Fixture.FIRE_GEAR_CARD), "The fixture equips a Fire gear card")
	_check(Deck.element(state) == Elements.FIRE, "Newly equipped Fire wins a tie over older Ice magic")
	state = _round_trip(state)
	_check(Deck.element(state) == Elements.FIRE, "Tie-break follows addition order across resume")
	var legacy: Dictionary = state.duplicate(true)
	legacy.erase(Deck.ADDITION_ORDER_KEY)
	_check(Deck.element(legacy) == Elements.ICE, "A legacy tie uses the ordered compiled deck")
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state = engine.grant_magic_to_deck(state, Fixture.FIRE_CARD)
	_check(Deck.element(state) == Elements.FIRE, "The newest elemental card wins an equal count")
	state = engine.grant_magic_to_deck(state, "gust_step")
	_check(Deck.element(state) == Elements.FIRE, "A newer minority element does not break the majority tie")
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	_check(Deck.element(state) == Elements.ICE, "Each copy counts toward the elemental majority")
	state["mode"] = "campfire"
	state = engine.purge_magic_card(state, Fixture.ICE_CARD, "campfire")
	_check(Deck.element(state) == Elements.ICE, "Removing the oldest duplicate preserves the newest copy for the tie")

func _test_starter_buffet() -> void:
	var state: Dictionary = engine.create_new_run(Fixture.SEED, Progression.default_data())
	state.erase(Deck.STARTER_BUFFET_SLOT_KEY)
	state = _round_trip(state)
	_check(Deck.element(state).is_empty(), "An early gear-02 save recognizes the starter Buffet")
	state["mode"] = "campfire"
	state = engine.purge_magic_card(state, "pale_spark", "campfire")
	_check(Deck.element(state).is_empty(), "Purging a preceding spell keeps the starter Buffet excluded")
	state = engine.grant_magic_to_deck(state, BUFFET)
	_check(Deck.element(state) == Elements.AIR, "An acquired Buffet contributes Air alongside the starter copy")
	state["mode"] = "campfire"
	state = engine.purge_magic_card(state, BUFFET, "campfire")
	_check(Deck.element(_round_trip(state)) == Elements.AIR, "Removing the starter does not exclude the remaining Buffet on Continue")
	_forget_copy_markers(state)
	state[Run.NEW_LOADOUT_MAGIC_KEY] = []
	state[Run.UNREAD_LOADOUT_MAGIC_KEY] = []
	var early: Dictionary = _round_trip(state)
	_check(early["reward_cards"] == [BUFFET] and early[Deck.STARTER_BUFFET_SLOT_KEY] == -1 and Deck.element(early) == Elements.AIR,
		"A pre-marker reward receipt identifies the remaining earned Buffet on Continue")

func _test_slots() -> void:
	var state: Dictionary = _roll_state(Elements.AIR, [Fixture.FIRE_CARD])
	var neutral: Dictionary = _roll_state(Elements.AIR, ["quick_stab"])
	for seed_value: int in range(REWARD_SEED_COUNT):
		state["seed"] = seed_value
		neutral["seed"] = seed_value
		var cards: Array[String] = engine._generate_card_rewards(state, FIXTURE_ROOM)
		var baseline: Array[String] = engine._generate_card_rewards(neutral, FIXTURE_ROOM)
		_check(cards.size() == 3 and cards.slice(0, 2) == baseline.slice(0, 2), "The two Air slots are unchanged at seed %d" % seed_value)
		if cards.size() != 3 or baseline.size() != 3: continue
		_check(Data.card_element(cards[2]) == Elements.FIRE, "Fire redirects the general slot in Air at seed %d" % seed_value)
		_check(Data.card_rarity(cards[2]) == Data.card_rarity(baseline[2]), "The redirected slot keeps the rarity roll at seed %d" % seed_value)
		_check(_unique(cards), "No duplicate offers at seed %d" % seed_value)
		_check(cards == engine._generate_card_rewards(state, FIXTURE_ROOM), "The seed reproduces offers at seed %d" % seed_value)
	state = _roll_state(Elements.FIRE, [Fixture.FIRE_CARD])
	neutral = _roll_state(Elements.FIRE, [])
	_check(engine._generate_card_rewards(state, FIXTURE_ROOM) == engine._generate_card_rewards(neutral, FIXTURE_ROOM), "A matching room keeps its original general roll")
	neutral["deck_cards"] = ["quick_stab"]
	_check(engine._generate_card_rewards(state, FIXTURE_ROOM) == engine._generate_card_rewards(neutral, FIXTURE_ROOM), "A neutral-only deck keeps its original roll")
	state = _roll_state(Elements.NONE, [Fixture.FIRE_CARD])
	var neutral_room_cards: Array[String] = engine._generate_card_rewards(state, FIXTURE_ROOM)
	_check(neutral_room_cards.size() == 3 and Data.card_element(neutral_room_cards[0]) == Elements.FIRE, "The first general draw redirects in a neutral room")

func _test_enhanced_and_reroll() -> void:
	var state: Dictionary = _roll_state(Elements.AIR, [Fixture.FIRE_CARD])
	var ordinary: Array[String] = engine._generate_card_rewards(state, FIXTURE_ROOM)
	var room: Dictionary = state["rooms"]["1,0"]
	room.merge({"type": "special", "special_type": "warband", "special_goal_met": true}, true)
	var enhanced: Array[String] = engine._generate_card_rewards(state, FIXTURE_ROOM)
	_check(enhanced.size() == 4 and _unique(enhanced), "Enhanced offers have four distinct cards")
	if enhanced.size() == 4:
		_check(enhanced.slice(0, 3) == ordinary and Data.card_element(enhanced[3]) == Elements.AIR, "Enhanced offers use the same redirected slot and an extra Air card")
		_check(enhanced.any(func(id: String) -> bool: return Data.card_rarity(id) != "common"), "Enhanced offers retain the rarity floor")
	var reroll: Dictionary = Skills._new_run(engine, ["discerning_eye"])
	reroll.merge(state, true)
	reroll["mode"] = "reward"
	reroll["current_room"] = FIXTURE_ROOM
	reroll["pending_reward"] = {"cards": enhanced}
	var replacement: Array = engine.reroll_card_reward(reroll)["pending_reward"]["cards"]
	_check(replacement.size() == 4 and Data.card_element(replacement[2]) == Elements.FIRE, "Discerning Eye uses the deck slot for enhanced rerolls")
	_check(replacement.all(func(id: String) -> bool: return not enhanced.has(id)), "Discerning Eye excludes the original offers")

func _test_save_resume_and_analytics() -> void:
	var combat: Dictionary = Fixture.combat(engine, Elements.AIR, true)
	_check(combat.get("mode", "") == "combat", "Save fixture enters an Air combat")
	if combat.get("mode", "") != "combat": return
	var outcome: Dictionary = Fixture.victory(combat)
	var reward: Dictionary = engine.finish_combat(combat, outcome)
	_check(reward.get("mode", "") == "reward", "Combat victory offers card rewards")
	var offers: Array = reward.get("pending_reward", {}).get("cards", [])
	var resumed_combat: Dictionary = _round_trip(combat)
	_check(engine.finish_combat(resumed_combat, Fixture.victory(resumed_combat))["pending_reward"]["cards"] == offers, "Resuming before victory reproduces the offers")
	var resumed_reward: Dictionary = _round_trip(reward)
	_check(resumed_reward["pending_reward"]["cards"] == offers, "Resuming an offered reward keeps the exact cards and order")
	_check(engine.finish_combat(resumed_reward, outcome) == resumed_reward, "Repeating a completed victory keeps its committed reward")
	_check(_check_analytics(resumed_reward, Elements.FIRE, [false, false, true]), "Logged Fire reward has a matching third slot")
	resumed_reward["pending_reward"]["cards"] = LEGACY_OFFERS.duplicate()
	_check(_round_trip(resumed_reward)["pending_reward"]["cards"] == LEGACY_OFFERS, "An already-rolled legacy offer is never regenerated")
	var neutral_combat: Dictionary = Fixture.combat(engine, Elements.AIR, false)
	var neutral_reward: Dictionary = engine.finish_combat(neutral_combat, Fixture.victory(neutral_combat))
	_check(_check_analytics(neutral_reward, null, [false, false, false]), "Logged neutral-deck reward has a JSON null element and false matches")

func _test_deferred_keeps_deck_match() -> void:
	var combat: Dictionary = Fixture.combat(engine, Elements.AIR, true)
	var coord: Vector2i = combat["current_room"]
	_check(coord == Vector2i(1, -1), "Deferred Choice reaches the seed 7319 Air room")
	var skill_state: Dictionary = Skills._new_run(engine, ["deferred_choice"])
	skill_state["mode"] = "reward"
	skill_state["pending_reward"] = {"cards": [Fixture.ICE_CARD]}
	skill_state = engine.skip_reward_for_heal(skill_state, Fixture.ICE_CARD)
	combat[Run.SKILL_STATE_KEY] = skill_state[Run.SKILL_STATE_KEY]
	combat["progression"] = skill_state["progression"]
	var board: Dictionary = Fixture.victory(combat)
	var reward: Dictionary = engine.finish_combat(combat, board)
	var cards: Array = reward["pending_reward"]["cards"]
	_check(cards.size() == 3 and cards[1] == Fixture.ICE_CARD and Data.card_element(cards[2]) == Elements.FIRE, "Air reward carries Frostbolt in the last nonmatching slot and keeps its Fire offer")
	_check(_round_trip(reward)["pending_reward"]["cards"] == cards, "Continue preserves the final deferred offer")
	var room: Dictionary = Graph.room(combat, coord)
	room.merge({"type": "special", "special_type": "warband"}, true)
	var enhanced: Dictionary = engine.finish_combat(combat, board)
	cards = enhanced["pending_reward"]["cards"]
	_check(cards.size() == 4 and cards[3] == Fixture.ICE_CARD and Data.card_element(cards[2]) == Elements.FIRE, "Enhanced Warband carries Frostbolt in the last nonmatching slot and keeps its Fire offer")
	_check(cards.any(func(id: String) -> bool: return Data.card_rarity(id) != "common"), "Enhanced Warband repairs the rarity floor without replacing Frostbolt or the Fire offer")
	combat["mode"] = "event"
	combat["event_state"] = {"page": "result", "outcomes": [{"type": "card_choice", "cards": ["gust_step", Fixture.FIRE_CARD]}]}
	var event_reward: Dictionary = engine.resolve_map_event(combat, "continue")
	_check(event_reward["pending_reward"]["cards"] == [Fixture.ICE_CARD, Fixture.FIRE_CARD], "Event redemption protects the only matching offer too")
	combat["event_state"]["outcomes"][0]["cards"] = ["hearth_rush", Fixture.FIRE_CARD]
	event_reward = engine.resolve_map_event(combat, "continue")
	_check(event_reward["pending_reward"]["cards"] == ["hearth_rush", Fixture.ICE_CARD], "All-matching event offers keep the original deferral slot")

func _test_lamplighter_reroll_exclusions() -> void:
	var skilled: Dictionary = Skills._new_run(engine, ["discerning_eye"])
	skilled = engine.grant_magic_to_deck(skilled, Fixture.FIRE_CARD)
	var state: Dictionary = GuardianInspection.build(engine, Combat.new(), skilled, {
		"guardian_id": "last_lamplighter", "guardian_case": "encounter", "attuned_magic": "keep", "equip": "keep"
	})
	state["seed"] = LAMPLIGHTER_REWARD_SEED
	state["relics"].append("procession_lantern")
	var reward: Dictionary = engine.finish_combat(state, Fixture.victory(state))
	var initial: Array = reward["pending_reward"]["cards"]
	_check(state["current_room"] == LAMPLIGHTER_ROOM and initial == ["wildfire_halo", "salamander_heart", "capacitor"], "Lamplighter trophy fallback exhausts the Fire legendaries in the initial offer")
	var replacement: Array = engine.reroll_card_reward(reward)["pending_reward"]["cards"]
	_check(replacement.size() == 3 and _unique(replacement) and replacement.all(func(id: String) -> bool: return not initial.has(id)), "Lamplighter reroll excludes prior offers from all three slots")
	_check(Data.card_element(replacement[0]) == Elements.FIRE, "Lamplighter reroll still draws its Fire slot")

func _test_stow_duplicate_item() -> void:
	var state: Dictionary = engine.create_new_run(Fixture.SEED, Progression.default_data())
	state["item_inventory"] = [FIREBOMB, FIREBOMB]
	state = engine.equip_item_card(state, 0)
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state = engine.equip_item_card(state, 0)
	_check(Deck.element(engine.unequip_item_card(state, 0)) == Elements.FIRE, "Stowing the older Firebomb retains the newer Fire addition")
	var stowed: Dictionary = engine.unequip_item_card(state, 1)
	_check(stowed["equipped_items"] == [FIREBOMB] and Deck.element(stowed) == Elements.ICE, "Stowing the newer Firebomb leaves Ice as the newest elemental addition")
	_check(Deck.element(_round_trip(stowed)) == Elements.ICE, "Continue preserves the addition order after stowing the newer copy")

	state = engine.create_new_run(Fixture.SEED, Progression.default_data())
	state["item_inventory"] = ["crimson_draught", FIREBOMB, FIREBOMB]
	state = engine.equip_item_card(state, 0)
	state = engine.equip_item_card(state, 0)
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state = engine.equip_item_card(state, 0, 0)
	state = _round_trip(state)
	_check(Deck.element(engine.unequip_item_card(state, 0)) == Elements.ICE, "Replacing the first slot records the new copy there across Continue")
	_check(Deck.element(engine.unequip_item_card(state, 1)) == Elements.FIRE, "Stowing the second slot retains the Firebomb that replaced the first")
	var combat_update: Dictionary = engine.set_combat_state(state, {"equipped_items": [FIREBOMB]})
	_check(Deck.element(combat_update) == Elements.ICE, "Combat consumption removes the first Firebomb slot even when that copy was equipped last")

func _test_equipped_donation() -> void:
	var state: Dictionary = engine.create_new_run(Fixture.SEED, Progression.default_data())
	state["item_inventory"] = ["crimson_draught", FIREBOMB, FIREBOMB]
	state = engine.equip_item_card(state, 0)
	state = engine.equip_item_card(state, 0)
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state = engine.equip_item_card(state, 0, 0)
	state["item_inventory"] = []
	state = Events.choose_event(_event_fixture(state, "starving_pilgrim"), "item", engine)
	_check(state["equipped_items"] == [FIREBOMB] and Deck.element(state) == Elements.ICE,
		"Pilgrim donation removes the first Firebomb's own history")
	_check(state.get(Deck.ITEM_SLOT_ORDER_KEY, [0]) == [0], "Donation updates the equipped slot history")
	state = Events.continue_event(state)
	for history: Array in [[1, 0], []]:
		var old_save: Dictionary = state.duplicate(true)
		old_save.erase(Deck.COPY_ORDER_KEY)
		var old_order: Array = old_save.get(Deck.ADDITION_ORDER_KEY, old_save["deck_cards"]).duplicate()
		old_order.append(FIREBOMB)
		old_save[Deck.ADDITION_ORDER_KEY] = old_order
		if history.is_empty(): old_save.erase(Deck.ITEM_SLOT_ORDER_KEY)
		else: old_save[Deck.ITEM_SLOT_ORDER_KEY] = history
		var resumed: Dictionary = _round_trip(old_save)
		_check(resumed["equipped_items"] == [FIREBOMB] and resumed.get(Deck.ITEM_SLOT_ORDER_KEY, [0]) == [0],
			"Continue repairs absent or oversized slot history and retains the equipped item")
		_check((resumed.get(Deck.ADDITION_ORDER_KEY, resumed["deck_cards"]) as Array).count(FIREBOMB) == 1,
			"Repaired history contains only the equipped copy")
		resumed["item_inventory"] = [STORM_JAR]
		var equipped: Dictionary = engine.equip_item_card(resumed, 0)
		_check(equipped["equipped_items"] == [FIREBOMB, STORM_JAR] and equipped["item_inventory"].is_empty()
			and equipped["deck_cards"].has(STORM_JAR), "Equipping after Continue keeps both items")

func _test_pack_sale() -> void:
	var state: Dictionary = ShopFixture.shop_fixture(engine)
	state["item_inventory"] = [FIREBOMB, FIREBOMB]
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state = engine.equip_item_card(state, 0)
	state = engine.sell_merchant_item(state, Run.MERCHANT_SCAVENGER, FIREBOMB)
	state = _round_trip(state)
	_check(state["item_inventory"].is_empty() and state["equipped_items"] == [FIREBOMB] and Deck.element(state) == Elements.FIRE,
		"Selling a pack Firebomb preserves the equipped copy and its addition age across Continue")

func _test_defeat_item_replacement() -> void:
	var state: Dictionary = engine.create_new_run(Fixture.SEED, Progression.default_data())
	state["item_inventory"] = [FIREBOMB, FIREBOMB]
	state = engine.equip_item_card(state, 0)
	state = engine.grant_magic_to_deck(state, Fixture.ICE_CARD)
	state = engine.equip_item_card(state, 0)
	for coord: Vector2i in engine.available_moves(state):
		if Graph.room(state, coord).get("type", "") != "combat": continue
		state = engine.move_to_room(state, coord)
		break
	var battle: Dictionary = state["combat_state"].duplicate(true)
	_check(not battle.is_empty(), "Item replacement fixture enters combat")
	if battle.is_empty(): return
	BattlefieldItems.consume(battle, FIREBOMB)
	BattlefieldItems.collect(battle, {"card_id": FIREBOMB})
	battle["player"]["hp"] = 0
	var defeated: Dictionary = engine.finish_combat(state, battle)
	_check(defeated["mode"] == "defeat" and defeated["equipped_items"] == [FIREBOMB, FIREBOMB],
		"Defeat retains the surviving and newly picked up Firebombs")
	defeated = _round_trip(defeated)
	defeated["mode"] = "room"
	var stowed: Dictionary = engine.unequip_item_card(defeated, 1)
	_check(stowed["equipped_items"] == [FIREBOMB] and Deck.element(stowed) == Elements.FIRE,
		"Checkpoint with the same item IDs preserves the actual surviving Firebomb's age")

func _test_mirror_duplicate() -> void:
	var state: Dictionary = engine.create_new_run(NEWEST_BUFFET_MIRROR_SEED, Progression.default_data())
	for card: String in [BUFFET, Fixture.ICE_CARD, BUFFET]:
		state = engine.grant_magic_to_deck(state, card)
	state = Events.choose_event(_event_fixture(state, "mirror_of_skins"), "hand", engine)
	_check(state["reward_cards"] == [BUFFET, Fixture.ICE_CARD, "break_the_veil"],
		"Mirror replaces only the newest Buffet's reward entry")
	state = Events.continue_event(state)
	state["mode"] = "campfire"
	state = engine.purge_magic_card(state, "break_the_veil", "campfire")
	_check(Deck.element(state) == Elements.ICE, "Purging the Mirror replacement leaves Frostbolt newer than Buffet")
	state = _round_trip(state)
	_check(Deck.element(state) == Elements.ICE, "Continue keeps the corrected Ice reward match")
	var reward: Dictionary = _roll_state(Elements.FIRE, [])
	reward.merge(state, true)
	Graph.room(reward, FIXTURE_ROOM).merge({"type": "combat", "element": Elements.FIRE}, true)
	reward["pending_reward"] = {"cards": engine._generate_card_rewards(reward, FIXTURE_ROOM)}
	_check(Data.card_element(reward["pending_reward"]["cards"][2]) == Elements.ICE
		and Snapshots.reward_offered(engine, reward, "mirror_fixture")["deck_element"] == Elements.ICE,
		"Offers and reward analytics use the surviving copies' Ice match")

func _test_early_gear_save() -> void:
	var state: Dictionary = engine.create_new_run(OPENING_BUFFET_MIRROR_SEED, Progression.default_data())
	state = engine.grant_magic_to_deck(state, BUFFET)
	state = Events.choose_event(_event_fixture(state, "mirror_of_skins"), "hand", engine)
	_check(state["reward_cards"] == [BUFFET, "earthen_rampart"], "Transforming the opening Buffet leaves the earned copy's reward entry")
	state = Events.continue_event(state)
	# An early save lost the earned receipt when the Mirror replaced the starter.
	state["reward_cards"] = ["earthen_rampart"]
	_forget_copy_markers(state)
	state = _round_trip(state)
	_check(state["attuned_magic_cards"].count(BUFFET) == 1 and state["reward_cards"] == ["earthen_rampart"]
		and state[Deck.STARTER_BUFFET_SLOT_KEY] == state["attuned_magic_cards"].find(BUFFET),
		"With no Buffet receipt, Continue marks the surviving Buffet as the starter")

func _test_early_starter_after_shatter_or_purge() -> void:
	for action: String in ["shatter", "purge"]:
		var state: Dictionary = engine.create_new_run(OPENING_BUFFET_MIRROR_SEED, Progression.default_data())
		if action == "shatter":
			state = Events.continue_event(Events.choose_event(_event_fixture(state, "mirror_of_skins"), action, engine))
			_check(state["seen_events"].has("mirror_of_skins"), "Early-save fixture resolved Shatter the glass")
		else:
			state["mode"] = "campfire"
			state = engine.purge_magic_card(state, "pale_spark", "campfire")
			_check(not state["attuned_magic_cards"].has("pale_spark"), "Early-save fixture purged only the starter Pale Spark")
		_forget_copy_markers(state)
		var resumed: Dictionary = _round_trip(state)
		_check(resumed["attuned_magic_cards"] == state["attuned_magic_cards"] and resumed["reward_cards"] == state["reward_cards"] and Deck.element(resumed).is_empty(),
			"Early Continue after %s keeps the opening Buffet with no reward receipt or deck element (receipts %s, element %s)" % [action, resumed["reward_cards"], Deck.element(resumed)])

func _forget_copy_markers(state: Dictionary) -> void:
	for key: String in [Deck.STARTER_BUFFET_SLOT_KEY, Deck.MAGIC_REWARD_SLOTS_KEY, Deck.COPY_ORDER_KEY, Deck.ADDITION_ORDER_KEY, Deck.ITEM_SLOT_ORDER_KEY]:
		state.erase(key)

func _event_fixture(state: Dictionary, event_id: String) -> Dictionary:
	state["current_room"] = FIXTURE_ROOM
	Graph.room(state, FIXTURE_ROOM).merge({"type": "event", "event_id": event_id, "cleared": false}, true)
	return Events.enter_event(state)

func _check_analytics(state: Dictionary, element: Variant, matches: Array) -> bool:
	Analytics.clear_storage()
	var payload: Dictionary = Snapshots.reward_offered(engine, state, "deck_element_fixture")
	if not Analytics.new().write_event("reward_offered", {"run_id": "deck_element_fixture"}, payload): return false
	var events: Array[Dictionary] = Analytics.load_all_events()
	if events.size() != 1: return false
	var logged: Dictionary = events[0]["payload"]
	return logged.has("deck_element") and logged["deck_element"] == element and logged.get("deck_match", []) == matches and logged["offered_cards"] == state["pending_reward"]["cards"]

func _round_trip(state: Dictionary) -> Dictionary:
	_check(Progression.save_run_state(state), "Fixture commits a save to the task-local store")
	return engine.repair_loaded_run_state(Progression.load_saved_run())

func _roll_state(room_element: String, cards: Array) -> Dictionary:
	return {"seed": Fixture.SEED, "rooms": {"1,0": {"type": "combat", "element": room_element}}, "deck_cards": cards}

func _unique(cards: Array) -> bool:
	return cards.all(func(id: String) -> bool: return cards.count(id) == 1)

func _check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
