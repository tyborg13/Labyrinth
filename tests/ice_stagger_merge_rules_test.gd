extends SceneTree
## pla-06 rules: Freeze, Chilled and Petrify are cut. Ice ground Exposes 2 a
## unit (hero, enemy, illusion) that enters it or starts its turn on it; the
## next damage spends it. Former Freeze cards say "On Ice: also Stagger 6"
## (dragons take half); Petrify is "Stagger 6"; enemy Frost Armor is boss-only.
## Run:
##   python3 tools/godot_task_runner.py --task-id pla-06 --stream -- \
##     godot --headless --path . --script res://tests/ice_stagger_merge_rules_test.gd

const CombatEngine = preload("res://scripts/combat_engine.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Battlefield = preload("res://scripts/battlefield_rules/dispatcher.gd")
const CardKeywords = preload("res://scripts/card_keyword_rules.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const GameData = preload("res://scripts/game_data.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const PassForecast = preload("res://scripts/pass_forecast_red_tiles.gd")

const PLAYER := Vector2i(3, 4)
const NO_TARGET := Vector2i(-1, -1)
const HP: int = 30
const HERO_HP: int = 40
const STAGGER_RIDER_ID: String = "rime_bolt"
const PARTIAL_STAGGER: int = 4
const CUT_WORDS := "(?i)\\b(freez\\w*|frozen|chill(ed|s|ing)?|petrif\\w*)\\b"

var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := CombatEngine.new()
	_test_hero_ice(engine)
	_test_enemy_ice(engine)
	_test_illusion_ice(engine)
	_test_expose_spent(engine)
	_test_expose_analytics(engine)
	_test_enemy_area_hits(engine)
	_test_opening_and_spawn_contact(engine)
	_test_limited_umbra_move_preview(engine)
	_test_former_freeze_cards(engine)
	_test_shatter_has_no_stagger(engine)
	_test_hush_white_silence_rite(engine)
	_test_petrify_staggers(engine)
	_test_legacy_statuses_removed(engine)
	_test_saved_ice_intents(engine)
	_test_frost_armor_boss_only(engine)
	_test_player_frost_armor(engine)
	_test_enemy_ice_riders(engine)
	_test_hero_stagger_cap(engine)
	_test_no_cut_status_in_data()
	for failure: String in _failures:
		push_error(failure)
	print("ICE STAGGER MERGE RULES: %d checks, %d failures" % [_checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

# ------------------------------------------------------------------ fixtures

func _grid() -> Array:
	var grid: Array = []
	for y: int in range(10):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 9 else "stone")
		grid.append(row)
	return grid

func _enemy(id: int, pos: Vector2i, type: String = "crawler", hp: int = HP) -> Dictionary:
	return {"id": id, "type": type, "pos": pos, "hp": hp, "max_hp": maxi(hp, HP), "block": 0, "stoneskin": 0, "intent": {}}

func _state(engine: CombatEngine, enemies: Array, player_pos: Vector2i = PLAYER, relics: Array = []) -> Dictionary:
	var layout: Dictionary = {
		"name": "Ice proof", "type": "combat", "coord": Vector2i(1, 1), "depth": 1,
		"element": "none", "umbra_stage": "clear", "grid": _grid(),
		"player_start": player_pos, "terrain": [], "traps": [], "loot": [],
		"enemies": [_enemy(99, Vector2i(9, 8))],
	}
	var state: Dictionary = engine.create_combat(40617, layout, {"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": ["brace", "brace", "brace", "brace", "brace", "brace", "brace", "brace"], "hand_size": 1, "relics": relics, "cards_per_turn": 8})
	state["player"] = {"pos": player_pos, "hp": HERO_HP, "max_hp": HERO_HP, "block": 0, "stoneskin": 0}
	state["enemies"] = enemies.duplicate(true)
	state["terrain"] = []
	state["traps"] = []
	state["loot"] = []
	state["illusions"] = []
	state["surfaces"] = {}
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["player_turn_restrictions"] = {}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	var queue: Array = []
	for enemy_var: Variant in enemies:
		var enemy: Dictionary = enemy_var as Dictionary
		queue.append({"kind": "enemy", "enemy_id": int(enemy["id"]), "actor_key": "enemy:%d" % int(enemy["id"]), "type": str(enemy["type"]), "team": "enemy", "time": 20, "seq": int(enemy["id"])})
	state["turn_queue"] = queue
	(state["deck"] as Dictionary)["hand"] = []
	(state["deck"] as Dictionary)["draw"] = ["brace", "brace", "brace"]
	return state

## Every action of a production card like a committed hand play.
func _play(engine: CombatEngine, state: Dictionary, card_id: String, targets: Array = []) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var hand: Array = ((next_state["deck"] as Dictionary).get("hand", []) as Array).duplicate()
	hand.push_front(card_id)
	(next_state["deck"] as Dictionary)["hand"] = hand
	var working: Dictionary = engine.prepare_player_card(next_state, 0, "play")
	var actions: Array = engine.card_play_actions(card_id, working)
	var cursor: int = 0
	for action_var: Variant in actions:
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		var tile: Vector2i = NO_TARGET
		if engine.player_action_needs_target(action):
			tile = targets[cursor] if cursor < targets.size() else NO_TARGET
			cursor += 1
		working = engine.apply_player_action(working, action, tile)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})

func _targets(engine: CombatEngine, state: Dictionary, card_id: String, index: int = 0) -> Array[Vector2i]:
	var actions: Array = engine.card_play_actions(card_id, state)
	return engine.valid_targets_for_player_action(state, (actions[index] as Dictionary).duplicate(true))

func _unit(state: Dictionary, id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return enemy
	return {}

func _index(state: Dictionary, id: int) -> int:
	var enemies: Array = state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		if int((enemies[index] as Dictionary).get("id", -1)) == id:
			return index
	return -1

func _hp(state: Dictionary, id: int) -> int:
	return int(_unit(state, id).get("hp", -1))

func _expose(state: Dictionary, id: int) -> int:
	return int(_unit(state, id).get("expose", 0))

func _stagger(engine: CombatEngine, before: Dictionary, after: Dictionary, id: int) -> int:
	return int(engine.stagger_delays_between(before, after).get(id, 0))

func _paint(state: Dictionary, tiles: Array, surface: String) -> void:
	for tile_var: Variant in tiles:
		Surface.place(state, tile_var as Vector2i, surface, {"actor_kind": "test"})

func _hand_size(state: Dictionary) -> int:
	return ((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

# ------------------------------------------------------------------ Ice ground

func _test_hero_ice(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))])
	_paint(state, [Vector2i(5, 4)], "ice")
	var moved: Dictionary = engine.apply_player_action(state, {"type": "move", "range": 3}, Vector2i(5, 4))
	var hero: Dictionary = moved.get("player", {}) as Dictionary
	_expect(hero.get("pos", NO_TARGET) == Vector2i(5, 4), "The hero moves onto the Ice tile")
	_expect(int(hero.get("expose", 0)) == 2, "The hero entering Ice gets Expose 2 (got %d)" % int(hero.get("expose", 0)))
	_expect(not bool(hero.get("chilled", false)), "Entering Ice never Chills the hero")
	# Starting a turn on Ice Exposes 2 as well.
	var start: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))])
	_paint(start, [PLAYER], "ice")
	var started: Dictionary = engine._resolve_player_start_of_turn(start)
	_expect(int((started["player"] as Dictionary).get("expose", 0)) == 2, "The hero starting its turn on Ice gets Expose 2")
	# Expose 2 does not stack past 2 from more Ice.
	var again: Dictionary = engine._resolve_player_start_of_turn(started)
	_expect(int((again["player"] as Dictionary).get("expose", 0)) == 2, "Ice Expose is 2, not more, on a second turn start")
	# Skate: this turn Ice doesn't Expose you.
	var skate: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))])
	_paint(skate, [Vector2i(5, 4), Vector2i(6, 4)], "ice")
	var skated: Dictionary = _play(engine, skate, "skate", [Vector2i(6, 4)])
	_expect((skated["player"] as Dictionary).get("pos", NO_TARGET) == Vector2i(6, 4), "Skate moves across the Ice")
	_expect(int((skated["player"] as Dictionary).get("expose", 0)) == 0, "Skate: Ice doesn't Expose you")
	# Hobnail Cleats: Ice doesn't Expose you.
	var cleats: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))], PLAYER, ["hobnail_cleats"])
	_paint(cleats, [Vector2i(5, 4)], "ice")
	var cleated: Dictionary = engine.apply_player_action(cleats, {"type": "move", "range": 3}, Vector2i(5, 4))
	_expect(int((cleated["player"] as Dictionary).get("expose", 0)) == 0, "Hobnail Cleats: Ice doesn't Expose you")

