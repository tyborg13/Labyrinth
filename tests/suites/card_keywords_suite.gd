extends RefCounted

# Stagger, Follow-up, Empower, state bonuses and scale bonuses (spec/card_keywords.md).
# Mechanics are exercised with fixture card definitions injected into the shared
# card cache and removed afterwards, so the suite is independent of cards.json.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CardKeywordRules = preload("res://scripts/card_keyword_rules.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const PLAYER_TILE := Vector2i(2, 4)
const NEAR_TILE := Vector2i(3, 4)
const FAR_TILE := Vector2i(6, 4)
const NO_TILE := Vector2i(-1, -1)

static func fixture_cards() -> Dictionary:
	var melee: Callable = func(damage: int, extra: Dictionary = {}) -> Dictionary:
		var action: Dictionary = {"type": "melee", "damage": damage, "range": 1, "element": "none"}
		action.merge(extra, true)
		return action
	return {
		"kwtest_filler": _card("KW Filler", 1, [{"type": "block", "amount": 1}]),
		"kwtest_stagger_strike": _card("KW Stagger Strike", 3, [melee.call(3, {"stagger": 3})]),
		"kwtest_follow_strike": _card("KW Follow Strike", 2, [melee.call(6)], {"follow_up": {"mods": [{"action": 0, "add": {"damage": 3}}], "append": [{"type": "draw", "amount": 1}]}}),
		"kwtest_follow_flurry": _card("KW Follow Flurry", 3, [melee.call(2)], {"flurry": true, "follow_up": {"mods": [{"action": 0, "add": {"damage": 2}}]}}),
		"kwtest_empower_time": _card("KW Empower Time", 4, [melee.call(5)], {"empower": {"cost": {"time": 2}, "mods": [{"action": 0, "set": {"stagger": 4}}]}}),
		"kwtest_empower_health": _card("KW Empower Health", 4, [melee.call(4)], {"empower": {"cost": {"health": 2}, "mods": [{"action": 0, "add": {"damage": 4}}]}}),
		"kwtest_empower_exhaust": _card("KW Empower Exhaust", 3, [{"type": "ranged", "damage": 3, "range": 4, "element": "none"}], {"empower": {"cost": {"exhaust": true}, "mods": [{"action": 0, "add": {"damage": 2}}]}}),
		"kwtest_empower_block": _card("KW Empower Block", 2, [{"type": "block", "amount": 4}], {"empower": {"cost": {"time": 1}, "mods": [{"action": 0, "set": {"amount": 7}}]}}),
		"kwtest_light_strike": _card("KW Light Strike", 3, [melee.call(4, {"state_bonus": [{"state": "light", "damage": 3, "stagger": 2}]})]),
		"kwtest_frozen_strike": _card("KW Frozen Strike", 3, [melee.call(4, {"state_bonus": [{"state": "frozen", "damage": 4}]})]),
		"kwtest_execute_strike": _card("KW Execute Strike", 5, [melee.call(10, {"state_bonus": [{"state": "half_hp", "damage": 5}]})]),
		"kwtest_stonefist": _card("KW Stonefist", 4, [melee.call(5, {"scale_bonus": {"per": "stoneskin", "damage": 1, "max": 6}})]),
		"kwtest_lance": _card("KW Lance", 4, [melee.call(4, {"range": 3, "scale_bonus": {"per": "tiles_moved", "damage": 1, "max": 5}})]),
		"kwtest_wheel": _card("KW Wheel", 5, [{"type": "move", "range": 3}, melee.call(4, {"required": true, "scale_bonus": {"per": "tiles_moved", "damage": 1, "max": 5}})]),
		"kwtest_blink": _card("KW Blink", 1, [{"type": "blink", "range": 4}]),
	}

static func _card(card_name: String, time: int, actions: Array, extra: Dictionary = {}) -> Dictionary:
	var card: Dictionary = {
		"name": card_name, "rarity": "common", "burn": false, "health_cost": 0, "time": time,
		"description": card_name, "accent": "#8f9499", "reward_pool": false, "actions": actions,
	}
	card.merge(extra, true)
	return card

static func install_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	var fixtures: Dictionary = fixture_cards()
	for card_id: String in fixtures:
		cards[card_id] = fixtures[card_id]

static func remove_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in fixture_cards():
		cards.erase(card_id)

static func run(expect: Callable) -> void:
	install_fixtures()
	_test_rules_helpers(expect)
	_test_stagger_delays_queued_turn(expect)
	_test_stagger_on_current_actor_applies_when_scheduled(expect)
	_test_stagger_boss_half_and_turn_cap(expect)
	_test_follow_up(expect)
	_test_follow_up_with_flurry(expect)
	_test_empower_costs(expect)
	_test_state_bonuses(expect)
	_test_scale_bonuses(expect)
	_test_icon_rows_and_grimoire(expect)
	_test_hand_display_rows(expect)
	remove_fixtures()

static func run_live(tree: SceneTree, expect: Callable) -> void:
	install_fixtures()
	await _test_live_time_badge_surcharge(tree, expect)
	await _test_live_targetless_empower_confirmation(tree, expect)
	await _test_live_targeted_empower_and_stagger_preview(tree, expect)
	remove_fixtures()
	# Live plays checkpoint the run; never leave fixture card ids in a saved run.
	ProgressionStore.clear_saved_run()

# ---------------------------------------------------------------- fixtures

static func _state(combat: CombatEngine, hand: Array, enemies: Array = []) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 8 else "stone")
		grid.append(row)
	var roster: Array = enemies if not enemies.is_empty() else [
		{"id": 1, "type": "crawler", "pos": NEAR_TILE, "hp": 40, "max_hp": 40},
		{"id": 2, "type": "crawler", "pos": FAR_TILE, "hp": 40, "max_hp": 40},
	]
	var layout: Dictionary = {
		"name": "Card keyword proof", "type": "combat", "coord": Vector2i(2, 2), "element": "none",
		"umbra_stage": "clear", "grid": grid, "player_start": PLAYER_TILE,
		"terrain": [], "traps": [], "loot": [], "enemies": roster,
	}
	var state: Dictionary = combat.create_combat(51207, layout, {"hp": 30, "max_hp": 30, "deck_cards": hand.duplicate(), "hand_size": 0, "relics": []})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = ["kwtest_filler", "kwtest_filler", "kwtest_filler"]
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	for enemy: Dictionary in state.get("enemies", []):
		enemy["block"] = 0
	state["cards_per_turn"] = 3
	return state

