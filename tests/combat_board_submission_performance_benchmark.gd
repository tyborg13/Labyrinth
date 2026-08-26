extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const SAMPLE_BATCHES: int = 7
const ANIMATION_SAMPLES: int = 180

var _errors: Array[String] = []
var _trusted_same_reference_supported: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var board := CombatBoardView.new()
	_trusted_same_reference_supported = _method_argument_count(board, "set_combat_state") >= 10
	board.size = Vector2(1920.0, 1080.0)
	root.add_child(board)
	await process_frame
	await process_frame

	var state: Dictionary = _stress_state()
	var presentation: Dictionary = _base_presentation(state)
	_set_board_state(board, state, presentation)
	await process_frame
	var player: Dictionary = state.get("player", {}) as Dictionary
	var player_center: Vector2 = board.call("world_position_for_unit_origin", player, player.get("pos", Vector2i.ZERO)) as Vector2

	var retained_layers: Array = board.call("_retained_render_layers") as Array
	_expect(retained_layers.size() >= 150, "stress board must exercise the production per-tile retained-layer fanout")
	var identical_presentations: Array[Dictionary] = []
	var effect_presentations: Array[Dictionary] = []
	var movement_presentations: Array[Dictionary] = []
	for sample_index: int in range(ANIMATION_SAMPLES):
		identical_presentations.append(presentation)
		var effect_frame: Dictionary = presentation.duplicate(false)
		effect_frame["effect_progress"] = float(sample_index + 1) / float(ANIMATION_SAMPLES)
		effect_presentations.append(effect_frame)
		var movement_progress: float = float(sample_index + 1) / float(ANIMATION_SAMPLES)
		movement_presentations.append(_moving_presentation(
			presentation,
			"player",
			player_center + Vector2(96.0 * movement_progress, -48.0 * movement_progress),
			Vector2i(5, 3)
		))

	_verify_incremental_geometry(board, state, presentation, "player", player, player_center + Vector2(52.0, -26.0), Vector2i(5, 3))
	var enemy: Dictionary = (board.call("_units_by_key", board.call("_visible_units")) as Dictionary).get("enemy_1", {}) as Dictionary
	var enemy_center: Vector2 = board.call("world_position_for_unit_origin", enemy, enemy.get("pos", Vector2i.ZERO)) as Vector2
	_verify_incremental_geometry(board, state, presentation, "enemy_1", enemy, enemy_center + Vector2(-44.0, 22.0), Vector2i(2, 2))
	_verify_in_place_enemy_commit(board, state, presentation, "enemy_1", Vector2i(2, 2))
	_set_board_state(board, state, presentation)

	var results: Dictionary = {
		"schema_version": 1,
		"workload_id": "combat_board_submission_animation_fanout_v1",
		"retained_layer_count": retained_layers.size(),
		"animation_samples": ANIMATION_SAMPLES,
	}
	results["identical_submission_usec"] = _measure_submission_batches(board, state, identical_presentations)
	results["effect_progress_submission_usec"] = _measure_submission_batches(board, state, effect_presentations)
	results["movement_submission_usec"] = _measure_submission_batches(board, state, movement_presentations)

	board.call("set_submission_performance_instrumentation_enabled", true)
	_submit_sequence(board, state, effect_presentations)
	results["effect_progress_phase_profile"] = board.call("submission_performance_instrumentation_snapshot")
	board.call("set_submission_performance_instrumentation_enabled", true)
	_submit_sequence(board, state, movement_presentations)
	results["movement_phase_profile"] = board.call("submission_performance_instrumentation_snapshot")
	board.call("set_submission_performance_instrumentation_enabled", false)
	results["semantic_errors"] = _errors.duplicate()

	if _errors.is_empty():
		print("COMBAT BOARD SUBMISSION PERF RESULT: %s" % JSON.stringify(results))
	else:
		push_error("COMBAT BOARD SUBMISSION PERF RESULT: FAIL %s" % JSON.stringify(results))
	board.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _measure_submission_batches(board: Control, state: Dictionary, presentations: Array[Dictionary]) -> Dictionary:
	var samples: Array[float] = []
	for _batch: int in range(SAMPLE_BATCHES):
		var started_usec: int = Time.get_ticks_usec()
		_submit_sequence(board, state, presentations)
		samples.append(float(Time.get_ticks_usec() - started_usec) / float(presentations.size()))
	return _stats(samples)