func _test_enemy_ice(engine: CombatEngine) -> void:
	# Cold Shoulder pushes an enemy onto Ice: entering Exposes it.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	_paint(state, [Vector2i(6, 4)], "ice")
	var pushed: Dictionary = _play(engine, state, "cold_shoulder", [Vector2i(4, 4)])
	_expect(_unit(pushed, 1).get("pos", NO_TARGET) == Vector2i(6, 4), "Cold Shoulder pushes the enemy onto the Ice")
	_expect(_expose(pushed, 1) == 2, "An enemy entering Ice gets Expose 2 (got %d)" % _expose(pushed, 1))
	_expect(not bool(_unit(pushed, 1).get("chilled", false)), "Entering Ice never Chills an enemy")
	# An enemy that starts its turn on Ice.
	var start: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4))])
	_paint(start, [Vector2i(6, 4)], "ice")
	var result: Dictionary = engine._resolve_enemy_start_of_turn(start, _index(start, 1))
	var after: Dictionary = result["state"] as Dictionary
	_expect(_expose(after, 1) == 2, "An enemy starting its turn on Ice gets Expose 2 (got %d)" % _expose(after, 1))
	_expect(not bool(result.get("skip_all", false)), "Ice never skips the enemy's turn")
	# Ice placed under a unit does not Expose it until it enters or starts a turn there.
	var placed: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	var warded: Dictionary = _play(engine, placed, "hoarfrost_ward")
	_expect(Surface.has_surface(warded, Vector2i(4, 4), "ice"), "Hoarfrost Ward leaves Ice under the adjacent enemy")
	_expect(_expose(warded, 1) == 0, "Ice placed under an enemy does not Expose it yet")

