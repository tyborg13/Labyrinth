extends RefCounted

## Wave-3 card keywords: Retaliate, Quicken, next-attack buffs and Rites.
## Mechanics are exercised with injected fixture cards; data/cards.json is
## untouched. See spec/card_keywords_wave3.md.

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const SurfaceRelicRules = preload("res://scripts/surface_relic_rules.gd")
const GuardianRelicRules = preload("res://scripts/guardian_relic_rules.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const RetaliateRules = preload("res://scripts/retaliate_rules.gd")
const TempoRules = preload("res://scripts/tempo_rules.gd")
const RiteRules = preload("res://scripts/rite_rules.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const NO_TARGET: Vector2i = Vector2i(-1, -1)
const PLAYER_TILE: Vector2i = Vector2i(2, 4)
const ADJACENT_TILE: Vector2i = Vector2i(3, 4)

const FIXTURES: Dictionary = {
	"w3_fx_retaliate": {"actions": [{"type": "block", "amount": 2}, {"type": "retaliate", "amount": 4}], "time": 3},
	"w3_fx_retaliate_riders": {"actions": [{"type": "retaliate", "amount": 2, "bleed": 1, "shock": 1, "push": 2}], "time": 3},
	"w3_fx_retaliate_push_only": {"actions": [{"type": "retaliate", "amount": 0, "push": 2}], "time": 5},
	"w3_fx_retaliate_bleed": {"actions": [{"type": "retaliate", "amount": 1, "bleed": 2, "push": 1}], "time": 3},
	"w3_fx_quicken": {"actions": [{"type": "draw", "amount": 1}, {"type": "quicken", "amount": 2}], "time": 2},
	"w3_fx_quicken_first": {"actions": [{"type": "quicken", "amount": 2}], "time": 3},
	"w3_fx_quicken_double": {"actions": [{"type": "quicken", "amount": 1}, {"type": "quicken", "amount": 2}], "time": 2},
	"w3_fx_quicken_big": {"actions": [{"type": "quicken", "amount": 4}], "time": 2},
	"w3_fx_slow_guard": {"actions": [{"type": "block", "amount": 1}], "time": 6},
	"w3_fx_cheap_guard": {"actions": [{"type": "block", "amount": 1}], "time": 2},
	"w3_fx_strike": {"actions": [{"type": "melee", "damage": 3, "range": 1, "element": "none"}], "time": 4},
	"w3_fx_buff": {"actions": [{"type": "block", "amount": 1}, {"type": "next_attack", "damage": 3}], "time": 2},
	"w3_fx_buff_then_strike": {"actions": [{"type": "next_attack", "damage": 3}, {"type": "melee", "damage": 3, "range": 1, "element": "none"}], "time": 3},
	"w3_fx_lightning_chain": {"element": "lightning", "actions": [{"type": "next_attack", "element": "lightning", "chain": 2}], "time": 2},
	"w3_fx_pierce": {"actions": [{"type": "next_attack", "damage": 4, "pierce": true}], "time": 2},
	"w3_fx_headlong": {"actions": [{"type": "move", "range": 4}, {"type": "next_attack", "per_tile_moved": {"damage": 1, "max": 4}}], "time": 2},
	"w3_fx_bolt": {"element": "lightning", "actions": [{"type": "ranged", "damage": 2, "range": 4, "element": "lightning"}], "time": 3},
	"w3_fx_shot": {"actions": [{"type": "ranged", "damage": 2, "range": 4, "element": "none"}], "time": 3},
	"w3_fx_push": {"element": "earth", "actions": [{"type": "push", "amount": 1, "damage": 0, "range": 1, "element": "earth"}], "time": 3},
	"w3_fx_melee_push": {"actions": [{"type": "melee", "damage": 1, "range": 1, "element": "none", "push": 1}], "time": 3},
	# Sleet Squall's shape: a zero-damage push, then an Ice hit on the moved target.
	"w3_fx_sleet": {"element": "ice", "actions": [{"type": "push", "damage": 0, "range": 3, "amount": 2, "element": "ice"}, {"type": "ranged", "damage": 3, "range": 3, "element": "ice", "target": "previous_target"}], "time": 5},
	"w3_fx_ice_strike": {"element": "ice", "actions": [{"type": "melee", "damage": 2, "range": 1, "element": "ice"}], "time": 3},
	"w3_fx_rite_pyre": {"burn": true, "actions": [], "time": 5, "description": "Rite: your Fire tiles deal 2 more damage.", "rite": {"effects": [{"type": "surface_damage_bonus", "surface": "fire", "amount": 2}]}},
	"w3_fx_rite_salamander": {"burn": true, "actions": [], "time": 6, "rite": {"effects": [{"type": "surface_immunity", "surface": "fire"}, {"type": "turn_start_on_surface", "surface": "fire", "rewards": [{"type": "stoneskin", "amount": 3}, {"type": "draw", "amount": 1}]}]}},
	"w3_fx_rite_hoarfrost": {"burn": true, "actions": [], "time": 4, "rite": {"effects": [{"type": "status_applied_reward", "status": "freeze", "rewards": [{"type": "block", "amount": 3}, {"type": "draw", "amount": 1}]}]}},
	"w3_fx_rite_storm": {"burn": true, "actions": [], "time": 5, "rite": {"effects": [{"type": "turn_start_surface_pulse", "surface": "electrified", "damage": 2, "element": "lightning"}]}},
	"w3_fx_rite_tempest": {"burn": true, "actions": [], "time": 6, "rite": {"effects": [{"type": "card_time_discount", "amount": 1}]}},
	"w3_fx_rite_tailwinds": {"burn": true, "actions": [], "time": 4, "rite": {"effects": [{"type": "independent_movement_bonus", "amount": 1}, {"type": "forced_movement_bonus", "amount": 1}]}},
	"w3_fx_rite_mountain": {"burn": true, "actions": [], "time": 5, "rite": {"effects": [{"type": "turn_start_reward", "rewards": [{"type": "stoneskin", "amount": 3}]}]}},
	"w3_fx_rite_noon": {"burn": true, "actions": [], "time": 5, "rite": {"effects": [{"type": "player_light_aura", "radius": 2}, {"type": "target_state_action_mod", "conditions": {"target_in_light": true}, "add": {"damage": 2}}]}},
	"w3_fx_rite_thorns": {"burn": true, "health_cost": 2, "actions": [], "time": 5, "description": "Rite: enemies that hit you in melee take 3 and Bleed 1.", "rite": {"effects": [{"type": "thorns", "damage": 3, "bleed": 1}]}},
	"w3_fx_rite_relic_probe": {"burn": true, "actions": [], "time": 3, "rite": {"effects": [{"type": "conductive_fire"}, {"type": "chain_hop_damage", "amount": 50}]}}
}

static func run(expect: Callable) -> void:
	# Warm catalog caches built from GameData.cards() before fixtures exist, so
	# the injected cards never leak into later suites through a cached catalog.
	GrimoireLibrary.entry_map()
	_install_fixtures()
	var engine: CombatEngine = CombatEngine.new()
	_test_retaliate_melee_block_first(engine, expect)
	_test_retaliate_ignores_ranged(engine, expect)
	_test_retaliate_stacking_and_riders(engine, expect)
	_test_retaliate_expiry(engine, expect)
	_test_retaliate_kill_rewards(engine, expect)
	_test_retaliate_presentation_steps(engine, expect)
	_test_quicken_next_card_only(engine, expect)
	_test_quicken_stacks_min_and_expiry(engine, expect)
	_test_next_attack_consumption(engine, expect)
	_test_next_attack_element_and_pierce(engine, expect)
	_test_next_attack_per_tile_moved(engine, expect)
	_test_next_attack_skips_forced_movement(engine, expect)
	_test_rite_fire(engine, expect)
	_test_rite_freeze_reward(engine, expect)
	_test_rite_turn_start_effects(engine, expect)
	_test_rite_time_discount(engine, expect)
	_test_rite_tailwinds(engine, expect)
	_test_rite_noon(engine, expect)
	_test_thorns_stack_with_retaliate(engine, expect)
	_test_rites_are_combat_scoped(engine, expect)
	_test_rites_visible_to_relic_rule_readers(engine, expect)
	_test_presentation_contracts(engine, expect)
	_test_run_scene_hand_display(engine, expect)
	_remove_fixtures()

# ------------------------------------------------------------------ fixtures

static func _install_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in FIXTURES.keys():
		var card: Dictionary = (FIXTURES[card_id] as Dictionary).duplicate(true)
		card["name"] = card_id.trim_prefix("w3_fx_").capitalize()
		card["rarity"] = "common"
		if not card.has("burn"):
			card["burn"] = false
		if not card.has("description"):
			card["description"] = card["name"]
		card["reward_pool"] = false
		cards[card_id] = card

static func _remove_fixtures() -> void:
	var cards: Dictionary = GameData.cards()
	for card_id: String in FIXTURES.keys():
		cards.erase(card_id)

static func _room(enemy_pos: Vector2i, enemy_hp: int = 20, block: int = 0) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String] = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 8 else "stone")
		grid.append(row)
	return {
		"name": "Wave 3 Keyword Room",
		"coord": Vector2i(3, 1),
		"depth": 1,
		"type": "combat",
		"element": ElementData.NONE,
		"grid": grid,
		"player_start": PLAYER_TILE,
		"enemies": [{"id": 1, "type": "crawler", "pos": enemy_pos, "hp": enemy_hp, "max_hp": enemy_hp, "block": block}],
		"loot": [],
		"traps": []
	}

