extends SceneTree

const Suite = preload("res://tests/suites/health_ghost_suite.gd")
const ThemeSuite = preload("res://tests/suites/health_bar_theme_suite.gd")
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://scripts/progression_store.gd").set_storage_path("user://health_ghost/progression.json")
	preload("res://scripts/progression_store.gd").set_run_storage_path("user://health_ghost/run.save")
	preload("res://scripts/settings_store.gd").set_storage_path("user://health_ghost/settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://health_ghost/analytics")
	Suite.run(_expect)
	print("HEALTH GHOST TRACKER SUITE: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	var prior_failures: int = _failures.size()
	ThemeSuite.run(_expect)
	print("HEALTH BAR THEME SUITE: %s" % ("PASS" if _failures.size() == prior_failures else "FAIL"))
	prior_failures = _failures.size()
	await Suite.run_integration(self, _expect)
	print("HEALTH GHOST INTEGRATION SUITE: %s" % ("PASS" if _failures.size() == prior_failures else "FAIL"))
	for failure: String in _failures:
		push_error(failure)
	print("HEALTH GHOST TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
