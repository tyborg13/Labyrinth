extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	_test_deterministic_illusion_tie(expect)
	_test_melee_stops_at_first_attack_tile(expect)
	_test_ranged_stays_when_attack_is_available(expect)
	_test_ranged_moves_to_line_of_sight(expect)
	_test_directional_aoe_uses_attack_enabling_endpoint(expect)
	_test_retreat_preserves_followup_attack(expect)
	_test_safe_route_beats_equal_length_trap_route(expect)
	_test_forced_choke_crosses_and_triggers_trap(expect)
	_test_blocking_terrain_is_cleared(expect)
	_test_enemy_congestion_is_a_hard_current_blocker(expect)
	_test_large_footprint_stops_when_attack_is_available(expect)
	_test_threat_exposes_exact_plan_beside_conservative_union(expect)
	_test_enemy_action_analytics_retains_path(expect)

static func _test_deterministic_illusion_tie(expect: Callable) -> void:
	var expected_path: Array[Vector2i] = _tiles([])
	for seed: int in [11, 47, 103, 999]:
		var combat: CombatEngine = CombatEngine.new()
		var enemy: Dictionary = _enemy(Vector2i(4, 4), {
			"name": "Tie Claw",
			"actions": [{"type": "melee", "damage": 3, "range": 1}]
		})
		var state: Dictionary = _state(combat, seed, Vector2i(3, 4), [enemy], [], [], [{"id": 1, "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4}])
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		expect.call(str(plan.get("target_key", "")) == "illusion_1", "Equal-distance target ties should deterministically prefer the illusion")
		var path: Array[Vector2i] = _tiles(plan.get("path", []))
		if expected_path.is_empty():
			expected_path = path
		expect.call(path == expected_path, "Enemy execution paths should not change with RNG state once intent is revealed")

static func _test_melee_stops_at_first_attack_tile(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Long Charge",
		"actions": [
			{"type": "move_toward", "range": 4},
			{"type": "melee", "damage": 3, "range": 1}
		]
	}
	var state: Dictionary = _state(combat, 20, Vector2i(4, 4), [_enemy(Vector2i(4, 6), intent)])
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(plan.get("path", [])) == _tiles([Vector2i(4, 6), Vector2i(4, 5)]), "Melee enemies should stop on the first tile that enables their attack")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(((resolved.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 5), "Resolved melee movement should use the minimal planned destination")
	expect.call(int((resolved.get("player", {}) as Dictionary).get("hp", 0)) == 21, "An enemy that reaches melee range should execute its follow-up attack")

static func _test_ranged_stays_when_attack_is_available(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Steady Shot",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "ranged", "damage": 4, "range": 4}
		]
	}
	var state: Dictionary = _state(combat, 21, Vector2i(2, 4), [_enemy(Vector2i(5, 4), intent, "harrier")])
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(plan.get("path", [])).size() == 1, "Ranged enemies should not move after they already have a legal shot")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(((resolved.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Ranged resolution should preserve an already-valid firing position")
	expect.call(int((resolved.get("player", {}) as Dictionary).get("hp", 0)) == 20, "A stationary ranged enemy should still fire")

static func _test_ranged_moves_to_line_of_sight(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var grid: Array = _grid()
	(grid[4] as Array)[4] = "pillar"
	var intent: Dictionary = {
		"name": "Find a Lane",
		"actions": [
			{"type": "move_toward", "range": 2},
			{"type": "ranged", "damage": 4, "range": 4}
		]
	}
	var state: Dictionary = _state(combat, 22, Vector2i(2, 4), [_enemy(Vector2i(5, 4), intent, "harrier")], [], [], [], grid)
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(bool(plan.get("attack_available", false)), "Ranged planning should find a same-turn line-of-sight endpoint")
	expect.call(_tiles(plan.get("path", [])).size() == 2, "Ranged enemies should move only one tile when one sidestep opens a shot")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(int((resolved.get("player", {}) as Dictionary).get("hp", 0)) == 20, "The line-of-sight endpoint should produce the projected ranged hit")

static func _test_directional_aoe_uses_attack_enabling_endpoint(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Glass Line",
		"actions": [
			{"type": "move_toward", "range": 2},
			{
				"type": "aoe",
				"damage": 5,
				"range": 0,
				"pattern": [[1, 0], [2, 0], [3, 0], [4, 0]],
				"orient_toward_target": true
			}
		]
	}
	var state: Dictionary = _state(combat, 23, Vector2i(6, 4), [_enemy(Vector2i(2, 2), intent)])
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(plan.get("destination", Vector2i.ZERO) == Vector2i(2, 4), "Directional AOE planning should choose the lane that actually enables its pattern")
	expect.call(_tiles(plan.get("projected_attack", [])).has(Vector2i(6, 4)), "Directional AOE projection should include the selected target")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(int((resolved.get("player", {}) as Dictionary).get("hp", 0)) == 19, "Directional AOE resolution should match the projected lane")

static func _test_retreat_preserves_followup_attack(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Kite",
		"actions": [
			{"type": "move_away", "range": 2},
			{"type": "ranged", "damage": 4, "range": 3}
		]
	}
	var state: Dictionary = _state(combat, 24, Vector2i(2, 4), [_enemy(Vector2i(5, 4), intent, "harrier")])
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(plan.get("path", [])).size() == 1, "Retreat intents should stay put instead of retreating out of attack range")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(int((resolved.get("player", {}) as Dictionary).get("hp", 0)) == 20, "A kiting enemy should preserve and execute its follow-up attack")

static func _test_safe_route_beats_equal_length_trap_route(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Safe Advance",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 3, "range": 1}
		]
	}
	var traps: Array = [{"id": "trap_4_4", "pos": Vector2i(4, 4), "element": "fire", "damage": 2}]
	var state: Dictionary = _state(combat, 25, Vector2i(3, 2), [_enemy(Vector2i(5, 4), intent)], [], traps)
	var path: Array[Vector2i] = _tiles(combat.enemy_intent_plan(state, 0).get("path", []))
	expect.call(not path.has(Vector2i(4, 4)), "Enemy planning should prefer a safe attack-enabling route over an equally short trapped route")

static func _test_forced_choke_crosses_and_triggers_trap(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Forced Advance",
		"actions": [
			{"type": "move_toward", "range": 2},
			{"type": "melee", "damage": 3, "range": 1}
		]
	}
	var traps: Array = [{"id": "trap_4_4", "pos": Vector2i(4, 4), "element": "fire", "damage": 2}]
	var state: Dictionary = _state(combat, 26, Vector2i(2, 4), [_enemy(Vector2i(5, 4), intent)], [], traps, [], _corridor_grid())
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(plan.get("path", [])).has(Vector2i(4, 4)), "A finite trap cost should still permit the only attack-enabling route")
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	var resolved: Dictionary = result.get("state", {})
	expect.call((resolved.get("traps", []) as Array).is_empty(), "Voluntary movement across a forced choke should trigger the trap")
	var saw_path: bool = false
	for step_var: Variant in result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		if str(step.get("kind", "")) == "move" and _tiles(step.get("path", [])).has(Vector2i(4, 4)):
			saw_path = true
	expect.call(saw_path, "Movement animation steps should retain the exact trap-crossing path")

static func _test_blocking_terrain_is_cleared(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Break Through",
		"actions": [
			{"type": "move_toward", "range": 2},
			{"type": "melee", "damage": 3, "range": 1}
		]
	}
	var terrain: Array = [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(3, 4), "hp": 3, "max_hp": 3}]
	var state: Dictionary = _state(combat, 27, Vector2i(5, 4), [_enemy(Vector2i(2, 4), intent)], terrain, [], [], _corridor_grid())
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(int(plan.get("blocking_terrain_index", -1)) == 0, "Future-route planning should identify the first destructible obstacle it can clear")
	expect.call(_tiles(plan.get("path", [])).size() == 1, "Enemies should stop before blocking terrain instead of moving through it")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(int(((resolved.get("terrain", []) as Array)[0] as Dictionary).get("hp", 0)) == 0, "An attack intent should clear reachable terrain blocking the future route")

static func _test_enemy_congestion_is_a_hard_current_blocker(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Congested Advance",
		"actions": [
			{"type": "move_toward", "range": 2},
			{"type": "melee", "damage": 3, "range": 1}
		]
	}
	var enemies: Array = [
		_enemy(Vector2i(2, 4), intent),
		_enemy(Vector2i(3, 4), {"name": "Wait", "actions": []}, "crawler", 2)
	]
	var state: Dictionary = _state(combat, 28, Vector2i(5, 4), enemies, [], [], [], _corridor_grid())
	var blocked_plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(blocked_plan.get("path", [])).size() == 1, "Enemies should never move through a currently occupied ally tile")
	expect.call(_tiles(blocked_plan.get("route", [])).has(Vector2i(3, 4)), "Future planning may treat allied congestion as temporary without violating current collision")
	(state.get("enemies", []) as Array)[1]["hp"] = 0
	var clear_plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(clear_plan.get("path", [])).size() > 1, "Enemies should resume progress deterministically once congestion clears")