static func _play(combat: CombatEngine, state: Dictionary, hand_index: int, targets: Array, mode: String = "play") -> Dictionary:
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", []) as Array
	var card_id: String = str(hand[hand_index])
	var prepared: Dictionary = combat.prepare_player_card(state, hand_index, mode)
	var actions: Array = combat.card_play_actions(card_id, prepared)
	var working: Dictionary = prepared
	var cursor: int = 0
	var previews: Array = []
	for action_var: Variant in actions:
		var action: Dictionary = action_var
		var target: Vector2i = NO_TILE
		if combat.player_action_needs_target(action):
			target = targets[cursor] if cursor < targets.size() else NO_TILE
			cursor += 1
		if str(action.get("type", "")) in ["melee", "ranged", "aoe"]:
			previews.append((combat.surface_preview_for_player_action(working, action, target, true).get("state", {}) as Dictionary))
		working = combat.apply_player_action(working, action, target)
	var finished: Dictionary = combat.finish_player_card(working, hand_index, combat.card_plays_spent_for_actions(actions), {"play_mode": "play"})
	return {"prepared": prepared, "actions": actions, "resolved": working, "finished": finished, "previews": previews}

static func _enemy(state: Dictionary, enemy_id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == enemy_id:
			return enemy
	return {}

static func _hp(state: Dictionary, enemy_id: int) -> int:
	return int(_enemy(state, enemy_id).get("hp", 0))

static func _queue_entry(state: Dictionary, enemy_id: int) -> Dictionary:
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == enemy_id:
			return entry
	return {}

static func _queue_time(state: Dictionary, enemy_id: int) -> int:
	return int(_queue_entry(state, enemy_id).get("time", -1))

# ---------------------------------------------------------------- engine tests

static func _test_rules_helpers(expect: Callable) -> void:
	expect.call(CardKeywordRules.stagger_delay("crawler", 3, 0) == 3, "Stagger delays an ordinary enemy by its full value")
	for dragon: String in ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]:
		expect.call(CardKeywordRules.stagger_delay(dragon, 3, 0) == 1, "%s takes half Stagger, rounded down" % dragon)
	expect.call(CardKeywordRules.stagger_delay("crawler", 4, 4) == 2, "Stagger cannot exceed 6 per enemy per player turn")
	expect.call(CardKeywordRules.stagger_delay("crawler", 3, 6) == 0, "A capped enemy takes no further Stagger this turn")
	expect.call(CardKeywordRules.empower_cost_label({"time": 2}) == "+2 Time" and CardKeywordRules.empower_cost_label({"health": 1}) == "1 HP" and CardKeywordRules.empower_cost_label({"exhaust": true}) == "Exhaust", "Empower cost labels name each cost")

static func _test_stagger_delays_queued_turn(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, ["kwtest_stagger_strike"])
	var before_time: int = _queue_time(state, 1)
	var before_seq: int = int(_queue_entry(state, 1).get("seq", 0))
	var clock: int = int(state.get("initiative_clock", 0))
	var result: Dictionary = _play(combat, state, 0, [NEAR_TILE])
	var resolved: Dictionary = result["resolved"]
	expect.call(_queue_time(resolved, 1) == before_time + 3, "Stagger 3 moves the struck enemy's queued turn 3 later")
	expect.call(int(_queue_entry(resolved, 1).get("seq", 0)) != before_seq, "A staggered entry claims a new sequence number")
	expect.call(int(resolved.get("initiative_clock", -1)) == clock, "Stagger never changes the initiative clock")
	expect.call(_queue_time(resolved, 2) == _queue_time(state, 2), "Stagger leaves other enemies untouched")
	expect.call(_hp(resolved, 1) == 37, "The Stagger hit still deals its damage")
	var preview: Dictionary = (result["previews"] as Array)[0]
	expect.call(_queue_time(preview, 1) == before_time + 3 and _hp(preview, 1) == _hp(resolved, 1), "Hover preview resolves the same Stagger and damage as the commit")
	var summary: Dictionary = combat.card_keyword_play_summary("kwtest_stagger_strike", state, result["finished"], result["actions"])
	expect.call(int(summary.get("stagger_applied", 0)) == 3 and not bool(summary.get("follow_up_active", true)) and not bool(summary.get("empowered", true)) and summary.get("empower_cost", {}) == null, "Analytics summary reports applied Stagger and inactive keywords")
	var delays: Dictionary = combat.stagger_delays_between(state, resolved)
	expect.call(int(delays.get(1, 0)) == 3 and not delays.has(2), "Stagger delays between states identify the staggered enemy")
	var display: Dictionary = state.duplicate(false)
	display[CardKeywordRules.PREVIEW_DELAYS_KEY] = delays
	var order: Array[Dictionary] = combat.current_turn_order(display)
	var previewed: bool = false
	for entry: Dictionary in order:
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == 1 and int(entry.get("stagger_preview", 0)) == 3:
			previewed = int(entry.get("time", 0)) == before_time + 3
			break
	expect.call(previewed, "Turn-order projection shows the transient Stagger delay on the delayed slot")
	expect.call(_queue_time(state, 1) == before_time, "A turn-order preview never mutates the committed queue")

static func _test_stagger_on_current_actor_applies_when_scheduled(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, ["kwtest_stagger_strike"])
	var queue: Array = []
	for entry: Dictionary in state.get("turn_queue", []):
		if int(entry.get("enemy_id", -1)) != 1:
			queue.append(entry)
	state["turn_queue"] = queue
	var result: Dictionary = _play(combat, state, 0, [NEAR_TILE])
	var resolved: Dictionary = result["resolved"]
	expect.call(_queue_entry(resolved, 1).is_empty(), "An unqueued enemy is not given a new turn by Stagger")
	expect.call(int((resolved.get(CardKeywordRules.STAGGER_PENDING_KEY, {}) as Dictionary).get("1", 0)) == 3, "Stagger on the current actor is stored until it is scheduled")
	var scheduled: Dictionary = resolved.duplicate(true)
	var enemy: Dictionary = combat._normalized_enemy(_enemy(scheduled, 1))
	var intent_cost: int = combat._enemy_intent_time_cost(enemy.get("intent", {}) as Dictionary)
	combat._schedule_enemy_after_turn(scheduled, enemy, intent_cost)
	var plain: Dictionary = resolved.duplicate(true)
	plain.erase(CardKeywordRules.STAGGER_PENDING_KEY)
	combat._schedule_enemy_after_turn(plain, enemy, intent_cost)
	expect.call(_queue_time(scheduled, 1) == _queue_time(plain, 1) + 3, "Pending Stagger is added when the enemy's next turn is scheduled")
	expect.call(not scheduled.has(CardKeywordRules.STAGGER_PENDING_KEY), "Pending Stagger is consumed once")

