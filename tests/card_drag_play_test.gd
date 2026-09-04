extends SceneTree

const CardDragPlaySuite = preload("res://tests/suites/card_drag_play_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://card_drag_play_test"))
	ProgressionStore.set_storage_path("user://card_drag_play_test/progression.json")
	ProgressionStore.set_run_storage_path("user://card_drag_play_test/current_run.save")
	SettingsStore.set_storage_path("user://card_drag_play_test/settings.json")
	ProgressionStore.clear_saved_run()
	CardDragPlaySuite.run(Callable(self, "_expect"))
	await CardDragPlaySuite.run_live(self, Callable(self, "_expect"))
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("CARD DRAG PLAY TEST RESULT: FAIL (%d)" % _failures.size())
		quit(1)
		return
	print("CARD DRAG PLAY TEST RESULT: PASS")
	quit()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
