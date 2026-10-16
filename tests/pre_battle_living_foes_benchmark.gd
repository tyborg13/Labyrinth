extends "res://tests/pre_battle_living_foes_fixture.gd"

## Windowed, matched steady-state before/after workload. Headless logic mode
## validates the workload only and intentionally emits no performance verdict.
const OUTPUT: String = "user://probes/pb_01_performance"
const WARMUP_FRAMES: int = 45
const SAMPLE_FRAMES: int = 180
const LOGIC_FRAMES: int = 2
const TRIAL_ORDER: Array[String] = ["before", "after", "after", "before"]
var _logic_only: bool = false

func _initialize() -> void:
	_logic_only = "--logic-only" in OS.get_cmdline_user_args()
	_setup()
	root.size = PROBE_VIEWPORT
	if not _logic_only:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_run.call_deferred()

func _run() -> void:
	var instance: Node = await _living_fixture()
	var trials: Array[Dictionary]
	var samples: Dictionary = {"before": [], "after": []}
	for index: int in range(TRIAL_ORDER.size()):
		var mode: String = TRIAL_ORDER[index]
		var panel: Control = await _set_roster(instance, PERFORMANCE_ROSTER, {"type": "kill_all"}, mode == "before")
		_expect(panel.find_children("PreBattleEnemyLiveActor", "Control", true, false).size() == (0 if mode == "before" else 6), "Benchmark requires six still/live foes respectively")
		if _logic_only:
			for frame: int in range(LOGIC_FRAMES): await process_frame
			continue
		var viewports: Array[RID]
		viewports.append(_viewport.get_viewport_rid())
		for live: Node in panel.find_children("PreBattleEnemyLiveActor", "Control", true, false):
			var renderer: Node = live.get("renderer")
			var viewport: SubViewport = renderer.get("viewport")
			viewports.append(viewport.get_viewport_rid())
		for rid: RID in viewports: RenderingServer.viewport_set_measure_render_time(rid, true)
		for frame: int in range(WARMUP_FRAMES): await RenderingServer.frame_post_draw
		await _capture("%s/%02d_%s_1920x1080_ui100.png" % [OUTPUT, index, mode])
		var intervals: Array[float]
		var process_times: Array[float]
		var cpu_times: Array[float]
		var gpu_times: Array[float]
		var previous: int = Time.get_ticks_usec()
		for frame: int in range(SAMPLE_FRAMES):
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			intervals.append(float(now - previous) / 1000.0)
			previous = now
			process_times.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
			var cpu: float = 0.0
			var gpu: float = 0.0
			for rid: RID in viewports:
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu_times.append(cpu)
			gpu_times.append(gpu)
		samples[mode].append_array(intervals)
		trials.append({"mode": mode, "frame_interval_ms": intervals, "process_ms": process_times, "viewport_cpu_ms": cpu_times, "viewport_gpu_ms": gpu_times, "summary": _stats(intervals)})
	var report: Dictionary = {"viewport": [1920, 1080], "ui_scale": 1.0, "roster": PERFORMANCE_ROSTER, "trial_order": TRIAL_ORDER, "baseline": "Original stills; new live nodes removed; identical production scene/layout/kit", "warmup_frames": WARMUP_FRAMES, "sample_frames": SAMPLE_FRAMES, "trials": trials, "logic_only": _logic_only}
	if not _logic_only:
		var before: Dictionary = _stats(samples["before"])
		var after: Dictionary = _stats(samples["after"])
		report["before"] = before
		report["after"] = after
		# Director budget 2026-10-16: living idles may cost up to 1 ms median; p95 stays under 8 ms (16.7 ms frame).
		report["no_frame_time_regression"] = after["median_ms"] <= before["median_ms"] + 1.0 and after["p95_ms"] <= 8.0
		print("PB-01 FRAME TIME: before=%s after=%s" % [JSON.stringify(before), JSON.stringify(after)])
		_expect(report["no_frame_time_regression"], "Six-foe frame time within budget (median +1 ms, p95 under 8 ms)")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT + "/measurement.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PB-01 SIX-FOE BENCHMARK%s: %s" % [" LOGIC ONLY (NO PERFORMANCE MEASUREMENT)" if _logic_only else "", "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _stats(values: Array) -> Dictionary:
	var ordered: Array = values.duplicate()
	ordered.sort()
	return {"samples": ordered.size(), "median_ms": ordered[ordered.size() / 2], "p95_ms": ordered[ceili(ordered.size() * 0.95) - 1]}