static func _test_stagger_boss_half_and_turn_cap(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, ["kwtest_stagger_strike"])
	var boss: Dictionary = state.duplicate(true)
	(boss["enemies"][0] as Dictionary)["type"] = "vyraketh"
	var boss_before: int = _queue_time(boss, 1)
	expect.call(combat._apply_stagger_to_enemy(boss, 1, 3) == 1 and _queue_time(boss, 1) == boss_before + 1, "Dragons take half Stagger, rounded down")
	var capped: Dictionary = state.duplicate(true)
	var capped_before: int = _queue_time(capped, 1)
	var first: int = combat._apply_stagger_to_enemy(capped, 1, 4)
	var second: int = combat._apply_stagger_to_enemy(capped, 1, 4)
	var third: int = combat._apply_stagger_to_enemy(capped, 1, 2)
	expect.call(first == 4 and second == 2 and third == 0, "Stagger stacks to at most 6 per enemy per player turn")
	expect.call(_queue_time(capped, 1) == capped_before + 6, "The capped delay is applied to the queued turn")
	var next_turn: Dictionary = capped.duplicate(true)
	next_turn["turn_flags"] = {}
	expect.call(combat._apply_stagger_to_enemy(next_turn, 1, 2) == 2, "The Stagger cap resets with the player's turn flags")
	var dead: Dictionary = state.duplicate(true)
	(dead["enemies"][0] as Dictionary)["hp"] = 0
	expect.call(combat._apply_stagger_to_enemy(dead, 1, 3) == 0, "A defeated enemy is not staggered")
	var lethal: Dictionary = state.duplicate(true)
	(lethal["enemies"][0] as Dictionary)["hp"] = 2
	var lethal_result: Dictionary = _play(combat, lethal, 0, [NEAR_TILE])
	expect.call(int(lethal_result["resolved"].get(CardKeywordRules.STAGGER_TOTAL_KEY, 0)) == 0, "A killing blow applies no Stagger")