static func _state(engine: CombatEngine, enemy_pos: Vector2i = ADJACENT_TILE, enemy_hp: int = 20, block: int = 0) -> Dictionary:
	var state: Dictionary = engine.create_combat(4303, _room(enemy_pos, enemy_hp, block), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["w3_fx_cheap_guard", "w3_fx_cheap_guard", "w3_fx_cheap_guard", "w3_fx_cheap_guard", "w3_fx_cheap_guard", "w3_fx_cheap_guard", "w3_fx_cheap_guard", "w3_fx_cheap_guard"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
		"cards_per_turn": 8
	})
	var deck: Dictionary = state["deck"] as Dictionary
	deck["hand"] = []
	state["deck"] = deck
	return state

## Resolve every action of `card_id` like a committed hand play and finish it.
static func _play(engine: CombatEngine, state: Dictionary, card_id: String, target: Vector2i = NO_TARGET) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var deck: Dictionary = next_state["deck"] as Dictionary
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	hand.push_front(card_id)
	deck["hand"] = hand
	next_state["deck"] = deck
	var working: Dictionary = engine.prepare_player_card(next_state, 0, "play")
	var actions: Array = engine.card_play_actions(card_id, working)
	for action_var: Variant in actions:
		var action: Dictionary = action_var as Dictionary
		var tile: Vector2i = target if engine.player_action_needs_target(action) else NO_TARGET
		working = engine.apply_player_action(working, action, tile)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})

static func _enemy(state: Dictionary) -> Dictionary:
	return ((state.get("enemies", []) as Array)[0] as Dictionary)

static func _player(state: Dictionary) -> Dictionary:
	return state.get("player", {}) as Dictionary

static func _enemy_strike(engine: CombatEngine, state: Dictionary, action: Dictionary) -> Dictionary:
	return engine._resolve_enemy_action(state.duplicate(true), 0, action)

static func _melee(damage: int = 3) -> Dictionary:
	return {"type": "melee", "damage": damage, "range": 1}

# ------------------------------------------------------------------ Retaliate

static func _test_retaliate_melee_block_first(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine, ADJACENT_TILE, 20, 2)
	state = _play(engine, state, "w3_fx_retaliate")
	expect.call(int((state.get("retaliate", {}) as Dictionary).get("amount", 0)) == 4, "Retaliate should store its amount until the next player turn")
	var after: Dictionary = _enemy_strike(engine, state, _melee(3))
	expect.call(int(_enemy(after).get("block", 0)) == 0 and int(_enemy(after).get("hp", 0)) == 18, "Retaliate damage should be absorbed by the attacker's Block first (4 vs 2 Block leaves 2 HP loss)")
	expect.call(int(_player(after).get("hp", 0)) == 23, "The enemy melee hit still resolves against the player's Block")
	var events: Array[Dictionary] = RetaliateRules.events_between(state, after)
	expect.call(events.size() == 1 and int(events[0].get("damage", 0)) == 4 and str(events[0].get("attack_type", "")) == "melee", "Retaliate should record one retaliate_triggered surface event per enemy attack")
	var chilled_state: Dictionary = state.duplicate(true)
	Surface.place(chilled_state, ADJACENT_TILE, "ice", {"actor_kind": "player"})
	chilled_state["enemies"][0]["chilled"] = true
	chilled_state["enemies"][0]["block"] = 0
	chilled_state["enemies"][0]["expose"] = 3
	var chilled_after: Dictionary = _enemy_strike(engine, chilled_state, _melee(3))
	expect.call(int(_enemy(chilled_after).get("hp", 0)) == 16 and int(_enemy(chilled_after).get("expose", 0)) == 3, "Retaliate is not direct damage: no Chilled bonus and no Expose use")

