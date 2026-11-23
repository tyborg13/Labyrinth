extends SceneTree
## pla-04r3 rules: Burst N destroys the thing named, then deals N damage to every
## unit on its tile and the four tiles next to it, the hero included unless
## the card says "sparing you"; several sources hit each unit once; a card's
## base effect always happens and its "On X: also Burst" is an extra hit.
## The enemies' death Burst and kegs use the same cross. Traps caught in a
## Burst trigger. Run:
##   python3 tools/godot_task_runner.py --task-id pla-04r3 --stream -- \
##     godot --headless --path . --script res://tests/burst_rules_test.gd

const CombatEngine = preload("res://scripts/combat_engine.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const TerrainCardRules = preload("res://scripts/terrain_card_rules.gd")
const TooltipLoops = preload("res://scripts/tooltip_loop_registry.gd")

const PLAYER := Vector2i(3, 4)
const NO_TARGET := Vector2i(-1, -1)
const HP: int = 30
const HERO_HP: int = 40

var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := CombatEngine.new()
	_test_cross_includes_player(engine)
	_test_sparing_you(engine)
	_test_one_hit_across_sources(engine)
	_test_concealed_ground(engine)
	_test_concealed_network(engine)
	_test_footprint_burst(engine)
	_test_additive_base_and_burst(engine)
	_test_death_burst_shape(engine)
	_test_keg_and_trap(engine)
	_test_card_family(engine)
	_test_preview_shows_hero_hit(engine)
	_test_empowered_preview(engine)
	_test_rockburst_keg(engine)
	_test_burst_board_memory(engine)
	_test_dust_devil_selected_tile(engine)
	_test_conditional_echo(engine)
	_test_keg_flying_victim(engine)
	_test_death_burst_fifo(engine)
	_test_loop_registration()
	for failure: String in _failures:
		push_error(failure)
	print("BURST RULES: %d checks, %d failures" % [_checks, _failures.size()])
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

func _state(engine: CombatEngine, enemies: Array, player_pos: Vector2i = PLAYER) -> Dictionary:
	var layout: Dictionary = {
		"name": "Burst proof", "type": "combat", "coord": Vector2i(1, 1), "depth": 1,
		"element": "none", "umbra_stage": "clear", "grid": _grid(),
		"player_start": player_pos, "terrain": [], "traps": [], "loot": [],
		"enemies": [_enemy(99, Vector2i(9, 8))],
	}
	var state: Dictionary = engine.create_combat(40417, layout, {"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": ["brace", "brace", "brace", "brace", "brace", "brace", "brace", "brace"], "hand_size": 1, "relics": [], "cards_per_turn": 8})
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
	(state["deck"] as Dictionary)["hand"] = []
	(state["deck"] as Dictionary)["draw"] = ["brace", "brace", "brace"]
	return state

## Every action of a production card like a committed hand play.
func _play(engine: CombatEngine, state: Dictionary, card_id: String, targets: Array = [], mode: String = "play") -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var hand: Array = ((next_state["deck"] as Dictionary).get("hand", []) as Array).duplicate()
	hand.push_front(card_id)
	(next_state["deck"] as Dictionary)["hand"] = hand
	var working: Dictionary = engine.prepare_player_card(next_state, 0, mode)
	var actions: Array = engine.card_play_actions(card_id, working)
	var cursor: int = 0
	for action_var: Variant in actions:
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		var tile: Vector2i = NO_TARGET
		if engine.player_action_needs_target(action):
			tile = targets[cursor] if cursor < targets.size() else NO_TARGET
			cursor += 1
		working = engine.apply_player_action(working, action, tile)
	return engine.finish_player_card(working, 0, engine.card_plays_spent_for_actions(actions), {"play_mode": mode})

func _targets(engine: CombatEngine, state: Dictionary, card_id: String, index: int = 0) -> Array[Vector2i]:
	var actions: Array = engine.card_play_actions(card_id, state)
	return engine.valid_targets_for_player_action(state, (actions[index] as Dictionary).duplicate(true))

func _hp(state: Dictionary, id: int) -> int:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return int(enemy.get("hp", -1))
	return -1

func _unit(state: Dictionary, id: int) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) == id:
			return enemy
	return {}

func _hero(state: Dictionary) -> int:
	return int((state.get("player", {}) as Dictionary).get("hp", -1))

func _paint(state: Dictionary, tiles: Array, surface: String) -> void:
	for tile_var: Variant in tiles:
		Surface.place(state, tile_var as Vector2i, surface, {"actor_kind": "test"})

func _terrain(state: Dictionary, id: String, pos: Vector2i, kind: String, hp: int, extra: Dictionary = {}) -> void:
	var piece: Dictionary = {"id": id, "pos": pos, "kind": kind, "hp": hp, "max_hp": hp, "blocks_sight": false}
	piece.merge(extra, true)
	(state["terrain"] as Array).append(piece)

func _terrain_at(state: Dictionary, pos: Vector2i) -> Dictionary:
	for piece: Dictionary in state.get("terrain", []):
		if piece.get("pos", NO_TARGET) == pos and int(piece.get("hp", 0)) > 0:
			return piece
	return {}

func _has_light(state: Dictionary, pos: Vector2i) -> bool:
	for source: Variant in (state.get("umbra", {}) as Dictionary).get("light_sources", []):
		if typeof(source) == TYPE_DICTIONARY and (source as Dictionary).get("pos", NO_TARGET) == pos:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _hover(engine: CombatEngine, state: Dictionary, card: String, target: Vector2i, mode: String = "play") -> Dictionary:
	(state["deck"] as Dictionary)["hand"] = [card]
	var prepared: Dictionary = engine.prepare_player_card(state, 0, mode)
	var actions: Array = engine.card_play_actions(card, prepared)
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	scene.set("_combat_state", prepared)
	scene.set("_preview_combat_state", prepared)
	scene.set("_hovered_board_tile", target)
	var result: Dictionary = {}
	scene.call("_append_surface_action_preview", result, {"state": prepared, "action": actions[0], "target_tiles": [target], "actions": actions, "action_index": 0})
	scene.free()
	return result

