extends "res://tests/run_tests.gd"

## Invocation-only extraction of the turn-clock and card-pool presentation checks.
## Assertions remain inherited verbatim from their original suite bodies.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await preload("res://tests/suites/turn_clock_copy_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/turn_clock_hud_suite.gd").run(self, Callable(self, "_assert"))
	await preload("res://tests/suites/card_pool_overhaul_suite.gd").run_live(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_clock_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_clock_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
