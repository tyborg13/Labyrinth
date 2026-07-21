extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const SAMPLE_BATCHES: int = 7
const PREVIEW_ITERATIONS: int = 8
const PREVIEW_REFERENCE_ITERATIONS: int = 2
const SHORTCUT_COLD_ITERATIONS: int = 4
const SHORTCUT_CACHED_ITERATIONS: int = 80
const SHORTCUT_REFERENCE_ITERATIONS: int = 1
const PRESENTATION_COLD_ITERATIONS: int = 3
const PRESENTATION_CACHED_ITERATIONS: int = 50
const MOVE_APPLY_ITERATIONS: int = 80
const BOARD_SUBMISSION_ITERATIONS: int = 300
const VISIBLE_UNIT_ITERATIONS: int = 600

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var combat := CombatEngine.new()
	var run_scene := RunSceneScript.new()
	var state: Dictionary = _benchmark_combat_state(combat)
	var source_snapshot: Dictionary = state.duplicate(true)
	var actions: Array = [
		{"type": "move", "range": 5},
		{"type": "melee", "damage": 40, "range": 1}
	]
	var semantic_errors: Array[String] = []
	var preview: Dictionary = run_scene.call("_card_preview_from_state", "benchmark_move_attack", state, actions, 0)
	var reference_preview: Dictionary = run_scene.call("_card_preview_from_state", "benchmark_move_attack", state, actions, 0, false, false)
	if preview != reference_preview:
		semantic_errors.append("position-only move legality preview differs from fully resolved reference")
	var move_targets: Array = preview.get("target_tiles", [])
	if move_targets.is_empty():
		push_error("PERF BENCHMARK: move preview produced no targets")
		quit(1)
		return
	var hovered_tile: Vector2i = move_targets[move_targets.size() - 1]
	run_scene.set("_hovered_board_tile", hovered_tile)
	var movement_plan: Dictionary = combat.movement_plan_for_player_action(state, actions[0], move_targets)
	for move_target_var: Variant in move_targets:
		var move_target: Vector2i = move_target_var
		var standard_path: Array[Vector2i] = combat.path_for_player_action(state, actions[0], move_target)
		var planned_path: Array[Vector2i] = combat.path_from_player_movement_plan(movement_plan, move_target)
		if planned_path != standard_path:
			semantic_errors.append("planned path differs at %s" % str(move_target))
		var standard_state: Dictionary = combat.apply_player_action(state, actions[0], move_target)
		var planned_state: Dictionary = combat.apply_prevalidated_player_move(state, actions[0], move_target, planned_path)
		if planned_state != standard_state:
			semantic_errors.append("planned move result differs at %s" % str(move_target))

	# Warm caches and the GDScript VM before collecting wall-clock samples.
	run_scene.call("_card_preview_from_state", "benchmark_move_attack", state, actions, 0)
	run_scene.call("_preview_shortcuts_for_current_action", preview)
	run_scene.call("_preview_presentation", preview)

	var results: Dictionary = {"schema_version": 2}
	results["move_target_count"] = move_targets.size()
	_record_metric(results, "preview_us_per_call", _measure_samples(PREVIEW_ITERATIONS, func() -> void:
		run_scene.call("_card_preview_from_state", "benchmark_move_attack", state, actions, 0)
	))
	_record_metric(results, "preview_reference_us_per_call", _measure_samples(PREVIEW_REFERENCE_ITERATIONS, func() -> void:
		run_scene.call("_card_preview_from_state", "benchmark_move_attack", state, actions, 0, false, false)
	))
	_record_metric(results, "shortcut_cold_us_per_call", _measure_samples(SHORTCUT_COLD_ITERATIONS, func() -> void:
		run_scene.call("_invalidate_preview_derived_caches")
		run_scene.call("_preview_shortcuts_for_current_action", preview)
	))
	run_scene.call("_preview_shortcuts_for_current_action", preview)
	_record_metric(results, "shortcut_cached_us_per_call", _measure_samples(SHORTCUT_CACHED_ITERATIONS, func() -> void:
		run_scene.call("_preview_shortcuts_for_current_action", preview)
	))
	_record_metric(results, "shortcut_reference_us_per_call", _measure_samples(SHORTCUT_REFERENCE_ITERATIONS, func() -> void:
		run_scene.call("_preview_shortcuts_for_current_action", preview, true)
	))
	_record_metric(results, "presentation_cold_us_per_call", _measure_samples(PRESENTATION_COLD_ITERATIONS, func() -> void:
		run_scene.call("_invalidate_preview_derived_caches")
		run_scene.call("_preview_presentation", preview)
	))
	run_scene.call("_preview_presentation", preview)
	_record_metric(results, "presentation_cached_us_per_call", _measure_samples(PRESENTATION_CACHED_ITERATIONS, func() -> void:
		run_scene.call("_preview_presentation", preview)
	))

	var move_action: Dictionary = actions[0]
	_record_metric(results, "move_apply_us_per_call", _measure_samples(MOVE_APPLY_ITERATIONS, func() -> void:
		combat.apply_player_action(state, move_action, hovered_tile)
	))

	var board := CombatBoardView.new()
	board.size = Vector2(1280.0, 720.0)
	var presentation: Dictionary = {
		"focus_tiles": [hovered_tile],
		"path_tiles": combat.path_for_player_action(state, move_action, hovered_tile),
		"active_door_tiles": {},
		"locked_door_tiles": {}
	}
	board.set_combat_state(state, move_targets, [], hovered_tile, "", "", {}, {}, presentation)
	_record_metric(results, "board_submission_us_per_call", _measure_samples(BOARD_SUBMISSION_ITERATIONS, func() -> void:
		board.set_combat_state(state, move_targets, [], hovered_tile, "", "", {}, {}, presentation)
	))
	_record_metric(results, "visible_units_us_per_call", _measure_samples(VISIBLE_UNIT_ITERATIONS, func() -> void:
		board.call("_visible_units")
	))
	results["loaded_unit_asset_type_count"] = (board.get("_unit_assets_loaded") as Dictionary).size()

	var shortcut_result: Dictionary = run_scene.call("_preview_shortcuts_for_current_action", preview)
	var shortcut_digest: int = _shortcut_digest(shortcut_result)
	var shortcut_plan_count: int = (shortcut_result.get("plans", {}) as Dictionary).size()
	var reference_shortcuts: Dictionary = run_scene.call("_preview_shortcuts_for_current_action", preview, true)
	if _shortcut_digest(reference_shortcuts) != shortcut_digest:
		semantic_errors.append("spatially filtered shortcuts differ from exhaustive reference")
	run_scene.call("_invalidate_preview_derived_caches")
	var rebuilt_shortcuts: Dictionary = run_scene.call("_preview_shortcuts_for_current_action", preview)
	if _shortcut_digest(rebuilt_shortcuts) != shortcut_digest:
		semantic_errors.append("shortcut digest changed after cache invalidation")
	var first_presentation: Dictionary = run_scene.call("_preview_presentation", preview)
	var second_presentation: Dictionary = run_scene.call("_preview_presentation", preview)
	if first_presentation != second_presentation:
		semantic_errors.append("cached presentation differs from cold presentation")
	if state != source_snapshot:
		semantic_errors.append("source combat state was mutated")
	results["source_state_unchanged"] = state == source_snapshot
	results["planned_move_results_match"] = not _has_error_prefix(semantic_errors, "planned")
	results["shortcut_digest"] = shortcut_digest
	results["presentation_digest"] = hash(first_presentation)
	results["shortcut_plan_count"] = shortcut_plan_count
	results["semantic_errors"] = semantic_errors

	if semantic_errors.is_empty():
		print("PERF RESULT: %s" % JSON.stringify(results))
	else:
		push_error("PERF RESULT: FAIL %s" % JSON.stringify(results))
	board.free()
	run_scene.free()
	quit(0 if semantic_errors.is_empty() else 1)