func _hover_hp_loss(preview: Dictionary, key: String) -> int:
	return int(preview.get("damage_preview", {}).get(key, {}).get("hp_loss", 0))

func _events(state: Dictionary, kind: String) -> Array:
	return (state.get("surface_events", []) as Array).filter(func(event: Dictionary) -> bool: return event.get("kind") == kind)

func _test_empowered_preview(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var hero := Vector2i(4, 4)
	var state: Dictionary = _state(engine, [_enemy(1, target)], hero)
	state["relics"] = ["crown_of_surplus"]
	state["player"]["hp"] = 6
	_paint(state, [target], "fire")
	var preview: Dictionary = _hover(engine, state, "pyroclasm", target, "empower")
	_expect(_hover_hp_loss(preview, "enemy_1") == 24, "Empowered Pyroclasm previews one repeat and its Burst")
	_expect(_hover_hp_loss(preview, "player") == 6 and preview.get("focus_tiles", []).has(hero) and preview.get("damage_preview", {}).get("player", {}).get("lethal", false), "Empowered Pyroclasm previews its lethal self-hit and Burst footprint")
	var after: Dictionary = _play(engine, state, "pyroclasm", [target, target], "empower")
	_expect(engine.combat_outcome(after) == "defeat" and _hp(after, 1) == HP - 24, "Empowered Pyroclasm's play agrees with hover")

func _test_rockburst_keg(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4))])
	_terrain(state, "keg", target, TerrainCardRules.KEG_KIND, 3, {"burst_damage": 6})
	var after: Dictionary = _play(engine, state, "rockburst", [target])
	_expect(_hp(after, 1) == HP - 6 and _events(after, "detonate").is_empty(), "Rockburst on a keg deals only the keg's Burst")
	_expect(not Surface.has_surface(after, target, "rubble"), "Rockburst on a keg leaves no Rubble")

