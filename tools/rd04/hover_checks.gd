extends SceneTree
var checks: int = 0
var failures: Array[String]
var baseline: bool = false
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	baseline = OS.get_cmdline_user_args().has("--baseline")
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")
func _run() -> void:
	var suite = load("res://tools/rd04/baseline_hover_equivalence.gd" if baseline else "res://tests/perf/hover_equivalence.gd")
	await suite.run(self, _check)
	var unique: Dictionary = {}
	for failure: String in failures: unique[failure] = int(unique.get(failure, 0)) + 1
	var path: String = "/private/tmp/labyrinth_codex/rd-04/hover_%s.json" % ("baseline" if baseline else "candidate")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures.size(), "unique": unique}, "\t"))
	print("RD04 %s HOVER: %d checks, %d failures (%d distinct labels)" % ["BASELINE" if baseline else "CANDIDATE", checks, failures.size(), unique.size()])
	quit(0 if failures.is_empty() else 1)
func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
