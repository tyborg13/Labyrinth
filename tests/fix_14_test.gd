extends "res://tests/fix_12_test.gd"

const Cascades = preload("res://tests/suites/fix_14_suite.gd")

func _run() -> void:
	Cascades.legacy_check(_expect)
	if not OS.get_cmdline_user_args().has("--legacy-only"): Cascades.run(_expect)
	if not OS.get_cmdline_user_args().has("--check-only"): await _test_playback()
	for failure: String in _failures: push_error(failure)
	print("FIX-14 TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_playback() -> void:
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_factor = 1.0
	var progression = preload("res://scripts/progression_store.gd")
	progression.set_storage_path("user://fix_14_profile.json")
	progression.set_run_storage_path("user://fix_14_run.save")
	preload("res://scripts/settings_store.gd").set_storage_path("user://fix_14_settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://fix_14_analytics")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Observer)
	root.add_child(scene)
	await _settle()
	scene.call("_load_run_state", preload("res://scripts/run_engine.gd").new().create_new_run(Suite.Fixtures.TEST_SEED, progression.default_data()))
	await _settle()
	await _cascade_playback(scene)
	for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false): player.call("stop")
	scene.queue_free()
	await process_frame

func _cascade_playback(scene: Control) -> void:
	if not OS.get_cmdline_user_args().has("--legacy-only"): await Cascades.run_playback(self, scene, _expect)
	await Cascades.run_playback(self, scene, _expect, Callable(), true)
