extends RefCounted
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/defense_relic_rules.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Rites = preload("res://scripts/rite_rules.gd")
const KeywordSuite = preload("res://tests/suites/card_keywords_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const TARGET := Vector2i(3, 4)
const NONE := Vector2i(-1, -1)
const FIXTURES := {
	"u5_guard": {"time": 3, "actions": [{"type": "block", "amount": 6}]},
	"u5_strike": {"time": 4, "actions": [{"type": "melee", "damage": 3, "range": 1}]},
	"u5_double": {"time": 4, "actions": [{"type": "melee", "damage": 3, "range": 1}, {"type": "melee", "damage": 3, "range": 1}]},
	"u5_retaliate": {"time": 3, "actions": [{"type": "retaliate", "amount": 5}]},
	"u5_blood": {"time": 3, "health_cost": 3, "actions": [{"type": "block", "amount": 1}]},
	"u5_flurry": {"time": 3, "health_cost": 2, "flurry": true, "actions": [{"type": "block", "amount": 1}]},
	"u5_empower": {"time": 4, "health_cost": 1, "actions": [{"type": "block", "amount": 2}], "empower": {"cost": {"health": 2}, "mods": [{"action": 0, "add": {"amount": 2}}]}},
	"u5_empower_exhaust": {"time": 4, "actions": [{"type": "block", "amount": 2}], "empower": {"cost": {"exhaust": true}, "mods": [{"action": 0, "add": {"amount": 2}}]}},
	"u5_rite": {"time": 4, "burn": true, "actions": [], "rite": {"effects": [{"type": "independent_movement_bonus", "amount": 1}]}},
	"u5_rite_fast": {"time": 1, "burn": true, "health_cost": 1, "actions": [], "rite": {"effects": [{"type": "thorns", "damage": 2}]}},
	"u5_exhaust": {"time": 7, "burn": true, "actions": [{"type": "block", "amount": 1}]},
	"u5_exhaust_time": {"time": 3, "burn": true, "actions": [{"type": "block", "amount": 1}], "empower": {"cost": {"time": 1}, "mods": [{"action": 0, "add": {"amount": 1}}]}},
	"u5_heal": {"time": 3, "burn": true, "actions": [{"type": "heal", "amount": 1}]},
	"u5_conditional_heal": {"time": 3, "burn": true, "actions": [{"type": "melee", "damage": 1, "range": 1, "rewards": [{"type": "heal", "amount": 1}]}]},
	"u5_follow_heal": {"time": 3, "burn": true, "actions": [{"type": "block", "amount": 1}], "follow_up": {"append": [{"type": "heal", "amount": 1}]}},
	"u5_item": {"time": 4, "item": true, "consume_on_play": true, "actions": [{"type": "block", "amount": 1}]},
	"u5_ice": {"time": 4, "actions": [{"type": "melee", "damage": 1, "range": 1, "element": "ice"}]},
	"u5_force": {"time": 4, "actions": [{"type": "push", "damage": 0, "amount": 1, "range": 1}]},
	"u5_move_guard": {"time": 4, "actions": [{"type": "move", "range": 1, "block_per_tile": 3}]},
	"u5_reward_guard": {"time": 4, "actions": [{"type": "melee", "damage": 1, "range": 1, "rewards": [{"type": "block", "amount": 3}]}]}
}

static func install_fixtures() -> void:
	for id: String in FIXTURES:
		var card: Dictionary = (FIXTURES[id] as Dictionary).duplicate(true)
		card["name"] = id.trim_prefix("u5_").capitalize()
		card["description"] = ""
		card["rarity"] = "common"
		card["reward_pool"] = false
		card["art_path"] = Data.card_def("quick_stab").get("art_path", "")
		Data.cards()[id] = card

static func state(engine: CombatEngine, relics: Array = []) -> Dictionary:
	var s: Dictionary = KeywordSuite._state(engine, ["u5_guard", "u5_strike", "u5_rite", "u5_blood", "u5_retaliate"])
	s["relics"] = relics.duplicate()
	s["cards_per_turn"] = 2
	s["turn_flags"] = {}
	s["relic_flags"] = {}
	(s["deck"] as Dictionary)["draw"] = ["u5_guard", "u5_guard", "u5_guard"]
	return s

static func play(engine: CombatEngine, source: Dictionary, id: String, target: Vector2i = NONE, empower: bool = false) -> Dictionary:
	var working: Dictionary = source.duplicate(true)
	(working["deck"] as Dictionary)["hand"] = [id]
	working = engine.prepare_player_card(working, 0, "empower" if empower else "play")
	var actions: Array = engine.card_play_actions(id, working)
	for action: Dictionary in actions:
		working = engine.apply_player_action(working, action, target if engine.player_action_needs_target(action) else NONE)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions))

