extends RefCounted

const Rules = preload("res://scripts/opening_boon_rules.gd")
const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Dialogue = preload("res://scripts/dialogue_engine.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const SCAVENGER_ONE: Vector2i = Vector2i(1, 0)
const SCAVENGER_TWO: Vector2i = Vector2i(2, 0)
const PRICE_ROUNDING_BASE: int = 175
const ROLL_SEED_FIRST: int = 1
const ROLL_SEED_LAST: int = 32

static func run(expect: Callable) -> void:
	_rolls_and_eligibility(expect)
	_effects(expect)
	_heirlooms(expect)
	_debt(expect)
	_analytics(expect)
	print("OPENING BOON RULES: deterministic rolls, eligibility, all effects, heirlooms, Debt and event receipts checked")

static func _rolls_and_eligibility(expect: Callable) -> void:
	var engine := Run.new()
	var state: Dictionary = Fixture.state()
	expect.call(state[Rules.STATE_KEY] == Fixture.state()[Rules.STATE_KEY], "Same seed and profile roll exactly the same offers")
	expect.call(state[Rules.STATE_KEY]["offers"].size() == 3, "One boon per column is rolled at creation")
	var seen: Dictionary = {}
	for seed: int in range(ROLL_SEED_FIRST, ROLL_SEED_LAST + 1):
		# Roll coverage does not need 32 independently generated section graphs;
		# real create/save/repair and the live scene are exercised separately.
		var profile: Dictionary = Fixture.profile()
		var rolled: Dictionary = {"seed": seed, "run_index": profile["run_counter"], "progression": profile, "equipped_equipment": Data.starting_equipped_equipment(), "relics": []}
		Rules.initialize(rolled)
		for offer: Dictionary in rolled[Rules.STATE_KEY]["offers"]:
			seen[offer["boon"]] = true
			if offer.has("element"):
				for card: String in offer["spells"]: expect.call(Data.card_element(card) == offer["element"], "Rolled spells match the displayed element")
	expect.call(seen.size() == 9 and seen.has("armory"), "Every eligible boon including rare Armory rolls in production")
	expect.call(not Rules.equipment_pool(state).is_empty() and Rules.definitions()["boons"]["armory"]["rarity"] == "rare", "Armory rolls the director-approved rare equipment tier")
	var restricted: Dictionary = state.duplicate(true)
	for slot: String in restricted["equipped_equipment"]: restricted["equipped_equipment"][slot] = ""
	restricted["equipped_equipment"]["weapon"] = Data.starting_equipped_equipment()["weapon"]
	expect.call(Rules.equipment_pool(restricted).keys() == ["weapon"], "Armory only samples slots whose starter is still held")
	for pool: Array in Rules.equipment_pool(state).values():
		for item: String in pool: expect.call(Data.equipment_def(item)["rarity"] == "rare", "Every eligible Armory piece is rare")
	expect.call(Store.save_run_state(state), "Rolled offer saves")
	var resumed: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(resumed[Rules.STATE_KEY] == state[Rules.STATE_KEY], "Save/resume preserves the complete roll without rerolling")
	var first: Dictionary = Fixture.profile()
	first["run_counter"] = 1
	expect.call(not Rules.pending(engine.create_new_run(Fixture.PROOF_SEED, first)), "First run never offers a boon")
	var guided: Dictionary = Fixture.profile()
	guided[Tutorial.PROGRESSION_KEY] = Tutorial.default_state()
	expect.call(not Rules.pending(engine.create_new_run(Fixture.PROOF_SEED, guided)), "Active guided tutorial never offers a boon")
	var locked: Dictionary = Fixture.profile()
	locked[Store.EMACIATED_AWAKENING_SEEN_KEY] = false
	var awakening_run: Dictionary = engine.create_new_run(Fixture.PROOF_SEED, locked)
	awakening_run["progression"][Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	expect.call(not Rules.pending(engine.repair_loaded_run_state(awakening_run)), "Awakening during a run does not retroactively create an offer")
	state.erase(Rules.STATE_KEY)
	expect.call(not Rules.pending(engine.repair_loaded_run_state(state)), "Legacy saves without an offer never roll one on repair")

static func _effects(expect: Callable) -> void:
	var engine := Run.new()
	for id: String in ["elemental_gift", "armory", "purge", "focus", "vitality", "trinket", "blood_price", "pawned_light", "debt", "heirloom"]:
		var before: Dictionary = Fixture.force_boon(id)
		var row: Dictionary = before[Rules.STATE_KEY]["offers"][0]
		var choices: Array = []
		if id in ["elemental_gift", "blood_price"]: choices.append(row["spells"][0])
		if id == "purge": choices = ["pale_spark", "pale_spark"]
		var result: Dictionary = Rules.choose(engine, before, id, choices)
		expect.call(bool(result[Rules.STATE_KEY]["resolved"]), id + " resolves the one run choice")
		expect.call(not bool(before[Rules.STATE_KEY]["resolved"]), id + " leaves caller state immutable")
		expect.call(Rules.choose(engine, result, id, choices) == result, id + " cannot be applied twice")
		match id:
			"elemental_gift", "blood_price":
				expect.call(result["attuned_magic_cards"].size() == 7 and result["deck_cards"].has(choices[0]) and result["magic_inventory"].is_empty(), id + " puts the chosen spell straight in the deck")
				if id == "blood_price": expect.call(result["player_max_hp"] == before["player_max_hp"] - 5 and result["player_hp"] <= result["player_max_hp"], "Blood Price charges five max HP and clamps current HP")
			"armory", "heirloom":
				var slot: String = Data.equipment_slot(row["item"])
				var starter: String = Data.starting_equipped_equipment()[slot]
				expect.call(result["equipped_equipment"][slot] == row["item"] and not result["equipment_inventory"].has(starter) and not result["collected_equipment"].has(starter), id + " removes the replaced starter completely")
				for card: String in Data.equipment_cards(starter): expect.call(not result["deck_cards"].has(card), id + " removes starter equipment cards")
				for card: String in Data.equipment_cards(row["item"]): expect.call(result["deck_cards"].has(card), id + " adds base equipment cards")
			"purge": expect.call(result["attuned_magic_cards"].size() == 4 and not result["attuned_magic_cards"].has("pale_spark"), "Purge removes exactly two chosen copies")
			"focus":
				expect.call(result["attuned_magic_cards"] == row["spells"] and result["attuned_magic_cards"].size() == 4, "Focus exchanges all six starters for the four upfront spells")
			"vitality": expect.call(result["player_max_hp"] == before["player_max_hp"] + 6 and result["player_hp"] == before["player_hp"] + 6 and result["player_hp"] == result["player_max_hp"], "Vitality grants six max and current HP, keeping the run full")
			"trinket", "pawned_light":
				expect.call(result["relics"].has(row["relic"]), id + " grants the rolled relic")
				expect.call(result["player_max_hp"] == before["player_max_hp"] + Data.stat_bonus_from_relics([row["relic"]], "max_hp"), id + " uses normal relic pickup stat effects")
				if id == "pawned_light": expect.call(result["player_hp"] == ceili(float(result["player_max_hp"]) / 2.0), "Pawned Light sets half HP rounded upward after relic bonuses")
			"debt": expect.call(engine.held_embers(result) == engine.held_embers(before) + 120 and result["boon_debt"]["pending"], "Debt grants 120 run Embers and arms the first visit")
	var armory: Dictionary = Fixture.force_boon("armory")
	var rolled_slot: String = armory[Rules.STATE_KEY]["offers"][0]["slot"]
	armory["equipped_equipment"][rolled_slot] = ""
	expect.call(Rules.choose(engine, armory, "armory") == armory, "Armory cannot silently replace a changed or absent starter")
	var wounded: Dictionary = Fixture.force_boon("vitality")
	wounded["player_hp"] -= 3
	var healed: Dictionary = Rules.choose(engine, wounded, "vitality")
	expect.call(healed["player_hp"] == wounded["player_hp"] + 6, "Vitality adds exactly six current HP when damaged before talking")
	var purge: Dictionary = Fixture.force_boon("purge")
	expect.call(Rules.choose(engine, purge, "purge", ["pale_spark", "quick_stab"]) == purge, "Purge cannot remove an equipment card")
	expect.call(Rules.choose(engine, purge, "purge", ["pale_spark"]) == purge, "Incomplete Purge is free and leaves the offer pending")
	var one_copy: Dictionary = purge.duplicate(true)
	one_copy["attuned_magic_cards"].erase("pale_spark")
	expect.call(Rules.starter_spells(one_copy).count("pale_spark") == 1, "Multiplicity regression starts with exactly one remaining copy")
	expect.call(Rules.choose(engine, one_copy, "purge", ["pale_spark", "pale_spark"]) == one_copy, "Purge refuses two copies when only one remains")
	var blood: Dictionary = Fixture.force_boon("blood_price")
	expect.call(Rules.choose(engine, blood, "blood_price", ["quick_stab"]) == blood, "An unoffered spell never charges Blood Price")
	var declined: Dictionary = Rules.choose(engine, purge, "")
	expect.call(declined["deck_cards"] == purge["deck_cards"] and not Rules.pending(declined), "Take nothing consumes the choice without changing the build")
	var gift: Dictionary = Fixture.force_boon("elemental_gift")
	gift["current_room"] = Vector2i(1, 0)
	expect.call(Rules.choose(engine, gift, "") == gift, "Boon decisions are accepted only in the start room")

static func _heirlooms(expect: Callable) -> void:
	var state: Dictionary = Fixture.state(true)
	expect.call(state[Rules.STATE_KEY]["offers"][0]["boon"] == "heirloom", "A stored heirloom always occupies column one")
	expect.call(state["equipped_equipment"]["weapon"] != Fixture.PROOF_HEIRLOOM, "Heirloom is never automatically equipped")
	var taken: Dictionary = Rules.choose(Run.new(), state, "heirloom")
	expect.call(Store.heirloom(taken["progression"]).is_empty(), "Taking an heirloom consumes the progression piece")
	state["mode"] = "defeat"
	state["equipment_grafts"] = {Fixture.PROOF_HEIRLOOM: {"debug_only": true}}
	var retained: Dictionary = Rules.leave_heirloom(state, "")
	expect.call(Store.heirloom(retained["progression"]) == Fixture.PROOF_HEIRLOOM and retained[Rules.HEIRLOOM_END_KEY]["done"], "Leave nothing keeps the previous heirloom")
	var item: String = str(state["equipped_equipment"]["offhand"])
	var replaced: Dictionary = Rules.leave_heirloom(state, item)
	expect.call(Store.heirloom(replaced["progression"]) == item, "Newly left equipment replaces the previous piece")
	expect.call(typeof(replaced["progression"][Store.HEIRLOOM_KEY]) == TYPE_STRING, "Only the base item id persists, never upgrades or grafts")
	var still_equipped: String = str(replaced["equipped_equipment"]["weapon"])
	expect.call((replaced["equipped_equipment"] as Dictionary).values().has(still_equipped) and still_equipped != item, "Repeated-selection regression retries a different still-equipped piece")
	expect.call(Rules.leave_heirloom(replaced, still_equipped) == replaced, "Repeated run-end actions cannot replace the recorded choice")
	expect.call(Store.save_data(replaced["progression"]) and Store.heirloom(Store.load_data()) == item, "Heirloom survives profile save/reload")
	for outcome: String in ["victory", "defeat"]:
		state["mode"] = outcome
		var prompt: Dictionary = Dialogue.new().heirloom_dialogue(state)
		expect.call(Rules.heirloom_prompt_pending(state) and prompt["lines"][0]["text"] == Rules.definitions()["dialogue"]["heirloom_prompt"], outcome + " prompts with the exact approved line")
		expect.call(prompt["lines"][0]["options"].size() == state["equipped_equipment"].size() + 1, "Run end lists each equipped piece plus Leave nothing")

static func _debt(expect: Callable) -> void:
	var engine := Run.new()
	var state: Dictionary = Rules.choose(engine, Fixture.force_boon("debt"), "debt")
	var base: int = engine.merchant_buy_cost("scavenger", "pale_spark")
	expect.call(engine.merchant_buy_cost("scavenger", "pale_spark", state) == base, "Debt does not inflate prices before visiting a Scavenger")
	state["current_room"] = SCAVENGER_ONE
	Rules.enter_scavenger(state)
	expect.call(engine.merchant_buy_cost("scavenger", "pale_spark", state) == ceili(float(base) * 1.5), "First Scavenger prices are multiplied by 1.5 and rounded up")
	expect.call(Rules.price(state, PRICE_ROUNDING_BASE) == 263, "Debt rounds 175 times 1.5 upward to 263")
	expect.call(engine.scavenger_purge_price(state) == 75, "Debt also applies to the first room's purge service")
	state["current_room"] = SCAVENGER_TWO
	Rules.enter_scavenger(state)
	expect.call(engine.merchant_buy_cost("scavenger", "pale_spark", state) == base and engine.scavenger_purge_price(state) == 50, "Second Scavenger and later purge services use ordinary prices")
	state["current_room"] = SCAVENGER_ONE
	expect.call(engine.merchant_buy_cost("scavenger", "pale_spark", state) == ceili(float(base) * 1.5), "Saved first-room identity retains its price modifier")
	# Exercise production room entry as well as the pricing projection. Fixtures
	# use the ordinary legacy graph so this assertion needs no synthetic stock.
	var travelling: Dictionary = engine.create_new_run(Fixture.PROOF_SEED, Fixture.profile(), false)
	travelling["boon_debt"] = {"pending": true}
	var origin: Dictionary = travelling["rooms"]["0,0"]
	origin["connections"] = [{"coord": SCAVENGER_ONE, "door_dir": Vector2i.RIGHT, "kind": "outward"}]
	var shop: Dictionary = engine.room_metadata(travelling, SCAVENGER_ONE)
	shop["type"] = "scavenger"
	shop["merchant_kind"] = "scavenger"
	shop["revealed"] = true
	shop["sealed"] = false
	travelling["rooms"]["1,0"] = shop
	travelling = engine.move_to_room(travelling, SCAVENGER_ONE)
	expect.call(travelling["current_room"] == SCAVENGER_ONE and travelling["boon_debt"].get("room") == SCAVENGER_ONE and not travelling["boon_debt"]["pending"], "Normal Scavenger room entry consumes Debt's first-visit marker")

static func _analytics(expect: Callable) -> void:
	var state: Dictionary = Fixture.force_boon("vitality")
	state = Rules.offer(state)
	expect.call(Rules.offer(state) == state, "Repeated talk does not append another offered event")
	state = Rules.choose(Run.new(), state, "vitality")
	state["mode"] = "victory"
	state = Rules.leave_heirloom(state, "")
	var events: Array = state[Rules.EVENTS_KEY]
	expect.call(events.size() == 3 and events[0]["type"] == "run_start_boon_offered" and events[1]["type"] == "run_start_boon_chosen" and events[2]["type"] == "heirloom_left", "All three additive event receipts travel in the saved run")
	expect.call(events[0]["payload"].has("rolled_contents") and events[0]["payload"].has("columns") and events[1]["payload"]["boon"] == "vitality" and events[2]["payload"]["none"], "Event payloads identify columns, rolled content, chosen boon and empty heirloom")