static func _test_retaliate_ignores_ranged(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine, Vector2i(5, 4)), "w3_fx_retaliate")
	var after: Dictionary = _enemy_strike(engine, state, {"type": "ranged", "damage": 3, "range": 4})
	expect.call(int(_player(after).get("hp", 0)) < 24 or int(_player(after).get("block", 0)) < 2, "The ranged fixture should hit the player")
	expect.call(int(_enemy(after).get("hp", 0)) == 20, "A ranged hit from distance should not trigger Retaliate")
	var adjacent: Dictionary = _play(engine, _state(engine), "w3_fx_retaliate")
	var adjacent_after: Dictionary = _enemy_strike(engine, adjacent, {"type": "ranged", "damage": 3, "range": 4})
	expect.call(int(_enemy(adjacent_after).get("hp", 0)) == 16, "Any attack made from an adjacent tile counts as melee for Retaliate")
	var shove: Dictionary = _enemy_strike(engine, adjacent, {"type": "push", "amount": 2, "damage": 2, "range": 1})
	expect.call(Vector2i(_player(shove).get("pos", PLAYER_TILE)) != PLAYER_TILE and int(_enemy(shove).get("hp", 0)) == 16, "An adjacent shove that knocks the player away still triggers Retaliate")
	var nudge: Dictionary = _enemy_strike(engine, adjacent, {"type": "push", "amount": 1, "damage": 0, "range": 1})
	expect.call(int(_enemy(nudge).get("hp", 0)) == 20, "A zero-damage shove does not trigger Retaliate")

static func _test_retaliate_stacking_and_riders(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine)
	state = _play(engine, state, "w3_fx_retaliate")
	state = _play(engine, state, "w3_fx_retaliate")
	expect.call(int((state["retaliate"] as Dictionary).get("amount", 0)) == 8, "Two Retaliate plays in one turn should add their amounts")
	var stacked: Dictionary = _enemy_strike(engine, state, _melee(3))
	expect.call(int(_enemy(stacked).get("hp", 0)) == 12, "Stacked Retaliate should deal the summed amount once per attack")
	var riders: Dictionary = _state(engine)
	riders = _play(engine, riders, "w3_fx_retaliate_riders")
	riders = _play(engine, riders, "w3_fx_retaliate_bleed")
	var totals: Dictionary = RetaliateRules.totals(riders, [])
	expect.call(int(totals["amount"]) == 3 and int(totals["bleed"]) == 3 and int(totals["shock"]) == 1 and int(totals["push"]) == 2, "Retaliate riders stack: amounts and Bleed add, Shock and Push take the maximum")
	var rider_after: Dictionary = _enemy_strike(engine, riders, _melee(2))
	var enemy: Dictionary = _enemy(rider_after)
	expect.call(int(enemy.get("hp", 0)) == 17, "Retaliate damage lands before its riders")
	expect.call(int(enemy.get("bleed", 0)) == 3 and int(enemy.get("shock", 0)) == 1, "Retaliate should apply Bleed and Shock to the attacker")
	expect.call(Vector2i(enemy.get("pos", Vector2i.ZERO)) == Vector2i(5, 4), "Retaliate Push should move the attacker 2 tiles away from the player through normal forced movement")

static func _test_retaliate_expiry(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_retaliate")
	var enemy_turn: Dictionary = engine.finish_player_activation(state)
	expect.call(enemy_turn.has("retaliate"), "Retaliate should last through the enemy activations after the player's turn")
	var next_turn: Dictionary = engine.prepare_next_player_turn(enemy_turn)
	expect.call(not next_turn.has("retaliate"), "Retaliate should clear at the start of the player's next turn")
	var after: Dictionary = _enemy_strike(engine, next_turn, _melee(3))
	expect.call(int(_enemy(after).get("hp", 0)) == 20, "Expired Retaliate should not damage an attacker")

static func _test_retaliate_kill_rewards(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine, ADJACENT_TILE, 3), "w3_fx_retaliate")
	var embers_before: int = int(state.get("room_embers", 0))
	var bonus_before: int = int(state.get("death_bonus_card_plays_this_turn", 0))
	var after: Dictionary = _enemy_strike(engine, state, _melee(3))
	expect.call(int(_enemy(after).get("hp", 0)) == 0, "Retaliate can defeat the attacker")
	expect.call(int(after.get("room_embers", 0)) == embers_before + int(GameData.enemy_def("crawler").get("reward_embers", 0)), "A Retaliate kill should still pay normal death rewards")
	expect.call(int(after.get("death_bonus_card_plays_this_turn", 0)) == bonus_before, "A Retaliate kill is not a card hit and grants no card play")
	var rewards: Array = after.get("death_rewards", []) as Array
	expect.call(not rewards.is_empty() and int((rewards[rewards.size() - 1] as Dictionary).get("card_plays", -1)) == 0, "The Retaliate death reward records zero card plays")

