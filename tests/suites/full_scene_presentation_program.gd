extends "res://tests/run_tests.gd"

## Invocation-only partition; inherited assertion bodies are unchanged.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await _test_main_scenes_instantiate()
	await preload("res://tests/suites/ui_components_suite.gd").run(self, Callable(self, "_assert"))
	_suppress_guided_tutorial_for_legacy_live_scene_tests()
	await EmberRewardFeedbackSuite.run(self, Callable(self, "_assert"))
	await En06EnemiesSuite.run_live(self, Callable(self, "_assert"))
	await En03EnemiesSuite.run_live(self, Callable(self, "_assert"))
	await preload("res://tests/suites/dragon_exchange_presentation_suite.gd").run_live(self, Callable(self, "_assert"))
	await CombatMotionTimingSuite.run(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_presentation_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_presentation_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
