extends "res://tools/fx33/native_capture.gd"

const REMOVED: Array[String] = ["death_tile_glow_dispatch", "death_puff", "death_ribbon", "air_line_dispatch", "air_painter_route"]
const CLOCK_FIELDS: Array[String] = ["authored_frames", "rendered_frames", "authored_duration_usec"]
const FOCUSED: Array[String] = ["chain_attack", "battlefield_conduction", "en01_enemies", "en06_enemies", "hoarder"]

var _checks: int
var _failures: int

func _take() -> void:
	if OS.get_cmdline_user_args().has("--focused"):
		for suite: String in FOCUSED:
			var failures: int = _failures
			await (load("res://tests/suites/%s_suite.gd" % suite) as Script).run(_expect)
			print("FX-33 FOCUSED %s %s" % [suite, "PASS" if _failures == failures else "FAIL"])
		_finish()
		return
	_plan = true
	_install_plan_clock()
	var output: String = _arg("--out")
	var baseline: String = _arg("--compare-before")
	var requested: String = _arg("--case")
	if not output.is_absolute_path() or (not requested.is_empty() and requested not in Fixtures.CASES):
		_fail("Use tools/fx33/native.sh --dry-run [--case name].")
		return
	var cases: Array[String] = Fixtures.CASES.duplicate()
	if not requested.is_empty(): cases.assign([requested])
	for id: String in cases:
		if id == "recording" and not OS.get_cmdline_user_args().has("--reel"): continue
		for reduced: bool in ([false] if id == "recording" else [false, true]):
			var take: String = id + ("_reduced" if reduced else "")
			var report: Dictionary = await take_case(id, output.path_join(take), reduced)
			if report.is_empty(): return
			if not baseline.is_empty():
				var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline.path_join(take).path_join("take.json")))
				_compare(take, before, report)
			_print_take(take, report)
	_finish()

func _compare(take: String, before: Dictionary, after: Dictionary) -> void:
	var observed: Dictionary = JSON.parse_string(JSON.stringify(after))
	for field: String in ["done", "actions", "frames", "resolved", "view_frames", "strikes", "capacitor_contacts"]:
		_expect(before[field] == observed[field], take + " preserves " + field)
	for field: String in CLOCK_FIELDS:
		_expect(before["clock"].get(field) == after["clock"].get(field), take + " preserves " + field)
	_expect(before["painters"].get("floor_line", 0) == after["painters"].get("floor_line", 0), take + " preserves floor line submissions")
	if after["case"] in ["chain_bolt", "storm_salvo", "chain_conduction", "spark_conduction", "storm_relay", "capacitor"]:
		_expect(after["painters"].get("impact", 0) == 0, take + " does not submit procedural contact")
	for site: String in REMOVED:
		_expect(after["painters"].get(site, 0) == 0, take + " does not submit " + site)
	if after["case"] == "skybreak":
		_expect(after["painters"].get("setup_ribbon", 0) == 0, take + " has no setup ribbon")
		_expect(not after["strikes"].is_empty(), take + " samples the baked sky strike")
	_check_pairs(take, after)
	var checked: Array[String] = ["tick", "kindled_tick", "hoarder", "enemy_kill", "warden_trap", "hidden", "hidden_trace", "recording"]
	if after["case"] in checked: _check_burst(take, after)
	if after["case"] in ["chain_bolt", "storm_salvo", "chain_conduction", "spark_conduction", "storm_relay"]:
		_check_chain(take, after)
	elif after["case"] == "capacitor":
		_expect(not after["stamps"].is_empty(), take + " plays Lightning tile bursts")
		_check_capacitor(take, after)
	if after["case"] in Fixtures.STRIPS:
		_expect(after["columns"].size() == (5 if after["case"] == "tick" else 3), take + " has every native strip column")
		_expect(before["columns"] == observed["columns"], take + " preserves native strip samples")
	if after["case"] == "recording":
		_expect(after["reel_frames"] == REEL_FRAMES and after["actions"].has("burst/1")
			and after["actions"].has("chain_bolt/chain/2"), "The reel has both actions in one fight")

func _check_chain(take: String, report: Dictionary) -> void:
	var card: String = {"chain_conduction": "chain_bolt", "spark_conduction": "spark_dart"}.get(report["case"], report["case"])
	var contacts: Array = report["resolved"][card]["chain"]
	for index: int in contacts.size():
		var hit: Array = contacts[index]
		var xy: String = hit[1].trim_prefix("(").trim_suffix(")").replace(", ", ":")
		var kind: String = "ranged" if index == 0 else "chain"
		var action: Dictionary = report["actions"].get("%s/%s/%d" % [card, kind, index], {})
		_expect(not action.is_empty(), "%s has a resolved beat for %s" % [take, xy])
		if action.is_empty(): continue
		var at: int = int(action["contact"])
		var tile_count: int = report["stamps"].filter(func(stamp: Dictionary) -> bool:
			return stamp["layer"] == "front" and stamp["tile"] == xy and stamp["start"] == at).size()
		tile_count += report["shots"].filter(func(shot: Dictionary) -> bool:
			return shot["tile"] == xy and shot["frame"] == at).size()
		_expect(tile_count == 1, "%s plays one baked contact at %s on frame %d (%s, found %d)" % [take, xy, at, hit[0], tile_count])
	if report["case"] == "spark_conduction" and not report["reduced"]:
		_expect(not report["view_frames"].is_empty(), take + " exercises the retained floor line")

