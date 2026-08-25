extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunScene = preload("res://scripts/run_scene.gd")

const ATTACK_TYPES := ["melee", "ranged", "aoe", "push", "pull"]
const MOVEMENT_TYPES := ["move", "blink"]
const PLAYER_START := Vector2i(2, 4)
const GRID_WIDTH: int = 13
const GRID_HEIGHT: int = 9


static func run(expect: Callable) -> void:
	_test_every_move_then_attack_card_builds_enemy_shortcut(expect)
	_test_move_only_card_does_not_build_enemy_shortcut(expect)
	_test_every_card_has_one_player_target_decision(expect)
	_test_intensity_attacks_always_have_a_baseline(expect)
	_test_ranged_aoe_can_anchor_on_an_empty_tile(expect)
	_test_action_upgrades_preserve_one_target_decision(expect)
	_test_preferred_routes_collect_pickups_without_crossing_traps(expect)


static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_live_single_click_sequence(tree, expect, "slipstream_cut", "clear", Vector2i(5, 4), "Move-melee-push shortcuts should choose their previewed default push direction without another click")
	await _test_live_single_click_sequence(tree, expect, "sidestep_slash", "heart", Vector2i(4, 4), "Visible move-melee targets should retain one-click shortcuts under Umbra")


static func _test_every_move_then_attack_card_builds_enemy_shortcut(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var cases: Array = _move_then_attack_cases(combat)
	var covered_card_ids: Array = []
	var covered_attack_types: Dictionary = {}
	var covered_melee_cards: int = 0
	for case_index: int in range(cases.size()):
		var case: Dictionary = cases[case_index]
		var card_id: String = str(case.get("card_id", ""))
		var card_actions: Array = case.get("actions", []) as Array
		var card_attack_action: Dictionary = card_actions[int(case.get("attack_index", -1))]
		var attack_range: int = maxi(1, int(card_attack_action.get("range", 1)))
		var enemy_tile := Vector2i(PLAYER_START.x + attack_range + 1, PLAYER_START.y)
		var state: Dictionary = _combat_state(combat, card_id, enemy_tile, 84000 + case_index)
		state = combat.prepare_player_card(state, 0, "play")
		var actions: Array = combat.card_play_actions(card_id, state)
		var runtime_case: Dictionary = _first_move_then_attack_case(combat, actions)
		var move_index: int = int(runtime_case.get("move_index", -1))
		var attack_index: int = int(runtime_case.get("attack_index", -1))
		expect.call(move_index >= 0 and attack_index >= 0, "%s should retain its move-attack sequence after runtime card preparation" % card_id)
		if move_index < 0 or attack_index < 0:
			continue
		var attack_action: Dictionary = actions[attack_index]
		state = _apply_actions_before_movement(combat, state, actions, move_index, expect, card_id)
		var run_scene := RunScene.new()
		var preview: Dictionary = run_scene.call("_card_preview_from_state", card_id, state, actions, move_index)
		expect.call(
			int(preview.get("action_index", -1)) == move_index,
			"%s should enter its movement step before building a combined shortcut" % card_id
		)
		expect.call(not (preview.get("target_tiles", []) as Array).is_empty(), "%s should retain ordinary movement destinations beside its enemy shortcut" % card_id)
		var shortcuts: Dictionary = run_scene.call("_preview_shortcuts_for_current_action", preview)
		var plan: Dictionary = (shortcuts.get("plans", {}) as Dictionary).get(enemy_tile, {}) as Dictionary
		expect.call(
			not plan.is_empty(),
			"%s should let the player select the enemy once for its move-then-%s sequence" % [card_id, str(attack_action.get("type", ""))]
		)
		if not plan.is_empty():
			expect.call(
				(plan.get("move_target", Vector2i(-1, -1)) as Vector2i).x >= 0,
				"%s shortcut should include movement when the enemy starts outside attack range" % card_id
			)
			expect.call(
				int(plan.get("action_index", -1)) == attack_index,
				"%s shortcut should resolve the intended follow-up attack" % card_id
			)
		covered_card_ids.append(card_id)
		covered_attack_types[str(attack_action.get("type", ""))] = true
		if str(attack_action.get("type", "")) == "melee":
			covered_melee_cards += 1
		run_scene.free()

	expect.call(covered_card_ids.size() == 15, "Current card data should expose all 15 move-then-attack cards to shortcut coverage")
	expect.call(covered_melee_cards == 12, "Current card data should expose all 12 move-then-melee cards to prepared-runtime shortcut coverage")
	expect.call(covered_attack_types.keys().all(func(attack_type: Variant) -> bool: return str(attack_type) in ["melee", "push"]), "Combined movement cards should only use adjacent melee or push follow-ups")


static func _test_move_only_card_does_not_build_enemy_shortcut(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var card_id := "guarded_step"
	var actions: Array = (GameData.card_def(card_id).get("actions", []) as Array).duplicate(true)
	var enemy_tile := Vector2i(5, PLAYER_START.y)
	var state: Dictionary = _combat_state(combat, card_id, enemy_tile, 84999)
	var run_scene := RunScene.new()
	var preview: Dictionary = run_scene.call("_card_preview_from_state", card_id, state, actions, 0)
	var shortcuts: Dictionary = run_scene.call("_preview_shortcuts_for_current_action", preview)
	expect.call(
		(shortcuts.get("plans", {}) as Dictionary).is_empty(),
		"Movement followed only by automatic utility effects should keep normal tile targeting"
	)
	run_scene.free()


static func _test_every_card_has_one_player_target_decision(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var converted_aoe_ids: Array[String] = ["ember_rain", "molten_reach", "rime_shard", "windlass_volley"]
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var actions: Array = card.get("actions", []) as Array
		var targeted_indices: Array[int] = []
		var has_movement: bool = false
		var has_ranged_attack: bool = false
		for action_index: int in range(actions.size()):
			var action: Dictionary = actions[action_index] as Dictionary
			var action_type: String = str(action.get("type", ""))
			has_movement = has_movement or action_type in MOVEMENT_TYPES
			has_ranged_attack = has_ranged_attack or action_type in ["ranged", "aoe"] or (action_type in ["push", "pull"] and int(action.get("range", 0)) > 1)
			if action_type in ATTACK_TYPES:
				expect.call(not action.has("requires_intensity"), "%s should always retain a baseline attack instead of gating the whole attack behind intensity" % card_id)
			if combat.player_action_needs_target(action):
				targeted_indices.append(action_index)
		expect.call(not (has_movement and has_ranged_attack), "%s should not combine movement with a ranged target" % card_id)
		expect.call(targeted_indices.size() <= 2, "%s should never expose more than one combined target decision" % card_id)
		if targeted_indices.size() == 2:
			var move_action: Dictionary = actions[targeted_indices[0]] as Dictionary
			var attack_action: Dictionary = actions[targeted_indices[1]] as Dictionary
			expect.call(str(move_action.get("type", "")) == "move", "%s multi-action targeting should start with ordinary movement" % card_id)
			expect.call(str(attack_action.get("type", "")) in ["melee", "push"] and int(attack_action.get("range", 0)) == 1, "%s multi-action targeting should finish with one adjacent enemy click" % card_id)
			expect.call(bool(attack_action.get("required", false)), "%s enemy shortcut should commit its adjacent follow-up attack when the enemy is selected" % card_id)
		if bool(card.get("flurry", false)):
			var state: Dictionary = _combat_state(combat, card_id, Vector2i(8, PLAYER_START.y), 86000 + card_id.hash())
			state["cards_played_this_turn"] = 0
			var unresolved_targets: int = 0
			for runtime_action_var: Variant in combat.card_play_actions(card_id, state):
				var runtime_action: Dictionary = runtime_action_var as Dictionary
				if combat.player_action_needs_target(runtime_action) and not bool(runtime_action.get("reuse_previous_target", false)):
					unresolved_targets += 1
			expect.call(unresolved_targets <= 1, "%s Flurry repetitions should reuse the first selected target" % card_id)
	for card_id: String in converted_aoe_ids:
		var actions: Array = GameData.card_def(card_id).get("actions", []) as Array
		expect.call(actions.any(func(action: Variant) -> bool: return str((action as Dictionary).get("type", "")) == "aoe" and not ((action as Dictionary).get("pattern", []) as Array).is_empty()), "%s should provide an authored ranged AOE pattern" % card_id)


static func _test_preferred_routes_collect_pickups_without_crossing_traps(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var goal := Vector2i(5, PLAYER_START.y)
	var pickup_tile := Vector2i(3, PLAYER_START.y - 1)
	var state: Dictionary = _combat_state(combat, "guarded_step", Vector2i(9, PLAYER_START.y), 87001)
	state["loot"] = [{"id": "route_gear", "kind": "equipment", "equipment_id": "test_gear", "pos": pickup_tile, "claimed": false}]
	var action: Dictionary = {"type": "move", "range": 5}
	var plan: Dictionary = combat.movement_plan_for_player_action(state, action, [goal])
	var pickup_path: Array[Vector2i] = combat.path_from_player_movement_plan(plan, goal)
	expect.call(pickup_path.has(pickup_tile), "Preferred movement should spend spare range to collect useful gear")
	state["traps"] = [{"id": "route_trap", "pos": pickup_tile, "element": "fire", "damage": 2, "triggered": false}]
	plan = combat.movement_plan_for_player_action(state, action, [goal])
	var safe_path: Array[Vector2i] = combat.path_from_player_movement_plan(plan, goal)
	expect.call(not safe_path.has(pickup_tile), "Avoiding a live trap should outrank collecting a pickup")


static func _test_intensity_attacks_always_have_a_baseline(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _combat_state(combat, "rime_shard", Vector2i(5, PLAYER_START.y), 87002)
	state["elemental_intensity"] = {"fire": 0, "ice": 1, "lightning": 1, "air": 0, "earth": 0}
	for card_id: String in ["rime_shard", "volt_surge"]:
		var actions: Array = GameData.card_def(card_id).get("actions", []) as Array
		var attack: Dictionary = actions[1] as Dictionary
		var element_id: String = "ice" if card_id == "rime_shard" else "lightning"
		var below_state: Dictionary = state.duplicate(true)
		(below_state.get("elemental_intensity", {}) as Dictionary)[element_id] = 1
		var threshold_state: Dictionary = below_state.duplicate(true)
		(threshold_state.get("elemental_intensity", {}) as Dictionary)[element_id] = 2
		expect.call(combat.player_action_can_resolve(below_state, attack), "%s should remain targetable below its intensity threshold" % card_id)
		expect.call(not combat.valid_targets_for_player_action(below_state, attack).is_empty(), "%s should retain legal attack targets below its intensity threshold" % card_id)
		expect.call(
			combat.final_damage_for_player_action(threshold_state, attack) > combat.final_damage_for_player_action(below_state, attack),
			"%s should gain damage at its threshold instead of gating its entire attack" % card_id
		)


static func _test_ranged_aoe_can_anchor_on_an_empty_tile(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var center := Vector2i(4, 4)
	var state: Dictionary = _combat_state(combat, "ember_rain", Vector2i(4, 3), 87003)
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0},
		{"id": 2, "type": "crawler", "pos": Vector2i(5, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0},
	]
	var action: Dictionary = (GameData.card_def("ember_rain").get("actions", []) as Array)[0] as Dictionary
	expect.call(combat.valid_targets_for_player_action(state, action).has(center), "Ranged AOE should allow an empty visible tile as its selected center")
	var result: Dictionary = combat.apply_player_action(state, action, center)
	for enemy_var: Variant in result.get("enemies", []):
		expect.call(int((enemy_var as Dictionary).get("hp", 20)) < 20, "An empty-center AOE should damage enemies on the other pattern squares")
	var light_sources: Array = (result.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	expect.call(not light_sources.is_empty() and (light_sources[0] as Dictionary).get("pos", Vector2i(-1, -1)) == center, "An AOE Light rider should anchor at the selected empty center")


static func _test_action_upgrades_preserve_one_target_decision(expect: Callable) -> void:
	var action_element: Dictionary = {"kind": "action", "key": "action:new"}
	var ranged_options: Array = GameData.upgrade_options_for_element("bone_dart", action_element, {})
	var targetless_options: Array = GameData.upgrade_options_for_element("brace", action_element, {})
	expect.call(
		not ranged_options.any(func(option: Variant) -> bool: return str((option as Dictionary).get("label", "")) == "Add Move 1"),
		"Targeted cards should not regain a second decision through the Add Move upgrade"
	)
	expect.call(
		targetless_options.any(func(option: Variant) -> bool: return str((option as Dictionary).get("label", "")) == "Add Move 1"),
		"Targetless cards should retain Add Move as their single target decision"
	)


static func _move_then_attack_cases(combat: CombatEngine) -> Array:
	var cases: Array = []
	var cards: Dictionary = GameData.cards()
	var card_ids: Array = cards.keys()
	card_ids.sort()
	for card_id_var: Variant in card_ids:
		var card_id: String = str(card_id_var)
		var actions: Array = ((cards.get(card_id, {}) as Dictionary).get("actions", []) as Array).duplicate(true)
		var card_case: Dictionary = _first_move_then_attack_case(combat, actions)
		if card_case.is_empty():
			continue
		card_case["card_id"] = card_id
		card_case["actions"] = actions
		cases.append(card_case)
	return cases


static func _first_move_then_attack_case(combat: CombatEngine, actions: Array) -> Dictionary:
	for move_index: int in range(actions.size()):
		if typeof(actions[move_index]) != TYPE_DICTIONARY:
			continue
		if str((actions[move_index] as Dictionary).get("type", "")) not in MOVEMENT_TYPES:
			continue
		var attack_index: int = _next_targeted_attack_index(combat, actions, move_index + 1)
		if attack_index >= 0:
			return {"move_index": move_index, "attack_index": attack_index}
	return {}


static func _next_targeted_attack_index(combat: CombatEngine, actions: Array, start_index: int) -> int:
	for action_index: int in range(start_index, actions.size()):
		if typeof(actions[action_index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[action_index]
		if not combat.player_action_needs_target(action):
			continue
		return action_index if str(action.get("type", "")) in ATTACK_TYPES else -1
	return -1


static func _apply_actions_before_movement(combat: CombatEngine, source_state: Dictionary, actions: Array, move_index: int, expect: Callable, card_id: String) -> Dictionary:
	var state: Dictionary = source_state
	for action_index: int in range(move_index):
		var action: Dictionary = actions[action_index]
		if not combat.player_action_can_resolve(state, action):
			continue
		if combat.player_action_needs_target(action):
			var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
			expect.call(not targets.is_empty(), "%s setup action %d should have a legal target" % [card_id, action_index])
			if targets.is_empty():
				return state
			state = combat.apply_player_action(state, action, _setup_target_away_from_attack_lane(targets))
		else:
			state = combat.apply_player_action(state, action)
	return state


static func _setup_target_away_from_attack_lane(targets: Array[Vector2i]) -> Vector2i:
	for target: Vector2i in targets:
		if target.y != PLAYER_START.y:
			return target
	return targets[0]


static func _combat_state(combat: CombatEngine, card_id: String, enemy_tile: Vector2i, seed: int) -> Dictionary:
	var enemy: Dictionary = {
		"id": 1,
		"type": "crawler",
		"pos": enemy_tile,
		"hp": 100,
		"max_hp": 100,
		"block": 0,
		"stoneskin": 0
	}
	var layout: Dictionary = {
		"name": "Move Attack Shortcut Test",
		"coord": Vector2i.ZERO,
		"type": "combat",
		"element": "air",
		"grid": _open_grid(),
		"player_start": PLAYER_START,
		"enemies": [enemy],
		"traps": [],
		"loot": [],
		"terrain": []
	}
	var state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": PLAYER_START,
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [enemy]
	return state


static func _test_live_single_click_sequence(tree: SceneTree, expect: Callable, card_id: String, umbra_stage: String, enemy_tile: Vector2i, message: String) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(packed != null, "%s live shortcut fixture should load RunScene" % card_id)
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	var combat := CombatEngine.new()
	var layout: Dictionary = _live_combat_layout(umbra_stage, enemy_tile)
	var state: Dictionary = _combat_state(combat, card_id, enemy_tile, 85000 + enemy_tile.x)
	state["grid"] = layout.get("grid", [])
	state["umbra"] = combat.call("_initial_umbra_state", layout)
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state.erase("player_turn_restrictions")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_refresh_ui")
	await tree.process_frame
	await tree.process_frame
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var board: Node = instance.get_node("BoardUnderlay/CombatBoard")
	expect.call((board.get("attack_tiles") as Array).has(enemy_tile), "%s: enemy should be exposed as the combined shortcut target" % message)
	expect.call(not (board.get("move_tiles") as Array).is_empty(), "%s: ordinary movement destinations should remain available beside the enemy shortcut" % message)
	instance.call("_on_board_tile_hovered", enemy_tile)
	await tree.process_frame
	await tree.process_frame
	var path_tiles: Array = ((board.get("presentation") as Dictionary).get("path_tiles", []) as Array)
	expect.call(path_tiles.size() >= 2, "%s: hovering the enemy shortcut should show a movement route arrow" % message)
	expect.call(path_tiles[0] == PLAYER_START if not path_tiles.is_empty() else false, "%s: the shortcut route arrow should begin at the player" % message)
	expect.call(path_tiles[path_tiles.size() - 1] != enemy_tile if not path_tiles.is_empty() else false, "%s: the shortcut route arrow should end on the adjacent melee approach tile" % message)
	await instance.call("_on_board_tile_clicked", enemy_tile)
	var resolved_state: Dictionary = instance.get("_combat_state") as Dictionary
	var resolved_enemy: Dictionary = (resolved_state.get("enemies", []) as Array)[0] as Dictionary
	expect.call(int(resolved_enemy.get("hp", 100)) < 100, "%s: the enemy click should resolve melee damage" % message)
	expect.call(int(instance.get("_selected_card_index")) < 0, "%s: the enemy click should finish instead of pausing on another target choice" % message)
	instance.queue_free()
	await tree.process_frame


static func _live_combat_layout(umbra_stage: String, enemy_tile: Vector2i) -> Dictionary:
	return {
		"name": "Live Move Attack Shortcut Test",
		"coord": Vector2i.ZERO,
		"type": "combat",
		"element": "air",
		"umbra_stage": umbra_stage,
		"grid": _open_grid(),
		"player_start": PLAYER_START,
		"enemies": [{"id": 1, "type": "crawler", "pos": enemy_tile, "hp": 100, "max_hp": 100, "block": 0}],
		"traps": [],
		"loot": [],
		"terrain": []
	}


static func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(GRID_HEIGHT):
		var row: Array = []
		for x: int in range(GRID_WIDTH):
			row.append("wall" if x == 0 or y == 0 or x == GRID_WIDTH - 1 or y == GRID_HEIGHT - 1 else "stone")
		grid.append(row)
	return grid