func _test_burst_board_memory(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var neighbor := Vector2i(6, 4)
	var state: Dictionary = _state(engine, [_enemy(1, target), _enemy(2, neighbor)])
	state["relics"] = ["crown_of_surplus"]
	state["enemies"][0]["chilled"] = true
	_paint(state, [target], "ice")
	var shattered: Dictionary = _play(engine, state, "shatter", [target, target], "empower")
	_expect(_hp(shattered, 2) == HP - 5, "Empowered Shatter keeps the Ice snapshot after its first hit melts the Ice")
	var ritual: Dictionary = _state(engine, [_enemy(1, neighbor)])
	ritual["relics"] = ["ashen_brand"]
	ritual["traps"] = [{"id": "ice", "pos": Vector2i(5, 3), "element": "ice", "damage": 1}]
	_paint(ritual, [target], "fire")
	var burned: Dictionary = _play(engine, ritual, "inferno_ritual", [target])
	_expect(_hp(burned, 1) == HP - 3 - 9, "Ashen Brand reads Inferno Ritual's original Fire after an Ice trap replaces it (got %d)" % _hp(burned, 1))

func _test_dust_devil_selected_tile(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var state: Dictionary = _state(engine, [_enemy(1, target), _enemy(2, Vector2i(5, 5))])
	state["traps"] = [{"id": "air", "pos": Vector2i(4, 4), "element": "air", "damage": 1}]
	_paint(state, [target], "rubble")
	var after: Dictionary = _play(engine, state, "dust_devil", [target])
	_expect(_unit(after, 1).get("pos") != target, "The Air trap moves the enemy off the selected tile")
	_expect(_unit(after, 2).get("pos") == Vector2i(5, 7), "Dust Devil Pushes from the selected tile after the trap moves its occupant")

func _test_conditional_echo(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var remote := Vector2i(8, 5)
	var state: Dictionary = _state(engine, [_enemy(1, remote)])
	state["relics"] = ["mirror_triptych"]
	state["illusions"] = [{"id": 1, "pos": Vector2i(8, 4), "hp": 3, "max_hp": 3}]
	_paint(state, [remote], "fire")
	var after: Dictionary = _play(engine, state, "dust_devil", [target])
	_expect(_hp(after, 1) == HP and after["illusions"][0]["hp"] == 3, "Mirror Triptych does not echo a Burst that never happened")
	_paint(state, [target], "rubble")
	after = _play(engine, state, "dust_devil", [target])
	_expect(_hp(after, 1) == HP and after["illusions"][0]["hp"] == 3, "Fire alone cannot fuel the echo of a Rubble Burst")
	Surface.remove(state, remote, "fire", "test")
	_paint(state, [remote], "rubble")
	after = _play(engine, state, "dust_devil", [target])
	_expect(_hp(after, 1) == HP - 2 and after["illusions"][0]["hp"] == 2, "Mirror Triptych echoes half damage when both Rubble sources are present")
	var preview: Dictionary = _hover(engine, state, "dust_devil", target)
	_expect(_hover_hp_loss(preview, "enemy_1") == 2 and preview.get("focus_tiles", []).has(remote + Vector2i.RIGHT) and not preview.get("focus_tiles", []).has(remote + Vector2i.ONE), "Hover includes the damage and cross of the fueled echo after Dust Devil's follow-up")
	state["relics"].append("crown_of_surplus")
	preview = _hover(engine, state, "dust_devil", target, "empower")
	_expect(_hover_hp_loss(preview, "enemy_1") == 2 and preview.get("focus_tiles", []).has(remote + Vector2i.RIGHT) and not preview.get("focus_tiles", []).has(remote + Vector2i.ONE), "Empowered Dust Devil still previews the echo after spending its Rubble")

func _test_keg_flying_victim(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var armored_enemy: Dictionary = _enemy(2, target + Vector2i.DOWN, "iskaldra")
	armored_enemy["footprint"] = Vector2i(2, 2)
	armored_enemy["frost_armor"] = 1
	var state: Dictionary = _state(engine, [_enemy(1, target + Vector2i.RIGHT, "gust_shrike"), armored_enemy])
	_terrain(state, "keg", target, TerrainCardRules.KEG_KIND, 3, {"burst_damage": 6})
	var after: Dictionary = _play(engine, state, "pyroclasm", [target])
	var events: Array = _events(after, TerrainCardRules.KEG_EVENT)
	_expect(_hp(after, 1) == HP - 6 and events.size() == 1 and events[0].get("actor_keys") == ["enemy_1"], "The keg damages its flying victim and records that hit")
	_expect(_hp(after, 2) == HP, "The keg does not record the actor whose armor prevented damage")

func _test_death_burst_fifo(engine: CombatEngine) -> void:
	var target := Vector2i(5, 4)
	var state: Dictionary = _state(engine, [
		_enemy(1, Vector2i(4, 3), "ember_tick", 1),
		_enemy(2, Vector2i(4, 5), "ember_tick", 1),
		_enemy(3, Vector2i(4, 4), "ember_tick", 5),
		_enemy(4, Vector2i(3, 5), "crawler", 1),
	])
	_paint(state, [target + Vector2i.UP, target + Vector2i.DOWN], "fire")
	var after: Dictionary = _play(engine, state, "inferno_ritual", [target])
	var order: Array = (after.get("death_burst_events", []) as Array).map(func(event: Dictionary) -> int: return event["id"])
	_expect(order == [1, 2, 3], "Chained death Bursts resolve FIFO (got %s)" % str(order))
	var crawler_death: Array = _events(after, "actor_death").filter(func(event: Dictionary) -> bool: return event["id"] == 4)
	_expect(crawler_death.size() == 1 and crawler_death[0].get("source", {}).get("actor_id") == 2 and not crawler_death[0].get("player_card", true), "The second primary Tick gets the crawler kill in analytics")
	_expect(int(after.get("death_bonus_card_plays_this_turn", 0)) == 2, "Only the two primary card kills grant Card Plays")

# ------------------------------------------------------------------ the shape

func _test_cross_includes_player(engine: CombatEngine) -> void:
	# Pyroclasm: 9 damage. On Fire: also Burst 6 the Fire.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 5)), _enemy(3, Vector2i(7, 4)), _enemy(4, Vector2i(4, 3))])
	_paint(state, [Vector2i(5, 4)], "fire")
	var after: Dictionary = _play(engine, state, "pyroclasm", [Vector2i(5, 4)])
	_expect(_hp(after, 1) == HP - 9 - 6, "Pyroclasm's target on Fire takes 9 and the separate Burst 6 (got %d)" % _hp(after, 1))
	_expect(_hp(after, 2) == HP, "A diagonal neighbour is outside the Burst (got %d)" % _hp(after, 2))
	_expect(_hp(after, 4) == HP, "The other diagonal neighbour is outside the Burst (got %d)" % _hp(after, 4))
	_expect(_hp(after, 3) == HP, "A unit two tiles away is outside the Burst")
	_expect(not Surface.has_surface(after, Vector2i(5, 4), "fire"), "The Burst destroys the Fire")
	_expect(_hero(after) == HERO_HP, "The hero two tiles away is outside the Burst")
	# The hero inside the cross is hit too: no "sparing you" on Pyroclasm.
	var close: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))], Vector2i(4, 4))
	_paint(close, [Vector2i(5, 4)], "fire")
	var hit_self: Dictionary = _play(engine, close, "pyroclasm", [Vector2i(5, 4)])
	_expect(_hero(hit_self) == HERO_HP - 6, "The hero on a tile next to the source takes the Burst (got %d)" % _hero(hit_self))
	var rekindled: Dictionary = _play(engine, close, "rekindle_edge", [Vector2i(5, 4)])
	_expect(_hero(rekindled) == HERO_HP and not Surface.has_surface(rekindled, Vector2i(5, 4), "fire"), "Rekindle Edge Bursts the adjacent Fire and spares the hero")
	# Phoenix Cleave's Fire next to you Bursts onto your own tile.
	var cleave: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(5, 5))])
	_paint(cleave, [Vector2i(4, 4)], "fire")
	var cleaved: Dictionary = _play(engine, cleave, "phoenix_cleave")
	_expect(_hp(cleaved, 1) == HP - 10 - 10, "Phoenix Cleave: the enemy on Fire takes 10 and Burst 10 (got %d)" % _hp(cleaved, 1))
	_expect(_hp(cleaved, 2) == HP, "Phoenix Cleave's Burst leaves the diagonal untouched (got %d)" % _hp(cleaved, 2))
	_expect(_hero(cleaved) == HERO_HP - 1, "Phoenix Cleave: Lose Health 1; its Burst next to you spares you (got %d)" % _hero(cleaved))

func _test_sparing_you(engine: CombatEngine) -> void:
	# Immolation's Burst spares you; its cross leaves the diagonals untouched.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5)), _enemy(2, Vector2i(4, 4)), _enemy(3, Vector2i(5, 4))])
	_paint(state, [PLAYER], "fire")
	var after: Dictionary = _play(engine, state, "immolation")
	_expect(_hero(after) == HERO_HP, "Immolation's Burst spares you (got %d)" % _hero(after))
	_expect(_hp(after, 1) == HP, "The diagonal enemy is untouched (got %d)" % _hp(after, 1))
	_expect(_hp(after, 2) == HP - 3 - 8, "The adjacent enemy takes 3 and Burst 8 (got %d)" % _hp(after, 2))
	_expect(_hp(after, 3) == HP, "An enemy two tiles away is untouched")
	_expect(not Surface.has_surface(after, PLAYER, "fire"), "Your Fire is destroyed")

