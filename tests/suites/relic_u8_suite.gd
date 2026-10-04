extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Keywords = preload("res://tests/suites/card_keywords_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const ALL_RELICS := ["quick_draw_bandolier", "alchemists_retort", "quartermasters_ledger"]
const TARGET := Vector2i(3, 4)
const NONE := Vector2i(-1, -1)

static func state(engine: Combat, relics: Array = [], hand: Array = ["powder_keg", "throwing_net", "bone_ward_charm", "crimson_draught", "quick_stab"]) -> Dictionary:
	var s: Dictionary = Keywords._state(engine, hand)
	s["relics"] = relics.duplicate()
	s["turn_flags"] = {}
	s["relic_flags"] = {}
	s["cards_per_turn"] = 2
	s["equipped_items"] = []
	for id: String in hand:
		if Data.card_is_item(id):
			(s["equipped_items"] as Array).append(id)
	(s["deck"] as Dictionary)["draw"] = ["brace", "brace", "brace", "brace"]
	return s

static func play(engine: Combat, source: Dictionary, id: String, target: Vector2i = NONE) -> Dictionary:
	var hand: Array = (source["deck"] as Dictionary)["hand"]
	var index: int = hand.find(id)
	var working: Dictionary = engine.prepare_player_card(source, index)
	var actions: Array = engine.card_play_actions(id, working)
	for action: Dictionary in actions:
		working = engine.apply_player_action(working, action, target if engine.player_action_needs_target(action) else NONE)
	return engine.finish_player_card(working, index, engine.card_plays_spent_for_actions(actions))

static func resume(source: Dictionary) -> Dictionary:
	var old_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u8_resume.save")
	Store.save_run_state({"mode": "combat", "combat_state": source})
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {}) as Dictionary
	Store.clear_saved_run()
	Store.set_run_storage_path(old_path)
	return loaded

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	_test_bandolier_payment_and_budget(engine, expect)
	_test_retort_values_and_resolution(engine, expect)
	_test_retort_stored_keg(engine, expect)
	_test_ledger_lifetime_and_resume(engine, expect)
	_test_ledger_healing_and_preservation(engine, expect)
	_test_card_faces_and_forecasts(engine, expect)
	_test_free_card_sequences(engine, expect)

static func _test_bandolier_payment_and_budget(engine: Combat, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["quick_draw_bandolier"])
	for id: String in Data.item_card_ids():
		expect.call(engine.card_def(id, s).get("_item_time_surcharge_relic", "") == "quick_draw_bandolier", "Bandolier stamps the authored source id on " + id)
		expect.call(engine.card_time_cost(id, s) == int(Data.card_def(id)["time"]) + 1, "Bandolier adds one Time to " + id)
		expect.call(engine.card_plays_spent(id, s) == 0 and engine.card_plays_spent_for_actions(engine.card_play_actions(id, s)) == 0, "Bandolier item actions stamp zero plays: " + id)
	expect.call(engine.card_time_cost("quick_stab", s) == engine.card_time_cost("quick_stab") and engine.card_plays_spent("quick_stab", s) == 1, "Bandolier is idle on non-items")
	var idle: Dictionary = play(engine, state(engine, [], ["throwing_net"]), "throwing_net", TARGET)
	expect.call(idle["cards_played_this_turn"] == 1 and idle["player_turn_time_spent"] == 4, "Without Bandolier items pay a play and printed Time")
	s["cards_played_this_turn"] = 2
	s["player_movement_remaining"] = 0
	expect.call(engine.hand_card_has_play_budget(s, 1) and not engine.hand_card_has_play_budget(s, 4), "Bandolier keeps items playable at zero plays")
	var after: Dictionary = play(engine, s, "throwing_net", TARGET)
	expect.call(after["cards_played_this_turn"] == 2 and after["player_turn_time_spent"] == 5, "Net commits five Time without spending a play")
	expect.call((after["enemies"][0] as Dictionary).get("immobilize", false) and engine.cards_remaining_this_turn(after) == 0, "Net resolves normally at zero plays")
	var loaded: Dictionary = resume(after)
	expect.call(loaded["cards_played_this_turn"] == 2 and loaded["player_turn_time_spent"] == 5 and engine.hand_card_has_play_budget(loaded, 2), "Zero-play item availability and payment survive resume")
	(s["player_turn_restrictions"] as Dictionary)["frozen"] = true
	expect.call(not engine.hand_card_has_play_budget(s, 1), "Bandolier respects the Frozen play restriction")
	s = state(engine, ["quick_draw_bandolier"], ["throwing_net"])
	s["cards_played_this_turn"] = 2
	s["banked_play_active"] = 1
	s["skill_ids"] = [Skills.skill_id_for_effect("banked_play_no_time")]
	(s["turn_flags"] as Dictionary)["quicken_pending"] = 99
	expect.call(engine.card_time_cost("throwing_net", s) == 2, "Bandolier's one-Time surcharge follows the Quicken minimum")
	after = play(engine, s, "throwing_net", TARGET)
	expect.call(after["player_turn_time_spent"] == 2 and not after["last_card_used_banked_play"] and after["banked_play_spent_this_activation"] == 0, "Free items do not spend a banked play or trigger Borrowed Time")
	expect.call(int((after["turn_flags"] as Dictionary).get("quicken_pending", 0)) == 0, "The item still consumes incoming Quicken")

