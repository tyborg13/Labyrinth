extends "res://tests/pre_battle_deck_fit_probe.gd"

func _initialize() -> void:
	_setup()
	await _run_deck_proof(false)
	_viewport.queue_free()
	await process_frame
	print("PRE-BATTLE DECK FIT TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
