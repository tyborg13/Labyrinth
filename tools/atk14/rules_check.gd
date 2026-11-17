extends "res://tests/run_tests.gd"
## Focused existing rule/Chain suites; no full-suite entry point.
func _initialize() -> void:
	_initialize_test_storage()
	preload("res://tests/suites/battlefield_rules_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/battlefield_conduction_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/battlefield_fuel_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/chain_attack_suite.gd").run(Callable(self, "_assert"))
	_test_lightning_trap_wake_preserves_current_turn_actions()
	_test_lightning_trap_wake_never_banks_obsolete_control()
	_test_lightning_strikes_threat_tiles_are_previewed()
	_test_lightning_strikes_damage_incidental_terrain()
	for message: String in _failures: print("FAIL: " + message)
	print("ATK14 RULES RESULT: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)
