extends RefCounted
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const KeywordSuite = preload("res://tests/suites/card_keywords_suite.gd")
const TempoRules = preload("res://scripts/tempo_rules.gd")
const Rules = preload("res://scripts/tempo_relic_rules.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const NONE := Vector2i(-1, -1)
const TARGET := Vector2i(3, 4)
const FIXTURES := {
	"u4_strike": {"time": 4, "actions": [{"type": "melee", "damage": 3, "range": 1}]},
	"u4_heavy": {"time": 6, "actions": [{"type": "block", "amount": 1}]},
	"u4_guard": {"time": 3, "actions": [{"type": "block", "amount": 2}]},
	"u4_double": {"time": 3, "actions": [{"type": "melee", "damage": 1, "range": 1}, {"type": "melee", "damage": 1, "range": 1}]},
	"u4_stagger": {"time": 3, "actions": [{"type": "melee", "damage": 0, "range": 1, "stagger": 9}]},
	"u4_ranged_push": {"time": 3, "actions": [{"type": "ranged", "damage": 1, "range": 4, "push": 1}]},
	"u4_push": {"time": 3, "actions": [{"type": "melee", "damage": 1, "range": 1, "push": 1}]},
	"u4_follow": {"time": 3, "actions": [{"type": "melee", "damage": 1, "range": 1}], "follow_up": {"mods": [{"action": 0, "add": {"damage": 2}}]}},
	"u4_empower": {"time": 4, "actions": [{"type": "block", "amount": 1}], "empower": {"cost": {"time": 2}, "mods": [{"action": 0, "add": {"amount": 1}}]}},
	"u4_rite": {"time": 4, "burn": true, "actions": [], "rite": {"effects": []}},
	"u4_item": {"time": 4, "consume_on_play": true, "item": true, "actions": [{"type": "block", "amount": 1}]},
	"u4_flurry": {"time": 4, "flurry": true, "actions": [{"type": "block", "amount": 1}]}
}

static func install_fixtures() -> void:
	for id: String in FIXTURES:
		var card: Dictionary = (FIXTURES[id] as Dictionary).duplicate(true)
		card["name"] = id.trim_prefix("u4_").capitalize()
		card["description"] = ""
		card["rarity"] = "common"
		card["reward_pool"] = false
		card["art_path"] = GameData.card_def("quick_stab").get("art_path", "")
		GameData.cards()[id] = card

static func state(engine: CombatEngine, relics: Array = []) -> Dictionary:
	var result: Dictionary = KeywordSuite._state(engine, ["u4_strike", "u4_heavy", "u4_guard", "u4_follow", "u4_guard"])
	result["relics"] = relics.duplicate()
	result["cards_per_turn"] = 2 + GameData.stat_bonus_from_relics(relics, "cards_per_turn_bonus")
	result["player_turn_time_spent"] = 0
	result["cards_played_this_turn"] = 0
	(result["deck"] as Dictionary)["draw"] = ["u4_guard", "u4_strike", "u4_heavy"]
	result["turn_flags"] = {}
	result["relic_flags"] = {}
	result["turn_queue"] = [{"kind": "enemy", "key": "enemy:1", "enemy_id": 1, "time": 14, "seq": 1}, {"kind": "enemy", "key": "enemy:2", "enemy_id": 2, "time": 8, "seq": 2}]
	return result

static func play(engine: CombatEngine, source: Dictionary, id: String, target: Vector2i = NONE, empower: bool = false) -> Dictionary:
	var working: Dictionary = source.duplicate(true)
	(working["deck"] as Dictionary)["hand"] = [id]
	working = engine.prepare_player_card(working, 0, "empower" if empower else "play")
	var actions: Array = engine.card_play_actions(id, working)
	for action: Dictionary in actions:
		working = engine.apply_player_action(working, action, target if engine.player_action_needs_target(action) else NONE)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions))

