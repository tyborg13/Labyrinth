extends "res://tests/pre_battle_fixture.gd"

const RunSceneScript = preload("res://scripts/run_scene.gd")

func _initialize() -> void:
	_setup()
	var host := RunSceneScript.new()
	await FoeSuite.test_true_scale_lineups(host, _expect)
	host.free()
	_viewport.queue_free()
	await process_frame
	print("PRE-BATTLE TRUE SCALE TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
