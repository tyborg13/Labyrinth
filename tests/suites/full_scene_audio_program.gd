extends "res://tests/run_tests.gd"

## Invocation-only partition; inherited assertion bodies are unchanged.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	# Let autoloads enter the tree before the button suite checks is_loading().
	await process_frame
	await preload("res://tests/suites/ui_button_feedback_suite.gd").run(self, Callable(self, "_assert"))
	await RunSfxSuite.run(self, Callable(self, "_assert"))
	await AttackSfxSuite.run_live(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_audio_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_audio_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
