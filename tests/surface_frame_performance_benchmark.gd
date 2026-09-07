extends "res://tests/runtime_frame_performance_benchmark.gd"

func _initialize() -> void:
	OS.set_environment("LABYRINTH_RUNTIME_PERF_SURFACE_ONLY", "1")
	OS.set_environment("LABYRINTH_RUNTIME_PERF_CAPPED_HAND", "1")
	await super._initialize()
