extends "res://tests/enemy_no_action_test.gd"
## Real-renderer proof only; execute through tools/visual_probe_runner.py.
func _initialize() -> void:
	_visual_proof = true
	await super._initialize()