static func _test_follow_up(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, ["kwtest_follow_strike", "kwtest_follow_strike"])
	var first: Dictionary = _play(combat, state, 0, [NEAR_TILE])
	var first_actions: Array = first["actions"]
	expect.call(first_actions.size() == 1 and int((first_actions[0] as Dictionary).get("damage", 0)) == 6, "Follow-up is off for the first card of the activation")
	expect.call(_hp(first["resolved"], 1) == 34, "The first card deals its printed damage")
	var after_first: Dictionary = first["finished"]
	var hand_before: int = (((after_first.get("deck", {}) as Dictionary).get("hand", []) as Array)).size()
	var second: Dictionary = _play(combat, after_first, 0, [NEAR_TILE])
	var second_actions: Array = second["actions"]
	expect.call(second_actions.size() == 2 and int((second_actions[0] as Dictionary).get("damage", 0)) == 9 and str((second_actions[1] as Dictionary).get("type", "")) == "draw", "Follow-up adds damage and appends its draw for the second card")
	expect.call(_hp(second["resolved"], 1) == 25, "Follow-up damage resolves with the bonus")
	var preview: Dictionary = (second["previews"] as Array)[0]
	expect.call(_hp(preview, 1) == _hp(second["resolved"], 1), "Follow-up preview damage equals resolved damage")
	var hand_after: int = (((second["resolved"].get("deck", {}) as Dictionary).get("hand", []) as Array)).size()
	expect.call(hand_after == hand_before + 1, "Follow-up's appended draw draws a card")
	expect.call(combat.final_damage_for_player_action(after_first, second_actions[0]) == 9, "Hand display damage reflects an active Follow-up")
	var summary: Dictionary = combat.card_keyword_play_summary("kwtest_follow_strike", after_first, second["finished"], second_actions)
	expect.call(bool(summary.get("follow_up_active", false)), "Analytics marks the active Follow-up")
	var enemy_turn: Dictionary = after_first.duplicate(true)
	enemy_turn["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	expect.call(not CardKeywordRules.follow_up_condition_met(enemy_turn), "Follow-up is never active outside the player's activation")

static func _test_follow_up_with_flurry(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, ["kwtest_follow_flurry"])
	state["cards_played_this_turn"] = 1
	state["turn_flags"]["cards_finished"] = 1
	var prepared: Dictionary = combat.prepare_player_card(state, 0)
	var actions: Array = combat.card_play_actions("kwtest_follow_flurry", prepared)
	expect.call(actions.size() == 2, "Flurry repeats once per remaining play (two remain)")
	var all_bonus: bool = true
	for action: Dictionary in actions:
		all_bonus = all_bonus and int(action.get("damage", 0)) == 4 and bool(action.get(CardKeywordRules.FOLLOW_UP_FLAG, false))
	expect.call(all_bonus, "Every Flurry repeat uses the Follow-up state captured at the card's start")
	var working: Dictionary = prepared
	for action: Dictionary in actions:
		working = combat.apply_player_action(working, action, NEAR_TILE)
	expect.call(_hp(working, 1) == 32, "Both Flurry repeats resolve with the Follow-up bonus")
	var cold: Dictionary = _state(combat, ["kwtest_follow_flurry"])
	var cold_actions: Array = combat.card_play_actions("kwtest_follow_flurry", combat.prepare_player_card(cold, 0))
	expect.call(cold_actions.size() == 3 and int((cold_actions[0] as Dictionary).get("damage", 0)) == 2, "A first-card Flurry has no Follow-up bonus")

static func _test_empower_costs(expect: Callable) -> void:
	var combat := CombatEngine.new()
	# Time: added to paid Time; the turn-order Time preview includes it.
	var time_state: Dictionary = _state(combat, ["kwtest_empower_time"])
	var time_off: Dictionary = _play(combat, time_state, 0, [NEAR_TILE])
	var time_on: Dictionary = _play(combat, time_state, 0, [NEAR_TILE], "empower")
	expect.call(int(time_off["finished"].get("player_turn_time_spent", 0)) == 4, "An un-Empowered card pays its printed Time")
	expect.call(int(time_on["finished"].get("player_turn_time_spent", 0)) == 6, "Empower (+2 Time) adds 2 to the paid Time")
	expect.call(combat.card_empower_time_surcharge("kwtest_empower_time", time_on["prepared"]) == 2 and combat.card_empower_time_surcharge("kwtest_empower_time", time_off["prepared"]) == 0, "The Time surcharge exists only while Empower is on")
	expect.call(_queue_time(time_on["resolved"], 1) == _queue_time(time_state, 1) + 4 and _queue_time(time_off["resolved"], 1) == _queue_time(time_state, 1), "Empower's set mod grants its Stagger only when on")
	expect.call(not time_on["finished"].has(CardKeywordRules.PLAY_MODIFIERS_KEY), "The Empower flag is cleared when the card finishes")
	var time_summary: Dictionary = combat.card_keyword_play_summary("kwtest_empower_time", time_state, time_on["finished"], time_on["actions"])
	expect.call(bool(time_summary.get("empowered", false)) and time_summary.get("empower_cost", {}) == {"time": 2} and int(time_summary.get("stagger_applied", 0)) == 4, "Analytics records Empower and its cost")
	# Health: paid after effects, bypassing Block.
	var hp_state: Dictionary = _state(combat, ["kwtest_empower_health"])
	(hp_state["player"] as Dictionary)["block"] = 10
	var hp_off: Dictionary = _play(combat, hp_state, 0, [NEAR_TILE])
	var hp_on: Dictionary = _play(combat, hp_state, 0, [NEAR_TILE], "empower")
	var player_hp: int = int((hp_state["player"] as Dictionary).get("hp", 0))
	expect.call(int((hp_off["finished"]["player"] as Dictionary).get("hp", 0)) == player_hp and _hp(hp_off["resolved"], 1) == 36, "Without Empower no health is paid and the printed damage lands")
	expect.call(int((hp_on["resolved"]["player"] as Dictionary).get("hp", 0)) == player_hp, "The Empower health cost is not paid before effects")
	expect.call(int((hp_on["finished"]["player"] as Dictionary).get("hp", 0)) == player_hp - 2 and int((hp_on["finished"]["player"] as Dictionary).get("block", 0)) == 10, "Empower (2 HP) is paid after effects and bypasses Block")
	expect.call(_hp(hp_on["resolved"], 1) == 32 and _hp((hp_on["previews"] as Array)[0], 1) == 32, "Empowered damage matches between preview and resolution")
	# Exhaust: sends the card to burned; Rehearsed Escape keeps it.
	var exhaust_state: Dictionary = _state(combat, ["kwtest_empower_exhaust"])
	var exhaust_off: Dictionary = _play(combat, exhaust_state, 0, [FAR_TILE])
	var exhaust_on: Dictionary = _play(combat, exhaust_state, 0, [FAR_TILE], "empower")
	expect.call(((exhaust_off["finished"]["deck"] as Dictionary).get("discard", []) as Array).has("kwtest_empower_exhaust"), "Without Empower the card is discarded")
	expect.call(((exhaust_on["finished"]["deck"] as Dictionary).get("burned", []) as Array).has("kwtest_empower_exhaust") and str(exhaust_on["finished"].get("last_card_destination", "")) == "burn", "Empower (Exhaust) sends the card to the burned pile")
	expect.call(_hp(exhaust_on["resolved"], 2) == 35, "Empower (Exhaust) grants its damage bonus")
	var escape_id: String = SkillTreeLibrary.skill_id_for_effect("preserve_burn")
	var escape_state: Dictionary = exhaust_state.duplicate(true)
	escape_state["skill_ids"] = [escape_id]
	escape_state = combat.arm_rehearsed_escape(escape_state)
	var escaped: Dictionary = _play(combat, escape_state, 0, [FAR_TILE], "empower")
	expect.call(((escaped["finished"]["deck"] as Dictionary).get("discard", []) as Array).has("kwtest_empower_exhaust"), "Rehearsed Escape preserves an Empower (Exhaust) card like normal Exhaust")
	# Targetless: the Empower bonus resolves with the automatic action.
	var block_state: Dictionary = _state(combat, ["kwtest_empower_block"])
	var block_on: Dictionary = _play(combat, block_state, 0, [], "empower")
	expect.call(int((block_on["finished"]["player"] as Dictionary).get("block", 0)) == 7 and int(block_on["finished"].get("player_turn_time_spent", 0)) == 3, "A targetless Empower sets its amount and pays +1 Time")

static func _test_state_bonuses(expect: Callable) -> void:
	var combat := CombatEngine.new()
	# Light
	var dark: Dictionary = _state(combat, ["kwtest_light_strike"])
	var dark_result: Dictionary = _play(combat, dark, 0, [NEAR_TILE])
	expect.call(_hp(dark_result["resolved"], 1) == 36 and _queue_time(dark_result["resolved"], 1) == _queue_time(dark, 1), "A target outside Light gains no state bonus")
	var lit: Dictionary = dark.duplicate(true)
	var umbra: Dictionary = (lit.get("umbra", {}) as Dictionary).duplicate(true)
	var sources: Array = (umbra.get("light_sources", []) as Array).duplicate(true)
	sources.append({"id": "kwtest_light", "pos": NEAR_TILE, "radius": 1, "duration": 3})
	umbra["light_sources"] = sources
	lit["umbra"] = umbra
	expect.call(CardKeywordRules.state_condition_met(combat, lit, "light", 0) and not CardKeywordRules.state_condition_met(combat, dark, "light", 0), "The Light condition uses the light-coverage helper")
	var lit_result: Dictionary = _play(combat, lit, 0, [NEAR_TILE])
	expect.call(_hp(lit_result["resolved"], 1) == 33 and _queue_time(lit_result["resolved"], 1) == _queue_time(lit, 1) + 2, "A target in Light takes the bonus damage and Stagger")
	expect.call(_hp((lit_result["previews"] as Array)[0], 1) == _hp(lit_result["resolved"], 1), "Light bonus preview damage equals resolved damage")
	# Frozen
	var warm: Dictionary = _state(combat, ["kwtest_frozen_strike"])
	var warm_result: Dictionary = _play(combat, warm, 0, [NEAR_TILE])
	expect.call(_hp(warm_result["resolved"], 1) == 36, "An unfrozen target gains no Frozen bonus")
	var frozen: Dictionary = warm.duplicate(true)
	(frozen["enemies"][0] as Dictionary)["freeze"] = 1
	var frozen_result: Dictionary = _play(combat, frozen, 0, [NEAR_TILE])
	var frozen_loss: int = 40 - _hp(frozen_result["resolved"], 1)
	var plain_frozen: Dictionary = frozen.duplicate(true)
	var plain_action: Dictionary = {"type": "melee", "damage": 4, "range": 1, "element": "none"}
	var plain_loss: int = 40 - _hp(combat.apply_player_action(plain_frozen, plain_action, NEAR_TILE), 1)
	expect.call(frozen_loss > plain_loss and _hp((frozen_result["previews"] as Array)[0], 1) == _hp(frozen_result["resolved"], 1), "A Frozen target takes the bonus, matching its preview")
	# Half health
	var healthy: Dictionary = _state(combat, ["kwtest_execute_strike"])
	var healthy_result: Dictionary = _play(combat, healthy, 0, [NEAR_TILE])
	expect.call(_hp(healthy_result["resolved"], 1) == 30, "A target above half health takes printed damage")
	var bloodied: Dictionary = healthy.duplicate(true)
	(bloodied["enemies"][0] as Dictionary)["hp"] = 20
	var bloodied_result: Dictionary = _play(combat, bloodied, 0, [NEAR_TILE])
	expect.call(_hp(bloodied_result["resolved"], 1) == 5 and _hp((bloodied_result["previews"] as Array)[0], 1) == 5, "A target at half health takes the bonus, matching its preview")
	var just_above: Dictionary = healthy.duplicate(true)
	(just_above["enemies"][0] as Dictionary)["hp"] = 21
	expect.call(_hp(_play(combat, just_above, 0, [NEAR_TILE])["resolved"], 1) == 11, "Half health is evaluated before the hit (hp*2 <= max_hp)")

static func _test_scale_bonuses(expect: Callable) -> void:
	var combat := CombatEngine.new()
	# Stoneskin
	var bare: Dictionary = _state(combat, ["kwtest_stonefist"])
	var fist_action: Dictionary = combat.card_play_actions("kwtest_stonefist", bare)[0]
	expect.call(combat.final_damage_for_player_action(bare, fist_action) == 5, "No Stoneskin adds no damage")
	var armored: Dictionary = bare.duplicate(true)
	(armored["player"] as Dictionary)["stoneskin"] = 4
	expect.call(combat.final_damage_for_player_action(armored, fist_action) == 9, "Each Stoneskin adds 1 damage")
	var armored_result: Dictionary = _play(combat, armored, 0, [NEAR_TILE])
	expect.call(_hp(armored_result["resolved"], 1) == 31 and _hp((armored_result["previews"] as Array)[0], 1) == 31, "Stoneskin scaling resolves and previews identically")
	var fortress: Dictionary = bare.duplicate(true)
	(fortress["player"] as Dictionary)["stoneskin"] = 20
	expect.call(combat.final_damage_for_player_action(fortress, fist_action) == 11, "The Stoneskin bonus caps at its max")
	var modifiers: Array[Dictionary] = combat.damage_modifiers_for_player_action(armored, fist_action)
	var listed: bool = false
	for modifier: Dictionary in modifiers:
		listed = listed or (str(modifier.get("source", "")) == "Stoneskin" and int(modifier.get("amount", 0)) == 4)
	expect.call(listed, "The scale bonus is listed as a damage modifier for the hand display")
	# Tiles moved: independent movement + card Move + Blink, reset each turn.
	var moving: Dictionary = _state(combat, ["kwtest_lance", "kwtest_blink", "kwtest_wheel"], [
		{"id": 1, "type": "crawler", "pos": Vector2i(8, 4), "hp": 40, "max_hp": 40},
	])
	var lance_action: Dictionary = combat.card_play_actions("kwtest_lance", moving)[0]
	expect.call(combat.final_damage_for_player_action(moving, lance_action) == 4, "No movement adds no damage")
	var walked: Dictionary = combat.apply_player_movement(moving, Vector2i(4, 4))
	expect.call(CardKeywordRules.tiles_moved_this_turn(walked) == 2, "Independent movement counts tiles moved")
	expect.call(combat.final_damage_for_player_action(walked, lance_action) == 6, "Tiles moved scale the damage")
	var blinked: Dictionary = _play(combat, walked, 1, [Vector2i(6, 5)])["finished"]
	expect.call(CardKeywordRules.tiles_moved_this_turn(blinked) == 5, "Blink counts its Manhattan distance")
	var hand_after_blink: Array = (blinked.get("deck", {}) as Dictionary).get("hand", []) as Array
	var wheel_index: int = hand_after_blink.find("kwtest_wheel")
	var wheel_prepared: Dictionary = combat.prepare_player_card(blinked, wheel_index)
	var wheel_actions: Array = combat.card_play_actions("kwtest_wheel", wheel_prepared)
	var after_move: Dictionary = combat.apply_player_action(wheel_prepared, wheel_actions[0], Vector2i(7, 4))
	expect.call(CardKeywordRules.tiles_moved_this_turn(after_move) == 7, "Card Move adds the tiles it moved")
	var wheel_damage: int = combat.final_damage_for_player_action(after_move, wheel_actions[1])
	expect.call(wheel_damage == 9, "The tiles-moved bonus caps at its max")
	var struck: Dictionary = combat.apply_player_action(after_move, wheel_actions[1], Vector2i(8, 4))
	var wheel_preview: Dictionary = combat.surface_preview_for_player_action(after_move, wheel_actions[1], Vector2i(8, 4), true).get("state", {}) as Dictionary
	expect.call(_hp(struck, 1) == 40 - wheel_damage and _hp(wheel_preview, 1) == _hp(struck, 1), "Tiles-moved scaling resolves at hit time and matches its preview")
	var next_turn: Dictionary = combat.prepare_next_player_turn(struck)
	expect.call(CardKeywordRules.tiles_moved_this_turn(next_turn) == 0, "Tiles moved reset with the player's turn")

static func _test_icon_rows_and_grimoire(expect: Callable) -> void:
	for key: String in ["stagger", "follow_up", "empower"]:
		expect.call(ActionIcons.KEYWORDS.has(key) and ActionIcons.icon_texture(key) != null, "%s icon is registered and loads" % key)
		expect.call(GrimoireLibrary.entry_map().has("keyword:%s" % key), "Grimoire documents keyword:%s" % key)
	var stagger_row: Array = ActionIcons.tokens_for_action({"type": "melee", "damage": 3, "range": 1, "stagger": 2, "push": 1})
	var stagger_index: int = -1
	for index: int in range(stagger_row.size()):
		if str((stagger_row[index] as Dictionary).get("icon", "")) == "stagger":
			stagger_index = index
	expect.call(stagger_index >= 0 and int((stagger_row[stagger_index] as Dictionary).get("value", 0)) == 2, "Stagger shows as an icon token with its value")
	expect.call(stagger_index >= 0 and str((stagger_row[stagger_row.size() - 1] as Dictionary).get("icon", "")) == "push", "Stagger stays before Push/Pull in the token row")
	var shove_row: Array = ActionIcons.tokens_for_action({"type": "push", "damage": 2, "range": 1, "amount": 2, "stagger": 1})
	expect.call(str((shove_row[shove_row.size() - 1] as Dictionary).get("icon", "")) == "push", "Push remains the last token when Stagger is present")
	var follow_card: Dictionary = GameData.card_def("kwtest_follow_strike")
	var follow_rows: Array = ActionIcons.rows_for_card(follow_card)
	var follow_segment: Array = _segment(follow_rows, "follow_up")
	expect.call(follow_segment.size() == 3 and str((follow_segment[1] as Dictionary).get("value", "")) == "+3" and str((follow_segment[2] as Dictionary).get("icon", "")) == "draw", "Card rows show the Follow-up segment: icon, damage +3, draw 1")
	var empower_card: Dictionary = GameData.card_def("kwtest_empower_time")
	var empower_segment: Array = _segment(ActionIcons.rows_for_card(empower_card), "empower")
	expect.call(empower_segment.size() == 3 and str((empower_segment[1] as Dictionary).get("icon", "")) == "time" and str((empower_segment[2] as Dictionary).get("icon", "")) == "stagger", "Card rows show the Empower segment: icon, cost, bonus")
	var exhaust_segment: Array = _segment(ActionIcons.rows_for_card(GameData.card_def("kwtest_empower_exhaust")), "empower")
	expect.call(exhaust_segment.size() >= 2 and str((exhaust_segment[1] as Dictionary).get("icon", "")) == "exhaust", "An Exhaust Empower cost shows the Exhaust icon")
	var light_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("kwtest_light_strike").get("actions", []))
	var light_row: Array = light_rows[light_rows.size() - 1] as Array
	expect.call(str((light_row[0] as Dictionary).get("kind", "")) == "surface_condition" and str((light_row[0] as Dictionary).get("icon", "")) == "illuminate" and light_row.size() == 3, "A Light state bonus shows a condition token with its damage and Stagger")
	var frozen_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("kwtest_frozen_strike").get("actions", []))
	expect.call(str(((frozen_rows[frozen_rows.size() - 1] as Array)[0] as Dictionary).get("icon", "")) == "freeze", "The Frozen condition uses the Freeze icon")
	var execute_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("kwtest_execute_strike").get("actions", []))
	expect.call(str(((execute_rows[execute_rows.size() - 1] as Array)[0] as Dictionary).get("icon", "")) == "health", "The half-health condition uses the Health icon")
	# Card faces use compact condition labels; plain text and tooltips keep the full condition.
	var light_condition: Dictionary = light_row[0] as Dictionary
	expect.call(str(light_condition.get("prefix", "")) == "in" and ActionIcons.plain_text_for_tokens(light_row).begins_with("if Target in Light:") and ActionIcons.token_tooltip(light_condition).begins_with("If Target in Light"), "The Light condition reads 'in [Light]:' on the card face and keeps its full text")
	expect.call(str(((frozen_rows[frozen_rows.size() - 1] as Array)[0] as Dictionary).get("prefix", "")) == "vs" and str(((execute_rows[execute_rows.size() - 1] as Array)[0] as Dictionary).get("prefix", "")) == "≤½", "Frozen reads 'vs [Freeze]:' and half health '≤½ [Health]:' on the card face")
	var ground_row: Array = ActionIcons.tokens_for_surface_bonus({"type": "melee", "damage": 11, "range": 1, "surface_bonus": {"surface": "rubble", "subject": "target", "present": true, "damage": 4}})
	expect.call(str((ground_row[0] as Dictionary).get("prefix", "")) == "on" and ActionIcons.plain_text_for_tokens(ground_row).begins_with("Target on Rubble:"), "A target ground condition reads 'on [ground]:' and keeps 'Target on' in its text")
	expect.call(str((ground_row[1] as Dictionary).get("icon", "")) == "melee", "A melee ground bonus repeats the melee damage icon")
	var guard_row: Array = ActionIcons.tokens_for_surface_bonus({"type": "block", "amount": 6, "surface_bonus": {"surface": "electrified", "subject": "player", "present": true, "amount": 3}})
	expect.call(str((guard_row[0] as Dictionary).get("prefix", "")) == "on" and str((guard_row[0] as Dictionary).get("tooltip", "")).begins_with("if on Electrified"), "A self ground condition reads 'on [ground]:' and names the subject in its tooltip")
	expect.call(str((ActionIcons.tokens_for_surface_bonus({"type": "ranged", "damage": 4, "range": 3, "surface_bonus": {"surface": "fire", "subject": "target", "damage": 3}})[1] as Dictionary).get("icon", "")) == "ranged", "A ranged ground bonus keeps the ranged damage icon")
	var scale_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("kwtest_stonefist").get("actions", []))
	var scale_token: Dictionary = (scale_rows[scale_rows.size() - 1] as Array)[0]
	expect.call(str(scale_token.get("icon", "")) == "stoneskin" and str(scale_token.get("suffix", "")) == "+1 each (max 6)", "A scale bonus shows its icon and '+1 each (max N)'")
	var lance_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("kwtest_lance").get("actions", []))
	expect.call(str(((lance_rows[lance_rows.size() - 1] as Array)[0] as Dictionary).get("icon", "")) == "move", "A tiles-moved scale bonus uses the Move icon")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(follow_card).has("keyword:follow_up"), "Follow-up cards unlock the Follow-up grimoire entry")
	var empower_entries: Array[String] = GrimoireLibrary.entry_ids_for_card_def(empower_card)
	expect.call(empower_entries.has("keyword:empower") and empower_entries.has("keyword:stagger"), "Empower cards unlock Empower and the keywords their bonus grants")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("kwtest_stagger_strike")).has("keyword:stagger"), "Stagger actions unlock the Stagger grimoire entry")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("kwtest_light_strike")).has("keyword:stagger"), "State-bonus Stagger unlocks the Stagger grimoire entry")
	expect.call(InputRouterScript.glyph_label_for_family(InputRouterScript.ACTION_EMPOWER, InputRouterScript.FAMILY_XBOX) == "RS" and InputRouterScript.glyph_label_for_family(InputRouterScript.ACTION_EMPOWER, InputRouterScript.FAMILY_STEAM_DECK) == "R3", "The Empower controller prompt names the right-stick press")

