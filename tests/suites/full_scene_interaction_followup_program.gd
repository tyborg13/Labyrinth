extends "res://tests/suites/full_scene_interaction_program.gd"

## Invocation-only partition; all inherited assertion bodies are unchanged.
func _initialize() -> void:
	await _run_partition(1)
