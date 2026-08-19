extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const WARMUP_FRAMES: int = 45
const SAMPLE_FRAMES: int = 180
const OUTPUT_DIR: String = "user://performance/elemental_ambient_benchmark"

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	await process_frame
	board.call("set_combat_state", _mixed_state(), [], [], Vector2i(-1, -1), "", "", {}, {}, {"scene_props": []})
	_expect((board.call("_ambient_active_element_ids") as PackedStringArray).size() == ElementData.all_elements().size(), "Mixed-element workload must activate every particle family")
	for _frame: int in range(WARMUP_FRAMES):
		await RenderingServer.frame_post_draw
	board.call("reset_render_instrumentation")

	var intervals_ms: Array[float] = []
	var process_ms: Array[float] = []
	var previous_tick: int = Time.get_ticks_usec()
	for _frame: int in range(SAMPLE_FRAMES):
		await RenderingServer.frame_post_draw
		var now_tick: int = Time.get_ticks_usec()
		intervals_ms.append(float(now_tick - previous_tick) / 1000.0)
		previous_tick = now_tick
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	var snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var section_total: Dictionary = snapshot.get("render_section_total_usec", {}) as Dictionary
	var layer_draw_counts: Dictionary = snapshot.get("layer_draw_counts", {}) as Dictionary
	var ambient_draws: int = int(layer_draw_counts.get("ambient", 0))
	_expect(ambient_draws > 0, "Mixed-element workload must execute ambient retained-layer redraws")
	var hash_caches: Dictionary = {}
	var ambient_layer: Control = board.get("_ambient_render_layer") as Control
	if ambient_layer != null and _has_property(ambient_layer, "_ambient_hash01_caches_by_element"):
		hash_caches = ambient_layer.get("_ambient_hash01_caches_by_element") as Dictionary
	# The regression repeatedly emptied one shared cache while alternating passes.
	# Newer implementations expose the element-local cache map; older bases omit
	# this semantic counter but remain benchmark-compatible for direct comparison.
	if not hash_caches.is_empty():
		_expect(hash_caches.size() == ElementData.all_elements().size(), "Every active element must retain its particle hash cache")
		for element_id: String in ElementData.all_elements():
			_expect(not (hash_caches.get(element_id, {}) as Dictionary).is_empty(), "%s particle hashes must remain warm" % element_id)
	# Readback happens after every timed sample so proof I/O cannot contaminate the
	# frame-interval or ambient CPU measurements above.
	await RenderingServer.frame_post_draw
	var screenshot: Image = viewport.get_texture().get_image()
	_expect(screenshot.get_size() == VIEWPORT_SIZE, "Benchmark screenshot must remain exactly 1920x1080")
	_expect(screenshot.save_png(ProjectSettings.globalize_path("%s/mixed_elements_idle.png" % OUTPUT_DIR)) == OK, "Benchmark screenshot must save")

	var results: Dictionary = {
		"schema_version": 1,
		"workload_id": "mixed_element_ambient_idle_v1",
		"viewport": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"warmup_frames": WARMUP_FRAMES,
		"sample_frames": SAMPLE_FRAMES,
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"active_elements": ElementData.all_elements().size(),
		"frame_interval_ms": _stats(intervals_ms),
		"process_ms": _stats(process_ms),
		"ambient_draw_count": ambient_draws,
		"ambient_draw_cpu_us_total": int(section_total.get("ambient_particles", 0)),
		"ambient_draw_cpu_us_per_draw": float(section_total.get("ambient_particles", 0)) / float(maxi(1, ambient_draws)),
		"hash_cache_family_count": hash_caches.size(),
		"final_objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"final_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"final_orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"semantic_errors": _errors,
	}
	print("ELEMENTAL AMBIENT PERF RESULT: %s" % JSON.stringify(results))
	quit(0 if _errors.is_empty() else 1)

func _stats(values: Array[float]) -> Dictionary:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	var over_16_67: int = 0
	var over_20: int = 0
	var over_33_33: int = 0
	for value: float in sorted:
		total += value
		over_16_67 += 1 if value > 16.67 else 0
		over_20 += 1 if value > 20.0 else 0
		over_33_33 += 1 if value > 33.33 else 0
	return {
		"mean": total / float(maxi(1, sorted.size())),
		"median": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[-1] if not sorted.is_empty() else 0.0,
		"frames_over_16_67_ms": over_16_67,
		"frames_over_20_ms": over_20,
		"frames_over_33_33_ms": over_33_33,
	}

func _percentile(sorted: Array[float], percentile: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]

func _has_property(object: Object, property_name: String) -> bool:
	for descriptor: Dictionary in object.get_property_list():
		if str(descriptor.get("name", "")) == property_name:
			return true
	return false

func _mixed_state() -> Dictionary:
	return {
		"name": "Mixed elemental ambient benchmark",
		"room_coord": Vector2i(8, 12),
		"room_element": ElementData.ICE,
		"grid": _grid(),
		"moss": {},
		"elemental_intensity": {
			ElementData.FIRE: 3,
			ElementData.ICE: 3,
			ElementData.LIGHTNING: 3,
			ElementData.AIR: 3,
			ElementData.EARTH: 3,
		},
		"player": {},
		"enemies": [],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": [],
	}

func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