static func _test_retaliate_presentation_steps(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_retaliate_riders")
	state = engine.finish_player_activation(state)
	var enemies: Array = state["enemies"] as Array
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["intent"] = {"id": "w3_bite", "name": "Bite", "actions": [_melee(3)]}
	enemies[0] = enemy
	state["enemies"] = enemies
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, false)
	var attack_step: Dictionary = {}
	var retaliate_step: Dictionary = {}
	for step_var: Variant in result.get("steps", []):
		var step: Dictionary = step_var as Dictionary
		if str(step.get("kind", "")) == "melee":
			attack_step = step
		if str(step.get("label", "")) == "Retaliate":
			retaliate_step = step
	expect.call(not attack_step.is_empty() and Vector2i(attack_step.get("from", Vector2i.ZERO)) == ADJACENT_TILE, "The enemy strike animates from where it stood before Retaliate pushed it")
	expect.call(str(retaliate_step.get("kind", "")) == "status_damage" and not (retaliate_step.get("enemy_losses", []) as Array).is_empty(), "Retaliate should add a status_damage step carrying the attacker's losses for floating text")
	expect.call(retaliate_step.has("enemies_after") and int(((retaliate_step["enemies_after"] as Array)[0] as Dictionary).get("hp", 0)) == 18, "The Retaliate step should carry the attacker's after-state for animation")
	var push_only: Dictionary = _play(engine, _state(engine), "w3_fx_retaliate_push_only")
	var pushed: Dictionary = _enemy_strike(engine, push_only, _melee(3))
	var push_steps: Array[Dictionary] = RetaliateRules.presentation_steps(engine, push_only, pushed)
	expect.call(Vector2i(_enemy(pushed).get("pos", Vector2i.ZERO)) == Vector2i(5, 4) and int(_enemy(pushed).get("hp", 0)) == 20, "A zero-damage Retaliate still pushes the attacker")
	expect.call(push_steps.size() == 1 and str(push_steps[0].get("kind", "")) == "status" and Vector2i((push_steps[0].get("enemy_after", {}) as Dictionary).get("pos", Vector2i.ZERO)) == Vector2i(5, 4), "A rider-only Retaliate presents as a status step carrying the moved attacker")

# -------------------------------------------------------------------- Quicken