func _measure_samples(iterations: int, operation: Callable) -> Dictionary:
	var samples: Array = []
	for _batch: int in range(SAMPLE_BATCHES):
		var started_usec: int = Time.get_ticks_usec()
		for _iteration: int in range(iterations):
			operation.call()
		samples.append(float(Time.get_ticks_usec() - started_usec) / float(iterations))
	samples.sort()
	var p95_index: int = mini(samples.size() - 1, maxi(0, int(ceil(float(samples.size()) * 0.95)) - 1))
	return {
		"median": float(samples[floori(float(samples.size()) * 0.5)]),
		"p95": float(samples[p95_index]),
		"min": float(samples[0]),
		"max": float(samples[samples.size() - 1])
	}

func _record_metric(results: Dictionary, key: String, stats: Dictionary) -> void:
	results[key] = float(stats.get("median", 0.0))
	results["%s_p95" % key] = float(stats.get("p95", 0.0))
	results["%s_min" % key] = float(stats.get("min", 0.0))
	results["%s_max" % key] = float(stats.get("max", 0.0))

func _shortcut_digest(shortcuts: Dictionary) -> int:
	var plans: Dictionary = shortcuts.get("plans", {})
	var tiles: Array = plans.keys()
	tiles.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_tile: Vector2i = a
		var b_tile: Vector2i = b
		return a_tile.y < b_tile.y or (a_tile.y == b_tile.y and a_tile.x < b_tile.x)
	)
	var canonical: Array = []
	for tile_var: Variant in tiles:
		var plan: Dictionary = plans.get(tile_var, {})
		canonical.append({
			"tile": tile_var,
			"move_target": plan.get("move_target", Vector2i(-1, -1)),
			"move_distance": int(plan.get("move_distance", -1)),
			"path_tiles": plan.get("path_tiles", []),
			"movement_risk_chips": plan.get("movement_risk_chips", []),
			"action_index": int(plan.get("action_index", -1)),
			"action": plan.get("action", {}),
			"state": plan.get("state", {})
		})
	return hash(canonical)

