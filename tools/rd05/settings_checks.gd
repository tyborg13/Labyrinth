extends "res://tests/run_tests.gd"

# Reuse only the existing settings test; never invoke the full-suite entry point.
func _initialize() -> void:
	_initialize_test_storage()
	call_deferred("_rd05_settings")

func _rd05_settings() -> void:
	await _test_settings_persistence_audio_and_presentation_preferences()
	_finish_test_result()