static func _test_retort_values_and_resolution(engine: Combat, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["alchemists_retort"])
	for id: String in Data.item_card_ids():
		var base: Dictionary = Data.card_def(id)
		var boosted: Dictionary = Data.card_def_for_progression(id, s)
		for i: int in range((base["actions"] as Array).size()):
			var a: Dictionary = base["actions"][i]
			var b: Dictionary = boosted["actions"][i]
			for field: String in a:
				if field == "damage" or field == "burst_damage" or (field == "amount" and str(a["type"]) in ["block", "heal", "stoneskin"]):
					expect.call(int(b[field]) == ceili(float(a[field]) * 1.5), "Retort scales " + id + " " + field)
				else:
					expect.call(b[field] == a[field], "Retort leaves unrelated item value unchanged: " + id + " " + field)
	expect.call(Data.card_def_for_progression("quick_stab", s) == Data.card_def_for_progression("quick_stab", {}), "Retort is idle on non-items")
	expect.call(Data.card_def_for_progression("lamp_oil", s) == Data.card_def_for_progression("lamp_oil", {}), "Retort does not boost terrain hazard damage or placement")
	var guard: Dictionary = play(engine, s, "bone_ward_charm")
	expect.call(guard["player"]["block"] == 5 and guard["player"]["stoneskin"] == 3, "Retort grants ceil-scaled Block and Stoneskin")
	s = state(engine, ["alchemists_retort"], ["mossglass_elixir"])
	s["player"]["hp"] = 20
	var healed: Dictionary = play(engine, s, "mossglass_elixir")
	expect.call(healed["player"]["hp"] == 23 and healed["player"]["stoneskin"] == 2, "Retort boosts healing and rounds odd Stoneskin upward")
	s = state(engine, ["alchemists_retort"], ["thunderstone"])
	var action: Dictionary = engine.card_play_actions("thunderstone", s)[0]
	var preview: Dictionary = engine.resolve_player_action_for_presentation(s, action, TARGET)["state"]
	var commit: Dictionary = engine.apply_player_action(s, action, TARGET)
	expect.call(preview == commit and commit["enemies"][0]["hp"] == 32, "Retort's eight-damage Thunderstone preview equals commit")

static func _test_retort_stored_keg(engine: Combat, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["alchemists_retort"], ["powder_keg"])
	var placement: Vector2i = Vector2i(3, 3)
	var action: Dictionary = engine.card_play_actions("powder_keg", s)[0]
	var preview: Dictionary = engine.resolve_player_action_for_presentation(s, action, placement)["state"]
	var committed: Dictionary = engine.apply_player_action(s, action, placement)
	expect.call(preview == committed, "Retort keg placement preview equals commit")
	var index: int = engine._terrain_index_at_tile(committed, placement)
	expect.call(index >= 0, "Retort keg is placed")
	if index < 0:
		return
	var keg: Dictionary = committed["terrain"][index]
	expect.call(keg["hp"] == 3 and keg["burst_damage"] == 9, "Retort scales stored keg blast, leaves keg health at three")
	committed = resume(engine.finish_player_card(committed, 0))
	action = {"type": "ranged", "damage": 3, "range": 3}
	preview = engine.resolve_player_action_for_presentation(committed, action, placement)["state"]
	var blast: Dictionary = engine.apply_player_action(committed, action, placement)
	expect.call(preview == blast and blast["enemies"][0]["hp"] == 31, "Stored boosted blast survives resume; destruction forecast equals nine-damage commit")
	var idle: Dictionary = state(engine, [], ["powder_keg"])
	idle = play(engine, idle, "powder_keg", placement)
	index = engine._terrain_index_at_tile(idle, placement)
	expect.call(index >= 0 and idle["terrain"][index]["burst_damage"] == 6, "Without Retort keg blast stays six")

