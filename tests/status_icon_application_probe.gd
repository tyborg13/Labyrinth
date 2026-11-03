extends SceneTree

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	await preload("res://tests/helpers/status_icon_application_benchmark.gd").run(self)