func _submit_sequence(board: Control, state: Dictionary, presentations: Array[Dictionary]) -> void:
	for presentation: Dictionary in presentations:
		_set_board_state(board, state, presentation)

func _set_board_state(board: Control, state: Dictionary, presentation: Dictionary, trust_same_reference_state: bool = true) -> void:
	var arguments: Array = [state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation]
	if _trusted_same_reference_supported:
		arguments.append(trust_same_reference_state)
	board.callv("set_combat_state", arguments)

func _method_argument_count(object: Object, method_name: String) -> int:
	for method_var: Variant in object.get_method_list():
		if typeof(method_var) != TYPE_DICTIONARY:
			continue
		var method: Dictionary = method_var as Dictionary
		if str(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return 0

func _moving_presentation(base: Dictionary, actor_key: String, center: Vector2, draw_tile: Vector2i) -> Dictionary:
	var result: Dictionary = base.duplicate(false)
	result["unit_world_positions"] = {actor_key: center}
	result["unit_footprint_world_positions"] = {actor_key: center}
	result["unit_draw_tiles"] = {actor_key: draw_tile}
	return result

func _verify_incremental_geometry(
	board: Control,
	state: Dictionary,
	base: Dictionary,
	actor_key: String,
	unit: Dictionary,
	center: Vector2,
	draw_tile: Vector2i
) -> void:
	_expect(not unit.is_empty(), "%s must exist in the stress board" % actor_key)
	if unit.is_empty():
		return
	_set_board_state(board, state, base)
	var movement: Dictionary = _moving_presentation(base, actor_key, center, draw_tile)
	_set_board_state(board, state, movement)
	var incremental_hud_entries: Array = (board.get("_hud_layout_entries_cache") as Array).duplicate(true)
	var incremental_health_rects: Dictionary = (board.get("_hud_health_rects_cache") as Dictionary).duplicate(true)
	var incremental_obstructions: Array = (board.get("_foreground_obstruction_entries_cache") as Array).duplicate(true)

	board.set("_hud_health_rects_source_snapshot", {})
	board.call("_rebuild_hud_health_rects_cache")
	var full_hud_entries: Array = board.get("_hud_layout_entries_cache") as Array
	var full_health_rects: Dictionary = board.get("_hud_health_rects_cache") as Dictionary
	var full_obstructions: Array = board.call("_foreground_obstruction_entries", board.call("_visible_units")) as Array
	_expect(incremental_hud_entries == full_hud_entries, "%s incremental HUD entries must equal a forced full rebuild" % actor_key)
	_expect(incremental_health_rects == full_health_rects, "%s incremental health rects must equal a forced full rebuild" % actor_key)
	_expect(incremental_obstructions == full_obstructions, "%s incremental obstruction entries must equal a forced full rebuild" % actor_key)

func _verify_in_place_enemy_commit(
	board: Control,
	state: Dictionary,
	base: Dictionary,
	actor_key: String,
	committed_tile: Vector2i
) -> void:
	# Enemy animation playback interpolates through presentation, then mutates its
	# working combat dictionary in place at the authored step boundary. The first
	# post-mutation submission must remain conservative before later frames opt
	# back into the stable same-reference fast path.
	var original_enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	_set_board_state(board, state, base)
	var units_by_key: Dictionary = board.call("_units_by_key", board.call("_visible_units")) as Dictionary
	var enemy_before: Dictionary = units_by_key.get(actor_key, {}) as Dictionary
	var enemy_center: Vector2 = board.call("world_position_for_unit_origin", enemy_before, enemy_before.get("pos", Vector2i.ZERO)) as Vector2
	_set_board_state(board, state, _moving_presentation(base, actor_key, enemy_center + Vector2(36.0, 18.0), committed_tile))

	var enemies: Array = state.get("enemies", []) as Array
	for enemy_index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[enemy_index] as Dictionary
		if "enemy_%d" % int(enemy.get("id", -1)) != actor_key:
			continue
		enemy["pos"] = committed_tile
		enemies[enemy_index] = enemy
		break
	_set_board_state(board, state, base, false)
	var incremental_units: Array = (board.get("_visible_units_cache") as Array).duplicate(true)
	var incremental_hud_entries: Array = (board.get("_hud_layout_entries_cache") as Array).duplicate(true)
	var incremental_health_rects: Dictionary = (board.get("_hud_health_rects_cache") as Dictionary).duplicate(true)
	var incremental_obstructions: Array = (board.get("_foreground_obstruction_entries_cache") as Array).duplicate(true)
	var committed_enemy: Dictionary = (board.call("_units_by_key", incremental_units) as Dictionary).get(actor_key, {}) as Dictionary
	_expect(committed_enemy.get("pos", Vector2i(-1, -1)) == committed_tile, "%s committed in-place movement must replace interpolated geometry" % actor_key)

	board.set("_submission_cache_initialized", false)
	board.set("_submission_cache_valid", false)
	board.call("_rebuild_submission_caches")
	board.set("_hud_health_rects_source_snapshot", {})
	board.call("_rebuild_hud_health_rects_cache")
	_expect(incremental_units == (board.get("_visible_units_cache") as Array), "%s committed in-place units must equal a forced full rebuild" % actor_key)
	_expect(incremental_hud_entries == (board.get("_hud_layout_entries_cache") as Array), "%s committed in-place HUD entries must equal a forced full rebuild" % actor_key)
	_expect(incremental_health_rects == (board.get("_hud_health_rects_cache") as Dictionary), "%s committed in-place health rects must equal a forced full rebuild" % actor_key)
	_expect(incremental_obstructions == (board.get("_foreground_obstruction_entries_cache") as Array), "%s committed in-place obstructions must equal a forced full rebuild" % actor_key)

	state["enemies"] = original_enemies
	_set_board_state(board, state, base, false)

func _stress_state() -> Dictionary:
	var combat := CombatEngine.new()
	var layout: Dictionary = {
		"name": "Submission Performance Chamber",
		"coord": Vector2i(13, 0),
		"depth": 13,
		"type": "combat",
		"element": "lightning",
		"grid": _stress_grid(),
		"player_start": Vector2i(4, 4),
		"enemies": _stress_enemies(),
		"traps": [],
		"loot": [],
		"terrain": [],
	}
	var state: Dictionary = combat.create_combat(13009021, layout, {
		"hp": 120,
		"max_hp": 120,
		"deck_cards": ["quick_stab", "sidestep_slash", "guarded_step"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0,
	})
	state["player"] = {"pos": Vector2i(4, 4), "hp": 120, "max_hp": 120, "block": 30, "stoneskin": 20}
	state["enemies"] = _stress_enemies()
	state["illusions"] = [
		{"id": 1, "pos": Vector2i(2, 3), "hp": 8, "max_hp": 8},
		{"id": 2, "pos": Vector2i(6, 3), "hp": 8, "max_hp": 8},
	]
	state["elemental_intensity"] = {"fire": 6, "ice": 6, "lightning": 6, "air": 6, "earth": 6}
	return state

func _base_presentation(state: Dictionary) -> Dictionary:
	return {
		"board_backdrop_visible": true,
		"visible_enemy_ids": [1, 2, 3, 4, 5, 6, 7],
		"umbra_stage": "deep",
		"umbra_visible_tiles": [Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 5)],
		"umbra_light_sources": [{"pos": Vector2i(4, 4), "radius": 2, "remaining_activations": 3}],
		"effect": {
			"kind": "elemental_attack",
			"style": "fireball",
			"element": "fire",
			"from": Vector2i(4, 4),
			"to": Vector2i(6, 2),
			"progress": 0.0,
		},
	}

func _stress_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

func _stress_enemies() -> Array:
	return [
		_enemy(1, "crawler", Vector2i(1, 1)),
		_enemy(2, "harrier", Vector2i(3, 1)),
		_enemy(3, "cinder_ooze", Vector2i(5, 1)),
		_enemy(4, "frostglass_lancer", Vector2i(7, 1)),
		_enemy(5, "chainbound_gaoler", Vector2i(1, 6)),
		_enemy(6, "bile_bloomer", Vector2i(7, 6)),
		_enemy(7, "lightning_wisp", Vector2i(7, 4)),
	]

func _enemy(enemy_id: int, enemy_type: String, pos: Vector2i) -> Dictionary:
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": 999,
		"max_hp": 999,
		"block": 20,
		"stoneskin": 3,
		"intent": {"name": "Pressure", "actions": [{"type": "melee", "damage": 3, "range": 1}]},
	}

func _stats(source: Array[float]) -> Dictionary:
	var values: Array[float] = source.duplicate()
	values.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"min": values[0] if not values.is_empty() else 0.0,
		"max": values[-1] if not values.is_empty() else 0.0,
		"mean": total / float(values.size()) if not values.is_empty() else 0.0,
	}

func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var index: int = clampi(int(ceil(float(values.size()) * ratio)) - 1, 0, values.size() - 1)
	return values[index]

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
