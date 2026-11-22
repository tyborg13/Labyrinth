extends SceneTree
## Run the existing mechanics assertions that underpin the audit's state receipts.

const Suites: Array = [
	["card keywords", preload("res://tests/suites/card_keywords_suite.gd")],
	["card keywords W3", preload("res://tests/suites/card_keywords_w3_suite.gd")],
	["card ground effects", preload("res://tests/suites/card_mechanics_surfaces_suite.gd")],
	["relic hooks", preload("res://tests/suites/relic_suite.gd")],
	["relic U1", preload("res://tests/suites/relic_u1_suite.gd")],
	["relic U2", preload("res://tests/suites/relic_u2_suite.gd")],
	["relic U3", preload("res://tests/suites/relic_u3_suite.gd")],
	["relic U4", preload("res://tests/suites/relic_u4_suite.gd")],
	["relic U5", preload("res://tests/suites/relic_u5_suite.gd")],
	["relic U6", preload("res://tests/suites/relic_u6_suite.gd")],
	["relic U8", preload("res://tests/suites/relic_u8_suite.gd")],
]

var _checks: int
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("QA122 mechanics failure: " + message)

func _run() -> void:
	for suite: Array in Suites:
		var before: int = _checks
		var failures_before: int = _failures
		suite[1].run(_check)
		print("QA122 mechanics %s: %d checks, %d failures" %
			[suite[0], _checks - before, _failures - failures_before])
	print("QA122 MECHANICS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
