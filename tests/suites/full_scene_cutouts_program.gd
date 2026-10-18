extends "res://tests/run_tests.gd"

## Invocation-only partition; inherited assertion bodies are unchanged.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await process_frame
	_suppress_guided_tutorial_for_legacy_live_scene_tests()
	await preload("res://tests/suites/protagonist_cutout_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/strike_trail_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/enemy_strike_trail_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/protagonist_gear_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/contextual_cutout_suite.gd").run(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_cutouts_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_cutouts_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