static func resume(source: Dictionary) -> Dictionary:
	var old_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u5_resume.save")
	Store.save_run_state({"mode": "combat", "combat_state": source})
	var loaded: Dictionary = Store.load_saved_run().get("combat_state", {}) as Dictionary
	Store.clear_saved_run()
	Store.set_run_storage_path(old_path)
	return loaded

static func run(expect: Callable) -> void:
	install_fixtures()
	var engine := CombatEngine.new()
	_test_gorget(engine, expect)
	_test_throne(engine, expect)
	_test_mirror(engine, expect)
	_test_lung(engine, expect)
	_test_chalice(engine, expect)
	_test_reliquary(engine, expect)
	_test_phylactery(engine, expect)
	_test_rosary(engine, expect)
	_test_liturgy(engine, expect)
	_test_urn(engine, expect)
	_test_ui(engine, expect)
	for id: String in FIXTURES:
		Data.cards().erase(id)

static func retaliate_hit(engine: CombatEngine, source: Dictionary, action: Dictionary = {"type": "melee", "damage": 1, "range": 1}) -> Dictionary:
	return Retaliate.after_enemy_hit(engine, source.duplicate(true), 1, action)

static func _test_gorget(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["martyrs_gorget"])
	Retaliate.gain(s, {"amount": 7})
	(s["enemies"][0] as Dictionary)["block"] = 2
	(s["enemies"][0] as Dictionary)["stoneskin"] = 1
	var preview: Dictionary = retaliate_hit(engine, s)
	expect.call(int(preview["player"]["block"]) == 4, "Gorget grants actual Retaliate health loss after Block and Stoneskin")
	expect.call(s["player"]["block"] == 0, "Gorget forecast does not mutate the committed state")
	expect.call(preview == retaliate_hit(engine, resume(s)), "Gorget preview equals resolution after save/resume")
	(s["enemies"][0] as Dictionary)["block"] = 20
	expect.call(retaliate_hit(engine, s)["player"]["block"] == 0, "Gorget idle when defenses absorb Retaliate")
	s.erase("retaliate")
	expect.call(retaliate_hit(engine, s)["player"]["block"] == 0, "Gorget idle without Retaliate")
	Retaliate.gain(s, {"amount": 7})
	(s["enemies"][0] as Dictionary)["pos"] = Vector2i(6, 4)
	expect.call(retaliate_hit(engine, s, {"type": "ranged", "damage": 1})["player"]["block"] == 0, "Gorget idle on a distant ranged attack")
	var struck: Dictionary = state(engine, ["martyrs_gorget", "briar_throne"])
	(struck["player"] as Dictionary)["block"] = 10
	Retaliate.gain(struck, {"amount": 3})
	struck = engine._resolve_board_attack(struck, {"type": "melee", "damage": 1, "range": 1}, struck["player"]["pos"], "enemy", 1)
	expect.call(struck["player"]["block"] == 12 and struck["retaliate"]["amount"] == 4, "Gorget and Throne run once through the real enemy strike even when Block absorbs it")