func _test_one_hit_across_sources(engine: CombatEngine) -> void:
	# Discharge: Burst 7 this tile and every Electrified tile connected to it.
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(8, 5)), _enemy(3, Vector2i(6, 7))], Vector2i(4, 4))
	_paint(state, [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)], "electrified")
	var after: Dictionary = _play(engine, state, "discharge", [Vector2i(5, 4)])
	_expect(_hp(after, 1) == HP - 7, "An enemy beside three Electrified tiles is hit once (got %d)" % _hp(after, 1))
	_expect(_hp(after, 2) == HP, "The network's diagonal is outside the Burst (got %d)" % _hp(after, 2))
	_expect(_hp(after, 3) == HP, "An enemy outside every cross is untouched")
	_expect(_hero(after) == HERO_HP - 7, "Discharge hits you next to the network (got %d)" % _hero(after))
	_expect(not Surface.has_surface(after, Vector2i(5, 4), "electrified") and not Surface.has_surface(after, Vector2i(7, 4), "electrified"), "The network is destroyed")
	var preview: Dictionary = _hover(engine, state, "discharge", Vector2i(5, 4))
	var events: Array = _events(after, "detonate")
	var focus: Array = preview.get("focus_tiles", [])
	_expect(events.size() == 1 and events[0].get("burst_shape") == "cross" and focus == events[0].get("burst_tiles") and focus.size() == 11, "Discharge's hover and analytics share one footprint for the connected crosses")
	_expect(_hover_hp_loss(preview, "player") == 7 and _hover_hp_loss(preview, "enemy_1") == 7 and _hover_hp_loss(preview, "enemy_2") == 0, "Discharge hover matches the once-per-unit hit including the hero")
	# Inferno Ritual: each Fire tile hit Bursts; overlapping crosses hit once.
	var ritual: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 4)), _enemy(3, Vector2i(5, 6))])
	_paint(ritual, [Vector2i(5, 3), Vector2i(5, 5)], "fire")
	var ritualed: Dictionary = _play(engine, ritual, "inferno_ritual", [Vector2i(5, 4)])
	_expect(_hp(ritualed, 1) == HP - 3 - 9, "The centre enemy takes 3 and one Burst 9 (got %d)" % _hp(ritualed, 1))
	_expect(_hp(ritualed, 2) == HP - 3, "An enemy only the base attack reaches takes 3 (got %d)" % _hp(ritualed, 2))
	_expect(_hp(ritualed, 3) == HP - 9, "An enemy only a Burst reaches takes 9 (got %d)" % _hp(ritualed, 3))

func _confirmation(engine: CombatEngine, state: Dictionary, card: String, target: Vector2i) -> Dictionary:
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	state["deck"]["hand"] = [card]
	scene._combat_state = state
	scene._selected_card_index = 0
	scene._pending_actions = engine.card_play_actions(card, engine.prepare_player_card(state, 0))
	scene._pending_action_index = scene._pending_actions.size()
	var targets: Array[Vector2i] = [target]
	scene._pending_selected_targets = targets
	scene._preview_combat_state = _play(engine, state, card, targets)
	var known: Dictionary = scene._pending_card_known_forecast_state()
	var forecast: Dictionary = scene._pass_preview_source_state()
	var chips: Dictionary = scene._turn_order_stagger_preview_delays()
	scene.free()
	return {"known": known, "forecast": forecast, "stagger": chips}

func _test_concealed_ground(engine: CombatEngine) -> void:
	for card: String in ["frost_heave", "shatter", "icebound_chains"]:
		var chains: bool = card == "icebound_chains"
		var target: Vector2i = PLAYER + Vector2i(2 if chains else 3, 0)
		var state: Dictionary = _state(engine, [_enemy(1, target)])
		state["umbra"]["stage"] = "eclipse" if chains else "heart"
		state = engine._apply_umbra_vision(state, {"duration": 2})
		_paint(state, [target], "ice")
		_expect(not engine.is_tile_visible_to_player(state, target) and engine.is_enemy_visible_to_player(state, state["enemies"][0]), card + " fixture reveals the enemy but conceals its Ice")
		var expected_loss: int = {"frost_heave": 9, "shatter": 10, "icebound_chains": 5}[card]
		var hover: Dictionary = _hover(engine, state, card, target)
		var after: Dictionary = _play(engine, state, card, [target])
		var preview: Dictionary = _confirmation(engine, state, card, target)
		_expect(_hover_hp_loss(hover, "enemy_1") == expected_loss and _hp(after, 1) == HP - expected_loss, card + " hover agrees with resolution on concealed Ice")
		_expect(_hp(preview["known"], 1) == HP - expected_loss and _hp(preview["forecast"], 1) == HP - expected_loss, card + " confirmation and rail agree with resolution on concealed Ice")
		if chains:
			_expect(int(engine.stagger_delays_between(state, preview["forecast"]).get(1, 0)) == 6 and int(preview["stagger"].get(1, 0)) == 6,
				"Icebound Chains shows Stagger 6 in the forecast and on its chip")

