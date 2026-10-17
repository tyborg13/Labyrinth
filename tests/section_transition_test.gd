extends SceneTree
const Suite = preload("res://tests/suites/section_transition_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	Suite.run(_expect)
	await Suite.run_live(self, _expect)
	for failure: String in failures: push_error(failure)
	print("SECTION TRANSITION RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