func _test_illusion_ice(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))])
	_paint(state, [Vector2i(5, 5)], "ice")
	var created: Dictionary = engine._create_illusion(state, Vector2i(5, 5), 6)
	var illusion: Dictionary = (created.get("illusions", []) as Array)[0] as Dictionary
	_expect(int(illusion.get("expose", 0)) == 2, "An illusion arriving on Ice gets Expose 2 (got %d)" % int(illusion.get("expose", 0)))
	var start: Dictionary = created.duplicate(true)
	(start["illusions"][0] as Dictionary)["expose"] = 0
	var started: Dictionary = engine._resolve_player_start_of_turn(start)
	_expect(int((started["illusions"][0] as Dictionary).get("expose", 0)) == 2, "An illusion starting its activation on Ice gets Expose 2")
	# The next damage spends it: a 3-damage hit takes 5.
	var hit: Dictionary = engine._damage_actor_target(created, {"kind": "illusion", "id": int(illusion["id"])}, 3, false, {"type": "melee", "damage": 3})
	var struck: Dictionary = (hit.get("illusions", []) as Array)[0] as Dictionary
	_expect(int(struck.get("hp", 0)) == 6 - 5, "An Exposed illusion takes 3 + 2 (got %d Health left)" % int(struck.get("hp", 0)))
	_expect(int(struck.get("expose", 0)) == 0, "The hit spends the illusion's Expose")

func _test_expose_spent(engine: CombatEngine) -> void:
	# Shiver Shot (2, range 4) twice at an enemy that entered Ice: 2 + 2, then 2.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4))])
	(state["enemies"][0] as Dictionary)["expose"] = 2
	_paint(state, [Vector2i(6, 4)], "ice")
	var first: Dictionary = _play(engine, state, "shiver_shot", [Vector2i(6, 4)])
	_expect(_hp(first, 1) == HP - 4, "The first hit takes its Expose 2 (got %d)" % (HP - _hp(first, 1)))
	_expect(_expose(first, 1) == 0, "The first damage spends the Expose")
	var second: Dictionary = _play(engine, first, "shiver_shot", [Vector2i(6, 4)])
	_expect(_hp(second, 1) == HP - 6, "The second hit has no Expose left (got %d total)" % (HP - _hp(second, 1)))
	# An Exposed hero takes 2 more from the next enemy hit, once.
	var hero_state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	(hero_state["player"] as Dictionary)["expose"] = 2
	var hit: Dictionary = engine._damage_player(hero_state, 3, false, true, "enemy_attack")
	_expect(int((hit["player"] as Dictionary).get("hp", 0)) == HERO_HP - 5, "The Exposed hero takes 3 + 2")
	_expect(int((hit["player"] as Dictionary).get("expose", 0)) == 0, "The hit spends the hero's Expose")
	var again: Dictionary = engine._damage_player(hit, 3, false, true, "enemy_attack")
	_expect(int((again["player"] as Dictionary).get("hp", 0)) == HERO_HP - 8, "The next hit takes 3")
	# Standing on Ice no longer adds damage to every hit (Chilled is cut).
	var standing: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4))])
	_paint(standing, [Vector2i(6, 4)], "ice")
	(standing["enemies"][0] as Dictionary)["chilled"] = true
	var plain: Dictionary = _play(engine, standing, "shiver_shot", [Vector2i(6, 4)])
	_expect(_hp(plain, 1) == HP - 2, "A unit on Ice without Expose takes the printed damage (got %d)" % (HP - _hp(plain, 1)))

func _test_expose_analytics(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))])
	var ice := Vector2i(4, 4)
	_paint(state, [ice], "ice")
	var entered: Dictionary = engine.apply_player_action(state, {"type": "move", "range": 1}, ice)
	var events: Array[Dictionary] = engine._surface_events_since(state, entered)
	_expect(events.size() == 1 and events[0].get("status") == "expose" and events[0].get("trigger") == "entry", "Ice entry records one Expose application")
	var before_start: Dictionary = entered.duplicate(true)
	var started: Dictionary = engine._resolve_player_start_of_turn(entered)
	_expect(engine._surface_events_since(before_start, started).is_empty(), "Unspent Expose emits no duplicate application")
	started["player"]["expose"] = 0
	var spent: Dictionary = started.duplicate(true)
	var refreshed: Dictionary = engine._resolve_player_start_of_turn(started)
	var refresh: Array[Dictionary] = engine._surface_events_since(spent, refreshed)
	_expect(refresh.size() == 1 and refresh[0].get("trigger") == "start", "Ice start records Expose again after a spend")

func _test_enemy_area_hits(engine: CombatEngine) -> void:
	var victim := Vector2i(5, 4)
	var mark := Vector2i(5, 3)
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 4), "vyraketh"), _enemy(2, victim)])
	state["enemies"][0]["cinder_tiles"] = TypedArrays.vector2i([mark])
	state["enemies"][1]["expose"] = 2
	Surface.place(state, mark, "fire", {"actor_kind": "enemy", "actor_id": 1})
	var crownfire: Dictionary = engine._intent_by_id(GameData.enemy_def("vyraketh")["intents"], "crownfire")["actions"][0]
	var fire: Dictionary = engine._resolve_enemy_action(state, 0, crownfire)
	_expect(_hp(fire, 2) == HP - int(crownfire["damage"]) - 2 and _expose(fire, 2) == 0, "Crownfire adds and spends enemy Expose")
	var lob: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 4), "slag_mortar"), _enemy(2, victim)])
	lob["enemies"][0]["lob_tiles"] = TypedArrays.vector2i([victim])
	lob["enemies"][0]["lob_center"] = victim
	lob["enemies"][1]["expose"] = 2
	var landing: Dictionary = engine._intent_by_id(GameData.enemy_def("slag_mortar")["intents"], "slag_lands")["actions"][0]
	var landed: Dictionary = engine._resolve_enemy_action(lob, 0, landing)
	_expect(_hp(landed, 2) == HP - int(landing["center_damage"]) - 2 and _expose(landed, 2) == 0, "Lob Landing adds and spends enemy Expose")

