extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const EmberRewardFeedbackSuite = preload("res://tests/suites/ember_reward_feedback_suite.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://ember_reward_feedback_test")
	ProgressionStore.set_storage_path("user://ember_reward_feedback_test/progression.json")
	ProgressionStore.set_run_storage_path("user://ember_reward_feedback_test/current_run.save")
	SettingsStore.set_storage_path("user://ember_reward_feedback_test/settings.json")
	AnalyticsStore.set_storage_dir("user://ember_reward_feedback_test/analytics")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	AnalyticsStore.clear_storage()
	await EmberRewardFeedbackSuite.run(self, Callable(self, "_expect"))
	if _failures.is_empty():
		print("EMBER REWARD FEEDBACK TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	push_error("EMBER REWARD FEEDBACK TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
