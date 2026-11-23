extends SceneTree

const Force = preload("res://tests/suites/forced_movement_suite.gd")
const Privacy = preload("res://tests/suites/destruction_preview_privacy_suite.gd")

var _checks: int = 0
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	Privacy.run(_expect)
	Force.run(_expect)
	await Force.run_live(self, _expect)
	for failure: String in _failures: print("FAIL: " + failure)
	print("MRG-11I FORCE CHECKS: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok: _failures.append(message)
