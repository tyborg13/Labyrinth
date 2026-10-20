extends SceneTree

const Suite = preload("res://tests/suites/empower_seal_tooltip_suite.gd")
const Fixtures = preload("res://tests/suites/card_keywords_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Fixtures.install_fixtures()
	await Suite.run_live(self, _expect, Fixtures)
	Fixtures.remove_fixtures()
	Progression.clear_saved_run()
	for failure: String in failures: push_error(failure)
	print("EMPOWER SEAL TOOLTIP TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