func _check_capacitor(take: String, report: Dictionary) -> void:
	var contacts: Array = report["capacitor_contacts"]
	_expect(contacts.size() == 3, take + " publishes each of three resolved contacts")
	var rows: Dictionary = Fx.metadata()["rows"]
	for hop: Dictionary in contacts:
		var target: String = hop["tile"]
		var contact: int = int(hop["frame"])
		var wanted: int = int(rows["lightning_%s_front" % hop["row"]])
		var stamps: Array = report["stamps"].filter(func(stamp: Dictionary) -> bool:
			return stamp["layer"] == "front" and stamp["tile"] == target and stamp["start"] == contact and stamp["row"] == wanted)
		_expect(stamps.size() == 1, "%s has the Lightning %s row at %s on number sample %d" % [take, hop["row"], target, contact])
		var route: String = hop["from"] + "→" + target
		var flight: Array = report["spark_flight"].get(route, [])
		if report["reduced"]:
			_expect(flight.is_empty(), take + " shows the still without flight")
			if not stamps.is_empty(): _expect(stamps[0]["cell"] == Fx.metadata()["reduced_motion_frame"], take + " uses the Lightning still")
		else:
			_expect(not flight.is_empty() and int(flight[-1]) + 1 == contact, take + " Spark flies " + route + " until the existing contact")

func _check_pairs(take: String, report: Dictionary) -> void:
	var pairs: Dictionary
	for stamp: Dictionary in report["stamps"]:
		var key: String = "%s/%s" % [stamp["tile"], stamp["submitted"]]
		var layers: Dictionary = pairs.get_or_add(key, {})
		_expect(not layers.has(stamp["layer"]), take + " has one layer per tile per beat " + key)
		layers[stamp["layer"]] = true
		_expect(stamp["visible_at_submission"] and stamp["start"] >= stamp["submitted"], take + " submits visible tiles " + key)
		if report["reduced"]:
			_expect(stamp["start"] == stamp["submitted"], take + " shows the still at start " + key)
	for key: String in pairs:
		_expect(pairs[key].size() == 2, take + " has a depth pair " + key)

func _check_burst(take: String, report: Dictionary) -> void:
	var bursts: Array = report["resolved"].get("bursts", [])
	_expect(bursts.size() == 1, take + " resolves one death Burst")
	if bursts.size() != 1: return
	var event: Dictionary = bursts[0]
	var contact: Dictionary = report["actions"].get("burst/" + str(int(event["id"])), report["actions"].get("burst/-1", {}))
	if report["case"] == "enemy_kill" and contact.is_empty():
		for hop: Dictionary in report["capacitor_contacts"]:
			if not hop["bursts"].has(event["id"]): continue
			var affected: Array = event["rows"].keys()
			contact = {"contact": hop["frame"], "visible": affected.filter(func(tile: String) -> bool: return hop["visible"].has(tile))}
			break
	_expect(not contact.is_empty(), take + " reaches death Burst contact")
	if contact.is_empty(): return
	var rows: Dictionary = Fx.metadata()["rows"]
	var found: Dictionary
	for stamp: Dictionary in report["stamps"]:
		if stamp["submitted"] != contact["contact"]: continue
		var tile: String = stamp["tile"]
		if not contact["visible"].has(tile): continue
		var row: String = event["rows"][tile]
		_expect(stamp["row"] == rows["fire_" + row + "_" + stamp["layer"]], take + " uses the Fire " + row + " row at " + tile)
		var delay: float = 0.0 if report["reduced"] or tile == event["source"] else float(Fx.metadata()["delay_per_tile_seconds"])
		_expect(is_equal_approx(stamp["delay"], delay), take + " follows the Ground schedule at " + tile)
		if delay == 0.0: _expect(stamp["start"] == contact["contact"], take + " starts at Burst contact")
		if report["reduced"]: _expect(stamp["cell"] == Fx.metadata()["reduced_motion_frame"], take + " uses the authored still")
		found[tile] = true
	_expect(found.size() == contact["visible"].size() and not found.is_empty(), take + " plays every visible resolved Burst tile")
	if report["case"] in ["hidden", "hidden_trace"]:
		_expect(contact["visible"].size() < event["rows"].size(), take + " contains an actually hidden Burst tile")
	if report["case"] == "hidden_trace":
		_expect(not contact["visible"].has(event["source"]), take + " conceals the source centre")
		_expect(report["stamps"].size() == 2 * contact["visible"].size(), take + " presents the traced Burst only once")
		for stamp: Dictionary in report["stamps"]:
			_expect(stamp["tile"] != event["source"], take + " never stamps the hidden centre")
			if not report["reduced"]:
				_expect(stamp["start"] > contact["contact"], take + " spaces the visible arm from the concealed source")
	if report["case"] == "kindled_tick":
		_expect(report["resolved"].get("kindle", 0) > 0, take + " resolved Kindle")

func _print_take(take: String, report: Dictionary) -> void:
	var fronts: Array = report["stamps"].filter(func(stamp: Dictionary) -> bool: return stamp["layer"] == "front")
	for stamp: Dictionary in fronts:
		var row: String = str(Fx.metadata()["rows"].find_key(float(stamp["row"])))
		print("FX-33 TILE %s %s %s at %d (submitted %d, cell %d)" % [take, stamp["tile"], row, stamp["start"], stamp["submitted"], stamp.get("cell", -1)])
	for shot: Dictionary in report["shots"]:
		print("FX-33 SHOT %s %s %s at %d" % [take, shot["tile"], shot["name"], shot["frame"]])
	print("FX-33 ACTION %s done=%d clocks=%s painters=%s floor_frames=%d strikes=%d resolved=%s" % [
		take, report["done"], report["actions"], report["painters"], report["view_frames"].size(),
		report["strikes"].size(), report["resolved"]])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	printerr("FX-33 FAIL " + message)

func _finish() -> void:
	print("FX-33 VERIFY %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(int(_failures > 0))