static func resume(source: Dictionary) -> Dictionary:
	var previous_path: String = ProgressionStore._run_storage_path
	ProgressionStore.set_run_storage_path("user://relic_u4_resume.save")
	ProgressionStore.save_run_state({"mode": "combat", "combat_state": source})
	var loaded: Dictionary = ProgressionStore.load_saved_run().get("combat_state", {}) as Dictionary
	ProgressionStore.clear_saved_run()
	ProgressionStore.set_run_storage_path(previous_path)
	return loaded

static func run(expect: Callable) -> void:
	install_fixtures()
	var engine := CombatEngine.new()
	_test_sundial(engine, expect)
	_test_late_bell(engine, expect)
	_test_pendulum(engine, expect)
	_test_quicken_triggers(engine, expect)
	_test_borrowed(engine, expect)
	_test_sash(engine, expect)
	_test_finished_card_pricing(engine, expect)
	_test_crown(engine, expect)
	_test_feint_echo(engine, expect)
	_test_ui(engine, expect)
	for id: String in FIXTURES:
		GameData.cards().erase(id)

static func hero_projection(engine: CombatEngine, s: Dictionary) -> int:
	for entry: Dictionary in engine.current_turn_order(s, 20):
		if str(entry.get("kind", "")) == "player" and not bool(entry.get("active", false)):
			return int(entry.get("time", -1))
	return -1

static func _test_sundial(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["pocket_sundial"])
	expect.call(hero_projection(engine, s) == 19, "Sundial does not reduce a pass with both base plays unused")
	s["card_play_bonus_this_turn"] = 8
	expect.call(hero_projection(engine, s) == 19, "Bonus play refunds do not add Wait or earn Sundial")
	s["card_play_bonus_this_turn"] = 0
	s = play(engine, s, "u4_guard")
	expect.call(hero_projection(engine, s) == 17, "Sundial one play used still pays five Wait")
	var end: Dictionary = engine.finish_player_activation(resume(s))
	var queue: Array = end["turn_queue"]
	var hero_time: int = -1
	for entry: Dictionary in queue:
		if str(entry.get("kind", "")) == "player": hero_time = int(entry["time"])
	expect.call(hero_time == 17, "Sundial projection equals scheduling after save/resume")
	s["cards_played_this_turn"] = 2
	expect.call(hero_projection(engine, s) == 10, "Sundial brings a full turn back two Time sooner")

static func _test_late_bell(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["toll_late_bell"])
	var actions: Array = engine.card_play_actions("u4_strike", s)
	var preview: Dictionary = engine.apply_player_action(s, actions[0], TARGET)
	expect.call(int((preview["enemies"][0] as Dictionary)["hp"]) == 37, "Late Bell includes five Wait after the pending first card")
	var committed: Dictionary = play(engine, s, "u4_strike", TARGET)
	expect.call(preview["enemies"] == committed["enemies"], "Late Bell forecast equals commit")
	s["turn_queue"][0]["time"] = 19
	s["player_turn_time_spent"] = 1
	preview = engine.apply_player_action(s, engine.card_play_actions("u4_strike", s)[0], TARGET)
	expect.call(int((preview["enemies"][0] as Dictionary)["hp"]) == 37, "Enemy at exact hero next-turn time is not late")
	s["turn_queue"][0]["time"] = 14
	s["turn_flags"] = {"quicken_pending": 2}
	preview = engine.apply_player_action(s, engine.card_play_actions("u4_strike", s)[0], TARGET)
	expect.call(int((preview["enemies"][0] as Dictionary)["hp"]) == 37, "Quicken discounts card Time but the unused play still waits")
	var order: Array[Dictionary] = engine.current_turn_order(s)
	var bell: bool = false
	for entry: Dictionary in order:
		bell = bell or str(entry.get("late_relic_id", "")) == "toll_late_bell"
	expect.call(not bell, "Late Bell does not mark enemies before the end-now projection")
	s["current_actor"] = {"kind": "enemy", "enemy_id": 2}
	expect.call(not Rules.is_late(engine, s, 1, GameData.relic_effects_for_state(s)), "Late Bell idle on enemy turns")

	for partner: String in ["borrowed_hourglass", "pocket_sundial"]:
		var paired: Dictionary = state(engine, ["toll_late_bell", partner])
		paired["turn_queue"][0]["time"] = 12
		var action: Dictionary = engine.card_play_actions("u4_strike", paired)[0]
		var forecast: Dictionary = engine.surface_preview_for_player_action(paired, action, TARGET)["state"]
		var commit: Dictionary = play(engine, paired, "u4_strike", TARGET)
		expect.call(forecast["enemies"] == commit["enemies"] and commit["enemies"][0]["hp"] == 37, "Late Bell includes Wait and excludes the immediate shortcut from " + partner + " in preview and commit")
		paired["turn_queue"][0]["time"] = 8
		paired["turn_queue"][1]["time"] = 8
		expect.call(not Rules.is_late(engine, paired, 1, GameData.relic_effects_for_state(paired)), "Late Bell rail includes pending Wait with " + partner)
		paired[Rules.DEBT_KEY] = 3
		paired["turn_queue"][0]["time"] = 11
		expect.call(not Rules.is_late(engine, paired, 1, GameData.relic_effects_for_state(paired)), "Late Bell includes carried Time debt with " + partner)

