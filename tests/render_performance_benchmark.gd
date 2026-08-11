extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const WARMUP_FRAMES: int = 45
const PHASE_FRAMES: int = 150
const CONTINUOUS_REDRAW_SECONDS: float = 1.0 / 30.0
const OUTPUT_DIR: String = "user://performance/render_benchmark"

class LatePresentationSubmitter:
	extends Node

	var board: Control
	var state: Dictionary
	var attack_tiles: Array
	var presentation: Dictionary
	var submitted_process_frame: int = -1

	func _ready() -> void:
		process_priority = 100
		set_process(false)

	func arm(next_board: Control, next_state: Dictionary, next_attack_tiles: Array, next_presentation: Dictionary) -> void:
		board = next_board
		state = next_state
		attack_tiles = next_attack_tiles
		presentation = next_presentation
		set_process(true)

	func _process(_delta: float) -> void:
		submitted_process_frame = Engine.get_process_frames()
		board.call("set_combat_state", state, [], attack_tiles, Vector2i(4, 3), "Choose a target", "Late-submission cadence", {}, {}, presentation)
		board.set("_continuous_presentation_elapsed", 1.0)
		set_process(false)

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
		"schema_version": 2,
		"workload_id": "combat_board_max_content_v2",
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
	var dedup_snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary if board.has_method("render_instrumentation_snapshot") else {}
	if bool(dedup_snapshot.get("presentation_redraw_dedup_active", false)):
		results["post_process_redraw_cadence"] = await _verify_post_process_redraw_cadence(board, state)
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
	# A process-frame await resumes before that frame is rendered. Bracket every
	# phase on post-draw so the prior phase's final retained-layer work cannot be
	# misattributed after the instrumentation reset.
	await RenderingServer.frame_post_draw
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
		# Measure completed rendered frames, not process callbacks that resume before
		# queued CanvasItem redraws execute. The latter can coalesce two authored
		# interaction states and report CPU-only intervals as frame pacing.
		await RenderingServer.frame_post_draw
		var now_tick: int = Time.get_ticks_usec()
		frame_intervals_ms.append(float(now_tick - previous_tick) / 1000.0)
		previous_tick = now_tick
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitives_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	await RenderingServer.frame_post_draw
	var snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary if board.has_method("render_instrumentation_snapshot") else {}
	# Older revisions exposed coarse draw counters through the same method name.
	# Only enforce retained-renderer semantics when the retained-layer contract is
	# actually present, so the identical workload can benchmark a pre-pass base.
	if snapshot.has("retained_layer_count"):
		var layer_counts: Dictionary = snapshot.get("layer_draw_counts", {}) as Dictionary
		var scene_tile_counts: Dictionary = snapshot.get("scene_tile_draw_counts", {}) as Dictionary
		_expect(int(snapshot.get("retained_layer_count", 0)) >= 4, "render benchmark requires retained board layers")
		_expect(int(snapshot.get("static_draw_count", -1)) == 0, "steady-state phases must not redraw the static floor")
		if phase_name == "action_heavy":
			var action_hud_draws: int = int(layer_counts.get("hud", 0))
			_expect(action_hud_draws > 2, "unit damage-preview pulses must continuously composite projected HP on the HUD layer")
			_expect(action_hud_draws < PHASE_FRAMES, "damage-preview HUD pulses should keep the 30 Hz cadence instead of rebuilding on every authored effect frame")
			_expect(int(layer_counts.get("foreground", 0)) > 2, "large-enemy attack pulses must continuously redraw their foreground highlights")
			if bool(snapshot.get("presentation_redraw_dedup_active", false)):
				# The world still advances trap and tactical pulse animation, but
				# an explicit impact submission must replace the second full
				# continuous redraw that previously approached 2x phase length.
				var phase_elapsed_ms: float = 0.0
				for interval_ms: float in frame_intervals_ms:
					phase_elapsed_ms += interval_ms
				var continuous_redraw_budget: int = mini(
					PHASE_FRAMES - 1,
					int(ceil(phase_elapsed_ms / (CONTINUOUS_REDRAW_SECONDS * 1000.0))) + 2
				)
				_expect(int(layer_counts.get("world", 0)) >= PHASE_FRAMES - 2, "action impact submissions must redraw the world layer on every authored frame")
				_expect(int(layer_counts.get("effects", 0)) >= PHASE_FRAMES - 2, "action effect submissions must redraw the effects layer on every authored frame")
				_expect(int(scene_tile_counts.get("3,3", 0)) >= PHASE_FRAMES - 2, "action impacts must redraw the large-enemy scene layer on every authored frame")
				_expect(int(layer_counts.get("world", 999)) <= PHASE_FRAMES + continuous_redraw_budget, "explicit impact submissions must stay within the authored-frame plus 30 Hz wall-clock redraw budget")
				_expect(int(layer_counts.get("effects", 999)) <= PHASE_FRAMES + continuous_redraw_budget, "explicit effect submissions must stay within the authored-frame plus 30 Hz wall-clock redraw budget")
		elif phase_name == "interaction":
			_expect(int(layer_counts.get("overlays", 0)) >= PHASE_FRAMES, "pointer interaction must redraw responsive tile overlays")
			_expect(int(layer_counts.get("hud", 0)) >= PHASE_FRAMES, "pointer interaction must redraw responsive enemy HUDs")
			_expect(int(layer_counts.get("effects", -1)) == 0, "pointer interaction must retain unchanged effects")
		elif phase_name == "movement":
			_expect(int(layer_counts.get("hud", 0)) > 0, "moving actors must continuously update their anchored HUD geometry")
			_expect(int(layer_counts.get("scene_tile", 0)) > 0, "moving actors must continuously update scene geometry")
		else:
			_expect(int(layer_counts.get("hud", -1)) == 0, "idle ambient/sprite animation must retain unit HUDs")
			_expect(int(layer_counts.get("effects", -1)) == 0, "idle animation must retain the effects layer")
			_expect(int(layer_counts.get("ground", 0)) > 0, "idle trap animation must redraw the ground layer")
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
	var initial_snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	if not initial_snapshot.has("retained_layer_count"):
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