static func _segment(rows: Array, keyword: String) -> Array:
	for row_var: Variant in rows:
		var row: Array = row_var
		if not row.is_empty() and str((row[0] as Dictionary).get("keyword_segment", "")) == keyword:
			return row
	return []

static func _test_hand_display_rows(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene: Node = RunSceneScript.new()
	var state: Dictionary = _state(combat, ["kwtest_follow_strike", "kwtest_empower_health", "kwtest_stonefist"])
	var cold: Dictionary = scene.call("_card_widget_display", "kwtest_follow_strike", state)
	var cold_rows: Array = cold.get("summary_rows", [])
	var cold_segment: Array = _segment(cold_rows, "follow_up")
	expect.call(not cold_segment.is_empty() and not bool((cold_segment[0] as Dictionary).get("active", true)), "The hand shows an inactive Follow-up segment on the first card")
	expect.call(_first_damage_value(cold_rows) == 6, "An inactive Follow-up leaves the printed damage in the hand")
	var warm_state: Dictionary = state.duplicate(true)
	warm_state["turn_flags"]["cards_finished"] = 1
	var warm_rows: Array = (scene.call("_card_widget_display", "kwtest_follow_strike", warm_state) as Dictionary).get("summary_rows", [])
	var warm_segment: Array = _segment(warm_rows, "follow_up")
	expect.call(not warm_segment.is_empty() and bool((warm_segment[0] as Dictionary).get("active", false)), "The hand marks Follow-up active once a card was played")
	expect.call(_first_damage_value(warm_rows) == 9, "An active Follow-up shows the bonus damage in the hand")
	var draw_rows: int = 0
	for row_var: Variant in warm_rows:
		for token_var: Variant in row_var as Array:
			if str((token_var as Dictionary).get("icon", "")) == "draw":
				draw_rows += 1
	expect.call(draw_rows == 1, "The appended draw is shown once, inside the active Follow-up segment")
	var empower_rows: Array = (scene.call("_card_widget_display", "kwtest_empower_health", state) as Dictionary).get("summary_rows", [])
	var empower_segment: Array = _segment(empower_rows, "empower")
	expect.call(empower_segment.size() == 3 and str((empower_segment[1] as Dictionary).get("icon", "")) == "health_cost", "The hand shows the Empower segment with its health cost")
	var empowered_state: Dictionary = state.duplicate(false)
	empowered_state[CardKeywordRules.PLAY_MODIFIERS_KEY] = {"card_id": "kwtest_empower_health", "follow_up": false, "empowered": true}
	var empowered_rows: Array = (scene.call("_card_widget_display", "kwtest_empower_health", empowered_state) as Dictionary).get("summary_rows", [])
	expect.call(_first_damage_value(empowered_rows) == 8 and bool((_segment(empowered_rows, "empower")[0] as Dictionary).get("active", false)), "An Empowered selection shows its bonus damage and an active segment")
	var time_state: Dictionary = _state(combat, ["kwtest_empower_time"])
	expect.call(not (scene.call("_card_widget_display", "kwtest_empower_time", time_state) as Dictionary).has("time_surcharge"), "An Empower +Time card shows no surcharge while Empower is off")
	time_state[CardKeywordRules.PLAY_MODIFIERS_KEY] = {"card_id": "kwtest_empower_time", "follow_up": false, "empowered": true}
	var time_display: Dictionary = scene.call("_card_widget_display", "kwtest_empower_time", time_state)
	expect.call(int(time_display.get("time_surcharge", 0)) == 2, "A toggled Empower +Time carries its surcharge to the card display")

	var armored: Dictionary = state.duplicate(true)
	(armored["player"] as Dictionary)["stoneskin"] = 3
	var scale_rows: Array = (scene.call("_card_widget_display", "kwtest_stonefist", armored) as Dictionary).get("summary_rows", [])
	expect.call(_first_damage_value(scale_rows) == 8, "The hand shows the current Stoneskin-scaled damage")
	scene.free()

# The selected card's own Time badge adds a toggled Empower +Time, like the
# turn-order preview, and names the surcharge in its detail.
static func _test_live_time_badge_surcharge(tree: SceneTree, expect: Callable) -> void:
	var combat := CombatEngine.new()
	var scene: Node = RunSceneScript.new()
	var state: Dictionary = _state(combat, ["kwtest_empower_time"])
	state[CardKeywordRules.PLAY_MODIFIERS_KEY] = {"card_id": "kwtest_empower_time", "follow_up": false, "empowered": true}
	var display: Dictionary = scene.call("_card_widget_display", "kwtest_empower_time", state)
	scene.free()
	var widget: CardWidget = CardWidgetScene.instantiate()
	widget.configure("kwtest_empower_time", true, false, true, false, false, true, GameData.card_def("kwtest_empower_time"))
	tree.root.add_child(widget)
	await tree.process_frame
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []), int(display.get("time_surcharge", 0)))
	var badge: Control = widget.get("_time_badge") as Control
	expect.call(badge != null and int(badge.get("value")) == 6 and str(badge.tooltip_text).contains("Empower: +2"), "The selected card's Time badge shows printed Time plus the Empower surcharge")
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	expect.call(badge != null and int(badge.get("value")) == 4 and not str(badge.tooltip_text).contains("Empower"), "Clearing the surcharge restores the printed Time badge")
	widget.queue_free()
	await tree.process_frame

