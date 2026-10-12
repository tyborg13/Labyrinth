extends "res://tests/threats_at_rest_test.gd"
## Run only with tools/visual_probe_runner.py and a real windowed renderer.
## The focused headless test shares every semantic/input assertion, but never
## attempts a capture or claims pixel proof.

func _initialize() -> void:
	_visual_proof = true
	await super._initialize()
