extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
var _errors: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	var renderer := Renderer.new()
	root.add_child(renderer)
	await process_frame
	renderer.set_process(false)
	var scene: Node = load("res://scripts/run_scene.gd").new()
	preload("res://tests/suites/protagonist_ranged_suite.gd").run(renderer, scene, _expect)
	scene.free()
	renderer.free()
	for error: String in _errors:
		push_error(error)
	print("PROTAGONIST RANGED TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