func _test_opening_and_spawn_contact(engine: CombatEngine) -> void:
	var foe := Vector2i(7, 4)
	var layout: Dictionary = {"type": "combat", "coord": Vector2i(1, 1), "grid": _grid(), "player_start": PLAYER, "enemies": [_enemy(1, foe)], "surfaces": {}}
	_paint(layout, [PLAYER, foe], "ice")
	var opening: Dictionary = engine.create_combat(40617, layout, {"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": ["brace"]})
	_expect(int(opening["player"].get("expose", 0)) == 2 and _expose(opening, 1) == 2, "Combat opens with Expose 2 for the hero and enemy on Ice")
	var state: Dictionary = _state(engine, [_enemy(1, foe)])
	state["objective"] = {"type": "survive", "target_clock": 30, "next_reinforcement_clock": 5, "reinforcement_interval": 5, "reinforcement_pool": ["crawler"]}
	state["initiative_clock"] = 5
	for y: int in range(1, 9):
		for x: int in range(1, 10):
			Surface.place(state, Vector2i(x, y), "ice")
	var steps: Array[Dictionary] = engine._spawn_due_survival_reinforcements(state)
	var arrived: Array = steps[0]["spawned_enemies"] if not steps.is_empty() else []
	_expect(arrived.size() == 1 and int(arrived[0].get("expose", 0)) == 2, "Survival reinforcement enters on Ice with Expose 2")
	var summoned: Dictionary = engine._enemy_summon_minions(state, 0, {"minion_type": "rime_whelp", "count": 1})
	var minions: Array = (summoned["enemies"] as Array).filter(func(enemy: Dictionary) -> bool: return bool(enemy.get("summoned", false)))
	_expect(minions.size() == 1 and int(minions[0].get("expose", 0)) == 2, "An enemy summon placed on Ice arrives with Expose 2")

func _test_limited_umbra_move_preview(engine: CombatEngine) -> void:
	var scene := RunScene.new()
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(8, 2))])
	state["umbra"]["stage"] = "fringe"
	scene._combat_state = state
	var action: Dictionary = {"type": "move", "range": 1}
	var target := Vector2i(4, 4)
	var preview: Dictionary = {"state": state, "action": action, "target_tiles": [target]}
	scene._hovered_board_tile = target
	_paint(state, [target], "ice")
	var result: Dictionary = {}
	_expect(scene._preview_umbra_is_limited(state) and engine.is_tile_visible_to_player(state, target), "Fringe fixture has limited sight and visible Ice")
	scene._append_surface_action_preview(result, preview)
	var committed: Dictionary = engine.apply_player_action(state, action, target)
	_expect(result == {"surface_status_preview": {"player": {"expose": int(committed["player"].get("expose", 0))}}} and int(committed["player"].get("expose", 0)) == 2, "Fringe movement predicts only the visible Ice status applied by commitment")
	state["player"]["expose"] = 2
	result.clear()
	scene._append_surface_action_preview(result, preview)
	_expect(result.is_empty(), "A move across Ice shows no new status when Expose 2 is already active")
	state["player"]["expose"] = 0
	state["relics"] = ["hobnail_cleats"]
	scene._append_surface_action_preview(result, preview)
	_expect(result.is_empty() and int(engine.apply_player_action(state, action, target)["player"].get("expose", 0)) == 0, "Fringe movement with Hobnail Cleats predicts no Expose on visible Ice")
	scene.free()

func _test_former_freeze_cards(engine: CombatEngine) -> void:
	# Frostbolt: 4 at range 3. On Ice: also Stagger 6. Then leave Ice.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(3, 6))])
	_paint(state, [Vector2i(6, 4)], "ice")
	var bolted: Dictionary = _play(engine, state, "frostbolt", [Vector2i(6, 4)])
	_expect(_stagger(engine, state, bolted, 1) == 6, "Frostbolt on an enemy on Ice Staggers 6 (got %d)" % _stagger(engine, state, bolted, 1))
	_expect(int(_unit(bolted, 1).get("freeze", 0)) == 0, "Frostbolt never Freezes")
	_expect(_hp(bolted, 1) == HP - 4, "Frostbolt deals its printed 4 (no triple, no Chill bonus)")
	var dry: Dictionary = _play(engine, state, "frostbolt", [Vector2i(3, 6)])
	_expect(_stagger(engine, state, dry, 2) == 0, "Frostbolt off Ice does not Stagger")
	_expect(Surface.has_surface(dry, Vector2i(3, 6), "ice"), "Frostbolt still leaves Ice")
	_expect(_expose(dry, 2) == 0, "Ice left under the target does not Expose it yet")
	# A dragon takes half Stagger.
	var dragon_type: String = "iskaldra"
	_expect(DragonBossLibrary.is_dragon_boss_id(dragon_type), "Iskaldra is a dragon")
	var dragon: Dictionary = _state(engine, [_enemy(5, Vector2i(5, 3), dragon_type, 62)])
	(dragon["enemies"][0] as Dictionary)["footprint"] = Vector2i(2, 2)
	_paint(dragon, [Vector2i(5, 3)], "ice")
	var dragoned: Dictionary = _play(engine, dragon, "frostbolt", [Vector2i(5, 3)])
	_expect(_stagger(engine, dragon, dragoned, 5) == 3, "A dragon on Ice takes Stagger 3 from Frostbolt (got %d)" % _stagger(engine, dragon, dragoned, 5))
	# Every former Freeze card now carries its own Ice Stagger.
	for card_id: String in ["frostbolt", "icebound_chains", "rime_shard", "cold_grasp", "icicle_lance", "shatterline", "glacier_pin", "rimeplate_lock", "locket_chill", "frost_snare", "cold_shoulder", "frost_nova", "rime_hack", "shiver_shot", "rimefang", "sleet_squall", "hush_of_winter", "frozen_bite"]:
		var found: bool = false
		for action_var: Variant in (GameData.cards()[card_id] as Dictionary).get("actions", []):
			var bonus: Dictionary = (action_var as Dictionary).get("surface_bonus", {}) as Dictionary
			if str(bonus.get("surface", "")) == "ice" and str(bonus.get("subject", "")) == "target" and int(bonus.get("stagger", 0)) == 6:
				found = true
		_expect(found, "%s says On Ice: also Stagger 6" % card_id)
	# Cold Shoulder's Stagger is judged where the enemy stood when hit.
	var shoulder: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	_paint(shoulder, [Vector2i(4, 4)], "ice")
	var shouldered: Dictionary = _play(engine, shoulder, "cold_shoulder", [Vector2i(4, 4)])
	_expect(_stagger(engine, shoulder, shouldered, 1) == 6, "Cold Shoulder on an enemy on Ice Staggers 6 (got %d)" % _stagger(engine, shoulder, shouldered, 1))
	# Rime Shard: each enemy hit on Ice is Staggered, the others are not.
	var shard: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(5, 5))])
	_paint(shard, [Vector2i(5, 4)], "ice")
	var sharded: Dictionary = _play(engine, shard, "rime_shard", [Vector2i(5, 4)])
	_expect(_stagger(engine, shard, sharded, 1) == 6, "Rime Shard Staggers the enemy hit on Ice (got %d)" % _stagger(engine, shard, sharded, 1))