static func _test_quicken_next_card_only(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _state(engine)
	state = _play(engine, state, "w3_fx_quicken")
	expect.call(int(state.get("player_turn_time_spent", 0)) == 2, "A Quicken card never discounts itself")
	expect.call(TempoRules.quicken_pending(state) == 2, "Quicken should remain pending for the next card")
	var quickened: Dictionary = GameData.card_def_for_progression("w3_fx_slow_guard", state)
	expect.call(int(quickened.get("time", 0)) == 4 and int(quickened.get("_quicken_discount", 0)) == 2 and int(quickened.get("_time_discount_base", 0)) == 6, "Hand and turn-order card definitions should show the Quickened Time with a base stamp for the badge")
	expect.call(engine.card_time_cost("w3_fx_slow_guard", state) == 4, "The next card's Time cost is reduced by Quicken")
	state = _play(engine, state, "w3_fx_slow_guard")
	expect.call(int(state.get("player_turn_time_spent", 0)) == 6, "The next card pays the Quickened cost")
	expect.call(TempoRules.quicken_pending(state) == 0 and engine.card_time_cost("w3_fx_slow_guard", state) == 6, "Quicken discounts only the next card")
	expect.call(int(TempoRules.analytics_fields(state, "w3_fx_slow_guard").get("quicken_spent", 0)) == 2, "card_played analytics should report the Time removed by Quicken")
	var first: Dictionary = _play(engine, _state(engine), "w3_fx_quicken_first")
	expect.call(int(first.get("player_turn_time_spent", 0)) == 3 and TempoRules.quicken_pending(first) == 2, "Quicken as a card's first action still never discounts that card")
	var scheduled: Dictionary = engine.finish_player_activation(_play(engine, _play(engine, _state(engine), "w3_fx_quicken"), "w3_fx_slow_guard"))
	var player_time: int = -1
	for entry_var: Variant in scheduled.get("turn_queue", []):
		if str((entry_var as Dictionary).get("kind", "")) == "player":
			player_time = int((entry_var as Dictionary).get("time", -1))
	expect.call(player_time == int(scheduled.get("initiative_clock", 0)) + engine.player_base_initiative(scheduled) + 6, "The turn order schedules the player with the Quickened Time")

static func _test_quicken_stacks_min_and_expiry(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_quicken_double")
	expect.call(TempoRules.quicken_pending(state) == 3, "Several Quickens add up")
	expect.call(engine.card_time_cost("w3_fx_slow_guard", state) == 3, "Stacked Quicken reduces the next card by the sum")
	var big: Dictionary = _play(engine, _state(engine), "w3_fx_quicken_big")
	expect.call(engine.card_time_cost("w3_fx_cheap_guard", big) == 1, "Quicken cannot reduce a card below 1 Time")
	var chained: Dictionary = _play(engine, _play(engine, _state(engine), "w3_fx_quicken"), "w3_fx_quicken")
	expect.call(int(chained.get("player_turn_time_spent", 0)) == 3 and TempoRules.quicken_pending(chained) == 2, "A second Quicken card is discounted by the first and leaves only its own Quicken pending")
	var ended: Dictionary = engine.finish_player_activation(state)
	expect.call(TempoRules.quicken_pending(ended) == 0, "Unused Quicken expires at the end of the activation")
	var next_turn: Dictionary = engine.prepare_next_player_turn(ended)
	expect.call(engine.card_time_cost("w3_fx_slow_guard", next_turn) == 6, "Expired Quicken does not reach the next turn")

# ---------------------------------------------------------- Next-attack buffs

static func _test_next_attack_consumption(engine: CombatEngine, expect: Callable) -> void:
	var strike: Dictionary = (engine.card_play_actions("w3_fx_strike", {}) as Array)[0] as Dictionary
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_buff")
	expect.call(TempoRules.next_attack_buffs(state).size() == 1, "A next-attack buff should wait in turn_flags")
	expect.call(engine.final_damage_for_player_action(state, strike) == 6, "Preview and final damage include the pending next-attack bonus")
	var modifiers: Array[Dictionary] = engine.damage_modifiers_for_player_action(state, strike)
	expect.call(modifiers.any(func(entry: Dictionary) -> bool: return str(entry.get("kind", "")) == "next_attack" and int(entry.get("amount", 0)) == 3), "Damage modifiers should explain the next-attack bonus for the hand display")
	var cheap: Dictionary = _play(engine, state, "w3_fx_cheap_guard")
	expect.call(TempoRules.next_attack_buffs(cheap).size() == 1, "A non-attack card does not spend the buff")
	var struck: Dictionary = _play(engine, cheap, "w3_fx_strike", ADJACENT_TILE)
	expect.call(int(_enemy(struck).get("hp", 0)) == 14, "The next attack deals the extra damage")
	expect.call(TempoRules.next_attack_buffs(struck).is_empty() and engine.final_damage_for_player_action(struck, strike) == 3, "The buff is consumed by that attack only")
	var used: Dictionary = TempoRules.analytics_fields(struck, "w3_fx_strike")
	expect.call(typeof(used.get("next_attack_bonus_used", null)) == TYPE_DICTIONARY and int((used["next_attack_bonus_used"] as Dictionary).get("damage", 0)) == 3, "card_played analytics should report the consumed next-attack bonus")
	var same_card: Dictionary = _play(engine, _state(engine), "w3_fx_buff_then_strike", ADJACENT_TILE)
	expect.call(int(_enemy(same_card).get("hp", 0)) == 17 and TempoRules.next_attack_buffs(same_card).size() == 1, "A buff never applies to an attack on the card that granted it")
	var ended: Dictionary = engine.finish_player_activation(state)
	expect.call(TempoRules.next_attack_buffs(ended).is_empty(), "Unused next-attack buffs expire at the end of the activation")

static func _test_next_attack_element_and_pierce(engine: CombatEngine, expect: Callable) -> void:
	var bolt: Dictionary = (engine.card_play_actions("w3_fx_bolt", {}) as Array)[0] as Dictionary
	var shot: Dictionary = (engine.card_play_actions("w3_fx_shot", {}) as Array)[0] as Dictionary
	var state: Dictionary = _play(engine, _state(engine, Vector2i(5, 4)), "w3_fx_lightning_chain")
	expect.call(int(engine._resolved_surface_action(state, shot).get("chain", 0)) == 0, "An element-limited buff ignores attacks of other elements")
	expect.call(int(engine._resolved_surface_action(state, bolt).get("chain", 0)) == 2, "A Lightning attack gains the buffed Chain")
	var after_shot: Dictionary = _play(engine, state, "w3_fx_shot", Vector2i(5, 4))
	expect.call(TempoRules.next_attack_buffs(after_shot).size() == 1, "A non-matching attack does not consume the element buff")
	var after_bolt: Dictionary = _play(engine, after_shot, "w3_fx_bolt", Vector2i(5, 4))
	expect.call(TempoRules.next_attack_buffs(after_bolt).is_empty(), "The matching Lightning attack consumes the buff")
	var pierce: Dictionary = _play(engine, _state(engine, ADJACENT_TILE, 20, 5), "w3_fx_pierce")
	pierce = _play(engine, pierce, "w3_fx_buff")
	var strike: Dictionary = (engine.card_play_actions("w3_fx_strike", {}) as Array)[0] as Dictionary
	var resolved: Dictionary = engine._resolved_surface_action(pierce, strike)
	expect.call(bool(resolved.get("pierce", false)) and int(resolved.get("damage", 0)) == 10, "Several buffs stack additively and Pierce is granted")
	var pierced: Dictionary = _play(engine, pierce, "w3_fx_strike", ADJACENT_TILE)
	expect.call(int(_enemy(pierced).get("hp", 0)) == 10 and int(_enemy(pierced).get("block", 0)) == 5, "A Pierce buff deals damage straight through Block")

static func _test_next_attack_per_tile_moved(engine: CombatEngine, expect: Callable) -> void:
	var strike: Dictionary = (engine.card_play_actions("w3_fx_strike", {}) as Array)[0] as Dictionary
	var state: Dictionary = _play(engine, _state(engine, Vector2i(6, 5)), "w3_fx_headlong", Vector2i(5, 4))
	expect.call(TempoRules.tiles_moved(state) == 3, "Card movement counts tiles moved this activation")
	expect.call(engine.final_damage_for_player_action(state, strike) == 6, "per_tile_moved adds 1 damage per tile moved")
	var pool_action: Dictionary = engine.player_movement_action(state)
	if not pool_action.is_empty():
		var walked: Dictionary = engine.apply_player_action(state, pool_action, Vector2i(5, 6))
		expect.call(TempoRules.tiles_moved(walked) == 5 and engine.final_damage_for_player_action(walked, strike) == 7, "Independent movement also counts, capped at the buff maximum")
	var flags: Dictionary = (state["turn_flags"] as Dictionary).duplicate(true)
	flags[TempoRules.TILES_MOVED_KEY] = 9
	state["turn_flags"] = flags
	expect.call(engine.final_damage_for_player_action(state, strike) == 7, "per_tile_moved respects its maximum")

static func _test_next_attack_skips_forced_movement(engine: CombatEngine, expect: Callable) -> void:
	var buffed: Dictionary = _play(engine, _state(engine, Vector2i(4, 4)), "w3_fx_buff")
	var preview_actions: Array = engine.card_play_actions("w3_fx_sleet", buffed)
	var push: Dictionary = preview_actions[0] as Dictionary
	var push_modifiers: Array[Dictionary] = engine.damage_modifiers_for_player_action(buffed, push)
	expect.call(engine.final_damage_for_player_action(buffed, push) == 0 and not push_modifiers.any(func(entry: Dictionary) -> bool: return str(entry.get("kind", "")) == "next_attack"), "A zero-damage push neither previews nor lists the pending next-attack bonus")
	expect.call(engine.final_damage_for_player_action(buffed, preview_actions[1] as Dictionary) == 6, "The card's later Ice hit previews the bonus")
	# Resolve Sleet Squall one action at a time, like a committed hand play.
	var working: Dictionary = buffed.duplicate(true)
	var deck: Dictionary = working["deck"] as Dictionary
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	hand.push_front("w3_fx_sleet")
	deck["hand"] = hand
	working["deck"] = deck
	working = engine.prepare_player_card(working, 0, "play")
	var actions: Array = engine.card_play_actions("w3_fx_sleet", working)
	working = engine.apply_player_action(working, actions[0] as Dictionary, Vector2i(4, 4))
	expect.call(_enemy(working).get("pos", Vector2i.ZERO) == Vector2i(6, 4) and int(_enemy(working).get("hp", 0)) == 20, "The zero-damage push moves the enemy without dealing the next-attack bonus")
	expect.call(TempoRules.next_attack_buffs(working).size() == 1, "The zero-damage push does not spend the next-attack buff")
	var hit: Dictionary = actions[1] as Dictionary
	working = engine.apply_player_action(working, hit, Vector2i(4, 4) if engine.player_action_needs_target(hit) else NO_TARGET)
	var sleet: Dictionary = engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})
	expect.call(int(_enemy(sleet).get("hp", 0)) == 14 and TempoRules.next_attack_buffs(sleet).is_empty(), "The buff carries to the card's Ice hit (3 + 3) and is spent there")
	var used: Variant = TempoRules.analytics_fields(sleet, "w3_fx_sleet").get("next_attack_bonus_used", null)
	expect.call(typeof(used) == TYPE_DICTIONARY and str((used as Dictionary).get("action_type", "")) == "ranged", "card_played analytics attribute the bonus to the Ice hit, not the push")
	# A push-only card leaves the buff for the next card's attack.
	var pushed: Dictionary = _play(engine, _play(engine, _state(engine), "w3_fx_buff"), "w3_fx_push", ADJACENT_TILE)
	expect.call(int(_enemy(pushed).get("hp", 0)) == 20 and TempoRules.next_attack_buffs(pushed).size() == 1, "A zero-damage push card leaves the buff pending")
	var shot: Dictionary = _play(engine, pushed, "w3_fx_shot", _enemy(pushed).get("pos", Vector2i.ZERO))
	expect.call(int(_enemy(shot).get("hp", 0)) == 15 and TempoRules.next_attack_buffs(shot).is_empty(), "The next card's attack receives and spends the carried buff")
	# The hand row keeps the bonus on the Ice hit rather than the push.
	var scene: Node = RunSceneScript.new()
	var display: Dictionary = scene.call("_card_widget_display", "w3_fx_sleet", buffed)
	var ranged_token: Dictionary = _token_with_icon(display.get("summary_rows", []) as Array, "ranged")
	expect.call(int(ranged_token.get("value", 0)) == 6 and str(ranged_token.get("tone", "")) == "bonus", "The hand display shows the next-attack bonus on the Ice hit")
	scene.free()

