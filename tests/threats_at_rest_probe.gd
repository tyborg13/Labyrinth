extends "res://tests/threats_at_rest_test.gd"
## V2: open/crowded feet chips, order discs, tags, peak halo, live move previews
## and the four wave E2 intents around the hero (13_wave_e2_rest).
## Run only with tools/visual_probe_runner.py and a real windowed renderer.
## The focused headless test shares every semantic/input assertion, but never
## attempts a capture or claims pixel proof.

func _initialize() -> void:
	_visual_proof = true
	await super._initialize()

func _test_wave_e2_stage(scene: Node, combat: RefCounted) -> void:
	await super._test_wave_e2_stage(scene, combat)
	await _capture("13_wave_e2_rest_1920x1080")