func _test_shatter_has_no_stagger(engine: CombatEngine) -> void:
	var target := Vector2i(4, 4)
	for card_id: String in ["shatter", "shatter_swing"]:
		var state: Dictionary = _state(engine, [_enemy(1, target)])
		_paint(state, [target], "ice")
		var burst: Dictionary = _play(engine, state, card_id, [target])
		_expect(_hp(burst, 1) < HP and _stagger(engine, state, burst, 1) == 0, "The Ice hit and Burst do not grant Stagger for " + card_id)

func _test_hush_white_silence_rite(engine: CombatEngine) -> void:
	# Hush of Winter: 5. On Ice: also Stagger 6 and Draw 2.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(3, 7))])
	_paint(state, [Vector2i(6, 4)], "ice")
	var hushed: Dictionary = _play(engine, state, "hush_of_winter", [Vector2i(6, 4)])
	_expect(_stagger(engine, state, hushed, 1) == 6, "Hush of Winter on Ice Staggers 6")
	_expect(_hand_size(hushed) == 2, "Hush of Winter on Ice draws 2 (hand %d)" % _hand_size(hushed))
	var dry: Dictionary = _play(engine, state, "hush_of_winter", [Vector2i(3, 7)])
	_expect(_hand_size(dry) == 0 and _stagger(engine, state, dry, 2) == 0, "Hush of Winter off Ice neither draws nor Staggers")
	# Frozen Bite: 5. On Ice: also Stagger 6, gain Card Play 1 and Draw 1.
	var bite: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	_paint(bite, [Vector2i(4, 4)], "ice")
	var bitten: Dictionary = _play(engine, bite, "frozen_bite", [Vector2i(4, 4)])
	_expect(_stagger(engine, bite, bitten, 1) == 6, "Frozen Bite on Ice Staggers 6")
	_expect(_hand_size(bitten) == 1, "Frozen Bite on Ice draws 1 (hand %d)" % _hand_size(bitten))
	# White Silence: 6 and Stagger 6 each enemy you can see on Ice.
	var silence: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(7, 7))])
	_paint(silence, [Vector2i(6, 4)], "ice")
	var silenced: Dictionary = _play(engine, silence, "white_silence")
	_expect(_hp(silenced, 1) == HP - 8 and _stagger(engine, silence, silenced, 1) == 6, "White Silence hits and Staggers the enemy on Ice")
	_expect(_hp(silenced, 2) == HP and _stagger(engine, silence, silenced, 2) == 0, "White Silence skips the enemy off Ice")
	# Rite of Hoarfrost: when one of your Ice cards Staggers an enemy, gain Block 3 and Draw 1.
	var rite: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4))])
	_paint(rite, [Vector2i(6, 4)], "ice")
	var rited: Dictionary = _play(engine, rite, "rite_of_hoarfrost")
	var hand_before: int = _hand_size(rited)
	var bolted: Dictionary = _play(engine, rited, "frostbolt", [Vector2i(6, 4)])
	_expect(int((bolted["player"] as Dictionary).get("block", 0)) == 3, "Rite of Hoarfrost: an Ice Stagger gains Block 3 (got %d)" % int((bolted["player"] as Dictionary).get("block", 0)))
	_expect(_hand_size(bolted) == hand_before + 1, "Rite of Hoarfrost: an Ice Stagger draws 1")