static func _test_throne(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["briar_throne", "martyrs_gorget"])
	s = play(engine, s, "u5_retaliate")
	s = retaliate_hit(engine, s)
	s = retaliate_hit(engine, s)
	expect.call(s["retaliate"]["amount"] == 7 and s["player"]["block"] == 11, "Throne grows once per trigger and preserves Gorget Block")
	var next: Dictionary = engine.prepare_next_player_turn(resume(s))
	expect.call(next["retaliate"]["amount"] == 7, "Throne persists through turn reset and save/resume")
	expect.call(Retaliate.player_badges(next, engine._relic_effects(next))[0]["count"] == 7, "Throne Retaliate badge shows the growing amount")
	var committed: Dictionary = play(engine, next, "u5_guard")
	expect.call(committed["player"]["block"] == 0 and engine.card_def("u5_guard", next)["actions"][0]["amount"] == 0, "Throne suppresses card Block in definition and resolution")
	committed = play(engine, next, "u5_empower", NONE, true)
	expect.call(committed["player"]["block"] == 0, "Throne suppresses Empower Block")
	committed = play(engine, next, "u5_move_guard", Vector2i(2, 3))
	expect.call(committed["player"]["block"] == 0, "Throne suppresses movement Block riders")
	committed = play(engine, next, "u5_reward_guard", TARGET)
	expect.call(committed["player"]["block"] == 0, "Throne suppresses conditional card Block rewards")
	var idle: Dictionary = state(engine, ["briar_throne"])
	expect.call(not retaliate_hit(engine, idle).has("retaliate"), "Throne creates no Retaliate without a trigger")
	var ordinary: Dictionary = state(engine)
	Retaliate.gain(ordinary, {"amount": 5})
	expect.call(not engine.prepare_next_player_turn(ordinary).has("retaliate"), "Ordinary Retaliate still expires")
	expect.call(play(engine, ordinary, "u5_guard")["player"]["block"] == 6, "Block cards still work without Throne")
	Rites.start(idle, "u5_rite_fast", engine.card_def("u5_rite_fast", idle))
	idle = retaliate_hit(engine, idle)
	expect.call(Retaliate.totals(idle, engine._relic_effects(idle))["amount"] == 3, "Throne grows permanent Rite thorns too")

static func _test_mirror(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["cold_mirror"])
	(s["player"] as Dictionary)["block"] = 11
	(s["enemies"][0] as Dictionary)["chilled"] = true
	var action: Dictionary = engine.card_play_actions("u5_ice", s)[0]
	var preview: Dictionary = engine.apply_player_action(s, action, TARGET)
	var committed: Dictionary = play(engine, s, "u5_ice", TARGET)
	expect.call(preview["player"]["block"] == 0 and preview["player"]["frost_armor"] == 2, "Mirror spends all eleven Block for capped two Mantle layers")
	expect.call(preview["player"] == committed["player"], "Mirror forecast equals commit")
	(preview["player"] as Dictionary)["block"] = 4
	(preview["enemies"][0] as Dictionary)["freeze"] = 0
	(preview["enemies"][0] as Dictionary)["chilled"] = true
	preview = engine.apply_player_action(resume(preview), action, TARGET)
	expect.call(preview["player"]["frost_armor"] == 3, "Mirror can trigger again in the same turn after save/resume")
	for block: int in [0, 3, 4, 7, 8, 20]:
		var check: Dictionary = state(engine, ["cold_mirror"])
		(check["player"] as Dictionary)["block"] = block
		(check["enemies"][0] as Dictionary)["chilled"] = true
		check = engine.apply_player_action(check, action, TARGET)
		expect.call(int(check["player"].get("frost_armor", 0)) == mini(block / 4, 2), "Mirror layer threshold for %d Block" % block)
		expect.call(check["player"]["block"] == (block if block < 4 else 0), "Mirror all-or-nothing Block spend for %d" % block)
	(s["enemies"][0] as Dictionary)["chilled"] = false
	expect.call(engine.apply_player_action(s, action, TARGET)["player"]["block"] == 11, "Mirror idle when no Freeze applies")
	(s["enemies"][0] as Dictionary)["chilled"] = true
	(s["enemies"][0] as Dictionary)["type"] = "iskaldra"
	expect.call(engine.apply_player_action(s, action, TARGET)["player"]["block"] == 11, "Mirror idle against Freeze immunity")

