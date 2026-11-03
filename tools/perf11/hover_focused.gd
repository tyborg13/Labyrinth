extends SceneTree
## On-demand affected interaction suites; no new permanent timing/count guards.
const Drag = preload("res://tests/suites/card_drag_play_suite.gd")
const Keywords = preload("res://tests/suites/card_keywords_suite.gd")
const Clock = preload("res://tests/suites/turn_clock_hud_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(_draw_boundary)
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var selected: String = args[args.find("--suite") + 1] if args.has("--suite") else "all"
	if args.has("--reference-run"):
		var packed: PackedScene = load("res://scenes/run_scene.tscn")
		var bundle: Dictionary = packed._bundled.duplicate(true)
		var variants: Array = bundle["variants"]
		for index: int in range(variants.size()):
			if variants[index] is Script and variants[index].resource_path == "res://scripts/run_scene.gd":
				variants[index] = load(args[args.find("--reference-run") + 1])
		bundle["variants"] = variants
		# Replace only this process's cached scene for unchanged live fixtures.
		packed._bundled = bundle
	if selected in ["all", "drag"]:
		Drag.run(_expect)
		await Drag.run_live(self, _expect)
		print("PERF12 FOCUSED drag: %d failures" % failures.size())
	if selected in ["all", "empower"]:
		await Keywords.run_live(self, _expect)
		print("PERF12 FOCUSED empower: %d failures" % failures.size())
	if selected in ["all", "clock"]:
		await Clock.run(self, _expect)
		print("PERF12 FOCUSED clock: %d failures" % failures.size())
	for failure: String in failures: push_error(failure)
	print("PERF12 FOCUSED: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