func _test_petrify_staggers(engine: CombatEngine) -> void:
	var card: Dictionary = GameData.cards()["petrify"] as Dictionary
	_expect(int(card.get("time", 0)) == 3, "Petrify costs Time 3")
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	_expect(_targets(engine, state, "petrify").has(Vector2i(5, 4)), "Petrify targets an enemy within range 3")
	var after: Dictionary = _play(engine, state, "petrify", [Vector2i(5, 4)])
	_expect(_stagger(engine, state, after, 1) == 6, "Petrify Staggers 6 (got %d)" % _stagger(engine, state, after, 1))
	_expect(int(_unit(after, 1).get("petrify", 0)) == 0 and int(_unit(after, 1).get("block", 0)) == 0, "Petrify no longer skips a turn or gives Block")
	var dragon: Dictionary = _state(engine, [_enemy(5, Vector2i(5, 3), "iskaldra", 62)])
	(dragon["enemies"][0] as Dictionary)["footprint"] = Vector2i(2, 2)
	_expect(_targets(engine, dragon, "petrify").has(Vector2i(5, 3)), "Petrify can target a dragon")
	var dragoned: Dictionary = _play(engine, dragon, "petrify", [Vector2i(5, 3)])
	_expect(_stagger(engine, dragon, dragoned, 5) == 3, "A dragon takes Stagger 3 from Petrify (got %d)" % _stagger(engine, dragon, dragoned, 5))

func _test_legacy_statuses_removed(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	state["player"].merge({"freeze": 1, "chilled": true}, true)
	state["cards_played_this_turn"] = 1
	state["player_turn_restrictions"] = {"frozen": true, "shocked": true}
	state["enemies"][0].merge({"freeze": 1, "petrify": 1, "chilled": true, "block": 5}, true)
	var available: int = engine.cards_remaining_this_turn(state)
	engine._forfeit_remaining_card_plays(state)
	_expect(engine.cards_remaining_this_turn(state) == 0, "Legacy Freeze forfeits the available plays")
	var loaded: Dictionary = engine.normalize_player_movement_pool(state)
	_expect(not bool(loaded["player_turn_restrictions"].get("frozen", false)), "Loading an old save drops the hero's retired turn restriction")
	_expect(loaded["player_turn_restrictions"].get("shocked", false), "Save migration preserves the other restrictions")
	_expect(engine.cards_remaining_this_turn(loaded) == available and int(loaded["cards_played_this_turn"]) == 1 and int(loaded["plays_forfeited_this_turn"]) == 0, "Migration restores the forfeited plays and keeps the paid play")
	_expect(engine.normalize_player_movement_pool(loaded) == loaded, "A second migration leaves the restored activation unchanged")
	_expect(not loaded["player"].has("freeze") and not loaded["player"].has("chilled"), "Loading an old save drops the hero's retired statuses")
	_expect(int(_unit(loaded, 1).get("block", 0)) == 5, "Loading an old save preserves already-granted Block")
	var started: Dictionary = engine._resolve_enemy_start_of_turn(loaded, 0)
	_expect(not bool(started.get("skip_all", false)), "Loading an old save drops the enemy's turn denial")

func _test_saved_ice_intents(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4), "hoarfrost_seer"), _enemy(2, Vector2i(7, 4), "glacial_mirror"), _enemy(3, Vector2i(8, 4))])
	state["enemies"][0]["intent"] = {"id": "rime_bolt", "actions": [{"type": "ranged", "range": 4, "damage": 4, "element": "ice", "chilled": true}]}
	state["enemies"][1]["intent"] = {"id": "refraction", "chilled": true, "actions": [{"type": "aoe", "damage": 7}], "committed_plan": {"action": {"type": "aoe", "damage": 7, "chilled": true}}}
	state["enemies"][2]["intent"] = {"id": "fixture", "actions": [{"type": "ranged", "damage": 2, "chilled": true}]}
	(state["turn_queue"] as Array).append(engine._player_actor_entry(20, 5))
	_paint(state, [PLAYER], "ice")
	var loaded: Dictionary = engine.normalize_player_movement_pool(state)
	var bolt: Dictionary = loaded["enemies"][0]["intent"]["actions"][0]
	_expect(not JSON.stringify(loaded["enemies"]).contains('"chilled"'), "Migration removes Chilled riders from saved intents and actions")
	var mirror: Dictionary = loaded["enemies"][1]["intent"]
	_expect(int(mirror["actions"][0].get("surface_bonus", {}).get("stagger", 0)) == 6 and int(mirror["committed_plan"]["action"].get("surface_bonus", {}).get("stagger", 0)) == 6, "Migration restores saved Refraction riders and held action data")
	_expect(not loaded["enemies"][2]["intent"]["actions"][0].has("surface_bonus"), "Migration drops unsupported Chilled riders")
	var hit: Dictionary = engine._resolve_enemy_action(loaded, 0, bolt)
	_expect(_hero_queue_time(hit) == 26 and int(hit["player"]["hp"]) == HERO_HP - 4, "Migrated Rime Bolt delays the hero and keeps saved damage")

func _test_frost_armor_boss_only(engine: CombatEngine) -> void:
	for enemy_id: String in GameData.enemies():
		var enemy: Dictionary = GameData.enemies()[enemy_id] as Dictionary
		var uses: bool = JSON.stringify(enemy.get("intents", [])).contains("\"frost_armor\"")
		if uses:
			_expect(DragonBossLibrary.is_dragon_boss_id(enemy_id), "Only a boss keeps Frost Armor (%s uses it)" % enemy_id)
	_expect(JSON.stringify((GameData.enemies()["iskaldra"] as Dictionary).get("intents", [])).contains("\"frost_armor\""), "Iskaldra keeps Frost Armor")
	_expect(not ((GameData.enemies()["iskaldra"] as Dictionary).get("status_immunities", []) as Array).has("freeze"), "Iskaldra's Freeze immunity is gone")

	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4))])
	var guarded: Dictionary = engine._enemy_gain_frost_armor(state, 0, {"type": "frost_armor", "amount": 3})
	_expect(int(_unit(guarded, 1).get("block", 0)) == 3 and int(_unit(guarded, 1).get("frost_armor", 0)) == 0, "A legacy non-boss armor action grants its authored amount as Block")

