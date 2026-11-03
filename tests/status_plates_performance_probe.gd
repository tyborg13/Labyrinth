extends SceneTree

## Matched headless CPU-submission workload from the sb-01 review, not GPU/frame proof.
const Movement = preload("res://tests/suites/board_hud_movement_suite.gd")
const Plates = preload("res://scripts/board_status_plates.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const VIEWPORT := Vector2i(1920, 1080)
const UNIT_COUNT: int = 12
const WARMUP_FRAMES: int = 20
const MEASURED_FRAMES: int = 200
const GRID_COLUMNS: int = 4
const GRID_ORIGIN := Vector2(120, 180)
const GRID_STEP := Vector2(400, 250)
const FRAME_SIZE := Vector2(138, 34)
const OUTPUT: String = "user://status-performance.json"

class HudBoard extends "res://scripts/combat_board_view.gd":
	var samples: Array[int]
	var population: Array[Dictionary]
	func _ready() -> void:
		_load_assets(false)
		set_process(false)
	func _draw() -> void:
		_tooltip_regions.clear()
		var started: int = Time.get_ticks_usec()
		for i: int in range(population.size()):
			var frame := Rect2(GRID_ORIGIN + Vector2(float(i % GRID_COLUMNS) * GRID_STEP.x, float(i / GRID_COLUMNS) * GRID_STEP.y), FRAME_SIZE)
			_draw_health_bar(population[i], frame)
			_draw_unit_statuses(population[i], frame)
		samples.append(Time.get_ticks_usec() - started)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--first-status"):
		await preload("res://tests/helpers/status_icon_application_benchmark.gd").run(self)
		return
	if OS.get_cmdline_user_args().has("--movement-only"):
		var passed: bool = await Movement.run(self)
		quit(0 if passed else 1)
		return
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	var board := HudBoard.new()
	board.size = Vector2(VIEWPORT)
	for i: int in range(UNIT_COUNT):
		board.population.append({"key": "enemy_%d" % i, "role": "enemy", "type": "crawler", "hp": 24, "max_hp": 30, "block": 8, "stoneskin": 3, "immobilize": true, "bleed": 3, "expose": 2, "frost_armor": 3})
	root.add_child(board)
	var warm: Dictionary
	for frame: int in range(WARMUP_FRAMES + MEASURED_FRAMES):
		board.queue_redraw()
		await process_frame
		if frame == WARMUP_FRAMES: warm = _counters(board)
	var end: Dictionary = _counters(board)
	var samples: Array[int] = board.samples.slice(WARMUP_FRAMES)
	samples.sort()
	var errors: Array[String]
	if samples.size() != MEASURED_FRAMES: errors.append("wrong sample count")
	for field: String in ["resources", "nodes", "trim_cache", "styles", "layout_rebuilds", "layout_actors"]:
		if warm[field] != end[field]: errors.append("unstable " + field)
	var total: int = 0
	for sample: int in samples: total += sample
	var report: Dictionary = {"schema_version": 1, "metric": "headless_nameplate_cpu_submission", "cpu": OS.get_processor_name(), "os": OS.get_name(), "godot": Engine.get_version_info()["string"], "display_driver": DisplayServer.get_name(), "viewport": [1920, 1080], "ui_scale": 1.0, "units": UNIT_COUNT, "warmup_frames": WARMUP_FRAMES, "n": samples.size(), "p50_us": samples[samples.size() / 2], "p95_us": samples[int(samples.size() * 0.95)], "p99_us": samples[int(samples.size() * 0.99)], "max_us": samples.back(), "mean_us": float(total) / samples.size(), "warm": warm, "end": end, "semantic_errors": errors, "samples_us": samples}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	report.erase("samples_us")
	print("SB01_HUD_CPU ", JSON.stringify(report))
	print("STATUS PERFORMANCE OUTPUT: ", ProjectSettings.globalize_path(OUTPUT))
	print("STATUS PERFORMANCE PROBE RESULT: ", "PASS" if errors.is_empty() else "FAIL")
	board.queue_free()
	await process_frame
	if not await Movement.run(self): errors.append("incremental movement regression")
	quit(0 if errors.is_empty() else 1)

func _counters(board: Control) -> Dictionary:
	var cache: RefCounted
	for property: Dictionary in board.get_property_list():
		if property["name"] == "_status_plate_layout": cache = board.get("_status_plate_layout")
	return {"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "trim_cache": Assets._texture_used_rect_cache.size(), "styles": Plates._styles.size(), "layout_rebuilds": int(cache.get("rebuilds")) if cache != null else 0, "layout_hits": int(cache.get("hits")) if cache != null else 0, "layout_actors": (cache.get("_actors") as Dictionary).size() if cache != null else 0}
