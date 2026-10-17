extends "res://tests/suites/encounter_program_base.gd"

func _initialize() -> void:
	_write_visual_contract()
	Suite._test_validation(_expect)
	Suite._test_invalid_fallback(_expect)
	Suite._test_tokens_and_trim(_expect)
	Suite._test_weights(_expect)
	Suite._test_history(_expect)
	Suite._test_run_history(_expect)
	Suite._test_legacy(_expect)
	print("Encounter base totals: ", JSON.stringify(Suite.expansion_report()))
	_test_analytics()
	call_deferred("_headless_renderer_proof", "Encounter rules and renderers")