# ---------------------------------------------------------------------- Rites

static func _test_rite_fire(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_pyre")
	expect.call(RiteRules.active_rites(state).size() == 1 and ((state["deck"] as Dictionary).get("burned", []) as Array).has("w3_fx_rite_pyre"), "Playing a Rite Exhausts it and starts it for this combat")
	expect.call(str(TempoRules.analytics_fields(state, "w3_fx_rite_pyre").get("rite_started", "")) == "w3_fx_rite_pyre", "card_played analytics should report the started Rite")
	Surface.place(state, ADJACENT_TILE, "fire", {"actor_kind": "player"})
	var start_hit: Dictionary = engine._surface_contact(state.duplicate(true), "enemy", 1, CombatEngine.INVALID_TILE, true)
	expect.call(int(_enemy(start_hit).get("hp", 0)) == 15, "Rite of the Pyre: Fire turn-start damage deals 2 more (3 + 2)")
	var entry_hit: Dictionary = engine._surface_contact(state.duplicate(true), "enemy", 1, Vector2i(4, 4), false)
	expect.call(int(_enemy(entry_hit).get("hp", 0)) == 16, "Rite of the Pyre: Fire entry damage deals 2 more (2 + 2)")
	Surface.place(state, PLAYER_TILE, "fire", {"actor_kind": "player"})
	var player_hit: Dictionary = engine._surface_contact(state.duplicate(true), "player", -1, CombatEngine.INVALID_TILE, true)
	expect.call(int(_player(player_hit).get("hp", 0)) == 19, "The Fire bonus applies to everyone the Fire hits, including the player")
	var salamander: Dictionary = _play(engine, _state(engine), "w3_fx_rite_salamander")
	Surface.place(salamander, PLAYER_TILE, "fire", {"actor_kind": "enemy"})
	var immune: Dictionary = engine._surface_contact(salamander.duplicate(true), "player", -1, CombatEngine.INVALID_TILE, true)
	expect.call(int(_player(immune).get("hp", 0)) == 24, "Salamander Heart: the player takes no Fire tile damage")
	var hand_before: int = ((salamander["deck"] as Dictionary).get("hand", []) as Array).size()
	var next_turn: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(salamander))
	expect.call(int(_player(next_turn).get("hp", 0)) == 24 and int(_player(next_turn).get("stoneskin", 0)) == 3, "Turn start on Fire grants 3 Stoneskin without Fire damage")
	expect.call(((next_turn["deck"] as Dictionary).get("hand", []) as Array).size() == hand_before + int(next_turn.get("draw_per_turn", 0)) + 1, "Turn start on Fire also draws 1 extra card")

static func _test_rite_freeze_reward(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_hoarfrost")
	Surface.place(state, ADJACENT_TILE, "ice", {"actor_kind": "player"})
	state["enemies"][0]["chilled"] = true
	var hand_before: int = ((state["deck"] as Dictionary).get("hand", []) as Array).size()
	var block_before: int = int(_player(state).get("block", 0))
	var after: Dictionary = _play(engine, state, "w3_fx_ice_strike", ADJACENT_TILE)
	expect.call(int(_enemy(after).get("freeze", 0)) > 0, "The Ice hit should Freeze the Chilled enemy")
	expect.call(int(_player(after).get("block", 0)) == block_before + 3, "Rite of Hoarfrost: freezing an enemy grants 3 Block")
	expect.call(((after["deck"] as Dictionary).get("hand", []) as Array).size() == hand_before + 1, "Rite of Hoarfrost: freezing an enemy draws 1")

static func _test_rite_turn_start_effects(engine: CombatEngine, expect: Callable) -> void:
	var storm: Dictionary = _play(engine, _state(engine, Vector2i(5, 4)), "w3_fx_rite_storm")
	Surface.place(storm, Vector2i(5, 4), "electrified", {"actor_kind": "player"})
	var pulsed: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(storm))
	expect.call(int(_enemy(pulsed).get("hp", 0)) == 18, "Rite of the Storm: each enemy on Electrified takes 2 at the start of the player's turn")
	var pulsed_again: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(pulsed))
	expect.call(int(_enemy(pulsed_again).get("hp", 0)) == 16, "Rite pulses repeat every player turn for the rest of combat")
	var mountain: Dictionary = _play(engine, _state(engine), "w3_fx_rite_mountain")
	var skin: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(mountain))
	expect.call(int(_player(skin).get("stoneskin", 0)) == 3, "Rite of the Mountain: gain 3 Stoneskin at the start of each turn")

