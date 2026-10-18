extends "res://tests/helpers/counted_program.gd"

## The unchanged fix-05 regression gets its own bounded scheduler slot.
const Suite = preload("res://tests/suites/section_map_performance_suite.gd")
func _initialize() -> void:
	Suite.run(Callable(self, "_expect"))
	_finish("SECTION MAP PERFORMANCE PROGRAM RESULT")
