extends RefCounted

## Narrow, matched 12-unit HUD workload. Headless results measure CPU submission;
## native post-draw frame intervals are reported only by the windowed runner.
const Plates = preload("res://scripts/board_status_plates.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Fixture = preload("res://tests/status_icon_fixture.gd")
const SIZE := Vector2i(1920, 1080)
const UNIT_COUNT: int = 12
const TRIALS: int = 20
const COLUMNS: int = 4
const ORIGIN := Vector2(120, 180)
const STEP := Vector2(400, 250)
const FRAME_SIZE := Vector2(138, 34)
const DRAW_TIMEOUT_USEC: int = 5000000
const NATIVE_FRAME_CAP: int = 0
const NATIVE_IDLE_SLEEP_USEC: int = 0
const OUTPUT: String = "user://status-icon-application"

class HudBoard extends "res://scripts/combat_board_view.gd":
	var population: Array[Dictionary]
	var draws: Array[Dictionary]
	var load_usec: int
	var status_icon_jobs_usec: int = 0
	func _ready() -> void:
		var started: int = Time.get_ticks_usec()
		_load_assets(false)
		load_usec = Time.get_ticks_usec() - started
		set_process(false)
	func _load_keyword_icon_asset(icon: String) -> void:
		var started: int = Time.get_ticks_usec()
		super._load_keyword_icon_asset(icon)
		if Fixture.ICON_KEYS.has(icon): status_icon_jobs_usec += Time.get_ticks_usec() - started
	func _draw() -> void:
		_tooltip_regions.clear()
		var before: int = Plates._icon_visible_bounds.size()
		var started: int = Time.get_ticks_usec()
		for i: int in range(population.size()):
			var frame := Rect2(ORIGIN + Vector2(float(i % COLUMNS) * STEP.x, float(i / COLUMNS) * STEP.y), FRAME_SIZE)
			_draw_health_bar(population[i], frame)
			_draw_unit_statuses(population[i], frame)
		draws.append({"cpu_usec": Time.get_ticks_usec() - started, "new_bounds": Plates._icon_visible_bounds.size() - before})

static func run(tree: SceneTree) -> void:
	var native: bool = DisplayServer.get_name() != "headless"
	tree.root.size = SIZE
	tree.root.content_scale_size = SIZE
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		OS.low_processor_usage_mode = false
		OS.low_processor_usage_mode_sleep_usec = NATIVE_IDLE_SLEEP_USEC
		Engine.max_fps = NATIVE_FRAME_CAP
		DisplayServer.window_move_to_foreground()
	var samples: Array[Dictionary]
	var errors: Array[String]
	# Decode textures once, just as board loading does. Only these immutable
	# icons' derived bounds are made cold between trials; other caches stay warm.
	for icon: String in Fixture.ICON_KEYS: Icons.icon_texture(icon)
	for trial: int in range(TRIALS):
		Plates._icon_visible_bounds.clear()
		for icon: String in Fixture.ICON_KEYS:
			Assets._texture_used_rect_cache.erase(Assets._texture_processing_cache_key(Icons.icon_texture(icon)))
		var board := HudBoard.new()
		board.size = Vector2(SIZE)
		for i: int in range(UNIT_COUNT):
			board.population.append({"key": "enemy_%d" % i, "role": "enemy", "type": "crawler", "hp": 24, "max_hp": 30})
		tree.root.add_child(board)
		var bounds_at_load: int = Plates._icon_visible_bounds.size()
		await _draw_once(tree, board, native, errors)
		if tree.root.size != SIZE or tree.root.content_scale_size != SIZE: errors.append("Fixture viewport/UI scale changed")
		var previous_post_draw: int = Time.get_ticks_usec()
		# Replace each snapshot rather than mutating a retained caller dictionary.
		for i: int in range(UNIT_COUNT):
			var unit: Dictionary = board.population[i].duplicate(true)
			unit.merge({"block": 8, "stoneskin": 3, "immobilize": true, "bleed": 3, "expose": 2, "frost_armor": 3}, true)
			board.population[i] = unit
		var latency_started: int = Time.get_ticks_usec()
		var applied: Dictionary = await _draw_once(tree, board, native, errors)
		var completed: int = Time.get_ticks_usec()
		if native and not DisplayServer.window_is_focused(): errors.append("Native fixture lost foreground focus")
		if applied.is_empty():
			board.free()
			break
		var entries: int = 0
		for unit: Dictionary in board.population:
			entries += board._unit_defense_plate_entries(unit, Rect2(ORIGIN, FRAME_SIZE)).size()
			entries += board._unit_status_pill_entries(unit, Rect2(ORIGIN, FRAME_SIZE)).size()
		if entries != UNIT_COUNT * 6: errors.append("Fixture did not draw all 72 status/defense entries")
		samples.append({"trial": trial, "board_load_usec": board.load_usec,
			"status_icon_load_jobs_usec": board.status_icon_jobs_usec, "bounds_at_load": bounds_at_load,
			"first_status_draw_cpu_usec": applied["cpu_usec"], "draw_bounds_computations": applied["new_bounds"],
			"submission_to_draw_completion_usec": completed - latency_started,
			"native_frame_interval_usec": completed - previous_post_draw if native else 0,
			"entries": entries, "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"static_memory": int(Performance.get_monitor(Performance.MEMORY_STATIC))})
		if native: samples.back()["window_focused"] = DisplayServer.window_is_focused()
		board.queue_free()
		await tree.process_frame
	if samples.size() != TRIALS: errors.append("Incomplete first-status trials")
	for sample: Dictionary in samples:
		if sample["nodes"] != samples[0]["nodes"]: errors.append("Unbounded fixture node count")
		if sample["objects"] != samples[0]["objects"]: errors.append("Unbounded fixture object count")
		if not native: sample.erase("native_frame_interval_usec")
	var summary: Dictionary = {}
	for metric: String in ["board_load_usec", "status_icon_load_jobs_usec", "first_status_draw_cpu_usec", "submission_to_draw_completion_usec", "native_frame_interval_usec"]:
		if metric == "native_frame_interval_usec" and not native: continue
		var values: Array[int]
		for sample: Dictionary in samples: values.append(int(sample[metric]))
		if not values.is_empty(): summary[metric] = _stats(values)
	var report: Dictionary = {"schema_version": 1, "metric": "first_status_12_unit_hud", "native": native,
		"cpu": OS.get_processor_name(), "os": OS.get_name(), "godot": Engine.get_version_info()["string"],
		"display_driver": DisplayServer.get_name(), "viewport": [1920, 1080], "ui_scale": 1.0,
		"frame_cap": Engine.max_fps, "low_processor_usage_mode": OS.low_processor_usage_mode,
		"low_processor_sleep_usec": OS.low_processor_usage_mode_sleep_usec,
		"units": UNIT_COUNT, "trials": TRIALS, "summary": summary, "samples": samples, "semantic_errors": errors}
	var directory: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("STATUS_ICON_APPLICATION_JSON " + JSON.stringify(report))
	print("STATUS ICON APPLICATION OUTPUT: " + directory)
	print("STATUS ICON APPLICATION BENCHMARK RESULT: %s (%d trials; 12 units)" % ["PASS" if errors.is_empty() else "FAIL", samples.size()])
	for error: String in errors: push_error(error)
	tree.quit(0 if errors.is_empty() else 1)

static func _draw_once(tree: SceneTree, board: HudBoard, native: bool, errors: Array[String]) -> Dictionary:
	var expected: int = board.draws.size() + 1
	var deadline: int = Time.get_ticks_usec() + DRAW_TIMEOUT_USEC
	board.queue_redraw()
	while board.draws.size() < expected and Time.get_ticks_usec() < deadline:
		await tree.process_frame
		if native: await RenderingServer.frame_post_draw
	if board.draws.size() < expected:
		errors.append("Timed out waiting for the fixture's draw callback")
		return {}
	return board.draws.back()

static func _stats(input: Array[int]) -> Dictionary:
	var values: Array[int] = input.duplicate()
	values.sort()
	var total: int = 0
	var misses: Dictionary = {"16670": 0, "20000": 0, "33330": 0}
	for value: int in values:
		total += value
		for threshold: String in misses:
			if value > int(threshold): misses[threshold] += 1
	return {"p50": values[values.size() / 2], "p95": values[mini(values.size() - 1, int(values.size() * 0.95))],
		"p99": values[mini(values.size() - 1, int(values.size() * 0.99))], "max": values.back(),
		"mean": float(total) / values.size(), "threshold_misses": misses}