static func _test_lung(engine: CombatEngine, expect: Callable) -> void:
	for skin: int in [0, 1, 2, 5, 6, 10]:
		var s: Dictionary = state(engine, ["iron_lung"])
		(s["player"] as Dictionary)["stoneskin"] = skin
		var paid: Dictionary = play(engine, s, "u5_blood")
		var pairs: int = mini(3, skin / 2)
		expect.call(paid["player"]["hp"] == 30 - (3 - pairs) and paid["player"]["stoneskin"] == skin - pairs * 2, "Lung pays each health point using complete Stoneskin pairs: %d" % skin)
	var s: Dictionary = state(engine, ["iron_lung"])
	(s["player"] as Dictionary)["stoneskin"] = 5
	expect.call(play(engine, resume(s), "u5_empower", NONE, true)["player"]["hp"] == 29, "Lung pays card and Empower health costs from the same Stoneskin pool")
	s["cards_played_this_turn"] = 0
	(s["player"] as Dictionary)["stoneskin"] = 7
	var flurry: Dictionary = play(engine, s, "u5_flurry")
	expect.call(flurry["player"]["hp"] == 29 and flurry["player"]["stoneskin"] == 1, "Lung includes Flurry's repeated health costs")
	expect.call(play(engine, s, "u5_guard")["player"]["stoneskin"] == 7, "Lung idle on cards with no health cost")
	var damage: Dictionary = engine._lose_player_health(s.duplicate(true), 2, true, false, "collision")
	expect.call(damage["player"]["hp"] == 28 and damage["player"]["stoneskin"] == 7, "Lung does not convert non-cost health losses")
	var plain: Dictionary = state(engine)
	(plain["player"] as Dictionary)["stoneskin"] = 6
	expect.call(play(engine, plain, "u5_blood")["player"]["hp"] == 27, "Health costs still use health without Lung")

