extends RefCounted

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatObjectiveHud = preload("res://scripts/combat_objective_hud.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	_test_objective_registry_and_deterministic_mix(expect)
	_test_leader_clear_rewards_only_the_leader(expect)
	_test_survival_reinforcements_join_initiative_and_clock_wins(expect)
	_test_reach_exit_generation_and_completion(expect)
	_test_reach_exit_reward_commits_route_and_preserves_board(expect)
	_test_exit_objective_biases_control_and_blocking_routes(expect)
	_test_objective_persistence_and_ui_surfaces(expect)

static func _test_objective_registry_and_deterministic_mix(expect: Callable) -> void:
	for objective_type: String in [
		CombatObjectiveRules.KILL_ALL,
		CombatObjectiveRules.KILL_LEADER,
		CombatObjectiveRules.SURVIVE,
		CombatObjectiveRules.REACH_EXIT,
	]:
		var definition: Dictionary = CombatObjectiveRules.definition(objective_type)
		expect.call(not str(definition.get("name", "")).is_empty(), "%s should own a player-facing objective name" % objective_type)
		expect.call(not str(definition.get("description", "")).is_empty(), "%s should own exact objective rules text" % objective_type)
		expect.call(AssetLoader.load_texture(str(definition.get("icon_path", ""))) != null, "%s should own a loadable purpose-built objective icon" % objective_type)
	var room: Dictionary = _room_metadata(2)
	var seen: Dictionary = {}
	for seed: int in range(1, 160):
		var first: Dictionary = CombatObjectiveRules.build_for_room(seed, room, Vector2i.UP)
		var second: Dictionary = CombatObjectiveRules.build_for_room(seed, room, Vector2i.UP)
		expect.call(first == second, "Objective selection should be deterministic for a room seed")
		seen[str(first.get("type", ""))] = true
	expect.call(seen.size() == 4, "Later combat rooms should deterministically expose all four objective families across seeds")
	var first_room: Dictionary = _room_metadata(1)
	expect.call(str(CombatObjectiveRules.build_for_room(99, first_room, Vector2i.UP).get("type", "")) == CombatObjectiveRules.KILL_ALL, "The first combat should retain Kill All onboarding")

static func _test_leader_clear_rewards_only_the_leader(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var leader_hp: int = int(GameData.enemy_def("warden").get("max_hp", 1))
	var state: Dictionary = combat.create_combat(701, _combat_layout({
		"type": CombatObjectiveRules.KILL_LEADER,
		"leader_id": 1,
		"leader_type": "warden"
	}, [
		{"id": 1, "type": "warden", "pos": Vector2i(5, 3), "hp": leader_hp, "max_hp": leader_hp, "is_leader": true},
		{"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 8, "max_hp": 8},
		{"id": 3, "type": "cinder_ooze", "pos": Vector2i(6, 4), "hp": 10, "max_hp": 10},
	]), _player_snapshot())
	var resolved: Dictionary = combat.call("_damage_enemy", state, 0, 999)
	var enemies: Array = resolved.get("enemies", [])
	expect.call(combat.combat_outcome(resolved) == "victory", "Killing the marked leader should end combat immediately")
	expect.call(enemies.all(func(enemy: Dictionary) -> bool: return int(enemy.get("hp", 0)) <= 0), "Leader victory should clear every surviving follower for death animation")
	expect.call(bool((enemies[1] as Dictionary).get("objective_cleared", false)) and bool((enemies[2] as Dictionary).get("objective_cleared", false)), "Followers cleared by the objective should be distinguished from player kills")
	var leader_reward: int = int(GameData.enemy_def("warden").get("reward_embers", 0))
	expect.call(int(resolved.get("room_embers", 0)) == leader_reward, "Leader victory should grant only the leader's ember reward")
	expect.call((resolved.get("death_rewards", []) as Array).size() == 1, "Leader victory should not grant follower death rewards or death-play bonuses")
	expect.call((resolved.get("enemies", []) as Array).size() == 3, "An auto-cleared Cinder Ooze should not split after leader victory")

static func _test_survival_reinforcements_join_initiative_and_clock_wins(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var reinforcement_state: Dictionary = combat.create_combat(702, _combat_layout({
		"type": CombatObjectiveRules.SURVIVE,
		"target_clock": 20,
		"reinforcement_interval": 8,
		"next_reinforcement_clock": 8,
		"reinforcement_waves_spawned": 0,
		"reinforcement_pool": ["crawler"]
	}, [
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 8, "max_hp": 8},
	]), _player_snapshot())
	var advanced: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(reinforcement_state))
	var after_spawn: Dictionary = advanced.get("state", {}) as Dictionary
	var spawn_steps: Array = (advanced.get("steps", []) as Array).filter(func(step: Dictionary) -> bool: return str(step.get("kind", "")) == "reinforcement_spawn")
	expect.call(spawn_steps.size() == 1, "Crossing a survival wave time should emit one reinforcement animation step")
	expect.call((after_spawn.get("enemies", []) as Array).size() == 2, "A survival reinforcement should enter the live enemy roster")
	var spawned_enemy: Dictionary = (after_spawn.get("enemies", []) as Array)[1]
	expect.call(bool(spawned_enemy.get("objective_reinforcement", false)) and not (spawned_enemy.get("intent", {}) as Dictionary).is_empty(), "Reinforcements should arrive with an assigned intent")
	var queued_ids: Array[int] = []
	for entry_var: Variant in after_spawn.get("turn_queue", []):
		if typeof(entry_var) == TYPE_DICTIONARY and str((entry_var as Dictionary).get("kind", "")) == "enemy":
			queued_ids.append(int((entry_var as Dictionary).get("enemy_id", -1)))
	expect.call(queued_ids.has(int(spawned_enemy.get("id", -1))), "A survival reinforcement should be scheduled on the initiative queue")

	var victory_state: Dictionary = combat.create_combat(703, _combat_layout({
		"type": CombatObjectiveRules.SURVIVE,
		"target_clock": 9,
		"reinforcement_interval": 16,
		"next_reinforcement_clock": 16,
		"reinforcement_pool": ["crawler"]
	}, [
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 8, "max_hp": 8},
	]), _player_snapshot())
	var survived: Dictionary = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(victory_state)).get("state", {}) as Dictionary
	expect.call(int(survived.get("initiative_clock", 0)) >= 9 and combat.combat_outcome(survived) == "victory", "Survival should resolve as soon as initiative reaches its target without another actor action")

