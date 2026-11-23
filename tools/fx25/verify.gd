extends "res://tools/fx25/native_capture.gd"

const RANGED: Array[String] = ["veil_needle", "echo", "shade_bolt"]
const PROTECTED: Array[String] = ["void_claw", "night_coil", "starless_breath", "last_eclipse"]
const REDUCED_WITNESS := "area_ranged_reduced"
const RANGED_AREA: Array[String] = ["area_ranged", "area_terrain_hp"]
var _checks: int
var _failures: int

func _take() -> void:
	var output: String = _arg("--out")
	var baseline: String = _arg("--compare-before")
	var filter: String = _arg("--case")
	if output.is_empty() or (not filter.is_empty() and not Cases25.CASES.has(filter) and filter not in [Cases25.REEL, REDUCED_WITNESS]):
		_fail("Use tools/fx25/native.sh --dry-run [--case ID].")
		return
	_install_headless_clock()
	var ids: Array[String]
	ids.assign(Cases25.CASES.keys())
	ids.append_array([REDUCED_WITNESS, Cases25.REEL])
	for id: String in ids:
		if not filter.is_empty() and id != filter: continue
		var reduced: bool = id == REDUCED_WITNESS
		var report: Dictionary = await take_case("area_ranged" if reduced else id, output.path_join(id), "", true, reduced)
		_expect(not report.is_empty(), id + " completes playback")
		if report.is_empty(): continue
		_print_report(id, report, "before" if baseline.is_empty() else "after")
		if not baseline.is_empty():
			var path: String = baseline.path_join(id).path_join("take.json")
			_expect(FileAccess.file_exists(path), id + " has an exact-base comparison")
			if FileAccess.file_exists(path):
				_compare(id, JSON.parse_string(FileAccess.get_file_as_string(path)), report, reduced)
	print("FX-25 %s: %s (%d checks, %d failures)" % [
		"BASELINE" if baseline.is_empty() else "VERIFY", "PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _print_report(id: String, report: Dictionary, revision: String) -> void:
	for beat: Dictionary in report["beats"]:
		var pair_counts: Dictionary
		for pair: Dictionary in beat["pairs"].values():
			if pair["row"].ends_with("_front"):
				pair_counts[pair["tile"]] = pair_counts.get(pair["tile"], 0) + 1
		for hit: Dictionary in beat["hits"].values():
			pair_counts[hit["tile"]] = pair_counts.get(hit["tile"], 0) + 1
		print("FX-25 STEP %s %s/%s frames=%d duration_usec=%d contact=%d phase=%.5f done=%d unique_baked_impact=%s" % [
			revision, id, beat["id"], report["frames"], report["duration_usec"], beat["contact"], beat["contact_phase"],
			report["done"], not pair_counts.values().any(func(count: int) -> bool: return count > 1)])
		print(JSON.stringify({"pairs": beat["pairs"].values(), "shot_frames": beat["flight"], "shot_hits": beat["hits"].values(),
			"legacy": beat["legacy"], "hidden": beat["hidden"], "losses": beat["losses"], "tiles": beat["tiles"]}))

func _compare(id: String, before: Dictionary, after: Dictionary, reduced: bool) -> void:
	for key: String in ["frames", "rendered", "duration_usec", "done", "columns", "reel_frames"]:
		_expect(_same(before[key], after[key]), "%s preserves %s (%s / %s)" % [id, key, before[key], after[key]])
	for index: int in after["beats"].size():
		var beat: Dictionary = after["beats"][index]
		var old: Dictionary = before["beats"][index]
		var label: String = beat["id"]
		_expect(beat["contact"] >= 0, label + " has a contact")
		for key: String in ["losses", "terrain_lost", "contact", "contact_phase", "samples", "tiles", "hidden"]:
			_expect(_same(old[key], beat[key]), label + " preserves " + key)
		# fx-27 deliberately adds flight to the two Mimic single-target attacks.
		if label in ["echo", "shade_bolt"]:
			_expect(old["flight"].is_empty() and not beat["flight"].is_empty(), label + " adds Shade before the original contact")
		else:
			_expect(_same(old["flight"], beat["flight"]), label + " preserves flight")
		if label in RANGED:
			_expect(beat["pairs"].is_empty(), label + " never adds a tile burst to its mapped shot")
			if label == "veil_needle":
				_expect(not beat["flight"].is_empty(), label + " plays the existing Shade flight")
			var hits: Array = beat["hits"].values()
			_expect(hits.size() == 1 and hits[0]["row"] == "hit_gloom" and hits[0]["tile"] == beat["target"], label + " submits exactly one Gloom hit on the target")
			_expect(_same(old["hits"].values(), hits), label + " preserves Gloom submission timing")
			_expect(beat["legacy"].is_empty(), label + " submits no neutral decal under its mapped hit")
		elif label in PROTECTED:
			_expect(beat["pairs"].is_empty() and beat["hits"].is_empty() and _same(old["legacy"], beat["legacy"]),
				label + " keeps the protected dragon presentation")
		else:
			_check_pairs(beat, reduced)
		if label == "area_zero_blocked":
			_expect(beat["losses"]["hp"] == 0 and beat["losses"]["block"] > 0, label + " spends Block with no Health loss")
		elif label == "area_umbra":
			_expect(not beat["hidden"].is_empty() and beat["hidden"].size() < beat["tiles"].size(), label + " has both hidden and visible tiles")
		elif label == "area_terrain_hp":
			_expect(not beat["terrain_lost"].is_empty(), label + " damages surviving terrain")
		elif label == "area_ranged":
			_expect(beat["tiles"].size() == 3 and beat["losses"]["hp"] > 0, label + " resolves the hero and two neighbours")
		if label in RANGED_AREA:
			_expect(beat["flight"].is_empty() if reduced else not beat["flight"].is_empty(), label + " flies Shade only in normal motion")
	if id == Cases25.REEL:
		_expect(after["beats"][0]["contact"] < after["beats"][1]["contact"] and after["beats"][1]["contact"] < REEL_FRAMES,
			"Area then melee contact both fit the four-second reel")

func _check_pairs(beat: Dictionary, reduced: bool) -> void:
	var label: String = beat["id"]
	var center := _tile(beat["center"])
	var visible: Array = beat["tiles"].filter(func(tile: String) -> bool: return not beat["hidden"].has(tile))
	var area: bool = beat["action"] in ["aoe", "terrain_burst"]
	var rows: Array = beat["pairs"].values()
	_expect(beat["legacy"].is_empty(), label + " submits no legacy contact or footprint")
	_expect(rows.size() == 2 * visible.size(), label + " has exactly one pair per visible tile")
	_expect(beat["hits"].is_empty(), label + " uses only its tile bursts on arrival")
	_expect(not area or beat["replace_targeted"], label + " publishes the area replacement flag")
	for cell: String in visible:
		var pair: Array = rows.filter(func(entry: Dictionary) -> bool: return entry["tile"] == cell)
		if pair.size() != 2:
			_expect(false, label + " has two layers on " + cell)
			continue
		var hit: bool = cell in beat["terrain_lost"] or (cell == Cases20.coords(Cases25.HERO) and beat["losses"].values().any(func(loss: int) -> bool: return loss > 0))
		var prefix: String = "shadow_hit" if hit else "shadow_floor"
		var actual: Array = pair.map(func(entry: Dictionary) -> String: return entry["row"])
		_expect(actual.has(prefix + "_rear") and actual.has(prefix + "_front"), label + " selects " + prefix + " on " + cell)
		var delay: float = 0.0 if reduced or not area else minf(Fx.metadata()["max_delay_seconds"],
			Paths.manhattan(center, _tile(cell)) * float(Fx.metadata()["delay_per_tile_seconds"]))
		for entry: Dictionary in pair:
			_expect(entry["submitted"] == beat["contact"], label + " submits both layers at the existing contact")
			_expect(absf(entry["delay"] - delay) < CONTACT_EPSILON, label + " keeps the board-clock delay on " + cell)
			_expect(entry["first_visible"] >= entry["submitted"], label + " plays both layers on " + cell)
			if reduced:
				_expect(entry["still"] == int(Fx.metadata()["reduced_motion_frame_by_burst"]["shadow"]), label + " uses Shadow still frame 4")
		_expect(pair[0]["first_visible"] == pair[1]["first_visible"], label + " aligns both layers on " + cell)
	for cell: String in beat["hidden"]:
		_expect(rows.all(func(entry: Dictionary) -> bool: return entry["tile"] != cell), label + " skips Umbra tile " + cell)

func _tile(cell: String) -> Vector2i:
	var fields: PackedStringArray = cell.split(":")
	return Vector2i(int(fields[0]), int(fields[1]))

func _same(old: Variant, current: Variant) -> bool:
	return old == JSON.parse_string(JSON.stringify(current))

func _expect(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)