func _verify_post_process_redraw_cadence(board: Control, source_state: Dictionary) -> Dictionary:
	# Model timer-driven RunScene submissions with a higher process priority than
	# the board. Its explicit frame must render now, and a due continuous redraw
	# must still render on the following process frame.
	var state: Dictionary = source_state.duplicate(true)
	state["traps"] = []
	var presentation: Dictionary = _action_presentation()
	board.call("set_combat_state", state, [], _attack_tiles(), Vector2i(4, 3), "Choose a target", "Late-submission cadence", {}, {}, presentation)
	await process_frame
	await process_frame
	_reset_render_instrumentation(board)
	board.set("_continuous_presentation_elapsed", 0.0)

	var late_presentation: Dictionary = presentation.duplicate(true)
	late_presentation["impact_progress"] = 0.67
	late_presentation["impact_strength"] = 0.73
	var late_effect: Dictionary = (late_presentation.get("effect", {}) as Dictionary).duplicate(true)
	late_effect["progress"] = 0.67
	late_presentation["effect"] = late_effect
	var submitter := LatePresentationSubmitter.new()
	board.get_parent().add_child(submitter)
	submitter.arm(board, state, _attack_tiles(), late_presentation)
	await RenderingServer.frame_post_draw
	var explicit_snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var explicit_counts: Dictionary = explicit_snapshot.get("layer_draw_counts", {}) as Dictionary
	var explicit_scene_counts: Dictionary = explicit_snapshot.get("scene_tile_draw_counts", {}) as Dictionary
	var explicit_effects: int = int(explicit_counts.get("effects", 0))
	var explicit_world: int = int(explicit_counts.get("world", 0))
	var explicit_impact_scene: int = int(explicit_scene_counts.get("3,3", 0))
	_expect(explicit_effects >= 1, "a post-process explicit effect submission must render in its submitted frame")
	_expect(explicit_world >= 1, "a post-process explicit impact submission must render the world layer in its submitted frame")
	_expect(explicit_impact_scene >= 1, "a post-process explicit impact submission must render its actor scene layer in its submitted frame")

	var elapsed_before_following_process: float = float(board.get("_continuous_presentation_elapsed"))
	var explicit_effects_frame: int = int(board.get("_explicit_effects_redraw_process_frame"))
	var explicit_impact_frame: int = int(board.get("_explicit_impact_redraw_process_frame"))
	await RenderingServer.frame_post_draw
	var continuous_snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var continuous_counts: Dictionary = continuous_snapshot.get("layer_draw_counts", {}) as Dictionary
	var continuous_scene_counts: Dictionary = continuous_snapshot.get("scene_tile_draw_counts", {}) as Dictionary
	var continuous_effects: int = int(continuous_counts.get("effects", 0))
	var continuous_world: int = int(continuous_counts.get("world", 0))
	var continuous_impact_scene: int = int(continuous_scene_counts.get("3,3", 0))
	_expect(continuous_effects > explicit_effects, "a post-process effect submission must not suppress the following due continuous redraw")
	_expect(continuous_world > explicit_world, "a post-process impact submission must not suppress the following due continuous world redraw")
	_expect(continuous_impact_scene > explicit_impact_scene, "a post-process impact submission must not suppress the following due actor redraw")
	var submitted_process_frame: int = submitter.submitted_process_frame
	submitter.queue_free()
	return {
		"verified": continuous_effects > explicit_effects and continuous_world > explicit_world and continuous_impact_scene > explicit_impact_scene,
		"submitted_process_frame": submitted_process_frame,
		"elapsed_before_following_process": elapsed_before_following_process,
		"explicit_effects_frame": explicit_effects_frame,
		"explicit_impact_frame": explicit_impact_frame,
		"explicit_draw_counts": {"effects": explicit_effects, "world": explicit_world, "impact_scene": explicit_impact_scene},
		"following_draw_counts": {"effects": continuous_effects, "world": continuous_world, "impact_scene": continuous_impact_scene}
	}

func _reset_render_instrumentation(board: Control) -> void:
	if board.has_method("reset_render_instrumentation"):
		board.call("reset_render_instrumentation")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