static func _test_ledger_lifetime_and_resume(engine: Combat, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["quartermasters_ledger"], ["throwing_net", "throwing_net"])
	var after: Dictionary = play(engine, s, "throwing_net", TARGET)
	expect.call(after["deck"]["burned"] == ["throwing_net"] and (after["deck"]["consumed"] as Array).is_empty() and (after["deck"]["discard"] as Array).is_empty(), "Ledger item leaves play through Exhaust")
	expect.call(after["equipped_items"] == ["throwing_net", "throwing_net"], "Ledger retains both physical copies in the run loadout")
	after = play(engine, resume(after), "throwing_net", TARGET)
	expect.call((after["deck"]["burned"] as Array).size() == 2 and (after["deck"]["hand"] as Array).is_empty(), "Each duplicate item copy is usable once per combat across resume")
	var next_turn: Dictionary = engine.prepare_next_player_turn(resume(after))
	expect.call(not (next_turn["deck"]["hand"] as Array).has("throwing_net") and (next_turn["deck"]["burned"] as Array).size() == 2, "Exhausted Ledger items cannot return on the next turn")
	var run_engine := RunEngine.new()
	var run: Dictionary = run_engine.create_new_run(81722, {})
	run = run_engine.set_combat_state(run, next_turn)
	expect.call(run["equipped_items"] == ["throwing_net", "throwing_net"] and (run["deck_cards"] as Array).count("throwing_net") == 2, "Run reconciliation keeps both exhausted items for later combats")
	var fresh: Dictionary = engine.create_combat(812, {"grid": s["grid"], "player_start": s["player"]["pos"], "enemies": s["enemies"], "objective": {"type": "kill_all"}}, {"hp": 30, "max_hp": 30, "deck_cards": ["throwing_net", "throwing_net"], "equipped_items": run["equipped_items"], "relics": ["quartermasters_ledger"], "hand_size": 2})
	expect.call((fresh["deck"]["hand"] as Array).count("throwing_net") == 2 and (fresh["deck"]["burned"] as Array).is_empty(), "Next combat restores each Ledger item copy")
	var idle: Dictionary = play(engine, state(engine, [], ["throwing_net"]), "throwing_net", TARGET)
	expect.call(idle["deck"]["consumed"] == ["throwing_net"] and (idle["equipped_items"] as Array).is_empty(), "Without Ledger the item is removed from the run")

static func _test_ledger_healing_and_preservation(engine: Combat, expect: Callable) -> void:
	for id: String in ["crimson_draught", "mossglass_elixir"]:
		var s: Dictionary = state(engine, ALL_RELICS, [id])
		var card: Dictionary = engine.card_def(id, s)
		expect.call(card["consume_on_play"] and not card["burn"], "Ledger excludes healing item: " + id)
		var after: Dictionary = resume(play(engine, s, id))
		expect.call(after["deck"]["consumed"] == [id] and (after["equipped_items"] as Array).is_empty(), "Healing item remains permanently Consumed across resume: " + id)
	var s: Dictionary = state(engine, ["quartermasters_ledger", "pyre_keepers_urn", "ashen_phylactery"], ["throwing_net"])
	s["skill_ids"] = [Skills.skill_id_for_effect("preserve_item"), Skills.skill_id_for_effect("preserve_burn")]
	s["skill_flags"] = {"item_preserve_armed": true, "burn_preserve_armed": true}
	var after: Dictionary = play(engine, s, "throwing_net", TARGET)
	expect.call(after["deck"]["burned"] == ["throwing_net"] and (after["deck"]["discard"] as Array).is_empty(), "Preservation cannot replay a Ledger item in this combat")
	expect.call(not after.has("last_exhausted_card") and after["player"]["stoneskin"] == 0, "Ledger item Exhaust grants no non-item Exhaust history/rewards")
	after = engine.prepare_next_player_turn(resume(after))
	expect.call(not (after["deck"]["hand"] as Array).has("throwing_net"), "Urn cannot return a once-per-combat item")
	expect.call(not bool(engine.card_def("quick_stab", s).get("burn", false)), "Ledger is idle on non-items")