static func _test_pendulum(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["pendulum_weight"])
	(s["enemies"][0] as Dictionary)["block"] = 1
	(s["enemies"][0] as Dictionary)["stoneskin"] = 1
	(s["enemies"][0] as Dictionary)["freeze"] = 1
	var a: Dictionary = engine.card_play_actions("u4_stagger", s)[0]
	var preview: Dictionary = engine.apply_player_action(s, a, TARGET)
	var committed: Dictionary = play(engine, s, "u4_stagger", TARGET)
	expect.call(preview["enemies"] == committed["enemies"], "Pendulum forecast equals commit")
	expect.call(int((committed["enemies"][0] as Dictionary)["hp"]) == 39, "Stagger overflow three uses Block/Stoneskin and ignores Freeze")
	committed = resume(committed)
	engine._apply_stagger_to_enemy(committed, 1, 3)
	expect.call(int((committed["enemies"][0] as Dictionary)["hp"]) == 36, "Persisted Stagger cap converts all later delay")
	var idle: Dictionary = state(engine, ["pendulum_weight"])
	engine._apply_stagger_to_enemy(idle, 1, 3)
	expect.call(int((idle["enemies"][0] as Dictionary)["hp"]) == 40, "Pendulum idle under cap")
	(idle["enemies"][0] as Dictionary)["type"] = "iskaldra"
	idle["turn_flags"] = {"stagger_applied": {"1": 5}}
	engine._apply_stagger_to_enemy(idle, 1, 8)
	expect.call(int((idle["enemies"][0] as Dictionary)["hp"]) == 37, "Dragon halving precedes overflow calculation")
	var lethal: Dictionary = state(engine, ["pendulum_weight", "toll_late_bell"])
	(lethal["enemies"][0] as Dictionary)["hp"] = 2
	lethal["turn_flags"] = {"stagger_applied": {"1": 6}}
	engine._apply_stagger_to_enemy(lethal, 1, 3)
	expect.call(int(lethal.get("death_bonus_card_plays_this_turn", 0)) == 0, "Relic overflow kills never grant a card-hit kill play")