static func _test_rite_time_discount(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_tempest")
	expect.call(int(state.get("player_turn_time_spent", 0)) == 6, "A Rite pays its own full Time before it begins")
	expect.call(engine.card_time_cost("w3_fx_slow_guard", state) == 5 and engine.card_time_cost("w3_fx_cheap_guard", state) == 1, "Tempest Form: every card costs 1 less Time, minimum 1")
	var def: Dictionary = GameData.card_def_for_progression("w3_fx_slow_guard", state)
	expect.call(int(def.get("_rite_time_discount", 0)) == 1, "The Rite discount is stamped for the Time badge")
	state = _play(engine, state, "w3_fx_quicken")
	expect.call(engine.card_time_cost("w3_fx_slow_guard", state) == 3, "Quicken and the Rite discount combine")

static func _test_rite_tailwinds(engine: CombatEngine, expect: Callable) -> void:
	var base: Dictionary = _state(engine)
	var capacity_before: int = engine.player_movement_capacity(base)
	var state: Dictionary = _play(engine, base, "w3_fx_rite_tailwinds")
	expect.call(engine.player_movement_capacity(state) == capacity_before + 1, "Rite of Tailwinds: +1 independent movement")
	var next_turn: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(state))
	expect.call(engine.player_movement_remaining(next_turn) == capacity_before + 1, "The extra movement is available each player turn")
	var push: Dictionary = (engine.card_play_actions("w3_fx_push", state) as Array)[0] as Dictionary
	expect.call(int(push.get("amount", 0)) == 2, "Standalone Push moves 1 tile farther for any element")
	var melee_push: Dictionary = (engine.card_play_actions("w3_fx_melee_push", state) as Array)[0] as Dictionary
	expect.call(int(melee_push.get("push", 0)) == 2, "Push keyword riders move 1 tile farther")
	var modifiers: Array = ((push.get("_modifiers", {}) as Dictionary).get("amount", []) as Array)
	expect.call(not modifiers.is_empty() and str((modifiers[0] as Dictionary).get("source", "")) == "Rite Tailwinds", "The forced-movement modifier is attributed to the Rite card name")