func _test_player_frost_armor(engine: CombatEngine) -> void:
	var target := Vector2i(6, 4)
	var state: Dictionary = _state(engine, [_enemy(1, target)], PLAYER, ["cold_mirror"])
	state["player"]["block"] = 8
	_paint(state, [target], "ice")
	var mirrored: Dictionary = _play(engine, state, "frostbolt", [target])
	_expect(int(mirrored["player"].get("frost_armor", 0)) == 2 and int(mirrored["player"].get("block", -1)) == 0, "Cold Mirror keeps the hero's two Frost Armor layers in exchange for 8 Block")
	var mantle: Dictionary = _play(engine, state, "crystal_mantle")
	_expect(int(mantle["player"].get("frost_armor", 0)) == 3, "Crystal Mantle keeps the hero's three Frost Armor layers")

func _test_enemy_ice_riders(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4), "hoarfrost_seer")])
	var hero_entry: Dictionary = engine._player_actor_entry(20, 2)
	(state["turn_queue"] as Array).append(hero_entry)
	var bolt_intent: Dictionary = engine._intent_by_id(GameData.enemy_def("hoarfrost_seer")["intents"], "rime_bolt")
	var bolt: Dictionary = bolt_intent["actions"][0]
	var bare: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, bolt)
	_expect(_hero_queue_time(bare) == 20 and int(bare["player"]["hp"]) == HERO_HP - 3 and int(bare["player"].get("expose", 0)) == 0, "Rime Bolt applies no status on stone")
	_paint(state, [PLAYER], "ice")
	var frostbite: Dictionary = Battlefield.instance_for("rimejaw")
	frostbite["source"] = {"kind": "enemy", "id": 1, "type": "rimejaw"}
	var hit: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, bolt)
	_expect(_hero_queue_time(hit) == 26 and int(hit["player"]["hp"]) == HERO_HP - 3, "Rime Bolt delays an on-Ice hero by 6")
	var room: Dictionary = preload("res://scripts/battlefield_rules/frostbite.gd").resolve_beat(engine, state.duplicate(true), frostbite)
	_expect(_hero_queue_time(room) == 26 and int(room["player"]["hp"]) == HERO_HP, "Rimejaw's Frostbite delays the hero by 6 without damage")
	var room_with_foe: Dictionary = state.duplicate(true)
	room_with_foe["enemies"].append(_enemy(2, Vector2i(5, 5)))
	room_with_foe["turn_queue"].append(engine._enemy_actor_entry(room_with_foe, room_with_foe["enemies"][1], 20, 3))
	_paint(room_with_foe, [Vector2i(5, 5)], "ice")
	var after_card: Dictionary = _play(engine, room_with_foe, "frostbolt", [Vector2i(5, 5)])
	var after_room: Dictionary = preload("res://scripts/battlefield_rules/frostbite.gd").resolve_beat(engine, after_card.duplicate(true), frostbite)
	_expect(_enemy_queue_time(after_room, 2) == _enemy_queue_time(after_card, 2), "Frostbolt uses all 6 Stagger, leaving 6 minus 6 for Frostbite")
	_expect(CardKeywords.stagger_applied_this_turn(after_room, 2) == 6, "Card and battlefield Stagger share the enemy's 6-point allowance")
	var room_first: Dictionary = preload("res://scripts/battlefield_rules/frostbite.gd").resolve_beat(engine, room_with_foe.duplicate(true), frostbite)
	_expect(engine._apply_stagger_to_enemy(room_first, 2, 6) == 0, "Frostbite uses the same 6-point allowance before a card")
	state["enemies"][0]["type"] = "rimejaw"
	frostbite["dials"].erase("stagger")
	frostbite["beats_fired"] = 2
	state["battlefield_rule"] = frostbite
	var loaded: Dictionary = engine.normalize_player_movement_pool(state)
	_expect(int(loaded["battlefield_rule"]["dials"].get("stagger", 0)) == 6 and int(loaded["battlefield_rule"]["beats_fired"]) == 2, "A saved Rimejaw beat gains the new dial without resetting its cadence")

func _hero_queue_time(state: Dictionary) -> int:
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "player":
			return int(entry["time"])
	return -1

