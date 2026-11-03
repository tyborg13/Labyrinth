extends SceneTree

## Focused existing suites only. No full-suite discovery or renderer claim.
var _failures: Array[String]
var _checks: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	preload("res://tests/suites/actor_presentation_suite.gd").run(_expect)
	await preload("res://tests/suites/maquette_presentation_surfaces_suite.gd").run(_expect)
	print("MQ27 RUNTIME: %s (%d checks; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
