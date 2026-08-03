extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const WARMUP_FRAMES: int = 45
const PHASE_FRAMES: int = 150
const OUTPUT_DIR: String = "user://performance/render_benchmark"

var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	await process_frame
	var state: Dictionary = _stress_state()
	var idle_presentation: Dictionary = _idle_presentation()
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, idle_presentation)
	for _frame: int in range(WARMUP_FRAMES):
		await process_frame
	_reset_render_instrumentation(board)

	var results: Dictionary = {
		"schema_version": 1,
		"workload_id": "combat_board_max_content_v1",
		"warmup_frames": WARMUP_FRAMES,
		"phase_frames": PHASE_FRAMES,
		"viewport": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"ambient_particle_count": int(board.call("_ambient_particle_count", "ice", 81, 6)),
		"idle": await _measure_phase(board, state, idle_presentation, "idle"),
		"interaction": await _measure_phase(board, state, idle_presentation, "interaction"),
		"movement": await _measure_phase(board, state, _movement_presentation(), "movement"),
		"action_heavy": await _measure_phase(board, state, _action_presentation(), "action_heavy")
	}
	results["final_objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	results["final_nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	results["final_orphan_nodes"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	results["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_expect(int(results.get("final_orphan_nodes", -1)) == 0, "render benchmark must not leave orphan nodes")

	await process_frame
	await process_frame
	var screenshot: Image = viewport.get_texture().get_image()
	var screenshot_path: String = ProjectSettings.globalize_path("%s/action_heavy.png" % OUTPUT_DIR)
	if screenshot.get_size() != VIEWPORT_SIZE:
		var aspect_matches: bool = is_equal_approx(
			float(screenshot.get_width()) / float(maxi(1, screenshot.get_height())),
			float(VIEWPORT_SIZE.x) / float(VIEWPORT_SIZE.y)
		)
		_expect(aspect_matches, "render benchmark backing buffer must retain the authored 16:9 canvas")
		if aspect_matches:
			screenshot.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_expect(screenshot.get_size() == VIEWPORT_SIZE, "render benchmark screenshot must normalize to 1920x1080")
	_expect(screenshot.save_png(screenshot_path) == OK, "render benchmark screenshot could not be saved")
	results["in_place_state_redraw_verified"] = await _verify_in_place_state_redraw(board, idle_presentation)
	results["semantic_errors"] = _errors

	if _errors.is_empty():
		print("RENDER PERF RESULT: %s" % JSON.stringify(results))
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		push_error("RENDER PERF RESULT: FAIL %s" % JSON.stringify(results))
	quit(0 if _errors.is_empty() else 1)

func _measure_phase(board: Control, state: Dictionary, source_presentation: Dictionary, phase_name: String) -> Dictionary:
	var frame_intervals_ms: Array[float]
	var process_ms: Array[float]
	var draw_calls: Array[float]
	var objects_in_frame: Array[float]
	var primitives_in_frame: Array[float]
	_reset_render_instrumentation(board)
	var previous_tick: int = Time.get_ticks_usec()
	for frame_index: int in range(PHASE_FRAMES):
		if phase_name == "action_heavy":
			# CombatBoardView retains caller-owned snapshots. Give each animation
			# frame a distinct snapshot so the benchmark measures real submissions
			# instead of mutating the board's current dictionary in place.
			var presentation: Dictionary = source_presentation.duplicate(true)
			var phase: float = float(frame_index % 60) / 59.0
			presentation["impact_progress"] = phase
			presentation["impact_strength"] = 1.0 - phase * 0.35
			var effect: Dictionary = (presentation.get("effect", {}) as Dictionary).duplicate(true)
			effect["progress"] = phase
			presentation["effect"] = effect
			board.call("set_combat_state", state, [], _attack_tiles(), Vector2i(4, 3), "Choose a target", "Performance stress", {}, {}, presentation)
		elif phase_name == "interaction":
			var hover_tiles: Array[Vector2i] = _interaction_tiles()
			var motion := InputEventMouseMotion.new()
			motion.position = board.call("_tile_center", hover_tiles[frame_index % hover_tiles.size()]) as Vector2
			board.call("_gui_input", motion)
		elif phase_name == "movement":
			var presentation: Dictionary = source_presentation.duplicate(true)
			# Match the authored MOVE_STEP_FRAMES cadence while repeating it long
			# enough for stable frame-pacing statistics.
			var phase: float = float(frame_index % 8) / 7.0
			var from_point: Vector2 = board.call("world_position_for_tile", Vector2i(4, 4)) as Vector2
			var to_point: Vector2 = board.call("world_position_for_tile", Vector2i(4, 2)) as Vector2
			presentation["unit_world_positions"] = {"player": from_point.lerp(to_point, phase)}
			presentation["unit_draw_tiles"] = {"player": Vector2i(4, 2)}
			var effect: Dictionary = (presentation.get("effect", {}) as Dictionary).duplicate(true)
			effect["progress"] = phase
			presentation["effect"] = effect
			board.call("set_combat_state", state, [], [], Vector2i(4, 2), "Movement stress", "Animated actor position", {}, {}, presentation)
		await process_frame
		var now_tick: int = Time.get_ticks_usec()
		frame_intervals_ms.append(float(now_tick - previous_tick) / 1000.0)
		previous_tick = now_tick
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitives_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary if board.has_method("render_instrumentation_snapshot") else {}
	if not snapshot.is_empty():
		var layer_counts: Dictionary = snapshot.get("layer_draw_counts", {}) as Dictionary
		var scene_tile_counts: Dictionary = snapshot.get("scene_tile_draw_counts", {}) as Dictionary
		_expect(int(snapshot.get("retained_layer_count", 0)) >= 4, "render benchmark requires retained board layers")
		_expect(int(snapshot.get("static_draw_count", -1)) == 0, "steady-state phases must not redraw the static floor")
		if phase_name == "action_heavy":
			_expect(int(layer_counts.get("hud", 999)) <= 2, "damage-preview pulses must update in the effects layer without rebuilding unchanged HUD commands")
			_expect(int(layer_counts.get("foreground", 0)) > 2, "large-enemy attack pulses must continuously redraw their foreground highlights")
		elif phase_name == "interaction":
			_expect(int(layer_counts.get("world", 0)) >= PHASE_FRAMES, "pointer interaction must redraw responsive tile overlays")
			_expect(int(layer_counts.get("hud", 0)) >= PHASE_FRAMES, "pointer interaction must redraw responsive enemy HUDs")
			_expect(int(layer_counts.get("effects", -1)) == 0, "pointer interaction must retain unchanged effects")
		elif phase_name == "movement":
			_expect(int(layer_counts.get("hud", 0)) > 0, "moving actors must continuously update their anchored HUD geometry")
			_expect(int(layer_counts.get("scene_tile", 0)) > 0, "moving actors must continuously update scene geometry")
		else:
			_expect(int(layer_counts.get("hud", -1)) == 0, "idle ambient/sprite animation must retain unit HUDs")
			_expect(int(layer_counts.get("effects", -1)) == 0, "idle animation must retain the effects layer")
			_expect(int(layer_counts.get("world", -1)) == 0, "idle occupied-tile animation must retain ground overlays")
			_expect(int(scene_tile_counts.get("4,1", 0)) > 0, "pillar torch sprite sheets must redraw their grid-owned scene tile")
	var result: Dictionary = {
		"frame_interval_ms": _stats(frame_intervals_ms),
		"process_ms": _stats(process_ms),
		"draw_calls": _stats(draw_calls),
		"objects_in_frame": _stats(objects_in_frame),
		"primitives_in_frame": _stats(primitives_in_frame),
		"frames_over_16_67_ms": _count_over(frame_intervals_ms, 16.67),
		"frames_over_20_ms": _count_over(frame_intervals_ms, 20.0),
		"frames_over_33_33_ms": _count_over(frame_intervals_ms, 33.33)
	}
	if not snapshot.is_empty():
		var draw_count: int = maxi(1, int(snapshot.get("dynamic_draw_count", 0)))
		var total_draw_usec: int = int(snapshot.get("dynamic_draw_total_usec", 0))
		result["dynamic_draw_cpu_us_per_draw"] = float(total_draw_usec) / float(draw_count)
		result["dynamic_draw_cpu_us_per_phase_frame"] = float(total_draw_usec) / float(PHASE_FRAMES)
		result["render_instrumentation"] = snapshot
	return result

func _stats(source: Array[float]) -> Dictionary:
	var values: Array[float] = source.duplicate()
	values.sort()
	if values.is_empty():
		return {"median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "mean": 0.0}
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
		"max": values[values.size() - 1],
		"mean": total / float(values.size())
	}

func _percentile(sorted_values: Array[float], percentile: float) -> float:
	var index: int = clampi(int(ceil(float(sorted_values.size()) * percentile)) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]

func _count_over(values: Array[float], threshold: float) -> int:
	var count: int = 0
	for value: float in values:
		if value > threshold:
			count += 1
	return count

func _idle_presentation() -> Dictionary:
	return {
		"scene_props": [],
		"active_door_tiles": {},
		"locked_door_tiles": {},
		"ambient_time_seconds": 42.0,
		"visible_enemy_ids": [1, 2, 3, 4, 5, 6]
	}

func _action_presentation() -> Dictionary:
	var damage_preview: Dictionary = {}
	for enemy_id: int in range(1, 7):
		damage_preview["enemy_%d" % enemy_id] = {
			"hp": 162,
			"hp_loss": 18,
			"block": 6,
			"block_loss": 4,
			"stoneskin": 4,
			"stoneskin_loss": 0,
			"lethal": false
		}
	damage_preview["terrain_perf_crate_a"] = {"hp": 2, "hp_loss": 6, "lethal": false}
	return {
		"scene_props": [],
		"active_door_tiles": {},
		"locked_door_tiles": {},
		"ambient_time_seconds": 42.0,
		"visible_enemy_ids": [1, 2, 3, 4, 5, 6],
		"pulse_attack_tiles": true,
		"damage_preview": damage_preview,
		"impact_actor_keys": ["enemy_1", "enemy_2", "enemy_3", "enemy_4", "enemy_5", "enemy_6"],
		"impact_decals": [
			{"tile": Vector2i(2, 2), "element": "lightning", "kind": "aoe", "seed": 101, "progress": 0.35},
			{"tile": Vector2i(4, 2), "element": "lightning", "kind": "aoe", "seed": 102, "progress": 0.50},
			{"tile": Vector2i(6, 2), "element": "lightning", "kind": "aoe", "seed": 103, "progress": 0.65}
		],
		"effect": {
			"kind": "aoe",
			"preview": true,
			"element": "lightning",
			"from": Vector2i(4, 4),
			"to": Vector2i(4, 2),
			"tiles": _attack_tiles(),
			"progress": 0.0
		}
	}

func _movement_presentation() -> Dictionary:
	return {
		"scene_props": [],
		"active_door_tiles": {},
		"locked_door_tiles": {},
		"ambient_time_seconds": 42.0,
		"visible_enemy_ids": [1, 2, 3, 4, 5, 6],
		"focus_actor_keys": ["player"],
		"focus_tiles": [Vector2i(4, 2)],
		"effect": {"kind": "melee", "from": Vector2i(4, 4), "to": Vector2i(4, 2), "progress": 0.0}
	}

func _attack_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for tile: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2)]:
		tiles.append(tile)
	return tiles

func _interaction_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for tile: Vector2i in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 2), Vector2i(4, 4)]:
		tiles.append(tile)
	return tiles

