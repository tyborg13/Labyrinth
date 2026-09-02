extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const AttackSfxSuite = preload("res://tests/suites/attack_sfx_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://card_draw_sfx_test")
	ProgressionStore.set_storage_path("user://card_draw_sfx_test/progression.json")
	ProgressionStore.set_run_storage_path("user://card_draw_sfx_test/current_run.save")
	SettingsStore.set_storage_path("user://card_draw_sfx_test/settings.json")
	AnalyticsStore.set_storage_dir("user://card_draw_sfx_test/analytics")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	AnalyticsStore.clear_storage()
	AttackSfxSuite.run(Callable(self, "_expect"))
	await AttackSfxSuite.run_live(self, Callable(self, "_expect"))
	if _failures.is_empty():
		print("CARD DRAW SFX TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	push_error("CARD DRAW SFX TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