static func _test_card_faces_and_forecasts(engine: Combat, expect: Callable) -> void:
	var scene := RunScene.new()
	var s: Dictionary = state(engine, ALL_RELICS)
	scene.set("_combat_state", s)
	var keg: Dictionary = engine.card_def("powder_keg", s)
	var cost: Dictionary = ActionIcons.cost_rows_for_card(keg)[0][0]
	expect.call(cost["icon"] == "exhaust" and str(cost.get("tooltip", "")).contains("Once per combat"), "Ledger face reuses Exhaust with once-per-combat tooltip")
	expect.call(not ActionIcons.card_rules_text(keg).contains("Consume"), "Ledger derived rules label agrees with Exhaust")
	var healing_cost: Dictionary = ActionIcons.cost_rows_for_card(engine.card_def("crimson_draught", s))[0][0]
	expect.call(healing_cost["icon"] == "consume", "Healing face keeps Consume")
	var display: Dictionary = scene.call("_card_widget_display", "powder_keg", s)
	expect.call(display.get("time_surcharge", 0) == 1, "Item hand Time badge includes Bandolier surcharge")
	var blast_value: String = ""
	for row: Array in display.get("summary_rows", []):
		for token: Dictionary in row:
			if str(token.get("icon", "")) == "detonate":
				blast_value = str(token.get("value", ""))
	expect.call(blast_value == "9", "Retort keg card face prints its nine-damage blast")
	var actions: Array = engine.card_play_actions("throwing_net", s)
	var action: Dictionary = actions[0]
	var forecast: Dictionary = scene.call("_preview_damage_for_action", s, action, TARGET)
	var resolved: Dictionary = engine.apply_player_action(s, action, TARGET)
	expect.call(int((forecast.get("enemy_1", {}) as Dictionary).get("hp_loss", 0)) == 0 and resolved["enemies"][0]["hp"] == s["enemies"][0]["hp"], "Retort never turns the Net's zero damage into damage")
	scene.set("_selected_card_index", 1)
	var paid: Dictionary = scene.call("_pass_preview_state_after_resolved_target", resolved, actions, actions.size())
	var committed: Dictionary = engine.finish_player_card(resolved, 1, engine.card_plays_spent_for_actions(actions))
	expect.call(paid["cards_played_this_turn"] == committed["cards_played_this_turn"] and paid["player_turn_time_spent"] == committed["player_turn_time_spent"] and paid["deck"] == committed["deck"], "Net completion forecast equals zero-play, five-Time Ledger commit")
	s["cards_played_this_turn"] = 2
	scene.set("_combat_state", s)
	scene.call("_mark_combat_preview_state_changed")
	expect.call(bool((scene.call("_card_playability_for_index", 1) as Dictionary).get("printed_playable", false)), "Hand UI allows Bandolier Net at zero remaining plays")
	expect.call(not bool((scene.call("_card_playability_for_index", 4) as Dictionary).get("printed_playable", true)), "Hand UI still disables ordinary cards at zero plays")
	s = state(engine, ALL_RELICS, ["bone_ward_charm"])
	scene.set("_combat_state", s)
	scene.set("_selected_card_index", 0)
	scene.call("_mark_combat_preview_state_changed")
	var preview: Dictionary = scene.call("_card_preview_for_index", 0)
	paid = scene.call("_pass_preview_state_after_resolved_target", preview["state"], preview["actions"], (preview["actions"] as Array).size())
	committed = play(engine, s, "bone_ward_charm")
	expect.call(paid["player"] == committed["player"] and paid["cards_played_this_turn"] == 0 and paid["player_turn_time_spent"] == 5, "Boosted defense hover forecast equals Ledger/Bandolier commit")
	s = state(engine, ALL_RELICS, ["mossglass_elixir"])
	s["player"]["hp"] = 20
	scene.set("_combat_state", s)
	scene.call("_mark_combat_preview_state_changed")
	preview = scene.call("_card_preview_for_index", 0)
	paid = scene.call("_pass_preview_state_after_resolved_target", preview["state"], preview["actions"], (preview["actions"] as Array).size())
	committed = play(engine, s, "mossglass_elixir")
	expect.call(paid["player"] == committed["player"] and paid["deck"] == committed["deck"], "Boosted healing hover forecast equals Consume commit")
	s = state(engine, ALL_RELICS, ["thunderstone"])
	forecast = scene.call("_preview_damage_for_action", s, engine.card_play_actions("thunderstone", s)[0], TARGET)
	expect.call(int((forecast.get("enemy_1", {}) as Dictionary).get("hp_loss", 0)) == 8, "Boosted damage uses the existing eight-damage hover forecast")
	scene.free()