func _stress_state() -> Dictionary:
	return {
		"name": "Render Performance Chamber",
		"room_coord": Vector2i(7, 11),
		"room_element": "ice",
		"grid": _stress_grid(),
		"moss": {},
		"elemental_intensity": {"fire": 0, "ice": 6, "lightning": 0, "air": 0, "earth": 0},
		"player": {"pos": Vector2i(4, 4), "hp": 120, "max_hp": 120, "block": 30, "stoneskin": 12},
		"enemies": _stress_enemies(),
		"illusions": [],
		"npcs": [],
		"loot": [
			{"id": "perf_ember_a", "kind": "embers", "amount": 2, "pos": Vector2i(2, 4), "claimed": false},
			{"id": "perf_equipment", "kind": "equipment", "equipment_id": "training_sword", "pos": Vector2i(6, 4), "claimed": false}
		],
		"terrain": [
			{"id": "perf_crate_a", "kind": "wooden_crate", "pos": Vector2i(3, 5), "hp": 8, "max_hp": 12},
			{"id": "perf_crate_b", "kind": "wooden_crate", "pos": Vector2i(5, 5), "hp": 12, "max_hp": 12}
		],
		"traps": [
			{"id": "perf_fire", "pos": Vector2i(3, 4), "element": "fire", "damage": 20, "burn": 10, "armed": true},
			{"id": "perf_ice", "pos": Vector2i(5, 4), "element": "ice", "damage": 20, "freeze": 1, "armed": true}
		]
	}

