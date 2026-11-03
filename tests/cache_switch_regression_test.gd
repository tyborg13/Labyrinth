extends "res://tests/run_tests.gd"

# Run the existing assertions unchanged, without invoking the full suite's
# _initialize or its program-suite scheduler.
func _initialize() -> void:
	_initialize_test_storage()
	SteamServiceSuite.run(Callable(self, "_assert"))
	print("STEAM SERVICE TEST RESULT: %s" % ["PASS" if _failures.is_empty() else "FAIL"])
	preload("res://tests/helpers/steam_cache_switch_regressions.gd").run(Callable(self, "_assert"))
	print("STEAM CACHE SWITCH REGRESSION RESULT: %s" % ["PASS" if _failures.is_empty() else "FAIL"])
	await _test_settings_persistence_audio_and_presentation_preferences()
	for failure: String in _failures: push_error(failure)
	print("CACHE SWITCH STEAM/SETTINGS TEST RESULT: %s (%d assertions)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count])
	quit(0 if _failures.is_empty() else 1)
