extends "res://tools/fx26/native.gd"

var _checks: int
var _failures: int

func _take() -> void:
	if "--list-native" in OS.get_cmdline_user_args():
		print("FX-26 NATIVE CASES: " + " ".join(Cases.NATIVE_CASES))
		quit()
		return
	var output: String = _arg("--out")
	var before_dir: String = _arg("--base-dir")
	var after_dir: String = _arg("--after-dir")
	if output.is_empty() or before_dir.is_empty() or after_dir.is_empty():
		_fail("Use tools/fx26/native.sh --dry-run to stage the baseline and draw observers.")
		return
	_install_headless_clock()
	_verify_selection()
	var cases: Array[String]
	for element: String in Cases.AREAS:
		cases.append(element + "_hit")
		cases.append(element + "_empty")
	cases.append_array(Cases.CHAIN_CASES)
	cases.append("ice_reduced")
	cases.append(Cases.TERRAIN_CASE)
	var filter: String = _arg("--case")
	if not filter.is_empty() and filter not in cases and filter != Cases.REEL:
		_fail("Unknown fx-26 case " + filter)
		return
	for id: String in cases:
		if not filter.is_empty() and filter != id: continue
		var reduced: bool = id.ends_with("_reduced")
		var before: Dictionary = await take_case(id, output.path_join("before").path_join(id), before_dir, true, reduced)
		var after: Dictionary = await take_case(id, output.path_join("after").path_join(id), after_dir, true, reduced)
		if before.is_empty() or after.is_empty(): return
		print("FX-26 BEFORE " + JSON.stringify(before))
		print("FX-26 AFTER " + JSON.stringify(after))
		_compare(id, before, after, reduced)
	if filter.is_empty() or filter == Cases.REEL:
		var reel: Dictionary = await take_case(Cases.REEL, output.path_join("after/recording"), after_dir, true)
		_expect(reel.get("reel_frames") == REEL_FRAMES and reel.get("reel_order") == ["spark", "lance"], "One 300-frame fight plays Chain Bolt then Rime Shard")
	print("FX-26 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _verify_selection() -> void:
	for element: String in Cases.AREAS:
		for kind: String in ["aoe", "terrain_burst"]:
			var effect: Dictionary = {"kind": kind, "element": element, "range": 2}
			_expect(Shot20.resolve(effect) == Cases.AREAS[element][1], "%s %s resolves its shot" % [element, kind])
			effect["card_id"] = "dazzle"
			_expect(Shot20.resolve(effect) == "light", kind + " honors a card override")
			effect["card_id"] = "root_snare"
			_expect(Shot20.resolve(effect).is_empty(), kind + " honors an empty override")
	for effect: Dictionary in [
		{"kind": "aoe", "element": "ice", "range": 0},
		{"kind": "aoe", "element": "earth", "range": 2, "ground_burst": true},
		{"kind": "aoe", "element": "ice", "range": 2, "preview": true},
		{"kind": "aoe", "element": "shadow", "range": 4, "enemy_type": "noctyrax", "intent_id": "starless_breath"},
		{"kind": "lightning_strikes", "element": "lightning", "range": 2},
		{"kind": "ranged", "element": "lightning", "chain_index": 1, "from": Cases.AIM, "to": Cases.SECOND},
		{"kind": "chain", "element": "lightning", "chain_index": 1, "from": Cases.AIM, "to": Cases.SECOND, "path": [Cases.AIM, Cases.SECOND]},
	]:
		_expect(Shot20.resolve(effect).is_empty(), "Protected descriptor keeps its own painter: " + str(effect))

func _compare(id: String, before: Dictionary, after: Dictionary, reduced: bool) -> void:
	for key: String in ["beats", "frames", "duration_usec", "done", "resolved_hits", "losses", "columns"]:
		_expect(before[key] == after[key], id + " keeps " + key)
	var old: Array = before["samples"]
	var samples: Array = after["samples"]
	if id in Cases.CHAIN_CASES:
		_compare_chain(id, before, after, reduced)
		return
	var element: String = "none" if id == Cases.TERRAIN_CASE else id.get_slice("_", 0)
	var expected: String = Cases.AREAS[element][1]
	var shot_frames: Array = _flight(samples)
	_expect(shot_frames.is_empty() if reduced else not shot_frames.is_empty() and shot_frames.all(func(s: Dictionary) -> bool:
		return s["shot"] == expected and s["to_center"] and s["frame"] < after["beats"][0]["contact"]),
		id + " uses the existing shot to the aimed tile, only before contact")
	_expect(not _legacy(samples, "release") and not _legacy(samples, "travel") and not _legacy(samples, "generic_travel"),
		id + " does not submit a procedural flight or release")
	if not reduced and element in ["ice", "earth", "air"]:
		_expect(_legacy(old, "release") and _legacy(old, "travel"), id + " observes both original procedural painters")
	if element in ["fire", "lightning"]:
		_expect(_flight(old) == shot_frames, id + " keeps the fx-23 flight")
	var expected_bursts: Dictionary = before["bursts"].duplicate(true)
	if element == "shadow":
		var aim_rows: Array = expected_bursts[Cases20.coords(Cases.AIM)]
		aim_rows.append({"design": "hit_gloom", "frame": after["beats"][0]["contact"]})
	_expect(expected_bursts == after["bursts"], id + " preserves arrival rows and adds only the united Shade contact")
	if id == Cases.TERRAIN_CASE: return
	var aim: String = Cases20.coords(Cases.AIM)
	var losses: Array = after["losses"].get(aim, [0, 0, 0])
	_expect(losses[0] == 0 if id.ends_with("_empty") else losses[0] > 0, id + " resolves its intended hit or empty outcome")

func _compare_chain(id: String, before: Dictionary, after: Dictionary, reduced: bool) -> void:
	var count: int = 4 if id == "chain_relay" else 3
	_expect(after["beats"].size() == count and after["resolved_hits"].size() == count, id + " plays the resolver's full route")
	var first: Array = _beat_samples(after, 0)
	_expect(first == _beat_samples(before, 0), id + " preserves the opening caster-to-target path")
	var opening_tile: String = Cases20.coords(Cases.AIM)
	_expect(after["bursts"].get(opening_tile, []) == before["bursts"].get(opening_tile, []), id + " preserves the opening contact")
	for index: int in range(1, after["beats"].size()):
		var beat: Dictionary = after["beats"][index]
		var samples: Array = _beat_samples(after, index)
		var flights: Array = _flight(samples)
		_expect(reduced or _legacy(_beat_samples(before, index), "hop_arc"), "%s observes legacy hop %d" % [id, index])
		_expect(not _legacy(samples, "hop_arc"), "%s removes legacy hop %d" % [id, index])
		_expect(flights.is_empty() if reduced else not flights.is_empty() and flights.all(func(s: Dictionary) -> bool:
			return s["shot"] == "spark" and s["level_hop"] and s["frame"] < beat["contact"]), "%s keeps Spark inside hop %d's original flight window" % [id, index])
		var tile: String = beat["to"]
		var rows: Array = after["bursts"].get(tile, [])
		var hidden: bool = id == "chain_hidden" and tile == Cases20.coords(Cases.THIRD)
		if hidden:
			_expect(rows.is_empty() and flights.all(func(s: Dictionary) -> bool:
				return not s["target_visible"] and not s["target_actor_visible"] and not s["clip"].is_empty() \
					and s["clip"][-1].y < 1.0), id + " clips the last hop and never stamps the hidden target")
			continue
		var expected: String = "lightning_floor_front" if tile == Cases20.coords(Cases.RELAY) else "lightning_hit_front"
		_expect(rows == [{"design": expected, "frame": beat["contact"]}], "%s stamps exactly one %s at hop %d contact" % [id, expected, index])
	var blocked: Array = after["losses"].get(Cases20.coords(Cases.SECOND), [])
	_expect(blocked.size() == 3 and blocked[0] == 0 and blocked[1] > 0, id + " confirms that full Block spends a pool without Health loss")

func _beat_samples(report: Dictionary, index: int) -> Array:
	return report["samples"].filter(func(frame: Dictionary) -> bool: return frame["beat"] == index)

func _flight(samples: Array) -> Array:
	return samples.filter(func(frame: Dictionary) -> bool: return not frame["shot"].is_empty())

func _legacy(samples: Array, painter: String) -> bool:
	return samples.any(func(frame: Dictionary) -> bool: return frame["legacy"].has(painter))

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)
