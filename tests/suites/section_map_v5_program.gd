extends "res://tests/helpers/counted_program.gd"

const Suite = preload("res://tests/suites/section_map_v5_suite.gd")
# The separate legacy program retains the complete 200-seed hash sweep.
const LEGACY_HASH_SEEDS_IN_THIS_PROGRAM: int = 0

func _initialize() -> void:
	Suite.run(Callable(self, "_expect"), LEGACY_HASH_SEEDS_IN_THIS_PROGRAM)
	_finish("SECTION MAP V5 PROGRAM RESULT")
