extends "res://tests/run_tests.gd"
## atk-03 focused proof (not in the default groups): the forecast suites the
## repeat-activation forecast, the disc marks and the half-Health copy touch.

func _initialize() -> void:
	_initialize_test_storage()
	preload("res://tests/suites/turn_clock_wait_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/enemy_intent_preview_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/lethal_preview_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/bos01_feedback2_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/bos01_rules_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/battlefield_rules_suite.gd").run(Callable(self, "_assert"))
	InitiativeOrderSuite.run(Callable(self, "_assert"))
	var forecast_scene: Node = preload("res://scripts/run_scene.gd").new()
	preload("res://tests/suites/turn_clock_hud_suite.gd")._test_forecasts(forecast_scene, Callable(self, "_assert"))
	preload("res://tests/suites/turn_clock_hud_review_suite.gd")._test_forecast_copy(forecast_scene, Callable(self, "_assert"))
	preload("res://tools/ptf08/row_tests.gd").run(forecast_scene, Callable(self, "_assert"))
	forecast_scene.free()
	await _test_run_scene_pass_preview_chip_updates()
	for message: String in _failures:
		print("FAIL: " + message)
	print("ATK03 FOCUSED RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