static func _first_damage_value(rows: Array) -> int:
	for row_var: Variant in rows:
		for token_var: Variant in row_var as Array:
			var token: Dictionary = token_var
			if str(token.get("field", "")) == "damage":
				return int(token.get("value", -1))
	return -1

# ---------------------------------------------------------------- live RunScene

static func _live_instance(tree: SceneTree, expect: Callable, hand: Array, seed: int) -> Node:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(packed != null, "Card keyword live fixture loads RunScene")
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	var combat := CombatEngine.new()
	var state: Dictionary = _state(combat, hand)
	state["current_actor"] = {"kind": "player", "key": "player"}
	state.erase("player_turn_restrictions")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = Vector2i(2, 2)
	run_state["combat_state"] = state
	instance.set("_guided_tutorial_phase_id", "")
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	await tree.process_frame
	await tree.process_frame
	return instance

static func _command_button(instance: Node, button_name: String) -> BaseButton:
	var bar: Node = instance.get("_action_context_command_bar") as Node
	if bar == null:
		return null
	return bar.get_node_or_null(button_name) as BaseButton

static func _test_live_targetless_empower_confirmation(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, ["kwtest_empower_block"], 51301)
	if instance == null:
		return
	await instance.call("_on_card_pressed", 0)
	await tree.process_frame
	expect.call(bool(instance.call("_pending_card_requires_confirmation")), "A targetless Empower card enters its confirmation stage")
	var tracker: Dictionary = instance.call("_action_step_tracker_state")
	expect.call(str(tracker.get("mode", "")) == "confirmation", "The command host appears at a targetless card's confirmation stage")
	instance.call("_refresh_action_step_tracker")
	var button: BaseButton = _command_button(instance, "ActionContextEmpower")
	expect.call(button != null and button.text == "Empower +1 Time [E]", "The Empower toggle is labelled with its cost and shortcut")
	expect.call(int((instance.call("_turn_order_card_time_preview") as Dictionary).get("time", 0)) == 2, "The Time preview starts at the printed Time")
	await instance.call("_toggle_pending_empower")
	await tree.process_frame
	expect.call(bool(instance.call("_selected_card_empowered")), "Toggling Empower marks the selection Empowered")
	var preview_state: Dictionary = instance.get("_preview_combat_state")
	expect.call(int((preview_state.get("player", {}) as Dictionary).get("block", 0)) == 7, "Empower rebuilds the automatic preview from the card's start")
	expect.call(int((instance.call("_turn_order_card_time_preview") as Dictionary).get("time", 0)) == 3, "The turn-order Time preview includes Empower's +Time")
	instance.call("_refresh_action_step_tracker")
	button = _command_button(instance, "ActionContextEmpower")
	expect.call(button != null and button.text.begins_with("✓") and bool(button.get_meta("empower_active", false)), "The toggle shows its active state")
	await instance.call("_on_confirm_card_play_pressed")
	await tree.process_frame
	var committed: Dictionary = instance.get("_combat_state")
	expect.call(int((committed.get("player", {}) as Dictionary).get("block", 0)) == 7 and int(committed.get("player_turn_time_spent", 0)) == 3, "Confirming the Empowered targetless card commits its bonus and pays +1 Time")
	instance.queue_free()
	await tree.process_frame

