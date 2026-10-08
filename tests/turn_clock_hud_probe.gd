extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const Suite = preload("res://tests/suites/turn_clock_hud_suite.gd")
const OUTPUT := "user://probes/turn_clock_hud/1920x1080"
var _failures: Array[String]

func _initialize() -> void:
	print("turn clock hud probe: start")
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://turn_clock_hud_profile.json")
	ProgressionStore.set_run_storage_path("user://turn_clock_hud_run.save")
	SettingsStore.set_storage_path("user://turn_clock_hud_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	var path: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path)
	# Suite asserts each state's pill/style, strip order, plate, size and no
	# tooltip overlap before each of the eight named SubViewport captures. Failed
	# states are recorded while the remaining states continue to be captured.
	await Suite.run(self, Callable(self, "_expect"), path)
	print(path)
	for failure: String in _failures:
		push_error(failure)
	print("TURN CLOCK HUD PROBE RESULT: PASS" if _failures.is_empty() else "TURN CLOCK HUD PROBE RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