static func _test_chalice(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["bloodmoon_chalice"])
	s = engine._lose_player_health(s, 1, true, false, "card_health_cost")
	expect.call(Tempo.bonus_for_action(s, engine.card_play_actions("u5_strike", s)[0])["damage"] == 2, "Chalice is immediately eligible after own-turn health loss")
	var preview: Dictionary = engine.apply_player_action(s, engine.card_play_actions("u5_strike", s)[0], TARGET)
	var committed: Dictionary = play(engine, resume(s), "u5_strike", TARGET)
	expect.call(preview["enemies"] == committed["enemies"] and committed["enemies"][0]["hp"] == 35, "Chalice forecast equals saved commit")
	expect.call(Tempo.next_attack_buffs(committed).is_empty(), "Chalice spends its bonus on the attack")
	s = engine._lose_player_health(s, 2, true, false, "bleed")
	s = engine._lose_player_health(s, 4, true, false, "surface_fire")
	expect.call(Tempo.bonus_for_action(s, engine.card_play_actions("u5_strike", s)[0])["damage"] == 8, "Chalice accumulates health loss with an eight damage cap")
	committed = play(engine, s, "u5_double", TARGET)
	expect.call(committed["enemies"][0]["hp"] == 26, "Chalice only boosts the first attack of a multi-attack card")
	var ended: Dictionary = engine.finish_player_activation(resume(s))
	expect.call(Tempo.next_attack_buffs(ended).is_empty(), "Chalice unused bonus expires at turn end after save/resume")
	var enemy_turn: Dictionary = state(engine, ["bloodmoon_chalice"])
	enemy_turn["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	enemy_turn = engine._lose_player_health(enemy_turn, 2, true, false, "enemy_attack")
	expect.call(Tempo.next_attack_buffs(enemy_turn).is_empty(), "Chalice idle on enemy turns")
	var blocked: Dictionary = state(engine, ["bloodmoon_chalice"])
	(blocked["player"] as Dictionary)["block"] = 4
	blocked = engine._damage_player(blocked, 3, false)
	expect.call(Tempo.next_attack_buffs(blocked).is_empty(), "Chalice idle when no health is lost")
	var lung: Dictionary = state(engine, ["bloodmoon_chalice", "iron_lung"])
	(lung["player"] as Dictionary)["stoneskin"] = 6
	lung = play(engine, lung, "u5_blood")
	expect.call(Tempo.next_attack_buffs(lung).is_empty(), "Lung Stoneskin payments do not trigger Chalice")
	var costs: Dictionary = play(engine, state(engine, ["bloodmoon_chalice"]), "u5_empower", NONE, true)
	expect.call(costs["player"]["hp"] == 27 and Tempo.next_attack_buffs(costs)[0]["damage"] == 6, "Chalice counts both card and Empower health actually paid")
	var force: Dictionary = play(engine, s, "u5_force", TARGET)
	expect.call(not Tempo.next_attack_buffs(force).is_empty(), "Chalice waits through a non-damaging shove")
	var bleeding: Dictionary = state(engine, ["bloodmoon_chalice"])
	(bleeding["player"] as Dictionary)["bleed"] = 2
	var bleed_preview: Dictionary = engine.apply_player_action(bleeding, engine.card_play_actions("u5_strike", bleeding)[0], TARGET)
	var bleed_commit: Dictionary = play(engine, resume(bleeding), "u5_strike", TARGET)
	expect.call(bleed_commit["enemies"][0]["hp"] == 33 and bleed_commit["player"]["hp"] == 28, "Chalice boosts the hit whose pre-hit Bleed lost health, paying Bleed once")
	expect.call(bleed_preview["enemies"] == bleed_commit["enemies"], "Chalice pre-hit Bleed forecast equals commit")
	bleeding = engine._lose_player_health(bleeding, 3, true, false, "collision")
	bleed_commit = play(engine, bleeding, "u5_strike", TARGET)
	expect.call(bleed_commit["enemies"][0]["hp"] == 29, "Chalice caps combined earlier health loss and pre-hit Bleed at eight for one attack")

static func _test_reliquary(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["reliquary_box"])
	(s["deck"] as Dictionary)["hand"] = ["u5_strike", "u5_guard"]
	(s["deck"] as Dictionary)["draw"] = ["u5_rite_fast", "u5_guard", "u5_rite", "u5_strike"]
	var swapped: Dictionary = Rules.opening_hand(engine, s.duplicate(true))
	expect.call(swapped["deck"]["hand"] == ["u5_strike", "u5_rite"] and swapped["deck"]["draw"] == ["u5_rite_fast", "u5_guard", "u5_guard", "u5_strike"], "Reliquary swaps the last drawn card for the first Rite in draw order")
	expect.call(Rules.opening_hand(engine, swapped.duplicate(true)) == swapped, "Reliquary idle if a Rite is already in hand")
	expect.call(engine.card_time_cost("u5_rite", s) == 3 and engine.card_time_cost("u5_rite_fast", s) == 1 and engine.card_time_cost("u5_guard", s) == 3, "Reliquary discounts only Rites with minimum Time one")
	(s["deck"] as Dictionary)["draw"] = ["u5_guard"]
	expect.call(Rules.opening_hand(engine, s.duplicate(true)) == s, "Reliquary idle without a Rite in the deck")
	var layout: Dictionary = {"name": "Opening", "type": "combat", "grid": s["grid"], "player_start": Vector2i(2, 4), "enemies": s["enemies"]}
	var opening: Dictionary = engine.create_combat(999, layout, {"hp": 30, "max_hp": 30, "hand_size": 1, "deck_cards": ["u5_guard", "u5_strike", "u5_rite"], "relics": ["reliquary_box"]})
	expect.call(Rites.is_rite_card(engine.card_def(str(opening["deck"]["hand"][0]), opening)), "Reliquary runs on the actual opening draw")

static func _test_phylactery(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["ashen_phylactery", "reliquary_box"])
	expect.call(play(engine, s, "u5_exhaust")["player"]["stoneskin"] == 5, "Phylactery caps seven paid Time at five Stoneskin")
	expect.call(play(engine, s, "u5_rite")["player"]["stoneskin"] == 3, "Phylactery counts discounted Rite Time")
	s["turn_flags"] = {"quicken_pending": 2}
	expect.call(play(engine, s, "u5_exhaust_time", NONE, true)["player"]["stoneskin"] == 2, "Phylactery uses discounted Time plus Empower surcharge")
	expect.call(play(engine, state(engine, ["ashen_phylactery"]), "u5_empower_exhaust", NONE, true)["player"]["stoneskin"] == 4, "Phylactery triggers on Empower Exhaust")
	expect.call(play(engine, s, "u5_item")["player"]["stoneskin"] == 0, "Phylactery ignores Consume")
	expect.call(play(engine, s, "u5_guard")["player"]["stoneskin"] == 0, "Phylactery ignores ordinary discard")
	var banked: Dictionary = state(engine, ["ashen_phylactery"])
	banked["skill_ids"] = ["borrowed_time"]
	banked["banked_play_active"] = 1
	banked["cards_played_this_turn"] = 2
	banked = play(engine, banked, "u5_exhaust")
	expect.call(banked["player"]["stoneskin"] == 0 and banked["player_turn_time_spent"] == 0, "Phylactery gives no Stoneskin when Borrowed Time removes all paid Time")
	var preserved: Dictionary = state(engine, ["ashen_phylactery", "pyre_keepers_urn"])
	preserved["skill_ids"] = ["rehearsed_escape"]
	preserved["skill_flags"] = {"burn_preserve_armed": true}
	preserved = play(engine, preserved, "u5_exhaust")
	expect.call(preserved["player"]["stoneskin"] == 0 and not preserved.has(Rules.LAST_EXHAUST_KEY), "Preserved Exhaust grants no Phylactery reward or Urn history")
	s = play(engine, s, "u5_exhaust_time")
	s = play(engine, resume(s), "u5_exhaust_time")
	expect.call(s["player"]["stoneskin"] == 4, "Phylactery repeats without turn or combat limits across save/resume")

static func _test_rosary(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["rosary_of_vows", "briar_throne"])
	(s["player"] as Dictionary)["block"] = 15
	Rites.start(s, "u5_rite", engine.card_def("u5_rite", s))
	Rites.start(s, "u5_rite_fast", engine.card_def("u5_rite_fast", s))
	var next: Dictionary = engine.prepare_next_player_turn(resume(s))
	expect.call(next["player"]["block"] == 4, "Rosary grants two Block per active Rite after reset, even with Throne")
	var idle: Dictionary = engine.prepare_next_player_turn(state(engine, ["rosary_of_vows"]))
	expect.call(idle["player"]["block"] == 0, "Rosary idle without active Rites")
	expect.call(engine.prepare_next_player_turn(next)["player"]["block"] == 4, "Rosary grants every turn without accumulating old Block")

static func _test_liturgy(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["liturgy_of_ash"])
	s["cards_played_this_turn"] = 2
	s["player_movement_remaining"] = 0
	(s["deck"] as Dictionary)["hand"] = ["u5_rite", "u5_guard"]
	expect.call(engine.hand_card_has_play_budget(s, 0) and not engine.hand_card_has_play_budget(s, 1), "Liturgy permits only Rites at zero plays")
	expect.call(not engine.player_turn_resources_exhausted(s), "Liturgy prevents out-of-plays auto-pass while a Rite remains")
	var paid: Dictionary = play(engine, resume(s), "u5_rite")
	expect.call(paid["cards_played_this_turn"] == 2 and paid["player_turn_time_spent"] == 4 and Rites.active_rites(paid).size() == 1, "Liturgy pays Rite Time but no play after save/resume")
	expect.call(engine.player_turn_resources_exhausted(paid), "Out-of-plays resumes when the last free Rite is gone")
	s["banked_play_active"] = 1
	s["cards_played_this_turn"] = 3
	paid = play(engine, s, "u5_rite_fast")
	expect.call(paid["cards_played_this_turn"] == 3 and paid["banked_play_spent_this_activation"] == 0 and paid["player"]["hp"] == 29, "Liturgy neither consumes banked plays nor removes Rite health costs")
	expect.call(play(engine, state(engine, ["liturgy_of_ash"]), "u5_guard")["cards_played_this_turn"] == 1, "Liturgy leaves non-Rite play costs alone")

static func _test_urn(engine: CombatEngine, expect: Callable) -> void:
	var s: Dictionary = state(engine, ["pyre_keepers_urn", "ashen_phylactery"])
	s = play(engine, s, "u5_exhaust")
	var before: Dictionary = resume(s)
	var next: Dictionary = engine.prepare_next_player_turn(before)
	expect.call(next["deck"]["hand"][0] == "u5_exhaust" and (next["deck"]["burned"] as Array).is_empty(), "Urn returns most recent Exhaust before normal turn draw after save/resume")
	expect.call(RunScene.card_draw_sfx_count_between_states(before, next) == 3, "Urn return participates in normal draw animation and sound revision")
	var scene := RunScene.new()
	var transition: Dictionary = scene.call("_draw_hand_transition_between_states", before, next)
	expect.call((transition["draw_entries"] as Array).size() == 3 and transition["draw_entries"][0]["card_id"] == "u5_exhaust", "Urn is included in the ordinary draw animation entries")
	scene.free()
	var repeated: Dictionary = Rules.player_turn_start(engine, resume(next))
	expect.call(repeated["deck"] == next["deck"], "Urn cannot return twice in one turn across save/resume")
	next = play(engine, next, "u5_exhaust")
	expect.call(next["deck"]["burned"] == ["u5_exhaust"] and next["player"]["stoneskin"] == 10, "Urn keeps Exhaust rules and repeats Phylactery rewards")
	(next["deck"] as Dictionary)["hand"] = ["u5_guard", "u5_guard", "u5_guard", "u5_guard", "u5_guard", "u5_guard", "u5_guard"]
	next = engine.prepare_next_player_turn(resume(next))
	expect.call(next["deck"]["hand"].size() == 7 and (next["deck"]["draw"] as Array).back() == "u5_exhaust", "Urn places return on top of draw pile when hand is full")
	for excluded: String in ["u5_rite", "u5_heal", "u5_conditional_heal", "u5_follow_heal"]:
		var check: Dictionary = play(engine, state(engine, ["pyre_keepers_urn"]), "u5_exhaust")
		check = play(engine, check, excluded, TARGET)
		check = engine.prepare_next_player_turn(resume(check))
		expect.call(not (check["deck"]["hand"] as Array).has(excluded) and (check["deck"]["burned"] as Array).has("u5_exhaust"), "Urn does not skip excluded most recent Exhaust: " + excluded)
	var idle: Dictionary = engine.prepare_next_player_turn(state(engine, ["pyre_keepers_urn"]))
	expect.call(not idle.has(Rules.LAST_EXHAUST_KEY), "Urn idle without Exhaust history")
	var consumed: Dictionary = play(engine, state(engine, ["pyre_keepers_urn"]), "u5_item")
	expect.call(not consumed.has(Rules.LAST_EXHAUST_KEY), "Consume never becomes Urn Exhaust history")

static func _test_ui(engine: CombatEngine, expect: Callable) -> void:
	var scene := RunScene.new()
	var s: Dictionary = state(engine, ["iron_lung"])
	(s["player"] as Dictionary)["stoneskin"] = 5
	(s["deck"] as Dictionary)["hand"] = ["u5_blood"]
	scene.set("_combat_state", s)
	var preview: Dictionary = scene.call("_card_preview_for_index", 0)
	var forecast: Dictionary = preview.get("resolved_state", preview.get("state", {})) as Dictionary
	# Targetless forecast is the same finished-card payment path used on commit.
	expect.call(not forecast.is_empty(), "Lung hover produces a forecast")
	scene.set("_selected_card_index", 0)
	var paid: Dictionary = scene.call("_pass_preview_state_after_resolved_target", preview.get("state", s), preview.get("actions", []), (preview.get("actions", []) as Array).size())
	expect.call(paid["player"] == play(engine, s, "u5_blood")["player"], "Lung RunScene payment forecast equals commit")
	expect.call(paid["player"]["hp"] == 29 and paid["player"]["stoneskin"] == 1, "Lung forecast shows actual health and Stoneskin spent")
	s = state(engine, ["ashen_phylactery", "liturgy_of_ash", "reliquary_box"])
	(s["deck"] as Dictionary)["hand"] = ["u5_rite"]
	scene.set("_combat_state", s)
	scene.call("_mark_combat_preview_state_changed")
	preview = scene.call("_card_preview_for_index", 0)
	paid = scene.call("_pass_preview_state_after_resolved_target", preview["state"], preview["actions"], (preview["actions"] as Array).size())
	expect.call(paid["player"] == play(engine, s, "u5_rite")["player"] and paid["player"]["stoneskin"] == 3 and paid["cards_played_this_turn"] == 0, "Phylactery Rite hover equals discounted, zero-play commit")
	s = state(engine, ["briar_throne"])
	scene.set("_combat_state", s)
	var display: Dictionary = scene.call("_card_widget_display", "u5_guard", s)
	var block_value: String = "missing"
	for row: Array in display.get("summary_rows", []):
		for token: Dictionary in row:
			if str(token.get("icon", "")) == "block":
				block_value = str(token.get("value", ""))
	expect.call(block_value == "0", "Throne card face shows zero Block")
	s = state(engine, ["liturgy_of_ash"])
	s["cards_played_this_turn"] = 2
	(s["deck"] as Dictionary)["hand"] = ["u5_rite", "u5_guard"]
	scene.set("_combat_state", s)
	scene.call("_mark_combat_preview_state_changed")
	expect.call(bool((scene.call("_card_playability_for_index", 0) as Dictionary).get("printed_playable", false)), "Liturgy hand summary keeps free Rite playable at zero plays")
	expect.call(not bool((scene.call("_card_playability_for_index", 1) as Dictionary).get("printed_playable", true)), "Liturgy hand summary disables ordinary cards at zero plays")
	scene.call("_begin_card_play_meter_spend_preview", 0)
	expect.call(scene.call("_displayed_card_play_count") == 0, "Liturgy meter preview spends zero plays")
	scene.free()