static func _test_large_footprint_stops_when_attack_is_available(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Large Swipe",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 4, "range": 1}
		]
	}
	var large_enemy: Dictionary = _enemy(Vector2i(4, 4), intent)
	large_enemy["footprint"] = Vector2i(2, 2)
	var state: Dictionary = _state(combat, 29, Vector2i(3, 5), [large_enemy])
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(_tiles(plan.get("path", [])).size() == 1, "Large-footprint enemies should recognize attacks available from any footprint tile")
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0).get("state", {})
	expect.call(int((resolved.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Large-footprint attack resolution should match its stationary projection")

static func _test_threat_exposes_exact_plan_beside_conservative_union(expect: Callable) -> void:
	var combat: CombatEngine = CombatEngine.new()
	var intent: Dictionary = {
		"name": "Projected Claw",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 3, "range": 1}
		]
	}
	var state: Dictionary = _state(combat, 30, Vector2i(4, 4), [_enemy(Vector2i(4, 6), intent)])
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	expect.call(not (threat.get("move", []) as Array).is_empty() and not (threat.get("attack", []) as Array).is_empty(), "Threat preview should preserve the conservative move and attack unions")
	expect.call(_tiles(threat.get("projected_path", [])) == _tiles(plan.get("path", [])), "Threat preview should expose the exact current projected path")
	expect.call(threat.get("projected_destination", Vector2i.ZERO) == plan.get("destination", Vector2i.ZERO), "Threat preview should distinguish the exact destination")
	expect.call(_tiles(threat.get("projected_attack", [])) == _tiles(plan.get("projected_attack", [])), "Threat preview should expose the exact projected attack separately")

static func _test_enemy_action_analytics_retains_path(expect: Callable) -> void:
	var previous_storage_dir: String = AnalyticsStore.storage_dir()
	AnalyticsStore.set_storage_dir("user://enemy_pathfinding_analytics_test")
	AnalyticsStore.clear_storage()
	var run_scene: Node = RunSceneScript.new()
	run_scene.call("_analytics_log_enemy_actions", {
		"steps": [{
			"kind": "move",
			"actor_key": "enemy_1",
			"actor_name": "Crawler",
			"from": Vector2i(5, 4),
			"to": Vector2i(3, 4),
			"path": [Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4)],
			"target_key": "player",
			"target_losses": [],
			"enemy_losses": [],
			"terrain_losses": [],
			"triggered_traps": []
		}]
	})
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	expect.call(events.size() == 1 and str(events[0].get("event_type", "")) == "enemy_action_resolved", "Enemy resolution should emit an additive enemy_action_resolved event")
	if not events.is_empty():
		var payload: Dictionary = events[0].get("payload", {})
		expect.call(int(payload.get("path_steps", -1)) == 2, "Enemy action analytics should retain resolved path length")
		expect.call((payload.get("path", []) as Array).size() == 3, "Enemy action analytics should retain every ordered route tile")
	run_scene.free()
	AnalyticsStore.clear_storage()
	AnalyticsStore.set_storage_dir(previous_storage_dir)

static func _state(combat: CombatEngine, seed: int, player_pos: Vector2i, enemies: Array, terrain: Array = [], traps: Array = [], illusions: Array = [], grid_override: Array = []) -> Dictionary:
	var grid: Array = _grid() if grid_override.is_empty() else grid_override.duplicate(true)
	var layout: Dictionary = {
		"name": "Pathfinding Test",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": grid,
		"player_start": player_pos,
		"enemies": enemies.duplicate(true),
		"terrain": terrain.duplicate(true),
		"traps": traps.duplicate(true),
		"loot": []
	}
	var state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": player_pos, "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = enemies.duplicate(true)
	state["terrain"] = terrain.duplicate(true)
	state["traps"] = traps.duplicate(true)
	state["illusions"] = illusions.duplicate(true)
	state["rng_state"] = seed
	return state

static func _enemy(pos: Vector2i, intent: Dictionary, enemy_type: String = "crawler", enemy_id: int = 1) -> Dictionary:
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": intent.duplicate(true)
	}

static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
		grid.append(row)
	return grid

static func _corridor_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("ash" if y == 4 and x > 0 and x < 7 else "wall")
		grid.append(row)
	return grid

static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result