static func _test_reach_exit_generation_and_completion(expect: Callable) -> void:
	var generator := RoomGenerator.new()
	var room: Dictionary = _room_metadata(3)
	var layout: Dictionary = {}
	for seed: int in range(1, 300):
		var candidate: Dictionary = generator.generate_room(seed, room, Vector2i.UP)
		if str((candidate.get("objective", {}) as Dictionary).get("type", "")) == CombatObjectiveRules.REACH_EXIT:
			layout = candidate
			break
	expect.call(not layout.is_empty(), "Seeded generation should produce a Reach the Exit room")
	if layout.is_empty():
		return
	var objective: Dictionary = layout.get("objective", {}) as Dictionary
	expect.call((layout.get("enemies", []) as Array).size() == 7, "A local-depth-three exit encounter should add two enemies to the normal five")
	expect.call((layout.get("enemies", []) as Array).any(func(enemy: Dictionary) -> bool: return str(enemy.get("type", "")) == "chainbound_gaoler"), "Exit encounters should guarantee a movement-control anchor")
	expect.call((layout.get("terrain", []) as Array).size() >= 8, "Exit encounters should add three destructible blockers over the normal minimum")
	var terrain_tiles: Array[Vector2i] = []
	for terrain: Dictionary in layout.get("terrain", []):
		terrain_tiles.append(terrain.get("pos", Vector2i(-1, -1)))
	for target_tile: Vector2i in CombatObjectiveRules.exit_target_tiles(objective):
		expect.call(PathUtils.is_passable(layout.get("grid", []), target_tile), "Each objective threshold should remain a passable interior tile")
		expect.call(not terrain_tiles.has(target_tile), "Destructible terrain should never occupy an objective threshold")
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(704, layout, _player_snapshot())
	var target_tiles: Array[Vector2i] = CombatObjectiveRules.exit_target_tiles(state.get("objective", {}) as Dictionary)
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = target_tiles[0]
	state["player"] = player
	expect.call(combat.combat_outcome(state) == "victory", "Reaching any marked interior threshold should clear the encounter while enemies remain")

