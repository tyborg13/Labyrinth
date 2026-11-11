extends "res://tests/helpers/counted_program.gd"

# Isolate the main suite's enemy-tooltip continuity assertions without starting
# the full main body or its child-program scheduler.
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(Callable(self, "_expect"))
	_finish("PTF02 ENEMY INTENT CHECKS RESULT")
