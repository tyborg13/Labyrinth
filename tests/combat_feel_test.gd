extends SceneTree

const Suite = preload("res://tests/suites/combat_feel_suite.gd")
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://scripts/progression_store.gd").set_storage_path("user://feel_progression.json")
	preload("res://scripts/progression_store.gd").set_run_storage_path("user://feel_run.save")
	preload("res://scripts/settings_store.gd").set_storage_path("user://feel_settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://feel_analytics")
	await Suite.run(self,Callable(self,"_expect"))
	for failure: String in _failures:
		push_error(failure)
	print("FLOATING COMBAT TEXT TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	print("COMBAT FEEL TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
