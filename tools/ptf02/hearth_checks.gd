extends "res://tests/helpers/counted_program.gd"

const DepthSuite = preload("res://tests/suites/depth_rules_suite.gd")
const HearthSuite = preload("res://tests/suites/ember_hearth_suite.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DepthSuite._test_start_and_rewards(Callable(self, "_expect"))
	await HearthSuite.run(self, Callable(self, "_expect"))
	_finish("PTF02 HEARTH CHECKS RESULT")
