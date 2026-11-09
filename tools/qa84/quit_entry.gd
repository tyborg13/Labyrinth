extends SceneTree

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_start.call_deferred()

func _start() -> void:
	root.add_child(preload("res://tools/qa84/quit_probe.gd").new())
