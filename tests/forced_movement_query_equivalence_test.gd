extends SceneTree
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

# Oracle for the straight-line collision law (spec/forced_movement.md): a
# visible enemy in range (line of sight past range 1) is a legal Push/Pull
# target iff the action deals damage, or resolving it on a private copy moves
# the target or records a collision. The fast query only inspects the first
# step of the resolved line; the oracle runs the real resolver.

var failures: Array[String]
var comparisons: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := CombatEngine.new()
	for fixture_name: String in ["open", "dense", "heart", "surface_ready", "blocked"]:
		for variant: int in range(4):
			var state: Dictionary = Fixture._fixture(engine, fixture_name)
			if variant == 1:
				state["enemies"][0]["footprint"] = Vector2i(2, 2)
				state["illusions"] = [{"id": 1, "pos": Vector2i(4, 4), "hp": 10}]
			elif variant == 2:
				state["grid"][4][4] = "wall"
				state["enemies"][0]["hp"] = 0
				state["terrain"] = [{"id": "force_box", "pos": Vector2i(6, 4), "hp": 60, "max_hp": 60}]
			elif variant == 3:
				state["relics"] = ["anchor_chain", "cinderbrand_tongs", "thunder_relay"]
				state["skill_ids"] = ["open_sky"]
				state["enemies"][0]["immobilize"] = true
				state["enemies"][0]["block"] = 5
				Surface.place(state, Vector2i(3, 4), "ice")
			var before: Dictionary = state.duplicate(true)
			for kind: String in ["push", "pull"]:
				for distance: int in [1, 3, 9]:
					for amount: int in [0, 1, 3]:
						for damage: int in [0, 3]:
							for direction: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.UP]:
								var action: Dictionary = {"type": kind, "range": distance, "amount": amount, "damage": damage, "force_direction": direction}
								if variant == 3:
									action["_allow_sideways_force"] = true
								_compare(engine, state, action)
			check(state == before, "Force queries must not change source actors, collisions, surfaces or history")
	print("TEST RESULT: %s — %d forced-movement query comparisons (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", comparisons, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _compare(engine: CombatEngine, state: Dictionary, action: Dictionary) -> void:
	var actual: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	check(actual == _oracle_targets(engine, state, action), "Complete ordered force targets must match the resolving oracle (%s)" % str(action))
	var accept: Callable = func(tile: Vector2i) -> bool: return tile.x >= 4
	var limited: Array[Vector2i] = engine.valid_targets_for_player_action(state, action, 1, accept)
	var expected_limited: Array[Vector2i]
	for tile: Vector2i in actual:
		if accept.call(tile):
			expected_limited.append(tile)
			break
	check(limited == expected_limited, "Limited accepted targets must retain authoritative order and predicate")
	for tile: Vector2i in actual:
		_compare_line(engine, state, action, tile)

func _compare_line(engine: CombatEngine, state: Dictionary, action: Dictionary, tile: Vector2i) -> void:
	var enemy_index: int = engine._enemy_index_at_tile(state, tile)
	if enemy_index < 0:
		return
	var enemy: Dictionary = engine._normalized_enemy(state["enemies"][enemy_index])
	var options: Array[Vector2i] = engine.force_direction_options_for_player_action(state, action, tile)
	var chosen: Vector2i = engine.resolved_force_direction_for_player_action(state, action, tile)
	var stored: Vector2i = action.get("force_direction", Vector2i.ZERO)
	check(options.is_empty() or chosen == (stored if options.has(stored) else options[0]), "Resolution uses a candidate stored direction, else the default")
	var path: Array[Vector2i] = engine.forced_movement_tiles_for_player_action(state, action, tile)
	var trial: Dictionary = engine.apply_prevalidated_player_action(state.duplicate(true), action, tile)
	var moved: Dictionary = engine._surface_actor(trial, "enemy", int(enemy.get("id", -1)))
	if int(moved.get("hp", 0)) <= 0:
		return
	var landing: Vector2i = path[path.size() - 1] if not path.is_empty() else enemy.get("pos", Vector2i.ZERO)
	check(moved.get("pos") == landing, "The hover path must end where the committed line lands (%s at %s)" % [str(action), str(tile)])
	var offset: Vector2i = moved.get("pos", Vector2i.ZERO) - enemy.get("pos", Vector2i.ZERO)
	check(offset == Vector2i.ZERO or offset == chosen * PathUtils.manhattan(Vector2i.ZERO, offset), "Committed displacement is one straight line along the resolved direction")

func _oracle_targets(engine: CombatEngine, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var resolved: Dictionary = engine._resolved_surface_action(state, action)
	if not engine.player_action_can_resolve(state, resolved):
		return result
	var origin: Vector2i = resolved.get("_origin_tile", (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO))
	var reach: int = int(resolved.get("range", 1))
	var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
	for index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = engine._normalized_enemy(state["enemies"][index])
		if int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy, visible):
			continue
		var in_range: bool = false
		for enemy_tile: Vector2i in engine._enemy_footprint_tiles(enemy):
			if PathUtils.manhattan(origin, enemy_tile) <= reach and (reach <= 1 or engine.combat_line_of_sight(state, origin, enemy_tile)):
				in_range = true
				break
		if not in_range:
			continue
		var legal: bool = int(engine._action_with_target_state_relic_modifiers(state, resolved, index).get("damage", 0)) > 0
		if not legal:
			var trial: Dictionary = engine.apply_prevalidated_player_action(state.duplicate(true), action, enemy.get("pos", Vector2i.ZERO))
			var after: Dictionary = engine._surface_actor(trial, "enemy", int(enemy.get("id", -1)))
			legal = after.get("pos") != enemy.get("pos")
			for event: Dictionary in engine._surface_events_since(state, trial):
				if str(event.get("kind", "")) == "force_collision":
					legal = true
		if legal:
			engine._append_enemy_footprint_targets(result, enemy)
	return result

func check(ok: bool, message: String) -> void:
	comparisons += 1
	if not ok and failures.size() < 12:
		failures.append(message)
		push_error(message)
