extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const SAMPLE_BATCHES: int = 7
const PREVIEW_ITERATIONS: int = 8
const PREVIEW_REFERENCE_ITERATIONS: int = 2
const ENEMY_FORECAST_ITERATIONS: int = 8
const ENEMY_ROUND_ITERATIONS: int = 4
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

	var scheduled_forecast_state: Dictionary = state.duplicate(true)
	scheduled_forecast_state["current_actor"] = {"kind": "transition"}
	scheduled_forecast_state["initiative_clock"] = 0
	scheduled_forecast_state["turn_queue"] = [
		{"kind": "enemy", "enemy_id": 1, "time": 1, "seq": 1},
		{"kind": "enemy", "enemy_id": 2, "time": 2, "seq": 2},
		{"kind": "player", "time": 3, "seq": 3},
	]
	var scheduled_forecast_snapshot: Dictionary = scheduled_forecast_state.duplicate(true)
	var forecast_reference: Dictionary = combat.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled_forecast_state)
	var forecast_digest: int = hash(forecast_reference)
	_record_metric(results, "enemy_forecast_us_per_call", _measure_samples(ENEMY_FORECAST_ITERATIONS, func() -> void:
		combat.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled_forecast_state)
	))
	var forecast_repeat: Dictionary = combat.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled_forecast_state)
	combat.set_runtime_performance_instrumentation_enabled(true)
	var profiled_forecast: Dictionary = combat.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled_forecast_state)
	results["enemy_forecast_profile"] = combat.runtime_performance_instrumentation_snapshot()
	combat.set_runtime_performance_instrumentation_enabled(false)
	if profiled_forecast != forecast_reference:
		semantic_errors.append("instrumented enemy forecast differs from the uninstrumented result")
	if forecast_repeat != forecast_reference:
		semantic_errors.append("enemy forecast result changed between identical runs")
	if scheduled_forecast_state != scheduled_forecast_snapshot:
		semantic_errors.append("enemy forecast mutated its source state")
	if (forecast_reference.get("steps", []) as Array).is_empty():
		semantic_errors.append("enemy forecast benchmark must resolve at least one revealed enemy action")
	results["enemy_forecast_digest"] = forecast_digest
	results["enemy_forecast_step_count"] = (forecast_reference.get("steps", []) as Array).size()
	results["enemy_forecast_source_unchanged"] = scheduled_forecast_state == scheduled_forecast_snapshot

	var scheduled_round_state: Dictionary = state.duplicate(true)
	scheduled_round_state["current_actor"] = {"kind": "transition"}
	scheduled_round_state["initiative_clock"] = 0
	var scheduled_round_queue: Array = []
	for enemy_index: int in range((_benchmark_enemies() as Array).size()):
		scheduled_round_queue.append({"kind": "enemy", "enemy_id": enemy_index + 1, "time": enemy_index + 1, "seq": enemy_index + 1})
	scheduled_round_queue.append({"kind": "player", "time": scheduled_round_queue.size() + 1, "seq": scheduled_round_queue.size() + 1})
	scheduled_round_state["turn_queue"] = scheduled_round_queue
	var scheduled_round_snapshot: Dictionary = scheduled_round_state.duplicate(true)
	var turn_order_after_pop_state: Dictionary = scheduled_round_state.duplicate(true)
	var pop_result: Dictionary = combat.call("_pop_next_actor", turn_order_after_pop_state) as Dictionary
	turn_order_after_pop_state = pop_result.get("state", turn_order_after_pop_state) as Dictionary
	var shared_turn_order_context: Dictionary = combat.call(
		"_turn_order_projection_context",
		turn_order_after_pop_state,
		combat.umbra_visible_tile_lookup(turn_order_after_pop_state)
	) as Dictionary
	var independent_before_order: Array[Dictionary] = combat.current_turn_order(scheduled_round_state)
	var shared_before_order: Array[Dictionary] = combat.current_turn_order(scheduled_round_state, 8, shared_turn_order_context)
	var independent_after_order: Array[Dictionary] = combat.current_turn_order(turn_order_after_pop_state)
	var shared_after_order: Array[Dictionary] = combat.current_turn_order(turn_order_after_pop_state, 8, shared_turn_order_context)
	if independent_before_order != shared_before_order or independent_after_order != shared_after_order:
		semantic_errors.append("shared turn-order projection context differs from independent projection")
	var committed_round: Dictionary = _resolve_enemy_round(combat, scheduled_round_state, true)
	var no_commit_round: Dictionary = _resolve_enemy_round(combat, scheduled_round_state, false)
	var committed_presentation_steps: Array = _steps_without_commits(committed_round.get("steps", []))
	var no_commit_presentation_steps: Array = _steps_without_commits(no_commit_round.get("steps", []))
	var committed_step_count: int = _step_kind_count(committed_round.get("steps", []), "commit")
	var no_commit_step_count: int = _step_kind_count(no_commit_round.get("steps", []), "commit")
	if committed_round.get("state", {}) != no_commit_round.get("state", {}):
		semantic_errors.append("enemy round without recovery commits produced a different final state")
	if committed_round.get("player_turn_before_state", {}) != no_commit_round.get("player_turn_before_state", {}):
		semantic_errors.append("enemy round without recovery commits produced a different player-turn boundary state")
	if committed_presentation_steps != no_commit_presentation_steps:
		semantic_errors.append("enemy round without recovery commits changed presentation steps")
	if committed_step_count <= 0:
		semantic_errors.append("committed enemy round produced no recovery checkpoints")
	if no_commit_step_count != 0:
		semantic_errors.append("no-commit enemy round still produced recovery checkpoints")
	if scheduled_round_state != scheduled_round_snapshot:
		semantic_errors.append("enemy round benchmark mutated its source state")
	# Warm both modes before measuring full deterministic enemy rounds.
	_resolve_enemy_round(combat, scheduled_round_state, true)
	_resolve_enemy_round(combat, scheduled_round_state, false)
	_record_metric(results, "enemy_round_committed_us_per_call", _measure_samples(ENEMY_ROUND_ITERATIONS, func() -> void:
		_resolve_enemy_round(combat, scheduled_round_state, true)
	))
	_record_metric(results, "enemy_round_no_commit_us_per_call", _measure_samples(ENEMY_ROUND_ITERATIONS, func() -> void:
		_resolve_enemy_round(combat, scheduled_round_state, false)
	))
	combat.set_runtime_performance_instrumentation_enabled(true)
	var profiled_no_commit_round: Dictionary = _resolve_enemy_round(combat, scheduled_round_state, false)
	results["enemy_round_no_commit_profile"] = combat.runtime_performance_instrumentation_snapshot()
	combat.set_runtime_performance_instrumentation_enabled(false)
	if profiled_no_commit_round != no_commit_round:
		semantic_errors.append("instrumented no-commit enemy round differs from the uninstrumented result")
	results["enemy_round_commit_step_count"] = committed_step_count
	results["enemy_round_no_commit_step_count"] = no_commit_step_count
	results["enemy_round_presentation_step_count"] = no_commit_presentation_steps.size()
	results["enemy_round_final_state_digest"] = hash(no_commit_round.get("state", {}))
	results["enemy_round_presentation_digest"] = hash(no_commit_presentation_steps)
	results["enemy_round_source_unchanged"] = scheduled_round_state == scheduled_round_snapshot
	results["turn_order_shared_context_matches"] = independent_before_order == shared_before_order and independent_after_order == shared_after_order

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

