extends "res://tools/fx27/native_capture.gd"

const MIMIC_CASES: Array[String] = ["shade_bolt", "echo"]
const MIMIC_FRAMES := 48
const MIMIC_CONTACT_SAMPLE := 28
var _checks: int
var _failures: int

func _take() -> void:
	var base: String = _arg("--base-dir")
	var output: String = _arg("--out")
	if base.is_empty() or output.is_empty():
		_fail("Use tools/fx27/native.sh --dry-run.")
		return
	_install_headless_clock()
	for id: String in STRIPS:
		for reduced: bool in [false, true]:
			var suffix: String = id + ("_reduced" if reduced else "")
			var before: Dictionary = await take_case(id, output.path_join("before").path_join(suffix), base, true, reduced)
			var after: Dictionary = await take_case(id, output.path_join("after").path_join(suffix), "", true, reduced)
			if before.is_empty() or after.is_empty(): return
			_compare(suffix, before, after, reduced)
	for id: String in FOG_CASES:
		var take: Dictionary = await take_case(id, output.path_join("after").path_join(id), "", true)
		if take.is_empty(): return
		var beat: Dictionary = take["beat"]
		var spans: Array = beat["clip"]
		_expect(not spans.is_empty() and not beat["flight"].is_empty(), id + " submits the visible segment")
		if not spans.is_empty():
			var clipped: bool = spans[0][0] > 0.0 if id == "hidden_source" else spans[-1][1] < 1.0
			_expect(clipped, id + " clips its hidden endpoint")
		_expect(beat["hits"].size() == (1 if id == "hidden_source" else 0), id + " only hits a visible target")
		print("FX-27 UMBRA %s spans=%s hits=%d" % [id, spans, beat["hits"].size()])
	var old_echo: Dictionary = await take_case(RETALIATE_CASE, output.path_join("before").path_join(RETALIATE_CASE), base, true)
	if old_echo.is_empty(): return
	var new_echo: Dictionary = await take_case(RETALIATE_CASE, output.path_join("after").path_join(RETALIATE_CASE), "", true)
	if new_echo.is_empty(): return
	var retaliate: Dictionary = new_echo["beat"]["retaliate"]
	_expect(retaliate == old_echo["beat"]["retaliate"] and retaliate["frame"] > new_echo["beat"]["contact"]
		and retaliate["amount"] > 0 and new_echo["beat"]["hits"].size() == 1, "Echo preserves its separate Retaliate action")
	print("FX-27 RETALIATE frame=%d amount=%d" % [retaliate["frame"], retaliate["amount"]])
	var reel: Dictionary = await take_case(Cases25.REEL, output.path_join("after/recording"), "", true)
	_expect(reel.get("reel_frames") == REEL_FRAMES and reel.get("beat", {}).get("id") == "shade_bolt"
		and reel.get("beat", {}).get("hits", {}).size() == 1, "The 240-frame reel plays one resolved Shade Bolt at the hero")
	print("FX-27 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _compare(id: String, before: Dictionary, after: Dictionary, reduced: bool) -> void:
	var old: Dictionary = before["beat"]
	var beat: Dictionary = after["beat"]
	var mimic: bool = beat["id"] in MIMIC_CASES
	var area: bool = beat["id"] == "area_ranged"
	for key: String in ["frames", "rendered", "duration_usec", "done", "columns"]:
		_expect(before[key] == after[key], id + " preserves " + key)
	for key: String in ["contact", "authored_contact", "samples", "losses", "tiles", "target"]:
		_expect(old[key] == beat[key], id + " preserves " + key)
	_expect(not mimic or reduced or (after["frames"] == MIMIC_FRAMES and beat["contact"] == MIMIC_CONTACT_SAMPLE),
		id + " keeps the 48-frame beat and contact sample 28")
	_expect(old["flight"].is_empty() == (reduced or mimic), id + " measures the base flight state")
	_expect(beat["flight"].is_empty() == reduced, id + " flies Shade only in normal motion")
	if not reduced:
		_expect(beat["authored_release"] == beat["expected_release"] and beat["shot_release"] == beat["scheduled_release"], id + " releases at the style's sampled release frame")
		_expect(int(beat["flight"].keys()[-1]) + 1 == beat["contact"], id + " flies up to contact")
		if mimic: _expect(beat["launch_at_hand"], id + " starts from the posed casting hand")
	var hit: Dictionary = {"row": "hit_gloom", "tile": beat["target"], "frame": beat["contact"]}
	_expect(beat["hits"].values() == ([] if area else [hit]), id + " reserves Gloom for single-target contact")
	_expect(old["hits"].values() == ([] if area else [hit]), id + " measures the base Gloom arrival")
	_expect(beat["legacy"].is_empty() and old["legacy"].is_empty(), id + " has zero legacy decals")
	if area:
		var rows: Array = beat["pairs"].values()
		_expect(beat["aimed_centre"] and rows.size() == 2 * beat["tiles"].size(), id + " arrives at the aim and has a tendril pair on every tile")
		_expect(rows == old["pairs"].values() and rows.all(func(row: Dictionary) -> bool: return row["submitted"] == beat["contact"]), id + " preserves tendril rows and their contact sample")
	else:
		_expect(beat["pairs"].is_empty(), id + " has no redundant tile burst")
	print("FX-27 STEP %s frames=%d/%d contact=%d/%d authored_contact=%d release_sample=%d/%d authored_release=%d/%d gloom=%d/%d tendril_layers=%d/%d decals=%d/%d" % [
		id, before["frames"], after["frames"], old["contact"], beat["contact"], beat["authored_contact"],
		old["shot_release"], beat["shot_release"], old["authored_release"], beat["authored_release"],
		old["hits"].size(), beat["hits"].size(), old["pairs"].size(), beat["pairs"].size(),
		old["legacy"].size(), beat["legacy"].size()])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)
