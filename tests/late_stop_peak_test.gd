extends SceneTree

const Suite = preload("res://tests/suites/combat_feel_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	Suite._test_late_stop_peak(self, func(ok: bool, message: String) -> void:
		if not ok: failures.append(message)
	)
	for failure: String in failures: push_error(failure)
	print("LATE STOP PEAK TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
