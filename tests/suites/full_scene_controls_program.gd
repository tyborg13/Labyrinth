extends "res://tests/run_tests.gd"

## Invocation-only input partition; inherited assertion bodies are unchanged.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await process_frame
	await preload("res://tests/suites/cbt_01_suite.gd").run_live(self, Callable(self, "_assert"))
	await ForcedMovementSuite.run_live(self, Callable(self, "_assert"))
	await CardKeywordsSuite.run_live(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_controls_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_controls_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
