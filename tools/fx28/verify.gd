extends "res://tools/fx28/native.gd"

const CASES28: Array[String] = ["hero", "empty", "crate", "crate_loss", "hidden"]

var _checks: int
var _failures: int

func _take() -> void:
	var output: String = _arg("--out")
	var base: String = _arg("--base-dir")
	var after_dir: String = _arg("--after-dir")
	if output.is_empty() or base.is_empty() or after_dir.is_empty():
		_fail("Use tools/fx28/native.sh --dry-run to stage both revisions.")
		return
	_install_headless_clock()
	for id: String in CASES28:
		for reduced: bool in [false, true]:
			var case_id: String = id + ("_reduced" if reduced else "")
			var before: Dictionary = await take_case(id, output.path_join("before").path_join(case_id), base, true, reduced)
			var after: Dictionary = await take_case(id, output.path_join("after").path_join(case_id), after_dir, true, reduced)
			if before.is_empty() or after.is_empty(): return
			_compare(case_id, before, after, reduced)
	var reel: Dictionary = await take_case("recording", output.path_join("after/recording"), after_dir, true)
	if reel.is_empty(): return
	_expect(reel["contact"] < REEL_FRAMES, "The real end-turn fight lands within the four-second reel")
	print("FX-28 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _compare(id: String, before: Dictionary, after: Dictionary, reduced: bool) -> void:
	for key: String in ["release", "contact", "numbers", "surfaces", "finish", "columns", "timeline", "turn_order", "initial", "final"]:
		_expect(before[key] == after[key], id + " preserves " + key)
	_expect(before["clock"]["authored_frames"] == after["clock"]["authored_frames"] and before["clock"]["authored_duration_usec"] == after["clock"]["authored_duration_usec"], id + " preserves the submitted animation clocks")
	_expect(before["travel"] > 0 if not reduced else before["travel"] == 0, id + " base travel")
	_expect(before["impact"] > 0, id + " base procedural impact")
	_expect(after["travel"] == 0 and after["impact"] == 0, id + " zero procedural submissions")
	var samples: Array = after["head_samples"]
	_expect(samples.is_empty() if reduced else samples.size() >= ARC_COLUMNS.size(), id + " baked flight visibility")
	if not samples.is_empty():
		var apex: Dictionary = samples[0]
		for sample: Dictionary in samples:
			_expect([sample["cell"], sample["row"], sample["size"]] == sample["expected"] and is_zero_approx(sample["position_error"]), id + " uses the selected ember frame and tangent")
			if absf(sample["t"] - sample["apex"]) < absf(apex["t"] - apex["apex"]): apex = sample
		var release: Dictionary = samples.front()
		var landing: Dictionary = samples.back()
		_expect(is_zero_approx(release["t"]) and release["cell"] / release["size"] != apex["cell"] / apex["size"] and apex["cell"] / apex["size"] != landing["cell"] / landing["size"], id + " headings change from release through apex and into landing")
		print("FX-28 %s EMBER: release=%s apex=%s landing=%s (atlas x,y,side)" % [id, release["expected"], apex["expected"], landing["expected"]])
	var rows: Dictionary
	for burst: Dictionary in after["bursts"]:
		var tile: String = burst["tile"]
		_expect(not rows.has(tile), id + " only one burst at " + tile)
		rows[tile] = burst["row"]
		_expect(burst["born"] == after["contact"], id + " burst begins at contact on " + tile)
		var still: int = int(Fx.metadata().get("reduced_motion_frame_by_burst", {}).get("fire", Fx.metadata()["reduced_motion_frame"]))
		_expect(burst["reduced"] == reduced and burst["cell"] == (still if reduced else 0), id + " initial baked burst cell on " + tile)
	var expected_hit: bool = after["final"]["health"] < after["initial"]["health"] or after["final"]["prop_hp"] < after["initial"]["prop_hp"]
	for tile: String in after["visible_tiles"]:
		var row: String = "fire_hit_front" if tile == after["target"] and expected_hit else "fire_floor_front"
		_expect(rows.get(tile) == row, id + " expected " + row + " on " + tile)
	_expect(rows.size() == after["visible_tiles"].size(), id + " bursts only on visible footprint tiles")
	if id.begins_with("hidden"):
		_expect(not after["visible_tiles"].has(after["target"]) and not after["visible_tiles"].is_empty(), id + " hides the center and exposes an arm")
	if id.begins_with("crate"):
		_expect(after["final"]["prop_hp"] > 0 and expected_hit == id.begins_with("crate_loss"), id + " verifies surviving crate and Health delta")
	print("FX-28 %s: release=%s contact=%s text=%s fire=%s finish=%s procedural=%s/%s→%s/%s rows=%s" % [id, after["release"], after["contact"], after["numbers"], after["surfaces"], after["finish"], before["travel"], before["impact"], after["travel"], after["impact"], rows])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