func _resolve_enemy_round(combat: CombatEngine, state: Dictionary, include_commit_steps: bool) -> Dictionary:
	var next_state: Dictionary = state
	var steps: Array = []
	var player_turn_before_state: Dictionary = {}
	var safety: int = 0
	while combat.combat_outcome(next_state) == "" and safety < 100:
		safety += 1
		var slice_result: Dictionary = combat.advance_one_activation_with_steps(next_state, include_commit_steps)
		next_state = slice_result.get("state", next_state) as Dictionary
		steps.append_array(slice_result.get("steps", []))
		var slice_player_before: Variant = slice_result.get("player_turn_before_state", {})
		if typeof(slice_player_before) == TYPE_DICTIONARY and not (slice_player_before as Dictionary).is_empty():
			player_turn_before_state = slice_player_before as Dictionary
		if bool(slice_result.get("complete", false)):
			break
	return {
		"state": next_state,
		"steps": steps,
		"player_turn_before_state": player_turn_before_state,
		"safety": safety,
	}

func _steps_without_commits(steps_var: Variant) -> Array:
	var result: Array = []
	for step_var: Variant in steps_var as Array:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var as Dictionary
		if str(step.get("kind", "")) != "commit":
			result.append(step)
	return result

func _step_kind_count(steps_var: Variant, kind: String) -> int:
	var count: int = 0
	for step_var: Variant in steps_var as Array:
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("kind", "")) == kind:
			count += 1
	return count

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
