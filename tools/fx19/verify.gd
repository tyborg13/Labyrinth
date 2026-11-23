extends "res://tools/fx19/native_capture.gd"
## Verify real playback against the corresponding staged base take.

const FRAME_TOLERANCE: float = 1.0 / FPS
const TIME_EPSILON: float = 0.0001

func _validate_blink_take(receipt: Dictionary) -> void:
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("--reference")))
	if not reference is Dictionary or reference.get("case") != _case or reference.get("reduced") != _reduced:
		_fail("Expected the matching fx-19 baseline receipt.")
		return
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(receipt))
	for field: String in ["departure", "arrival", "complete", "cues", "preview"]:
		if normalized[field] != reference[field]:
			_fail("%s changed from base in %s." % [field, _case])
			return
	var expect_cue: bool = not ENEMY_CASES.has(_case)
	if expect_cue and receipt.cues != [receipt.arrival] or not expect_cue and not receipt.cues.is_empty():
		_fail("Unexpected Blink cue on the first landing submission.")
		return
	if expect_cue and (receipt.preview.get("authored", []).is_empty() or receipt.preview.get("fallback", []).is_empty()
			or receipt.preview["authored"] == receipt.preview["fallback"]):
		_fail("Both distinct aim-preview draw streams are required.")
		return
	var traces: Array = receipt.transit_draws
	var base_traces: Array = reference.transit_draws
	if _case != "shadowstep" and (base_traces.is_empty() or base_traces.all(func(trace: Array) -> bool: return trace.is_empty())):
		_fail("Failed to observe the legacy Blink overlay.")
		return
	if traces.any(func(trace: Array) -> bool: return not trace.is_empty()):
		_fail("Resolved Blink submitted legacy overlay primitives.")
		return

	var rows: Dictionary = Fx.self_metadata()["rows"]
	var expected: Dictionary = {receipt.landing: "summon"}
	if _case != "shadowstep":
		expected[receipt.origin] = "illusion" if _case == "afterimage" else "summon"
	var seen: Dictionary
	var reveal_seconds: float = Fx.reveal_seconds("summon", _reduced)
	for stamp: Dictionary in receipt.stamps:
		var tile: String = stamp.tile
		if not expected.has(tile):
			_fail("Burst on unexpected or hidden tile " + tile)
			return
		var effect: String = expected[tile]
		var key: String = "%s row %d" % [tile, stamp.row]
		if (stamp.row != rows[effect + "_rear"] and stamp.row != rows[effect + "_front"]) or seen.has(key):
			_fail("Duplicate or unexpected " + key)
			return
		seen[key] = true
		if not stamp.depth or not stamp.center or stamp.first < 0 or stamp.still != _reduced:
			_fail("Invalid FX-13 placement or visibility for " + key)
			return
		if _reduced and stamp.frames != [int(Fx.self_metadata()["reduced_motion_frame"])]:
			_fail("Expected the authored reduced-motion still for " + key)
			return
		if tile == receipt.landing:
			# The observer samples after the board process tick, but a scene
			# submission can arrive before that tick. Compare in that interval.
			var start: float = maxf(receipt.departure_seconds, receipt.arrival_seconds - reveal_seconds) - FRAME_TOLERANCE
			var reveal: int = maxi(receipt.arrival, receipt.departure + roundi(reveal_seconds * FPS))
			if absf(float(stamp.start_seconds) - start) > FRAME_TOLERANCE + TIME_EPSILON or absi(stamp.reveal - reveal) > 1:
				_fail("Landing period mismatch for %s: expected start %.4f, reveal by frame %d, got %s" % [key, start, reveal, stamp])
				return
		elif effect == "summon" and stamp.first != receipt.departure:
			_fail("Expected departure on the first transit submission for " + key)
			return
	if seen.size() != expected.size() * 2:
		_fail("Missing Blink burst pair(s): " + str(seen))
		return
	if _case == "afterimage":
		var old: Array = reference.stamps
		if old.size() != 2 or not old.all(func(stamp: Dictionary) -> bool: return seen.has("%s row %d" % [stamp.tile, stamp.row])):
			_fail("The existing Afterimage burst pair must remain.")
			return
		for stamp: Dictionary in receipt.stamps:
			if stamp.tile == receipt.origin and not old.any(func(previous: Dictionary) -> bool:
				return int(previous.row) == stamp.row and absf(float(previous.start_seconds) - stamp.start_seconds) <= TIME_EPSILON):
				_fail("Afterimage's fx-13 start changed.")
				return
	print("FX-19 VERIFY PASS %s reduced=%s, %d rows, landing %d, complete %d, cue frames %s" % [
		_case, _reduced, seen.size(), receipt.arrival, receipt.complete, receipt.cues])
