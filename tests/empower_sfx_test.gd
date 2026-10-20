extends SceneTree

const Suite = preload("res://tests/suites/empower_sfx_suite.gd")
const Fixtures = preload("res://tests/suites/card_keywords_suite.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
var failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Fixtures.install_fixtures()
	await Suite.run_live(self, _expect)
	Fixtures.remove_fixtures()
	Progression.clear_saved_run()
	for failure: String in failures: push_error(failure)
	print("EMPOWER SFX TEST RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
