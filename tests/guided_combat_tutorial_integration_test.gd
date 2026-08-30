extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GuidedCombatTutorialSuite = preload("res://tests/suites/guided_combat_tutorial_suite.gd")

const STORAGE_PATH: String = "user://guided_combat_tutorial_integration_test.json"
const RUN_STORAGE_PATH: String = "user://guided_combat_tutorial_integration_test.save"

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	call_deferred("_run_suite")


func _run_suite() -> void:
	_remove_test_files()
	GuidedCombatTutorialSuite.run(Callable(self, "_expect"))
	_remove_test_files()
	if _failures.is_empty():
		print("GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("GUIDED COMBAT TUTORIAL INTEGRATION TEST: FAIL (%d)" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _remove_test_files() -> void:
	for path: String in [
		STORAGE_PATH,
		STORAGE_PATH + ".backup",
		STORAGE_PATH + ".tmp",
		RUN_STORAGE_PATH,
		RUN_STORAGE_PATH + ".backup",
		RUN_STORAGE_PATH + ".tmp",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