static func _test_reach_exit_reward_commits_route_and_preserves_board(expect: Callable) -> void:
	var run_engine := RunEngine.new()
	var combat_engine := CombatEngine.new()
	var current_coord := Vector2i(2, -2)
	var destination := Vector2i(2, -3)
	var target_tile := Vector2i(4, 1)
	var door_tile := Vector2i(4, 0)
	var objective: Dictionary = {
		"type": CombatObjectiveRules.REACH_EXIT,
		"exits": [{
			"target_tile": target_tile,
			"door_tile": door_tile,
			"direction": Vector2i.UP,
			"coord": destination,
			"kind": "outward"
		}]
	}
	var layout: Dictionary = _combat_layout(objective, [
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 8, "max_hp": 8},
		{"id": 2, "type": "warden", "pos": Vector2i(3, 4), "hp": 18, "max_hp": 18},
	])
	layout["coord"] = current_coord
	layout["terrain"] = [{"id": 1, "type": "crate", "pos": Vector2i(4, 4), "hp": 6, "max_hp": 6}]
	layout["traps"] = [{"id": 1, "type": "spike", "pos": Vector2i(3, 3), "damage": 2}]
	layout["loot"] = [{"id": 1, "kind": "embers", "pos": Vector2i(6, 4), "amount": 3, "claimed": false}]
	var combat_state: Dictionary = combat_engine.create_combat(707, layout, _player_snapshot())
	var escaped_player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	escaped_player["pos"] = target_tile
	combat_state["player"] = escaped_player
	var run_state: Dictionary = run_engine.create_new_run(707, ProgressionStore.default_data())
	var current_room: Dictionary = _room_metadata(2)
	current_room["coord"] = current_coord
	current_room["revealed"] = true
	current_room["visited"] = true
	current_room["cleared"] = false
	current_room["sealed"] = false
	run_state["current_room"] = current_coord
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["rooms"] = {_room_key(current_coord): current_room}
	run_state["combat_state"] = combat_state
	run_state["mode"] = "combat"
	var reward_state: Dictionary = run_engine.finish_combat(run_state, combat_state)
	var pending_escape: Dictionary = run_engine.pending_escape(reward_state)
	var board_state: Dictionary = pending_escape.get("board_state", {}) as Dictionary
	expect.call(str(reward_state.get("mode", "")) == "reward", "Reaching an exit should still present the normal combat reward before travel")
	expect.call(pending_escape.get("destination", Vector2i.ZERO) == destination and pending_escape.get("door_tile", Vector2i(-1, -1)) == door_tile, "The crossed threshold should commit its exact destination and door")
	expect.call((board_state.get("enemies", []) as Array).size() == 2 and (board_state.get("enemies", []) as Array).all(func(enemy: Dictionary) -> bool: return int(enemy.get("hp", 0)) > 0), "Every surviving pursuer should remain in the escaped-board snapshot")
	expect.call((board_state.get("terrain", []) as Array).size() == 1 and (board_state.get("traps", []) as Array).size() == 1 and (board_state.get("loot", []) as Array).size() == 1, "Terrain, traps, and loot should remain on the board throughout the reward")
	var reward_cards: Array = (reward_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array
	expect.call(not reward_cards.is_empty(), "The route-lock fixture should offer a card reward")
	if reward_cards.is_empty():
		return
	var escape_state: Dictionary = run_engine.claim_card_reward(reward_state, str(reward_cards[0]))
	expect.call(str(escape_state.get("mode", "")) == RunEngine.MODE_ESCAPE and not run_engine.pending_escape(escape_state).is_empty(), "Claiming the reward should enter automatic escape transition mode without reopening route selection")
	var repaired_escape: Dictionary = run_engine.repair_loaded_run_state(escape_state)
	expect.call(str(repaired_escape.get("mode", "")) == RunEngine.MODE_ESCAPE and not run_engine.pending_escape(repaired_escape).is_empty(), "A saved automatic escape should preserve the locked route and populated board")
	var continued_state: Dictionary = run_engine.continue_pending_escape(repaired_escape)
	expect.call(continued_state.get("current_room", Vector2i.ZERO) == destination, "Automatic escape should advance through the committed door")
	expect.call(run_engine.pending_escape(continued_state).is_empty(), "The committed escape route should clear only after the destination loads")
	expect.call(str(continued_state.get("mode", "")) not in ["reward", RunEngine.MODE_ESCAPE], "Automatic escape should load the destination's normal encounter without reopening route selection")

static func _test_exit_objective_biases_control_and_blocking_routes(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var objective: Dictionary = {
		"type": CombatObjectiveRules.REACH_EXIT,
		"exits": [{"target_tile": Vector2i(4, 1), "door_tile": Vector2i(4, 0)}]
	}
	var state: Dictionary = combat.create_combat(705, _combat_layout(objective, [
		{"id": 1, "type": "chainbound_gaoler", "pos": Vector2i(4, 4), "hp": 12, "max_hp": 12},
	]), _player_snapshot())
	var gaoler_intents: Array = GameData.enemy_def("chainbound_gaoler").get("intents", [])
	var control_intent: Dictionary = {}
	var ordinary_intent: Dictionary = {}
	for intent_var: Variant in gaoler_intents:
		var intent: Dictionary = intent_var
		if CombatObjectiveRules.is_control_intent(intent):
			control_intent = intent
		else:
			ordinary_intent = intent
	expect.call(int(combat.call("_objective_adjusted_intent_weight", state, control_intent)) == maxi(1, int(control_intent.get("weight", 1))) * 3, "Exit encounters should triple authored control-intent weight")
	expect.call(int(combat.call("_objective_adjusted_intent_weight", state, ordinary_intent)) == maxi(1, int(ordinary_intent.get("weight", 1))), "Exit encounters should preserve non-control intent weight")
	var on_route_score: int = int(combat.call("_objective_exit_block_score", state, Vector2i(4, 2)))
	var off_route_score: int = int(combat.call("_objective_exit_block_score", state, Vector2i(7, 6)))
	expect.call(on_route_score < off_route_score, "Exit-aware enemy routing should prefer a tile on the player's shortest exit lane")

static func _test_objective_persistence_and_ui_surfaces(expect: Callable) -> void:
	var objective: Dictionary = {"type": CombatObjectiveRules.SURVIVE, "target_clock": 46, "next_reinforcement_clock": 16}
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(706, _combat_layout(objective, [
		{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 8, "max_hp": 8},
	]), _player_snapshot())
	var engine := RunEngine.new()
	var restored_layout: Dictionary = engine.call("_room_layout_from_combat_state", state)
	expect.call((restored_layout.get("objective", {}) as Dictionary) == objective, "Combat objective state should survive room-layout persistence")
	var pre_battle_host: Node = RunScene.new()
	var preview_chip: Control = pre_battle_host.call("_build_pre_battle_objective_chip", state, Color("d7a85d")) as Control
	expect.call(_labels_text(preview_chip).contains("SURVIVE") and _labels_text(preview_chip).contains("Hold out"), "The room preview should name and explain its combat objective")
	expect.call(preview_chip.find_child("PreBattleObjectiveIcon", true, false) != null, "The room preview should display the objective's purpose-built icon")
	preview_chip.free()
	pre_battle_host.free()
	var hud := CombatObjectiveHud.new()
	hud.set_combat_state(state)
	var detail: Label = hud.find_child("ObjectiveLiveDetail", true, false) as Label
	expect.call(detail != null and detail.text.contains("time remaining") and detail.text.contains("Reinforcements in"), "The live survival HUD should expose both victory time and the next reinforcement clock")
	hud.free()

static func _room_metadata(depth: int) -> Dictionary:
	return {
		"name": "Objective Test",
		"coord": Vector2i(2, -depth),
		"depth": depth,
		"type": "combat",
		"element": "fire",
		"connections": [
			{"door_dir": Vector2i.UP, "coord": Vector2i(2, -depth - 1), "kind": "outward"},
			{"door_dir": Vector2i.RIGHT, "coord": Vector2i(3, -depth), "kind": "lateral"},
			{"door_dir": Vector2i.DOWN, "coord": Vector2i(2, -depth + 1), "kind": "inward"},
			{"door_dir": Vector2i.LEFT, "coord": Vector2i(1, -depth), "kind": "lateral"},
		]
	}

static func _combat_layout(objective: Dictionary, enemies: Array) -> Dictionary:
	return {
		"name": "Objective Fixture",
		"coord": Vector2i(2, -2),
		"type": "combat",
		"depth": 2,
		"element": "fire",
		"grid": _grid(),
		"player_start": Vector2i(4, 7),
		"objective": objective.duplicate(true),
		"enemies": enemies.duplicate(true),
		"traps": [],
		"loot": [],
		"terrain": [],
	}

static func _player_snapshot() -> Dictionary:
	return {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "guarded_step"],
		"relics": [],
		"hand_size": 2,
		"cards_per_turn": 2,
		"draw_per_turn": 2,
	}

static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String] = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

static func _labels_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for label_var: Variant in node.find_children("*", "Label", true, false):
		parts.append((label_var as Label).text)
	return "\n".join(parts)

static func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
