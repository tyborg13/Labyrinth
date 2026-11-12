extends SceneTree

var checks: int = 0
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")
func _run() -> void:
	preload("res://scripts/settings_store.gd")._applied_board_health_bars = preload("res://scripts/settings_store.gd").BOARD_HEALTH_ALWAYS
	await preload("res://tests/perf/hover_equivalence.gd").run(self, _check)
	for failure: String in failures: push_error(failure)
	print("RD08 HOVER: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