static func _test_quicken_triggers(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = play(engine, state(engine, ["hourglass_splinter"]), "u4_heavy")
	expect.call(TempoRules.quicken_pending(s) == 2 and int(s["player_turn_time_spent"]) == 6, "Hourglass heavy card grants next-card Quicken without self discount")
	var cheap: Dictionary = state(engine, ["hourglass_splinter"])
	cheap["turn_flags"] = {"quicken_pending": 1}
	cheap = play(engine, cheap, "u4_heavy")
	expect.call(TempoRules.quicken_pending(cheap) == 0, "Hourglass threshold reads cost after discounts")
	s = play(engine, resume(s), "u4_guard")
	expect.call(TempoRules.quicken_pending(s) == 0 and int(s["player_turn_time_spent"]) == 7, "Hourglass Quicken survives resume and is consumed once")
	s = play(engine, state(engine, ["overclock_coil", "hourglass_splinter"]), "u4_empower", NONE, true)
	expect.call(TempoRules.quicken_pending(s) == 4, "Overclock and heavy-Time Quicken stack after Empower payment")
	cheap = play(engine, state(engine, ["overclock_coil"]), "u4_empower")
	expect.call(TempoRules.quicken_pending(cheap) == 0, "Overclock idle with Empower off")
	expect.call(TempoRules.quicken_pending(engine.finish_player_activation(s)) == 0, "Relic Quickens expire at activation end")

static func _test_borrowed(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = play(engine, state(engine, ["borrowed_hourglass"]), "u4_guard")
	(s["player"] as Dictionary)["block"] = 8
	s["player_movement_remaining"] = 0
	expect.call(hero_projection(engine, s) == 0, "Borrowed Hourglass projects immediate hero turn")
	var ended: Dictionary = engine.finish_player_activation(s)
	ended = resume(ended)
	var result: Dictionary = engine.advance_one_activation_with_steps(ended)
	var extra: Dictionary = result["state"]
	expect.call(engine.is_player_turn(extra) and int(extra["initiative_clock"]) == 0 and int(extra["turn"]) == int(s["turn"]) + 1, "Borrowed extra turn starts before enemy activation")
	expect.call(int(extra["cards_played_this_turn"]) == 0 and int(extra["player_movement_remaining"]) == int(extra["player_movement_capacity"]) and int((extra["player"] as Dictionary)["block"]) == 0, "Borrowed turn resets normal plays, movement and Block")
	expect.call(((extra["deck"] as Dictionary)["hand"] as Array).size() == 2, "Borrowed turn draws normally")
	extra = play(engine, extra, "u4_guard")
	expect.call(hero_projection(engine, extra) == 25, "Borrowed following activation includes both turns' Time and Wait")
	extra = engine.finish_player_activation(resume(extra))
	var hero: int = -1
	for entry: Dictionary in extra["turn_queue"]:
		if str(entry.get("kind", "")) == "player": hero = int(entry["time"])
	expect.call(hero == 25, "Borrowed cannot trigger twice after resume; debt matches projection")
	var idle: Dictionary = state(engine, ["borrowed_hourglass"])
	idle["cards_played_this_turn"] = 2
	expect.call(hero_projection(engine, idle) == 9, "Borrowed idle when all plays spent")
	expect.call(not Rules.used(engine.finish_player_activation(idle), GameData.relic_effects_for_state(idle)[0]), "Idle Borrowed does not spend combat charge")
	var together: Dictionary = state(engine, ["borrowed_hourglass", "pocket_sundial"])
	together = play(engine, together, "u4_guard")
	together = (engine.advance_one_activation_with_steps(engine.finish_player_activation(together))["state"] as Dictionary)
	expect.call(hero_projection(engine, together) == 27, "Sundial does not reduce either partial activation; Borrowed carries Wait without duplicating base initiative")

static func _test_sash(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["whirling_sash"])
	expect.call(engine.cards_remaining_this_turn(s) == 3, "Whirling Sash adds one play")
	expect.call(engine.card_time_cost("u4_guard", s) == 3, "Whirling Sash first two cards have no surcharge")
	s["cards_played_this_turn"] = 2
	s["turn_flags"]["cards_finished"] = 2
	expect.call(engine.card_time_cost("u4_guard", s) == 5, "Whirling Sash third card costs two more")
	var display: Node = RunScene.new()
	var shown: Dictionary = display.call("_card_widget_display", "u4_guard", s)
	expect.call(int(shown.get("time_surcharge", 0)) == 2, "Whirling Sash hand reuses Time surcharge display")
	display.free()
	s = play(engine, resume(s), "u4_guard")
	expect.call(int(s["player_turn_time_spent"]) == 5, "Whirling Sash surcharge is paid after resume")
	var discounted: Dictionary = state(engine, ["whirling_sash"])
	discounted["cards_played_this_turn"] = 2
	discounted["turn_flags"] = {"quicken_pending": 3, "cards_finished": 2}
	expect.call(engine.card_time_cost("u4_guard", discounted) == 3, "Whirling surcharge follows the printed-cost discount floor")
	var next_turn: Dictionary = engine.prepare_next_player_turn(s)
	expect.call(engine.cards_remaining_this_turn(next_turn) == 3 and engine.card_time_cost("u4_guard", next_turn) == 3, "Sash play bonus repeats each turn and surcharge resets")

static func _test_crown(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["crown_of_surplus"])
	var card: Dictionary = engine.card_def("u4_strike", s)
	expect.call(bool((card["empower"] as Dictionary).get("repeat_first", false)), "Crown grants existing Empower to an eligible card")
	var prepared: Dictionary = s.duplicate(true)
	(prepared["deck"] as Dictionary)["hand"] = ["u4_strike"]
	prepared = engine.prepare_player_card(prepared, 0, "empower")
	var a: Array = engine.card_play_actions("u4_strike", prepared)
	expect.call(a.size() == 2 and bool((a[1] as Dictionary).get("reuse_previous_target", false)), "Crown repeats first action via automatic target reuse")
	var preview: Dictionary = engine.apply_player_action(prepared, a[0], TARGET)
	preview = engine.apply_player_action(preview, a[1], TARGET)
	var committed: Dictionary = play(engine, s, "u4_strike", TARGET, true)
	expect.call(preview["enemies"] == committed["enemies"] and int((committed["enemies"][0] as Dictionary)["hp"]) == 34 and int(committed["player_turn_time_spent"]) == 7, "Crown damage forecast equals repeat commit and +3 Time")
	var surface_preview: Dictionary = engine.surface_preview_for_player_action(prepared, a[0], TARGET)
	expect.call((surface_preview["state"] as Dictionary)["enemies"] == committed["enemies"], "Crown existing hover forecast includes automatic repeat")
	var repeated_push: Dictionary = play(engine, s, "u4_ranged_push", TARGET, true)
	expect.call(int((repeated_push["enemies"][0] as Dictionary)["hp"]) == 38 and (repeated_push["enemies"][0] as Dictionary)["pos"] == Vector2i(5, 4), "Crown follows original displaced enemy while it remains legal")
	var off: Dictionary = play(engine, s, "u4_strike", TARGET)
	expect.call(int((off["enemies"][0] as Dictionary)["hp"]) == 37, "Crown idle with Empower off")
	var pushed: Dictionary = play(engine, s, "u4_push", TARGET, true)
	expect.call(int((pushed["enemies"][0] as Dictionary)["hp"]) == 39, "Crown repeat does nothing after target leaves legal range")
	(s["enemies"][0] as Dictionary)["hp"] = 2
	var lethal: Dictionary = play(engine, s, "u4_strike", TARGET, true)
	expect.call(int(lethal.get("death_bonus_card_plays_this_turn", 0)) == 1, "Crown cannot hit/reward a dead target twice")
	var guarded: Dictionary = play(engine, state(engine, ["crown_of_surplus"]), "u4_guard", NONE, true)
	expect.call(int((guarded["player"] as Dictionary)["block"]) == 4, "Crown repeats targetless first action")
	for excluded: String in ["u4_rite", "u4_item", "u4_flurry"]:
		expect.call(not engine.card_def(excluded, s).has("empower"), "Crown excludes " + excluded)
	expect.call(not bool((engine.card_def("u4_empower", s)["empower"] as Dictionary).get("repeat_first", false)), "Crown preserves printed Empower")

static func _test_feint_echo(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["feint_ribbon", "echoing_blade"])
	var idle: Array = engine.card_play_actions("u4_follow", s)
	expect.call(int((idle[0] as Dictionary)["damage"]) == 1, "Feint and Echo idle before two tiles moved")
	s = engine.apply_player_action(s, {"type": "move", "range": 2, "_movement_pool": true}, Vector2i(2, 2))
	# Put the test target adjacent after independent movement.
	(s["enemies"][0] as Dictionary)["pos"] = Vector2i(3, 2)
	var active: Array = engine.card_play_actions("u4_follow", s)
	expect.call(int((active[0] as Dictionary)["damage"]) == 3 and bool((active[0] as Dictionary).get("_follow_up_active", false)), "Feint activates first-card Follow-up after independent movement")
	s = play(engine, s, "u4_follow", Vector2i(3, 2))
	expect.call(TempoRules.quicken_pending(s) == 1 and TempoRules.player_badges(s).size() == 2, "Echo Follow-up grants Quicken and next-attack badges")
	expect.call(str(TempoRules.player_badges(s)[1]["tooltip"]).contains("Next card's attacks"), "Echo badge explains its whole-next-card scope")
	s = resume(s)
	var preview: Dictionary = engine.apply_player_action(s, engine.card_play_actions("u4_double", s)[0], Vector2i(3, 2))
	preview = engine.apply_player_action(preview, engine.card_play_actions("u4_double", s)[1], Vector2i(3, 2))
	var committed: Dictionary = play(engine, s, "u4_double", Vector2i(3, 2))
	expect.call(preview["enemies"] == committed["enemies"] and int((committed["enemies"][0] as Dictionary)["hp"]) == 31, "Echo boosts every attack of next card, forecast equals commit")
	expect.call(TempoRules.next_attack_buffs(committed).is_empty() and TempoRules.quicken_pending(committed) == 0, "Echo next-card bonuses consume once across resume")
	var guard: Dictionary = play(engine, s, "u4_guard")
	expect.call(TempoRules.next_attack_buffs(guard).is_empty(), "Echo expires on next card even without attacks")
	var earlier: Dictionary = state(engine, ["feint_ribbon"])
	earlier["cards_played_this_turn"] = 1
	earlier["turn_flags"] = {"tiles_moved": 2}
	expect.call(int((engine.card_play_actions("u4_follow", earlier)[0] as Dictionary)["damage"]) == 3, "Normal later-card Follow-up preserved")

static func _test_ui(engine: CombatEngine, expect: Callable) -> void:
	var scene: Node = RunScene.new()
	var s: Dictionary = state(engine, ["toll_late_bell"])
	s["turn_queue"][0]["time"] = 20
	var entry: Dictionary = {}
	for candidate: Dictionary in engine.current_turn_order(s):
		if candidate.has("late_relic_id"): entry = candidate; break
	var slot: Control = scene.call("_build_turn_order_slot", entry, 1)
	var bell_badge: Control = slot.get_node_or_null("LateRelicIcon") as Control
	var bell: TextureRect = bell_badge.get_child(0) as TextureRect if bell_badge != null and bell_badge.get_child_count() > 0 else null
	expect.call(bell_badge != null and bell != null and bell.size == Vector2(24, 24) and bell_badge.tooltip_text == "Late: your attacks deal 3 more.", "Late Bell uses its own 24px icon in a framed rail badge with the exact tooltip")
	var bell_data: Dictionary = (GameData.relics()["toll_late_bell"] as Dictionary).duplicate(true)
	GameData.relics()["toll_late_bell"]["effects"][0]["amount"] = 7
	var changed_slot: Control = scene.call("_build_turn_order_slot", entry, 1)
	expect.call(changed_slot.get_node("LateRelicIcon").tooltip_text == "Late: your attacks deal 7 more.", "Late Bell tooltip reads its authored damage effect")
	changed_slot.free()
	GameData.relics()["toll_late_bell"] = bell_data
	var widget := preload("res://scripts/card_widget.gd").new()
	for source: Array in [["whirling_sash", "_tempo_time_surcharge", "+2"], ["quick_draw_bandolier", "_item_time_surcharge", "+2"], ["fencers_gloves", "_relic_time_discount", "-2"]]:
		var id: String = source[0]
		var key: String = source[1]
		var original_name: String = GameData.relics()[id]["name"]
		GameData.relics()[id]["name"] = "Authored Source"
		var card: Dictionary = {"time": 3}
		card[key] = 2
		card[key + "_relic"] = id
		widget.call("_refresh_time_badge", card)
		expect.call(widget.get_node("TimeCostBadge").tooltip_text.contains("Authored Source: " + str(source[2])), "Time badge reads source relic name for " + key)
		GameData.relics()[id]["name"] = original_name
	widget.free()

	slot.free()
	s = state(engine, ["crown_of_surplus"])
	scene.set("_combat_state", s)
	scene.set("_selected_card_index", 0)
	expect.call(str(scene.call("_empower_command_text", false)) == "Empower +3 Time [E]", "Crown uses existing Empower button label")
	expect.call(str(scene.call("_empower_command_tooltip")) == "Empower (+3 Time): repeat this card's first action.\nThe cost is paid when the card finishes. Press E (controller: right stick).", "Crown tooltip keeps the shared cost-timing and input hints")
	(s["deck"] as Dictionary)["hand"] = ["u4_guard"]
	(s["umbra"] as Dictionary)["stage"] = CombatEngine.UMBRA_STAGE_DEEP
	scene.set("_combat_state", s)
	var prepared: Dictionary = engine.prepare_player_card(s, 0, "empower")
	var automatic: Array = engine.card_play_actions("u4_guard", prepared)
	var resolved: Dictionary = prepared
	for action: Dictionary in automatic:
		resolved = engine.apply_player_action(resolved, action)
	scene.set("_preview_combat_state", resolved)
	scene.set("_pending_actions", automatic)
	scene.set("_pending_action_index", automatic.size())
	expect.call(bool(scene.call("_unconfirmed_preview_must_preserve_umbra_information")), "Crown fixture exercises limited-Umbra confirmation")
	var known: Dictionary = scene.call("_pending_card_known_forecast_state")
	expect.call(int(known["player_turn_time_spent"]) == 6 and int((known["player"] as Dictionary)["block"]) == 4, "Crown targetless forecast preserves Empower payment under limited Umbra")
	scene.free()

static func _test_finished_card_pricing(engine: CombatEngine, expect: Callable) -> void:
	for free: String in ["u4_rite", "u4_item"]:
		var source: Dictionary = state(engine, ["whirling_sash", "fencers_gloves", "liturgy_of_ash", "quick_draw_bandolier"])
		var once: Dictionary = resume(play(engine, source, free))
		expect.call(once["cards_played_this_turn"] == 0 and TempoRules.cards_finished(once) == 1, "Free card counts once while preserving play budget: " + free)
		expect.call(engine.card_def("u4_guard", once).get("_relic_time_discount_relic", "") == "fencers_gloves", "Gloves stamps its source id after a free card: " + free)
		expect.call(engine.card_time_cost("u4_guard", once) == 2, "Gloves discount the card after a free card; Sash waits: " + free)
		var twice: Dictionary = play(engine, once, "u4_guard")
		expect.call(engine.card_def("u4_guard", twice).get("_tempo_time_surcharge_relic", "") == "whirling_sash", "Sash stamps its source id on surcharged cards: " + free)
		expect.call(engine.card_time_cost("u4_guard", twice) == 5, "Sash starts after two finished cards including a free card; Gloves finish: " + free)
	var flurry: Dictionary = state(engine, ["whirling_sash", "fencers_gloves"])
	flurry = resume(play(engine, flurry, "u4_flurry"))
	expect.call(flurry["cards_played_this_turn"] == 3 and TempoRules.cards_finished(flurry) == 1 and engine.card_time_cost("u4_guard", flurry) == 2, "A Flurry spends three slots but counts once for Sash and Gloves")
	var feint: Dictionary = state(engine, ["feint_ribbon", "liturgy_of_ash"])
	TempoRules.add_tiles_moved(feint, 2)
	feint = play(engine, feint, "u4_rite")
	expect.call(not Rules.follow_up_from_movement(feint, GameData.relic_effects_for_state(feint)), "A free Rite consumes Feint Ribbon's first-card condition")