static func _test_rite_noon(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_noon")
	expect.call(engine._light_source_covers_tile(state, PLAYER_TILE + Vector2i(2, 0)) and not engine._light_source_covers_tile(state, PLAYER_TILE + Vector2i(3, 0)), "Rite of Noon: the player radiates radius-2 Light")
	expect.call(engine.effective_light_sources(state).any(func(source: Dictionary) -> bool: return str(source.get("id", "")) == "player_aura"), "The player aura is a presented light source")
	var struck: Dictionary = _play(engine, state, "w3_fx_strike", ADJACENT_TILE)
	expect.call(int(_enemy(struck).get("hp", 0)) == 15, "Attacks against enemies in Light deal 2 more")

static func _test_thorns_stack_with_retaliate(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_thorns")
	expect.call(int(_player(state).get("hp", 0)) == 22, "A Rite with a health cost pays it as usual")
	var thorns_only: Dictionary = _enemy_strike(engine, state, _melee(3))
	expect.call(int(_enemy(thorns_only).get("hp", 0)) == 17 and int(_enemy(thorns_only).get("bleed", 0)) == 1, "Thorns: enemies that hit you in melee take 3 and Bleed 1")
	var next_turn: Dictionary = engine.prepare_next_player_turn(engine.finish_player_activation(state))
	var persists: Dictionary = _enemy_strike(engine, next_turn, _melee(3))
	expect.call(int(_enemy(persists).get("hp", 0)) == 17, "Thorns lasts for the rest of combat")
	var stacked: Dictionary = _play(engine, next_turn, "w3_fx_retaliate")
	var stacked_after: Dictionary = _enemy_strike(engine, stacked, _melee(3))
	expect.call(int(_enemy(stacked_after).get("hp", 0)) == 13 and int(_enemy(stacked_after).get("bleed", 0)) == 1, "Thorns stacks with Retaliate (3 + 4)")
	var badges: Array[Dictionary] = RetaliateRules.player_badges(stacked, RiteRules.effects(stacked))
	expect.call(badges.size() == 1 and str(badges[0].get("icon", "")) == "retaliate" and int(badges[0].get("count", 0)) == 7 and str(badges[0].get("tooltip", "")).contains("Bleed 1"), "The player badge shows the combined Retaliate amount and lists riders")

static func _test_rites_are_combat_scoped(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_tempest")
	expect.call(engine._relic_effects(state).any(func(effect: Dictionary) -> bool: return str(effect.get("relic_id", "")).begins_with("rite:w3_fx_rite_tempest:")), "Active Rite effects join relic evaluation with a unique rite relic_id")
	expect.call(engine._relic_effect_source_name(engine._relic_effects(state)[0]) == "Rite Tempest", "Rite effects name their source card")
	var next_combat: Dictionary = _state(engine)
	expect.call(RiteRules.active_rites(next_combat).is_empty() and engine._relic_effects(next_combat).is_empty(), "Rites never reach the next combat")
	expect.call(engine.card_time_cost("w3_fx_slow_guard", next_combat) == 6, "A previous combat's Rite no longer discounts cards")

static func _test_rites_visible_to_relic_rule_readers(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_rite_relic_probe")
	expect.call(SurfaceRelicRules.has_effect(state, "conductive_fire"), "SurfaceRelicRules sees Rite effects")
	expect.call(GuardianRelicRules.amount(state, "chain_hop_damage") == 50, "GuardianRelicRules sees Rite effects")
	expect.call(GameData.relic_effects_for_state(state).size() == 2, "GameData.relic_effects_for_state merges relics and Rites")

static func _test_presentation_contracts(engine: CombatEngine, expect: Callable) -> void:
	var retaliate_row: Array = ActionIcons.tokens_for_action({"type": "retaliate", "amount": 3, "bleed": 1})
	expect.call(not retaliate_row.is_empty() and str((retaliate_row[0] as Dictionary).get("icon", "")) == "retaliate", "Retaliate renders with its own icon")
	var quicken_row: Array = ActionIcons.tokens_for_action({"type": "quicken", "amount": 2})
	expect.call(not quicken_row.is_empty() and str((quicken_row[0] as Dictionary).get("icon", "")) == "quicken", "Quicken renders with its own icon")
	var next_row: Array = ActionIcons.tokens_for_action({"type": "next_attack", "element": "lightning", "chain": 1})
	expect.call(next_row.size() >= 2 and str((next_row[0] as Dictionary).get("icon", "")) == "next_attack", "Next-attack buffs render their bonus and element")
	for key: String in ["retaliate", "quicken", "rite", "next_attack"]:
		expect.call(ActionIcons.icon_texture(key) != null, "%s keyword icon should load" % key)
		expect.call(ActionIcons.action_icon_key({"type": key}) == key, "%s action type resolves through ACTION_ICON_ALIASES" % key)
	# Setup riders take a watermark only when the card has no primary role.
	for role_pair: Array in [["w3_fx_pierce", "attack_melee"], ["w3_fx_buff", "block"], ["w3_fx_headlong", "mobility"], ["w3_fx_quicken", "mobility"], ["w3_fx_retaliate_riders", "block"]]:
		expect.call(ActionIcons.card_role_emblem_key(GameData.card_def(str(role_pair[0]))) == str(role_pair[1]), "%s uses the %s role emblem" % [str(role_pair[0]), str(role_pair[1])])
	var thorn_card: Dictionary = GameData.card_def("w3_fx_rite_thorns")
	var thorn_rows: Array = ActionIcons.rows_for_card(thorn_card)
	var thorn_cost_row: Array = thorn_rows[0] as Array if not thorn_rows.is_empty() else []
	expect.call(thorn_rows.size() == 2 and thorn_cost_row.size() == 2 and str((thorn_cost_row[0] as Dictionary).get("icon", "")) == "rite" and str((thorn_cost_row[1] as Dictionary).get("icon", "")) == "health_cost" and str((thorn_cost_row[1] as Dictionary).get("value", "")) == "-2", "A Rite card leads with a labelled Rite keyword row and its health cost")
	expect.call(ActionIcons.token_tooltip(thorn_cost_row[0] as Dictionary if not thorn_cost_row.is_empty() else {}).contains("Rite: Exhaust. Lasts for the rest of this combat."), "The Rite keyword token explains Exhaust and duration")
	var thorn_text: Dictionary = (thorn_rows[1] as Array)[0] as Dictionary if thorn_rows.size() > 1 else {}
	expect.call(str(thorn_text.get("kind", "")) == "rules_text" and str(thorn_text.get("value", "")) == "Enemies that hit you in melee take 3 and Bleed 1.", "The Rite's rules text follows its keyword row without repeating Rite or the cost")
	expect.call(ActionIcons.tooltip_entries_for_rows(thorn_rows, ["rite"]).size() == 2, "Rite focus tooltips list Rite once plus the health cost")
	expect.call(ActionIcons.card_rules_text(thorn_card).ends_with("Health cost 2."), "Rite rules text keeps the health cost")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(thorn_card).has("keyword:rite"), "Rite cards unlock the Rite grimoire entry")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w3_fx_retaliate_riders")).has("keyword:retaliate"), "Retaliate cards unlock the Retaliate grimoire entry")
	expect.call(GrimoireLibrary.entry_ids_for_card_def(GameData.card_def("w3_fx_quicken")).has("keyword:quicken"), "Quicken cards unlock the Quicken grimoire entry")
	var state: Dictionary = _play(engine, _state(engine), "w3_fx_buff")
	state = _play(engine, state, "w3_fx_quicken")
	var badges: Array[Dictionary] = TempoRules.player_badges(state)
	expect.call(badges.size() == 2 and str(badges[0].get("icon", "")) == "quicken" and str(badges[1].get("icon", "")) == "next_attack", "Pending Quicken and next-attack buffs show player badges")
	var hud: Array[Dictionary] = RiteRules.hud_entries(_play(engine, _state(engine), "w3_fx_rite_pyre"))
	expect.call(hud.size() == 1 and str(hud[0].get("icon", "")) == "rite" and str(hud[0].get("tooltip", "")).contains("Fire tiles deal 2 more"), "Active Rites expose HUD entries with the card name and rules text")
	var playable_actions: Array = engine.card_play_actions("w3_fx_rite_pyre", _state(engine))
	expect.call(playable_actions.size() == 1 and str((playable_actions[0] as Dictionary).get("type", "")) == "rite" and not engine.player_action_needs_target(playable_actions[0] as Dictionary), "A Rite card resolves as one targetless step so it is playable")

static func _token_with_icon(rows: Array, icon: String) -> Dictionary:
	for row_var: Variant in rows:
		for token_var: Variant in row_var as Array:
			if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("icon", "")) == icon:
				return token_var as Dictionary
	return {}

static func _test_run_scene_hand_display(engine: CombatEngine, expect: Callable) -> void:
	var scene: Node = RunSceneScript.new()
	var buffed: Dictionary = _play(engine, _play(engine, _state(engine), "w3_fx_buff"), "w3_fx_lightning_chain")
	var strike_display: Dictionary = scene.call("_card_widget_display", "w3_fx_strike", buffed)
	var melee_token: Dictionary = _token_with_icon(strike_display.get("summary_rows", []) as Array, "melee")
	expect.call(int(melee_token.get("value", 0)) == 6 and str(melee_token.get("tone", "")) == "bonus", "The hand row shows the pending next-attack damage as a bonus")
	var bolt_display: Dictionary = scene.call("_card_widget_display", "w3_fx_bolt", buffed)
	var chain_token: Dictionary = _token_with_icon(bolt_display.get("summary_rows", []) as Array, "chain")
	expect.call(int(chain_token.get("value", 0)) == 2 and ActionIcons.token_is_modified(chain_token), "The hand row shows Chain granted by a pending Lightning buff")
	var rite_display: Dictionary = scene.call("_card_widget_display", "w3_fx_rite_thorns", _state(engine))
	var rite_rows: Array = rite_display.get("summary_rows", []) as Array
	expect.call(not _token_with_icon(rite_rows, "rite").is_empty() and str(_token_with_icon(rite_rows, "health_cost").get("value", "")) == "-2" and rite_rows.size() == 2 and str(((rite_rows[1] as Array)[0] as Dictionary).get("value", "")).begins_with("Enemies that hit you"), "A Rite card in hand shows its Rite keyword and health cost, then its rules text")
	var retaliate_display: Dictionary = scene.call("_card_widget_display", "w3_fx_retaliate_riders", _state(engine))
	expect.call(not _token_with_icon(retaliate_display.get("summary_rows", []) as Array, "retaliate").is_empty(), "A Retaliate card in hand shows the Retaliate token")
	scene.free()