func _test_concealed_network(engine: CombatEngine) -> void:
	var start := Vector2i(4, 4)
	var end := Vector2i(6, 4)
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 5)), _enemy(2, Vector2i(7, 5))])
	state["umbra"]["stage"] = "eclipse"
	state = engine._apply_umbra_vision(state, {"duration": 2})
	_expect(engine.is_tile_visible_to_player(state, start) and not engine.is_tile_visible_to_player(state, start + Vector2i.RIGHT),
		"Discharge fixture has a visible start and a concealed bridge")
	for card: String in ["discharge", "frost_circuit"]:
		var input: Dictionary = state.duplicate(true)
		_paint(input, [start, start + Vector2i.RIGHT, end], "electrified" if card == "discharge" else "ice")
		if card == "frost_circuit": input["enemies"][0]["pos"] = end
		var loss: int = 7 if card == "discharge" else 2
		var after: Dictionary = _play(engine, input, card, [start])
		var hover: Dictionary = _hover(engine, input, card, start)
		var confirm: Dictionary = _confirmation(engine, input, card, start)
		_expect(_hp(after, 1) == HP - loss and _hp(after, 2) == HP, card + " crosses concealed ground and hits only units in its area")
		_expect(_hover_hp_loss(hover, "enemy_1") == loss and _hp(confirm["known"], 1) == HP - loss and _hp(confirm["forecast"], 1) == HP - loss,
			card + " previews the Vision-revealed unit beyond its concealed bridge")
		_expect(Surface.has_surface(after, end, "electrified") == (card == "frost_circuit"), card + " changes the concealed end of the network")

	# A damaging Lightning card can conduct from the aimed tile through the
	# same bridge even when the target uses Vision rather than local sight.
	var lightning: Dictionary = state.duplicate(true)
	lightning["enemies"][0]["pos"] = end
	_paint(lightning, [start, start + Vector2i.RIGHT, end], "electrified")
	var shocked: Dictionary = _play(engine, lightning, "spark_dart", [start])
	var hover: Dictionary = _hover(engine, lightning, "spark_dart", start)
	var confirm: Dictionary = _confirmation(engine, lightning, "spark_dart", start)
	_expect(_hp(shocked, 1) == HP - 4 and _hp(shocked, 2) == HP, "Spark Dart conducts through the concealed bridge")
	_expect(_hover_hp_loss(hover, "enemy_1") == 4 and _hp(confirm["forecast"], 1) == HP - 4, "Spark Dart previews the same conducted hit")

func _test_footprint_burst(engine: CombatEngine) -> void:
	var bare := Vector2i(5, 4)
	var first := Vector2i(5, 5)
	var second := Vector2i(6, 5)
	var state: Dictionary = _state(engine, [_enemy(1, bare), _enemy(2, Vector2i(5, 6)), _enemy(3, Vector2i(6, 6))])
	state["enemies"][0]["footprint"] = Vector2i(2, 2)
	_paint(state, [second, first], "ice")
	for card: String in ["frost_heave", "shatter"]:
		var hit: int = 9 if card == "frost_heave" else 10
		for aim: Vector2i in [bare, second]:
			var source: Vector2i = first if aim == bare else second
			var after: Dictionary = _play(engine, state, card, [aim])
			var hover: Dictionary = _hover(engine, state, card, aim)
			var bursts: Array = _events(after, "detonate")
			_expect(_hp(after, 1) == HP - hit and _hover_hp_loss(hover, "enemy_1") == hit, card + " hits the whole Ice-standing unit from %s" % str(aim))
			_expect(bursts.size() == 1 and bursts[0]["burst_sources"] == [source] and hover.get("focus_tiles") == bursts[0]["burst_tiles"],
				card + " previews and Bursts the aimed Ice or first Ice in board order")

func _test_additive_base_and_burst(engine: CombatEngine) -> void:
	# Frost Heave: 3 damage and Immobilize. On Ice: also Burst 6 the Ice.
	var plain: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 3))])
	_expect(_targets(engine, plain, "frost_heave").has(Vector2i(5, 4)), "Frost Heave targets an enemy without Ice")
	var heaved: Dictionary = _play(engine, plain, "frost_heave", [Vector2i(5, 4)])
	_expect(_hp(heaved, 1) == HP - 3 and bool(_unit(heaved, 1).get("immobilize", false)), "Without Ice: the base 3 and Immobilize still happen")
	_expect(_hp(heaved, 2) == HP, "Without Ice there is no Burst")
	var iced: Dictionary = plain.duplicate(true)
	_paint(iced, [Vector2i(5, 4)], "ice")
	var burst: Dictionary = _play(engine, iced, "frost_heave", [Vector2i(5, 4)])
	_expect(_hp(burst, 1) == HP - 3 - 6, "On Ice: the target takes 3 and then Burst 6 (got %d)" % _hp(burst, 1))
	_expect(_hp(burst, 2) == HP, "On Ice: the diagonal neighbour is untouched (got %d)" % _hp(burst, 2))
	_expect(not Surface.has_surface(burst, Vector2i(5, 4), "ice") and not Surface.has_surface(burst, Vector2i(5, 4), "rubble"), "The Ice is destroyed and no Rubble is left")
	# Shatter: the base Ice hit can Freeze a Chilled target and melt its Ice;
	# the Burst still happens because the target stood on Ice when played.
	var chilled: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 4))])
	_paint(chilled, [Vector2i(5, 4)], "ice")
	(chilled["enemies"][0] as Dictionary)["chilled"] = true
	var shattered: Dictionary = _play(engine, chilled, "shatter", [Vector2i(5, 4)])
	_expect(_hp(shattered, 2) == HP - 5, "Shatter on Ice Bursts even when its hit melts the Ice (neighbour got %d)" % _hp(shattered, 2))
	_expect(_hp(shattered, 1) <= HP - 10, "Shatter's target takes its 5 and the Burst (got %d)" % _hp(shattered, 1))
	var dry: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 5))])
	var shot: Dictionary = _play(engine, dry, "shatter", [Vector2i(5, 4)])
	_expect(_hp(shot, 1) == HP - 5 and _hp(shot, 2) == HP, "Shatter without Ice: 5 damage, no Burst")

