extends "res://tools/fx23/native.gd"

func _take() -> void:
	var output: String = _arg("--out")
	if DisplayServer.get_name() != "headless" or output.is_empty():
		_fail("Provide a headless run and --out.")
		return
	_install_headless_clock()
	var cases: Dictionary = Cases23.HERO_CASES.merged(Cases23.inventory())
	for id: String in cases:
		if (await take_case(id, output.path_join(id), "", true)).is_empty(): return
	var reel: Dictionary = await take_case(Cases23.RECORDING, output.path_join("recording"), "", true)
	if reel.get("recorded_shots") != ["ember", "spark"] or reel.get("reel_frames") != REEL_FRAMES:
		_fail("The capture plan must play Ember and Spark in the 240-frame reel.")
		return
	print("MRG-15 FX-23 CAPTURE PLAN: PASS (%d strips, %d reel frames)" % [cases.size(), REEL_FRAMES])
	quit()