func _stress_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	(grid[1] as Array)[4] = "pillar"
	return grid

func _stress_enemies() -> Array:
	return [
		_enemy(1, "crawler", Vector2i(2, 2)),
		_enemy(2, "harrier", Vector2i(4, 2)),
		_enemy(3, "crawler", Vector2i(6, 2)),
		_enemy(4, "harrier", Vector2i(2, 6)),
		_enemy(5, "crawler", Vector2i(4, 6)),
		_enemy(6, "harrier", Vector2i(6, 6))
	]

func _enemy(enemy_id: int, enemy_type: String, pos: Vector2i) -> Dictionary:
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": 180,
		"max_hp": 180,
		"block": 10,
		"stoneskin": 4,
		"footprint": Vector2i(2, 2) if enemy_id == 1 else Vector2i.ONE,
		"intent": {"name": "Pressure", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 30, "range": 1}]}
	}

func _verify_in_place_state_redraw(board: Control, presentation: Dictionary) -> bool:
	if not board.has_method("render_instrumentation_snapshot") or not board.has_method("reset_render_instrumentation"):
		return false
	var retained_state: Dictionary = _stress_state()
	board.call("set_combat_state", retained_state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	board.call("reset_render_instrumentation")
	var enemies: Array = retained_state.get("enemies", []) as Array
	var first_enemy: Dictionary = enemies[0] as Dictionary
	first_enemy["hp"] = int(first_enemy.get("hp", 0)) - 1
	board.call("set_combat_state", retained_state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	var snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var redrew: bool = int(snapshot.get("dynamic_draw_count", 0)) > 0
	_expect(redrew, "in-place state mutations detected by the deep cache snapshot must still invalidate retained layers")
	return redrew

func _reset_render_instrumentation(board: Control) -> void:
	if board.has_method("reset_render_instrumentation"):
		board.call("reset_render_instrumentation")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