static func _test_free_card_sequences(engine: Combat, expect: Callable) -> void:
	var tempo := preload("res://scripts/tempo_rules.gd")
	var s: Dictionary = state(engine, ["quick_draw_bandolier"], ["throwing_net", "whetstone", "quick_stab", "quick_stab"])
	s = play(engine, s, "throwing_net", TARGET)
	s = resume(play(engine, s, "whetstone"))
	var action: Dictionary = engine.card_play_actions("quick_stab", s)[0]
	expect.call(action.get("_follow_up_active", false) and engine.final_damage_for_player_action(s, action) == 13 and engine._action_pierces_defense(engine._resolved_surface_action(s, action)), "Free Bandolier item then Whetstone preserves Follow-up, next-attack damage and Pierce")
	var forecast: Dictionary = engine.surface_preview_for_player_action(s, action, TARGET)["state"]
	var committed: Dictionary = play(engine, s, "quick_stab", TARGET)
	expect.call(forecast["enemies"] == committed["enemies"] and committed["enemies"][0]["hp"] == 27, "Whetstone after a free item previews and commits thirteen damage")
	expect.call(engine.final_damage_for_player_action(committed, engine.card_play_actions("quick_stab", committed)[0]) == 9, "The following Quick Stab keeps Follow-up and spends Whetstone once")
	var rite: Dictionary = state(engine, ["liturgy_of_ash"], ["rite_of_the_mountain", "quick_stab"])
	rite = play(engine, rite, "rite_of_the_mountain")
	expect.call(rite["cards_played_this_turn"] == 0 and bool(engine.card_play_actions("quick_stab", rite)[0].get("_follow_up_active", false)), "Liturgy's free Rite activates Follow-up on the next attack")
	var echo: Dictionary = state(engine, ["quick_draw_bandolier", "echoing_blade"], ["throwing_net", "quick_stab", "thunderstone", "quick_stab"])
	echo = play(engine, echo, "throwing_net", TARGET)
	echo = play(engine, echo, "quick_stab", TARGET)
	echo = resume(echo)
	action = engine.card_play_actions("thunderstone", echo)[0]
	expect.call(engine.final_damage_for_player_action(echo, action) == 7, "Echoing Blade applies to the immediately following free item")
	forecast = engine.surface_preview_for_player_action(echo, action, TARGET)["state"]
	committed = play(engine, echo, "thunderstone", TARGET)
	expect.call(forecast["enemies"] == committed["enemies"] and tempo.next_attack_buffs(committed).is_empty(), "Echoing Blade's free-item preview equals commit and expires at card finish")
	var idle: Dictionary = state(engine, ["quick_draw_bandolier", "echoing_blade"], ["throwing_net", "quick_stab", "bone_ward_charm", "quick_stab"])
	idle = play(engine, idle, "throwing_net", TARGET)
	idle = play(engine, idle, "quick_stab", TARGET)
	idle = play(engine, idle, "bone_ward_charm")
	expect.call(tempo.next_attack_buffs(idle).is_empty() and engine.final_damage_for_player_action(idle, engine.card_play_actions("quick_stab", idle)[0]) == 9, "Echoing Blade expires on the next free card even when it has no attack")
	var moved: Dictionary = state(engine, ["quick_draw_bandolier", "duelist_whetstone"], ["throwing_net", "sidestep_slash", "quick_stab"])
	moved = play(engine, moved, "throwing_net", TARGET)
	moved = engine.prepare_player_card(moved, 0)
	var actions: Array = engine.card_play_actions("sidestep_slash", moved)
	moved = engine.apply_player_action(moved, actions[0], Vector2i(3, 3))
	var hp: int = moved["enemies"][0]["hp"]
	forecast = engine.surface_preview_for_player_action(moved, actions[1], TARGET)["state"]
	moved = engine.apply_player_action(moved, actions[1], TARGET)
	expect.call(forecast == moved and hp - int(moved["enemies"][0]["hp"]) == 7, "Duelist Whetstone movement-attack retains its bonus after a free item")
	moved = engine.finish_player_card(moved, 0)
	expect.call(bool(engine.card_play_actions("quick_stab", moved)[0].get("_follow_up_active", false)), "Quick Stab keeps Follow-up after the Whetstone movement-attack card")
