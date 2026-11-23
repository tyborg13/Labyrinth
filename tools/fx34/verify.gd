extends "res://tools/fx34/native_capture.gd"

const Chain = preload("res://scripts/chain_attack_feedback.gd")
const NO_FRAME: int = -1
const GEAR_FRAMES: int = 11
const GEAR_SAMPLE_USEC: int = 45000
const REMAINDER_SECONDS: float = 0.08
const CLOCK_FIELDS: Array[String] = ["authored_frames", "rendered_frames", "authored_duration_usec"]

var _checks: int
var _failures: int

func _take() -> void:
	var output: String = _arg("--out")
	var baseline: String = _arg("--compare-before")
	var selected: String = _arg("--case")
	if not output.is_absolute_path() or (not selected.is_empty() and selected not in Fixture.CHAIN_CASES + Fixture.GEAR_CASES):
		_fail("Use tools/fx34/native.sh --dry-run [--case ID].")
		return
	_plan = true
	_install_plan_clock()
	for id: String in Fixture.CHAIN_CASES + Fixture.GEAR_CASES:
		if not selected.is_empty() and selected != id: continue
		for reduced: bool in [false, true]:
			var name: String = id + ("_reduced" if reduced else "")
			_record = id in Fixture.NATIVE_CASES and not reduced
			var report: Dictionary = await take_case(id, output.path_join(name), reduced)
			if report.is_empty(): return
			if baseline.is_empty():
				_check_base(name, report)
			else:
				var path: String = baseline.path_join(name).path_join("take.json")
				var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				_expect(before is Dictionary, name + " has exact-base proof")
				if before is Dictionary: _compare(name, before, report)
				_check_rows(name, report, reduced)
			if _record:
				_expect(report["reel_frames"] == REEL_PART_FRAMES and int(report["done"]) < REEL_PART_FRAMES,
					name + " has a complete three-second reel segment")
			print("FX-34 AUDIT %s painters %s primitives %s columns %s" % [name, report["painters"], report["primitives"], report["columns"]])
	print(output)
	print("FX-34 %s %s (%d checks, %d failures)" % ["BASELINE" if baseline.is_empty() else "VERIFY",
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _check_base(name: String, report: Dictionary) -> void:
	var hits: Array = report["paths"]
	if _case in Fixture.CHAIN_CASES:
		var target: String = _coord(Fixture.Witness.CONDUCTION_TARGET)
		_expect(hits.any(func(hit: Dictionary) -> bool: return hit["to"] == target and hit["path"].size() == 4),
			name + " resolves the four-cell floor route")
		if _case == "branches":
			_expect(hits.filter(func(hit: Dictionary) -> bool: return hit["kind"] == "conduction").size() == 3,
				name + " resolves three grouped branches")
		if not _reduced: _expect(report["primitives"].get("draw_polyline", 0) > 0, name + " exercises the old floor primitive")
	else:
		_expect(not report["missed"].is_empty(), name + " resolves missed gear")
		if _case != "fog_gear": _expect(report["primitives"].get("draw_rect", 0) > 0, name + " exercises the old cinder primitive")

func _compare(name: String, before: Dictionary, after: Dictionary) -> void:
	var observed: Dictionary = JSON.parse_string(JSON.stringify(after))
	for key: String in ["paths", "frames", "done", "origin", "columns", "submissions", "loot", "missed", "notice", "items", "beats", "shots"]:
		_expect(before[key] == observed[key], name + " preserves " + key)
	for key: String in CLOCK_FIELDS:
		_expect(before["clock"][key] == observed["clock"][key], name + " preserves clock " + key)
	var rows: Dictionary = Fx.metadata()["rows"]
	var floors: Array = [rows["lightning_floor_rear"], rows["lightning_floor_front"], rows["fire_floor_rear"], rows["fire_floor_front"]]
	var contacts: Array = observed["stamps"].filter(func(stamp: Dictionary) -> bool: return stamp["row"] not in floors)
	_expect(before["stamps"] == contacts, name + " preserves every existing contact stamp and its samples")
	_expect(after["painters"].is_empty(), name + " has zero deleted painter submissions")
	_expect(after["primitives"].is_empty(), name + " has zero effect primitive submissions")

func _check_rows(name: String, report: Dictionary, reduced: bool) -> void:
	var chain: bool = _case in Fixture.CHAIN_CASES
	var element: String = "lightning" if chain else "fire"
	var data: Dictionary = Fx.metadata()
	var rows: Dictionary = data["rows"]
	var expected: Dictionary = _expected_rows(report, chain)
	var actual: Array = report["stamps"].filter(func(stamp: Dictionary) -> bool:
		return int(stamp["row"]) in [int(rows[element + "_floor_rear"]), int(rows[element + "_floor_front"])] and (not chain or int(stamp["beat"]) == 1))
	_expect(actual.size() == 2 * expected.size(), name + " has one rear/front pair per visible floor tile")
	var all_cells: Array[int]
	if reduced:
		all_cells.append(int(data.get("reduced_motion_frame_by_burst", {}).get(element, data["reduced_motion_frame"])))
	else:
		all_cells.assign(range(int(data["frames"])))
	for tile: String in expected:
		var fraction: Array = expected[tile]
		var gate: float = 0.0 if not chain or reduced else float(fraction[0]) / float(fraction[1]) * Chain.HOP_CONTACT
		var frame: int = _first_sample_at(report["submissions"], gate)
		var sample: int = 1 if reduced or not chain else ceili(gate * 12)
		for front: bool in [false, true]:
			var matching: Array = actual.filter(func(stamp: Dictionary) -> bool: return stamp["tile"] == tile and stamp["front"] == front)
			_expect(matching.size() == 1, "%s %s has unique %s row" % [name, tile, "front" if front else "rear"])
			if matching.size() != 1: continue
			var stamp: Dictionary = matching[0]
			_expect(stamp["start"] == frame and stamp["sample"] == sample, "%s %s starts on sample %d at frame %d" % [name, tile, sample, frame])
			_expect(stamp["cells"] == all_cells, "%s %s plays its full row or still" % [name, tile])
			if reduced:
				var duration: float = data["reduced_motion_seconds"]
				var last_age: float = stamp["last_age"]
				_expect(last_age < duration and last_age + float(stamp["last_delta"]) >= duration - 0.000001,
					name + " retains the shared still duration on the tile player's clock")
			_expect(stamp["z"] == 0 and (int(stamp["depth"]) > 0 if front else int(stamp["depth"]) < 0),
				"%s %s has correct painter depth" % [name, tile])
			if tile == _coord(Fixture.BRANCH_HERO) and _case == "branches":
				_expect(not str(stamp["unit"]).is_empty(), name + " wraps the hero on an interior tile")
			print("FX-34 ROW %s %s %s_%s sample %d frame %d fraction %d/%d z %d order %+d vs %s cells %s" % [
				name, tile, element + "_floor", "front" if front else "rear", stamp["sample"], stamp["start"], fraction[0], fraction[1],
				stamp["z"], stamp["depth"], "tile" if str(stamp["unit"]).is_empty() else stamp["unit"], stamp["cells"]])
	if chain:
		_expect(report["beats"].size() == 2, name + " keeps the opening and grouped conduction beats")
		var contact: int = _first_sample_at(report["submissions"], 0.0 if reduced else Chain.HOP_CONTACT)
		for hit: Dictionary in report["paths"]:
			if hit["kind"] != "conduction": continue
			var count: int = report["stamps"].filter(func(stamp: Dictionary) -> bool:
				return (stamp["front"] and stamp["tile"] == hit["to"] and stamp["start"] == contact
					and int(stamp["row"]) == int(rows["lightning_hit_front"]))).size()
			_expect(count == 1, "%s preserves the Lightning hit at %s on frame %d" % [name, hit["to"], contact])
	else:
		_expect(report["submissions"].size() == GEAR_FRAMES, name + " keeps all eleven fade samples")
		_expect(int(report["clock"]["authored_duration_usec"]) >= GEAR_FRAMES * GEAR_SAMPLE_USEC, name + " retains the 0.495 s beat")
		var fade_end: int = _first_sample_at(report["submissions"], 1.0)
		var tail: int = int(report["done"]) - fade_end
		var expected_tail: int = ceili((GEAR_SAMPLE_USEC / 1000000.0 + REMAINDER_SECONDS) * FPS)
		_expect(absi(tail - expected_tail) <= 2, name + " retains the resolved-state tail")
		if _case == "salvaged":
			_expect(report["loot"].any(func(loot: Dictionary) -> bool:
				return loot.get("equipment_id") == Fixture.SECOND_ID and loot.get("resolution") == "salvaged"),
				name + " keeps equipment salvage resolution")

func _expected_rows(report: Dictionary, chain: bool) -> Dictionary:
	if not chain:
		if _case == "fog_gear": return {}
		var gear: Dictionary = {_coord(Fixture.FIRST_GEAR): [0, 1]}
		if _case == "two_missed": gear[_coord(Fixture.SECOND_GEAR)] = [0, 1]
		return gear
	var contacts: Array = []
	for hit: Dictionary in report["paths"]:
		if hit["kind"] == "conduction": contacts.append(hit["to"])
	var tiles: Dictionary = {}
	for hit: Dictionary in report["paths"]:
		var path: Array = hit["path"]
		var n: int = path.size() - 1
		for k: int in range(1, n):
			var tile: String = path[k]
			if tile in contacts or (_case == "fog_path" and tile == _coord(Fixture.FOG_TRUNK)): continue
			var old: Array = tiles.get(tile, [1, 1])
			if k * int(old[1]) < int(old[0]) * n: tiles[tile] = [k, n]
	return tiles

func _first_sample_at(samples: Dictionary, gate: float) -> int:
	var first: int = NO_FRAME
	for progress: String in samples:
		var frame: int = samples[progress]
		if float(progress) >= gate and (first < 0 or frame < first): first = frame
	return first

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	printerr("FX-34 CHECK FAILED " + message)