func _test_death_burst_shape(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 5), "ember_tick", 6), _enemy(2, Vector2i(4, 4)), _enemy(3, Vector2i(6, 5)), _enemy(4, Vector2i(7, 5))], Vector2i(5, 6))
	var after: Dictionary = engine._damage_enemy(state, 0, 99)
	var amount: int = int((GameData.enemy_def("ember_tick").get("death_burst", {}) as Dictionary).get("damage", 0))
	_expect(_hp(after, 2) == HP, "The death Burst leaves the diagonal untouched (got %d)" % _hp(after, 2))
	_expect(_hp(after, 3) == HP - amount, "The death Burst reaches an adjacent enemy (got %d)" % _hp(after, 3))
	_expect(_hp(after, 4) == HP, "Two tiles away is outside the death Burst")
	_expect(_hero(after) == HERO_HP - amount, "The death Burst hits the hero next to it (got %d)" % _hero(after))
	_expect(Surface.has_surface(after, Vector2i(5, 5), "fire") and not Surface.has_surface(after, Vector2i(6, 5), "fire"), "The death Burst leaves Fire on its source only")
	var events: Array = after.get("death_burst_events", []) as Array
	var tiles: Array = (events[0] as Dictionary).get("tiles", []) if not events.is_empty() else []
	_expect(tiles.size() == 5 and tiles.has(Vector2i(5, 5)) and not tiles.has(Vector2i(4, 4)), "The death Burst records its cross (got %s)" % str(tiles))

func _test_keg_and_trap(engine: CombatEngine) -> void:
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(5, 2)), _enemy(3, Vector2i(6, 5))], Vector2i(4, 4))
	_terrain(state, "keg_a", Vector2i(5, 4), TerrainCardRules.KEG_KIND, 3, {"burst_damage": 6, "owner_kind": "player", "surface_on_destroy": ""})
	_terrain(state, "keg_b", Vector2i(5, 3), TerrainCardRules.KEG_KIND, 3, {"burst_damage": 6, "owner_kind": "player", "surface_on_destroy": ""})
	state["traps"] = [{"id": "t1", "pos": Vector2i(5, 5), "element": "earth", "damage": 4}]
	var index: int = engine._terrain_index_at_tile(state, Vector2i(5, 4))
	var after: Dictionary = engine._damage_terrain(state.duplicate(true), index, 3)
	_expect(_terrain_at(after, Vector2i(5, 4)).is_empty() and _terrain_at(after, Vector2i(5, 3)).is_empty(), "A keg Burst sets off the keg next to it")
	_expect(_hp(after, 1) == HP - 6, "The keg's Burst reaches its neighboring tile (got %d)" % _hp(after, 1))
	_expect(_hp(after, 2) == HP - 6, "The chained keg's Burst reaches its neighboring tile (got %d)" % _hp(after, 2))
	_expect(_hp(after, 3) == HP, "Outside both crosses is untouched")
	_expect(_hero(after) == HERO_HP - 6, "The keg Burst hits the hero next to it once (got %d)" % _hero(after))
	_expect((after.get("traps", []) as Array).is_empty(), "A trap inside a Burst triggers")
	# Only a trap inside the cross triggers.
	var card: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	_paint(card, [Vector2i(5, 4)], "fire")
	card["traps"] = [
		{"id": "t2", "pos": Vector2i(6, 4), "element": "earth", "damage": 4},
		{"id": "t3", "pos": Vector2i(6, 3), "element": "earth", "damage": 4},
	]
	var fired: Dictionary = _play(engine, card, "pyroclasm", [Vector2i(5, 4)])
	_expect(fired.get("traps", []) == [card["traps"][1]], "A card Burst triggers the adjacent trap and leaves the diagonal trap")

# ------------------------------------------------------------------ preview

## The hover forecast resolves the hovered attack and its automatic follow-up
## Burst: the hero's own Health loss and tile appear in the preview.
func _test_preview_shows_hero_hit(engine: CombatEngine) -> void:
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var hero_tile := Vector2i(4, 4)
	var state: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))], hero_tile)
	_paint(state, [Vector2i(5, 4)], "fire")
	var hand: Array = ["pyroclasm"]
	(state["deck"] as Dictionary)["hand"] = hand
	var prepared: Dictionary = engine.prepare_player_card(state, 0, "play")
	var actions: Array = engine.card_play_actions("pyroclasm", prepared)
	scene.set("_combat_state", prepared)
	scene.set("_preview_combat_state", prepared)
	scene.set("_pending_actions", actions)
	scene.set("_pending_action_index", 0)
	scene.set("_hovered_board_tile", Vector2i(5, 4))
	var result: Dictionary = {}
	scene.call("_append_surface_action_preview", result, {"state": prepared, "action": actions[0], "target_tiles": [Vector2i(5, 4)]})
	var hero_loss: int = int(((result.get("damage_preview", {}) as Dictionary).get("player", {}) as Dictionary).get("hp_loss", 0))
	_expect(hero_loss == 6, "The preview shows the Burst's Health loss on you (got %d)" % hero_loss)
	var focus: Array = result.get("focus_tiles", []) as Array
	_expect(focus.has(hero_tile) and not focus.has(Vector2i(6, 3)) and focus.size() == 5, "The preview outlines the Burst's cross, your tile included (got %s)" % str(focus))
	var enemy_loss: int = int(((result.get("damage_preview", {}) as Dictionary).get("enemy_1", {}) as Dictionary).get("hp_loss", 0))
	_expect(enemy_loss == 15, "The preview shows the target's 9 and the Burst's 6 (got %d)" % enemy_loss)
	# A keg the shot breaks Bursts in the same preview, onto your tile too.
	var keg_state: Dictionary = _state(engine, [_enemy(1, Vector2i(7, 7))], hero_tile)
	_terrain(keg_state, "keg", Vector2i(5, 4), TerrainCardRules.KEG_KIND, 3, {"burst_damage": 6, "owner_kind": "player", "surface_on_destroy": ""})
	(keg_state["deck"] as Dictionary)["hand"] = hand.duplicate()
	var keg_prepared: Dictionary = engine.prepare_player_card(keg_state, 0, "play")
	var keg_actions: Array = engine.card_play_actions("pyroclasm", keg_prepared)
	scene.set("_combat_state", keg_prepared)
	scene.set("_preview_combat_state", keg_prepared)
	scene.set("_pending_actions", keg_actions)
	var keg_result: Dictionary = {}
	scene.call("_append_surface_action_preview", keg_result, {"state": keg_prepared, "action": keg_actions[0], "target_tiles": [Vector2i(5, 4)]})
	var keg_hero_loss: int = int(((keg_result.get("damage_preview", {}) as Dictionary).get("player", {}) as Dictionary).get("hp_loss", 0))
	_expect(keg_hero_loss == 6 and (keg_result.get("focus_tiles", []) as Array).has(hero_tile), "The preview shows a keg's Burst on you (got %d, %s)" % [keg_hero_loss, str(keg_result.get("focus_tiles", []))])
	scene.free()