func _test_hero_stagger_cap(engine: CombatEngine) -> void:
	var enemies: Array = [
		_enemy(1, PLAYER + Vector2i.RIGHT, "hoarfrost_seer"),
		_enemy(2, PLAYER + Vector2i.DOWN, "hoarfrost_seer"),
		_enemy(3, PLAYER + Vector2i.LEFT, "hoarfrost_seer"),
	]
	var state: Dictionary = _state(engine, enemies)
	var intent: Dictionary = engine._intent_by_id(GameData.enemy_def("hoarfrost_seer")["intents"], STAGGER_RIDER_ID)
	for index: int in range(enemies.size()):
		state["enemies"][index]["intent"] = intent.duplicate(true)
		state["turn_queue"][index]["time"] = index + 1
	_paint(state, [PLAYER], "ice")
	var scheduled: Dictionary = Committed.finish_player_activation(engine, state)
	var base_time: int = _hero_queue_time(scheduled)
	var phase: Dictionary = Committed.advance_to_player(engine, scheduled)
	var after: Dictionary = phase["state"]
	_expect(engine.is_player_turn(after) and int(after["initiative_clock"]) == base_time + 6, "Three Ice enemies add only 6 Time before the hero acts")
	var forecast: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(PassForecast.schedule(engine, state), true)
	_expect(int(forecast["state"]["initiative_clock"]) == int(after["initiative_clock"]), "Pass forecasts the same next hero clock as live resolution")
	_expect(int(forecast["status_gains"].get("stagger", 0)) == 6, "Pass reports the capped Stagger from all three attacks")
	_expect(forecast["enemy_stagger_limits"] == {"enemy_2": 0, "enemy_3": 0}, "Enemy intent previews have no remaining allowance after the first hit")

	var after_hit: Dictionary = engine._resolve_enemy_action(scheduled.duplicate(true), 0, intent["actions"][0])
	var frostbite: Dictionary = Battlefield.instance_for("rimejaw")
	var after_beat: Dictionary = preload("res://scripts/battlefield_rules/frostbite.gd").resolve_beat(engine, after_hit.duplicate(true), frostbite)
	_expect(_hero_queue_time(after_beat) == base_time + 6 and after_beat["activation_seq"] == after_hit["activation_seq"], "Frostbite shares the cap and does not requeue a capped hero")
	var rail: Array = engine.current_turn_order(after_beat)
	var hero_entries: Array = rail.filter(func(entry: Dictionary) -> bool: return entry.get("kind") == "player")
	_expect(not hero_entries.is_empty() and int(hero_entries[0]["time"]) == base_time + 6 and int(hero_entries[0].get("stagger_delay", 0)) == 6, "The rail places the hero at the capped clock and reports the delay")

	var partial: Dictionary = scheduled.duplicate(true)
	CardKeywords.stagger_player(engine, partial, PARTIAL_STAGGER)
	var partial_forecast: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(partial, true)
	_expect(int(partial_forecast["enemy_stagger_limits"].get("enemy_1", -1)) == 6 - PARTIAL_STAGGER, "A forecast from a partly staggered queue shows only the remaining Time")
	_expect(int(partial_forecast["state"]["initiative_clock"]) == base_time + 6, "A new hit fills the remaining allowance without exceeding the cap")

	var next_scheduled: Dictionary = Committed.finish_player_activation(engine, after)
	var next_base: int = _hero_queue_time(next_scheduled)
	CardKeywords.stagger_player(engine, next_scheduled, CardKeywords.STAGGER_TURN_CAP)
	_expect(_hero_queue_time(next_scheduled) == next_base + 6, "The hero gets a fresh Stagger allowance after acting")

func _enemy_queue_time(state: Dictionary, id: int) -> int:
	for entry: Dictionary in state.get("turn_queue", []):
		if str(entry.get("kind", "")) == "enemy" and int(entry.get("enemy_id", -1)) == id:
			return int(entry["time"])
	return -1

# ------------------------------------------------------------------ data scan

func _test_no_cut_status_in_data() -> void:
	var regex := RegEx.new()
	regex.compile(CUT_WORDS)
	var mechanics_keys: Array[String] = TypedArrays.strings(["type", "status", "statuses", "selector", "when", "icon", "id", "term", "rule", "status_immunities", "build_tags"])
	var texts: Array[String] = TypedArrays.strings(["description", "definition", "sentence", "text", "plain", "tooltip", "legacy", "body_lines", "paragraphs", "lines"])
	var files: Array[String] = TypedArrays.strings(["res://data/cards.json", "res://data/enemies.json", "res://data/relics.json", "res://data/glossary.json", "res://data/grimoire.json", "res://data/battlefield_rules.json", "res://data/special_encounters.json", "res://data/card_panel_text.json", "res://data/card_faces.json", "res://data/tooltip_loops.json", "res://data/skills.json", "res://data/pattern_rule_text.json", "res://data/sfx_cues.json"])
	for path: String in files:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var hits: Array[String]
		_scan(parsed, "", regex, mechanics_keys, texts, hits)
		_expect(hits.is_empty(), "%s still uses Freeze, Chilled or Petrify: %s" % [path, ", ".join(hits.slice(0, 6))])

func _scan(value: Variant, path: String, regex: RegEx, mechanics_keys: Array[String], texts: Array[String], hits: Array[String]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value as Dictionary
		for key_var: Variant in dictionary:
			var key: String = str(key_var)
			# Card ids that keep their names (Petrify, Frozen Bite, Locket Chill) are not rules.
			if regex.search(key) != null and key not in ["frozen_bite", "locket_chill", "petrify"]:
				hits.append("%s/%s (key)" % [path, key])
			_scan(dictionary[key_var], "%s/%s" % [path, key], regex, mechanics_keys, texts, hits)
	elif typeof(value) == TYPE_ARRAY:
		var array: Array = value as Array
		for index: int in range(array.size()):
			_scan(array[index], "%s[%d]" % [path, index], regex, mechanics_keys, texts, hits)
	elif typeof(value) == TYPE_STRING:
		var leaf: String = path.get_file().split("[")[0]
		var text: String = str(value)
		# Names of cards that keep their name (Frozen Bite, Locket Chill) are not rules.
		var stripped: String = text.replace("Frozen Bite", "").replace("Locket Chill", "").replace("frozen_bite", "").replace("locket_chill", "")
		if (leaf in mechanics_keys or leaf in texts or path.contains("/sentence") or path.contains("/actions")) and regex.search(stripped) != null:
			hits.append("%s=%s" % [path, text.substr(0, 60)])
