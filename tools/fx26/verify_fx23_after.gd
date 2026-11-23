extends "res://tools/fx23/verify.gd"
## Keep fx-23's after-side checks when its old scripts cannot load on this base.

func _take() -> void:
	var output: String = _arg("--out")
	var after_dir: String = _arg("--after-dir")
	if output.is_empty() or after_dir.is_empty():
		_fail("Provide --out and the instrumented fx-23 --after-dir.")
		return
	_install_headless_clock()
	var cases: Dictionary = Cases23.HERO_CASES.duplicate()
	cases.merge(Cases23.inventory())
	for id: String in cases:
		var take: Dictionary = await take_case(id, output.path_join(id), after_dir, true)
		if take.is_empty(): return
		var expected: String = cases[id][1] if Cases23.HERO_CASES.has(id) else cases[id][3]
		print("FX-23 AFTER %s %s" % [id, _summary(take)])
		_expect(take["shot"] == expected, id + " keeps its primary shot selection")
		_expect(not take["legacy_flight"] and not take["legacy_release"], id + " has no procedural Fire/Lightning flight or release")
		if expected.is_empty():
			_expect(take["draw_frames"].is_empty(), id + " keeps the protected dragon renderer")
		else:
			var flights: Array = take["draw_frames"]
			_expect(not flights.is_empty() and flights[-1] < take["contact"], id + " keeps its baked flight before contact")
		if id in ["fire_area", "lightning_area"]:
			_expect(take["ends_at_center"] and not take["bursts"].is_empty(), id + " keeps tile-centre flight and area rows")
		if id in ["fire_hit", "fire_blocked", "fire_floor", "lightning_hit", "slag_mortar_scatter_shot"]:
			var element: String = "lightning" if id == "lightning_hit" else "fire"
			var floor_contact: bool = id in ["fire_floor", "slag_mortar_scatter_shot"]
			_expect(_rows(take) == [element + ("_floor_front" if floor_contact else "_hit_front")], id + " keeps its outcome row")
		if id == "fire_blocked":
			_expect(take["loss"][0] == 0 and take["loss"][1] > 0, id + " spends Block")
		if id == "fire_floor":
			_expect(take["loss"] == [0, 0, 0], id + " loses no pools")
		if id == "lightning_chain":
			_expect(take["electrical_trace"], id + " preserves the resolver trace")
	var reduced: Dictionary = await take_case("fire_hit", output.path_join("fire_reduced"), after_dir, true, true)
	_expect(reduced.get("shot") == "ember" and reduced.get("draw_frames", [0]).is_empty()
		and _rows(reduced) == ["fire_hit_front"] and not reduced.get("legacy_flight") and not reduced.get("legacy_release"),
		"Reduced motion hides the shot and keeps the contact")
	var reel: Dictionary = await take_case(Cases23.RECORDING, output.path_join("recording"), after_dir, true)
	_expect(reel.get("reel_frames") == REEL_FRAMES and reel.get("recorded_shots") == ["ember", "spark"], "The 240-frame reel plays Fire then Lightning")
	_fog_proof = true
	var fog: Dictionary = await take_case("lightning_wisp_static_lash", output.path_join("wisp_fog"), after_dir, true)
	_expect(not fog.get("caster_visible", true) and fog.get("clip_start", -1.0) > 0.0 and _rows(fog) == ["lightning_hit_front"],
		"The hidden Wisp's shot clips its origin and contacts the visible hero")
	print("FX-23 AFTER-ONLY VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
