extends "res://tests/run_tests.gd"

## Invocation-only input partition; inherited assertion bodies are unchanged.
func _initialize() -> void:
	var started: int = Time.get_ticks_usec()
	_initialize_test_storage(true)
	await process_frame
	await CardDragPlaySuite.run_live(self, Callable(self, "_assert"))
	print("MAIN DOMAIN ASSERTIONS full_scene_card_drag_program: %d" % _assertion_count)
	print("MAIN DOMAIN RUNTIME full_scene_card_drag_program: %.3f seconds" % [float(Time.get_ticks_usec() - started) / 1000000.0])
	_finish_test_result()
