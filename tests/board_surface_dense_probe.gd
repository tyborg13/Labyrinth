extends "res://tests/board_surface_visual_probe.gd"

const WARMUP_FRAMES: int = 60
const SAMPLE_FRAMES: int = 180

func _initialize() -> void:
	preload("res://scripts/board_surface_presentation.gd").retained_cache_enabled = OS.get_environment("LABYRINTH_SURFACE_CACHE_BASE") != "1"
	preload("res://scripts/board_surface_presentation.gd").retained_electric_enabled = OS.get_environment("LABYRINTH_SURFACE_ELECTRIC_BASE") != "1"
	preload("res://scripts/board_surface_presentation.gd").retained_static_batch_enabled = OS.get_environment("LABYRINTH_SURFACE_STATIC_BASE") != "1"
	ground_loop_only = true
	await super._initialize()

func _capture(name: String, _settle_frames: int = 8) -> void:
	if name != "01_mixed_ground": return
	var board: Control = scene.get("board_view") as Control
	var counts: Dictionary = _seed_dense_ground()
	var modes: Array[Dictionary]
	for reduced: bool in [false, true]:
		var settings: Dictionary = Settings.load_settings()
		settings["reduced_motion"] = reduced
		Settings.save_settings(settings)
		scene.set("_settings", settings)
		scene.call("_refresh_ui")
		assert(bool((board.get("presentation") as Dictionary).get("reduced_motion", false)) == reduced)
		for warmup: int in range(WARMUP_FRAMES): await RenderingServer.frame_post_draw
		board.call("reset_render_instrumentation")
		var frame_ms: Array[float]
		var process_ms: Array[float]
		var previous: int = Time.get_ticks_usec()
		for sample: int in range(SAMPLE_FRAMES):
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			frame_ms.append(float(now - previous) / 1000.0)
			process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
			previous = now
		var instrument: Dictionary = board.call("render_instrumentation_snapshot")
		modes.append({
			"reduced_motion": reduced,
			"frame_interval_ms": _stats(frame_ms),
			"process_ms": _stats(process_ms),
			"layer_draw_counts": instrument.get("layer_draw_counts", {}),
			"layer_draw_total_usec": instrument.get("layer_draw_total_usec", {}),
			"render_section_total_usec": instrument.get("render_section_total_usec", {}),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		})
		# PNG readbacks happen outside the measured window. These two real board
		# frames expose the reduced-motion ground identity and animation behavior.
		var mode: String = "reduced" if reduced else "normal"
		await super._capture("dense_%s_00" % mode, 0)
		for frame: int in range(24): await RenderingServer.frame_post_draw
		await super._capture("dense_%s_24" % mode, 0)
	var result: Dictionary = {
		"retained_cache_enabled": preload("res://scripts/board_surface_presentation.gd").retained_cache_enabled,
		"retained_electric_enabled": preload("res://scripts/board_surface_presentation.gd").retained_electric_enabled,
		"retained_static_batch_enabled": preload("res://scripts/board_surface_presentation.gd").retained_static_batch_enabled,
		"schema_version": 1, "workload_id": "dense_shared_surfaces_live_hud_v4",
		"viewport": [1920, 1080], "ui_scale": 1.0,
		"warmup_frames": WARMUP_FRAMES, "sample_frames": SAMPLE_FRAMES,
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"surface_tiles": Ground.tiles(state).size(), "surface_counts": counts,
		"conductive_fire": true, "actors": (state["enemies"] as Array).size() + 1,
		"modes": modes,
		"limits": "Current Mac idle stress fixture with full HUD; vsync/scheduling included. No old-workload comparison or Windows/GPU certification. PNG readback excluded from samples.",
	}
	var file := FileAccess.open(OUTPUT.path_join("dense_timing.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("BOARD SURFACE DENSE RESULT: " + JSON.stringify(result))
	print("BOARD SURFACE DENSE PROBE: PASS")

func _stats(values: Array[float]) -> Dictionary:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	var over_16: int = 0
	var over_20: int = 0
	var over_33: int = 0
	for value: float in sorted:
		total += value
		over_16 += 1 if value > 16.667 else 0
		over_20 += 1 if value > 20.0 else 0
		over_33 += 1 if value > 33.333 else 0
	return {"mean": total / float(sorted.size()), "median": sorted[sorted.size() / 2], "p95": sorted[int(ceil(sorted.size() * 0.95)) - 1], "p99": sorted[int(ceil(sorted.size() * 0.99)) - 1], "max": sorted[-1], "frames_over_16_67_ms": over_16, "frames_over_20_ms": over_20, "frames_over_33_33_ms": over_33}

func _seed_dense_ground() -> Dictionary:
	state = state.duplicate(true)
	state["surfaces"] = {}
	var grid: Array = state["grid"]
	var counts: Dictionary = {"fire": 0, "ice": 0, "electrified": 0, "rubble": 0}
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, (grid[y] as Array).size() - 1):
			var kind: String = ["fire", "ice", "electrified"][posmod(x + y, 3)]
			Ground.place(state, Vector2i(x, y), kind)
			counts[kind] = int(counts[kind]) + 1
			if posmod(x + y, 2) == 0:
				Ground.place(state, Vector2i(x, y), "rubble")
				counts["rubble"] = int(counts["rubble"]) + 1
	var run: Dictionary = scene.get("_run_state") as Dictionary
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	return counts