func _has_error_prefix(errors: Array[String], prefix: String) -> bool:
	for error: String in errors:
		if error.begins_with(prefix):
			return true
	return false

func _benchmark_combat_state(combat: CombatEngine) -> Dictionary:
	var layout: Dictionary = {
		"name": "Performance Chamber",
		"coord": Vector2i(3, 3),
		"type": "combat",
		"element": "ice",
		"grid": _benchmark_grid(),
		"player_start": Vector2i(4, 4),
		"enemies": _benchmark_enemies(),
		"traps": [
			{"id": "trap_a", "pos": Vector2i(3, 4), "element": "fire", "damage": 20, "burn": 10},
			{"id": "trap_b", "pos": Vector2i(4, 3), "element": "ice", "damage": 20, "freeze": 1},
			{"id": "trap_c", "pos": Vector2i(5, 4), "element": "earth", "damage": 20, "immobilize": true}
		],
		"loot": [
			{"id": "ember_a", "kind": "embers", "amount": 2, "pos": Vector2i(2, 4), "claimed": false},
			{"id": "ember_b", "kind": "embers", "amount": 2, "pos": Vector2i(4, 6), "claimed": false}
		],
		"terrain": []
	}
	var state: Dictionary = combat.create_combat(73013, layout, {
		"hp": 320,
		"max_hp": 320,
		"deck_cards": ["quick_stab", "sidestep_slash", "guarded_step"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(4, 4),
		"hp": 320,
		"max_hp": 320,
		"block": 30,
		"stoneskin": 20
	}
	state["enemies"] = _benchmark_enemies()
	return state

func _benchmark_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

func _benchmark_enemies() -> Array:
	return [
		_enemy(1, "crawler", Vector2i(2, 2)),
		_enemy(2, "harrier", Vector2i(6, 2)),
		_enemy(3, "crawler", Vector2i(2, 6)),
		_enemy(4, "harrier", Vector2i(6, 6)),
		_enemy(5, "crawler", Vector2i(4, 1)),
		_enemy(6, "harrier", Vector2i(7, 4))
	]

func _enemy(enemy_id: int, enemy_type: String, pos: Vector2i) -> Dictionary:
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": 180,
		"max_hp": 180,
		"block": 10,
		"stoneskin": 0,
		"intent": {"name": "Pressure", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 30, "range": 1}]}
	}