static func _test_live_targeted_empower_and_stagger_preview(tree: SceneTree, expect: Callable) -> void:
	var instance: Node = await _live_instance(tree, expect, ["kwtest_empower_time"], 51302)
	if instance == null:
		return
	var queued_before: int = _queue_time(instance.get("_combat_state"), 1)
	await instance.call("_on_card_pressed", 0)
	await tree.process_frame
	expect.call(str((instance.call("_action_step_tracker_state") as Dictionary).get("mode", "")) == "selection", "A targeted Empower card starts at its first targeted action")
	instance.call("_refresh_action_step_tracker")
	var button: BaseButton = _command_button(instance, "ActionContextEmpower")
	expect.call(button != null and button.text == "Empower +2 Time [E]", "The targeted card offers Empower while its target is pending")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	await instance.call("_input", key)
	await tree.process_frame
	expect.call(bool(instance.call("_selected_card_empowered")), "The E key toggles Empower")
	var pending: Array = instance.get("_pending_actions")
	expect.call(not pending.is_empty() and int((pending[0] as Dictionary).get("stagger", 0)) == 4, "The pending action carries the Empower bonus")
	expect.call(int((instance.call("_turn_order_card_time_preview") as Dictionary).get("time", 0)) == 6, "The Time preview adds Empower's +2 Time")
	instance.call("_on_board_tile_hovered", NEAR_TILE)
	instance.call("_refresh_board_hover_presentation")
	var delays: Dictionary = instance.call("_turn_order_stagger_preview_delays")
	expect.call(int(delays.get(1, 0)) == 4, "Hovering a Stagger target previews the delay")
	var combat := CombatEngine.new()
	var order: Array[Dictionary] = combat.current_turn_order(instance.call("_turn_order_display_state"))
	var slot_delayed: bool = false
	for entry: Dictionary in order:
		if int(entry.get("enemy_id", -1)) == 1 and int(entry.get("stagger_preview", 0)) == 4:
			slot_delayed = int(entry.get("time", 0)) == queued_before + 4
	expect.call(slot_delayed, "The turn-order bar previews the delayed enemy slot")
	expect.call(str(instance.call("_turn_order_projection_badge_text", {"stagger_preview": 4})) == "Stagger +4", "The delayed slot is badged with its Stagger")
	await instance.call("_on_board_tile_clicked", NEAR_TILE)
	await tree.process_frame
	var committed: Dictionary = instance.get("_combat_state")
	expect.call(int(committed.get("player_turn_time_spent", 0)) == 6, "The Empowered targeted card pays +2 Time on commit")
	expect.call(_queue_time(committed, 1) == queued_before + 4, "The committed Stagger delays the enemy's queued turn")
	instance.queue_free()
	await tree.process_frame
