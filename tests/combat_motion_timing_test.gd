extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const CombatMotionTimingSuite = preload("res://tests/suites/combat_motion_timing_suite.gd")
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://combat_motion_timing/progression.json")
	ProgressionStore.set_run_storage_path("user://combat_motion_timing/current_run.save")
	SettingsStore.set_storage_path("user://combat_motion_timing/settings.json")
	AnalyticsStore.set_storage_dir("user://combat_motion_timing/analytics")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	var capture: bool = _capture_requested()
	if capture:
		root.size = Vector2i(1920, 1080)
	await CombatMotionTimingSuite.run(self, Callable(self, "_expect"), capture)
	for failure: String in _failures:
		push_error(failure)
	print("COMBAT MOTION TIMING TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _capture_requested() -> bool:
	return false
