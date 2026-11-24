extends "res://tests/helpers/counted_program.gd"

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Guardian = preload("res://tests/suites/guardian_suite.gd")
const Fix03 = preload("res://tests/suites/fix_03_suite.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Guardian.run(_expect)
	Fix03.run(_expect)
	_finish("GFIX-56 GUARDIAN AND FIX-03")
