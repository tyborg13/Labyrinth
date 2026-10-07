extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Scenarios = preload("res://tests/helpers/protagonist_gear_motion_scenarios.gd")
const Playback = preload("res://tests/fixtures/protagonist_gear_motion_run_scene.gd")
var _errors: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	Progression.set_storage_path("user://gear_motion_test_profile.json")
	Progression.set_run_storage_path("user://gear_motion_test_run.save")
	Progression.clear_saved_run()
	root.size = Vector2i(1920, 1080)
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	scene.set_script(Playback)
	root.add_child(scene)
	for frame: int in range(8):
		await process_frame
	await Scenarios.run(scene, _expect)
	scene.queue_free()
	await process_frame
	for error: String in _errors:
		push_error(error)
	print("PROTAGONIST GEAR MOTION GAMEPLAY TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
