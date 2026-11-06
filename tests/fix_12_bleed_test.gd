extends "res://tests/fix_12_test.gd"

func _run() -> void:
	await run_shard("bleed")

func _run_playback_group(scene: Control) -> void:
	preload("res://tests/suites/fix_14_bleed_suite.gd").check_status_tick_feedback(scene, _expect)
	await super._run_playback_group(scene)
