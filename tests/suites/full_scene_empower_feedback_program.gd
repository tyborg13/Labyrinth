extends "res://tests/run_tests.gd"

## Independent feedback cases formerly invoked inside the controls partition.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await process_frame
	preload("res://tests/suites/cutout_render_gate_suite.gd").run(self, Callable(self, "_assert"))
	CardKeywordsSuite.install_fixtures()
	await preload("res://tests/suites/empower_seal_suite.gd").run_feedback(self, Callable(self, "_assert"), CardKeywordsSuite)
	CardKeywordsSuite.remove_fixtures()
	ProgressionStore.clear_saved_run()
	print("MAIN DOMAIN ASSERTIONS full_scene_empower_feedback_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_empower_feedback_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