# ------------------------------------------------------------- card family

func _test_card_family(engine: CombatEngine) -> void:
	# Plasma Arc: each enemy hit on Fire also Bursts that Fire.
	var arc: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 3))], Vector2i(4, 5))
	_paint(arc, [Vector2i(5, 4)], "fire")
	var arced: Dictionary = _play(engine, arc, "plasma_arc", [Vector2i(5, 4)])
	_expect(not Surface.has_surface(arced, Vector2i(5, 4), "fire"), "Plasma Arc Bursts the Fire under the enemy it hits")
	_expect(_hero(arced) == HERO_HP, "Plasma Arc's Burst misses you on its diagonal (got %d)" % _hero(arced))
	# Rockburst: 4 damage to an enemy; on an Outcrop or crate, also Burst 4.
	var rock: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 6))])
	_terrain(rock, "crate", Vector2i(5, 5), "crate", 3)
	var targets: Array[Vector2i] = _targets(engine, rock, "rockburst")
	_expect(targets.has(Vector2i(5, 4)) and targets.has(Vector2i(5, 5)), "Rockburst targets an enemy or a crate")
	var hit: Dictionary = _play(engine, rock, "rockburst", [Vector2i(5, 4)])
	_expect(_hp(hit, 1) == HP - 4 and _hp(hit, 2) == HP and not _terrain_at(hit, Vector2i(5, 5)).is_empty(), "Rockburst on an enemy: 4 damage, no Burst")
	var cracked: Dictionary = _play(engine, rock, "rockburst", [Vector2i(5, 5)])
	_expect(_terrain_at(cracked, Vector2i(5, 5)).is_empty(), "Rockburst destroys the crate")
	_expect(_hp(cracked, 1) == HP - 4 and _hp(cracked, 2) == HP, "Rockburst's Burst 4 reaches the cross (got %d, %d)" % [_hp(cracked, 1), _hp(cracked, 2)])
	var rubble: bool = true
	for tile: Vector2i in [Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 6), Vector2i(4, 5), Vector2i(6, 5)]:
		rubble = rubble and Surface.has_surface(cracked, tile, "rubble")
	_expect(rubble and not Surface.has_surface(cracked, Vector2i(6, 6), "rubble"), "Rockburst leaves Rubble only on the cross")
	# Worldbreak: Burst 10 an adjacent Outcrop you raised; Stagger 2 each enemy hit.
	var world: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 5)), _enemy(2, Vector2i(6, 4)), _enemy(3, Vector2i(5, 5))])
	_terrain(world, "own", Vector2i(4, 4), TerrainCardRules.OUTCROP_KIND, 4, {"owner_kind": "player", "blocks_sight": true})
	var broken: Dictionary = _play(engine, world, "worldbreak", [Vector2i(4, 4)])
	_expect(_hp(broken, 1) == HP - 10, "Worldbreak's Burst reaches the adjacent enemy (got %d)" % _hp(broken, 1))
	_expect(_hp(broken, 2) == HP and _hp(broken, 3) == HP, "Worldbreak leaves the distant and diagonal enemies untouched")
	_expect(_hero(broken) == HERO_HP, "Worldbreak's Burst beside you spares you (got %d)" % _hero(broken))
	var staggered: Dictionary = ((broken.get("turn_flags", {}) as Dictionary).get(preload("res://scripts/card_keyword_rules.gd").STAGGER_TURN_FLAG, {}) as Dictionary)
	_expect(int(staggered.get("1", 0)) > 0, "Worldbreak Staggers each enemy hit (got %s)" % str(staggered))
	# Shattered Reflection: Create Light 2; on one of your illusions, Burst 6 first.
	var mirror: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(6, 5))])
	mirror["illusions"] = [{"id": 1, "pos": Vector2i(5, 4), "hp": 3, "max_hp": 3}]
	_expect(_targets(engine, mirror, "shattered_reflection").has(Vector2i(4, 6)), "Shattered Reflection targets a tile without an illusion")
	var lit: Dictionary = _play(engine, mirror, "shattered_reflection", [Vector2i(4, 6)])
	_expect(_has_light(lit, Vector2i(4, 6)), "Shattered Reflection without an illusion still creates Light")
	var shard: Dictionary = _play(engine, mirror, "shattered_reflection", [Vector2i(5, 4)])
	_expect(_has_light(shard, Vector2i(5, 4)), "Shattered Reflection on an illusion also creates Light")
	_expect(_hp(shard, 1) == HP - 6 and _hp(shard, 2) == HP, "Shattered Reflection Bursts the illusion, reaching the adjacent enemy (got %d)" % _hp(shard, 1))
	_expect((shard.get("illusions", []) as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("hp", 0)) > 0).is_empty(), "The illusion is destroyed")
	# Dust Devil: works on any tile; on Rubble, Burst 5 first.
	var devil: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(6, 5))])
	_expect(_targets(engine, devil, "dust_devil").has(Vector2i(5, 4)), "Dust Devil targets a tile without Rubble")
	var blown: Dictionary = _play(engine, devil, "dust_devil", [Vector2i(5, 4)])
	_expect(_hp(blown, 1) == HP and (_unit(blown, 1).get("pos", NO_TARGET) as Vector2i) == Vector2i(8, 4), "Without Rubble: Push 2 away from the tile, no damage, no Expose")
	_expect(int(_unit(blown, 1).get("expose", 0)) == 0, "Dust Devil no longer Exposes")
	var gritty: Dictionary = devil.duplicate(true)
	_paint(gritty, [Vector2i(5, 4)], "rubble")
	var gusted: Dictionary = _play(engine, gritty, "dust_devil", [Vector2i(5, 4)])
	_expect(_hp(gusted, 1) == HP - 5 and _hp(gusted, 2) == HP, "On Rubble: Burst 5 first reaches the cross (got %d, %d)" % [_hp(gusted, 1), _hp(gusted, 2)])
	_expect(not Surface.has_surface(gusted, Vector2i(5, 4), "rubble"), "Dust Devil's Burst destroys the Rubble")
	# Magma Vent: 4 damage on any tile; on Rubble also Burst 7, leaving Fire.
	var vent: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4)), _enemy(2, Vector2i(6, 4)), _enemy(3, Vector2i(6, 5))])
	var vented: Dictionary = _play(engine, vent, "magma_vent", [Vector2i(5, 4)])
	_expect(_hp(vented, 1) == HP - 4 and _hp(vented, 2) == HP, "Magma Vent without Rubble: 4 damage on the tile")
	var vent_rubble: Dictionary = vent.duplicate(true)
	_paint(vent_rubble, [Vector2i(5, 4)], "rubble")
	var erupted: Dictionary = _play(engine, vent_rubble, "magma_vent", [Vector2i(5, 4)])
	_expect(_hp(erupted, 1) == HP - 4 - 7 and _hp(erupted, 2) == HP - 7 and _hp(erupted, 3) == HP, "Magma Vent on Rubble: 4 and Burst 7 (got %d, %d)" % [_hp(erupted, 1), _hp(erupted, 2)])
	_expect(Surface.has_surface(erupted, Vector2i(5, 4), "fire") and not Surface.has_surface(erupted, Vector2i(6, 4), "fire"), "Magma Vent leaves Fire only on the Burst's own tile")
	# Cinder Second: Block 2 and Draw 1, then the Burst on Fire.
	var second: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	_expect(_targets(engine, second, "cinder_second", 2).has(Vector2i(5, 4)), "Cinder Second can target a tile without Fire")
	var drawn: Dictionary = _play(engine, second, "cinder_second", [Vector2i(5, 4)])
	_expect(int(drawn["player"].get("block", 0)) == 2 and _hp(drawn, 1) == HP, "Cinder Second without Fire: Block 2, no Burst")
	# Shatter Swing on Ice: its Burst next to you spares you.
	var swing: Dictionary = _state(engine, [_enemy(1, Vector2i(4, 4)), _enemy(2, Vector2i(4, 5))])
	_paint(swing, [Vector2i(4, 4)], "ice")
	var swung: Dictionary = _play(engine, swing, "shatter_swing", [Vector2i(4, 4)])
	_expect(_hero(swung) == HERO_HP and _hp(swung, 2) == HP - 6, "Shatter Swing's Burst 6 hits the adjacent enemy and spares you (got %d, %d)" % [_hero(swung), _hp(swung, 2)])
	# Black Sun Dial: each ground tile your Burst destroys feeds it, like Expend.
	var dial: Dictionary = _state(engine, [_enemy(1, Vector2i(5, 4))])
	dial["relics"] = ["black_sun_dial"]
	_paint(dial, [Vector2i(5, 3), Vector2i(5, 5)], "fire")
	var dialed: Dictionary = _play(engine, dial, "inferno_ritual", [Vector2i(5, 4)])
	var pending: int = preload("res://scripts/surface_variety_relic_rules.gd").pending_dial_damage(dialed)
	_expect(pending == 6, "Black Sun Dial gains +3 for each ground tile a Burst destroys (got %d)" % pending)
	# Flashsteam: each Ice tile hit also Bursts.
	var steam: Dictionary = _state(engine, [_enemy(1, Vector2i(6, 4)), _enemy(2, Vector2i(7, 4)), _enemy(3, Vector2i(7, 5))])
	_paint(steam, [Vector2i(6, 4)], "ice")
	var steamed: Dictionary = _play(engine, steam, "flashsteam", [Vector2i(5, 4)])
	_expect(_hp(steamed, 1) == HP - 3 - 4 and _hp(steamed, 2) == HP - 4 and _hp(steamed, 3) == HP, "Flashsteam: 3 in the cross, Burst 4 from the Ice tile (got %d, %d)" % [_hp(steamed, 1), _hp(steamed, 2)])

func _test_loop_registration() -> void:
	var fire: Dictionary = TooltipLoops.find("burst", {"kind": "hero_card", "id": "inferno_ritual"})
	var grimoire: Dictionary = TooltipLoops.find("burst", {"kind": "grimoire", "id": "keyword:burst"})
	_expect(fire.get("id") == "detonate_fire" and TooltipLoops.media_available(fire) and grimoire == fire, "The approved Fire loop is routed from its cards and the Burst Grimoire entry")
	var discharge: Dictionary = TooltipLoops.find("burst", {"kind": "hero_card", "id": "discharge"})
	_expect(discharge.get("id") == "discharge_network" and TooltipLoops.media_available(discharge), "The approved network loop is routed from the Discharge card's Burst")
	var ember_tick: Dictionary = TooltipLoops.find("burst", {"kind": "enemy", "id": "ember_tick"})
	_expect(ember_tick.get("id") == "burst_ember_tick" and TooltipLoops.media_available(ember_tick), "The approved death Burst loop is routed from Ember Tick's Burst")
