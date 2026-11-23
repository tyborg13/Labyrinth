extends "res://tools/fx29/fixture.gd"

const Shot = preload("res://scripts/shot_fx.gd")
const Contact = preload("res://scripts/enemy_mechanics/lightning_contact_view.gd")
const CASES: Array[String] = ["hero_end", "two_units", "past_hero", "crate", "hidden", "cancelled"]
const CUTOUT_FRAMES: int = 66
const CUTOUT_RELEASE: int = 13
const CUTOUT_CONTACT: int = 34
const CUTOUT_SECONDS: float = 1.1
const FALLBACK_FRAMES: int = 8
const FALLBACK_SECONDS: float = 0.3
const EASE: float = 1.4
const LATE_STYLE_TEST_FRAMES: int = 135
const LATE_STYLE_TEST_CONTACT: int = 25

var _births: Dictionary
var _seen_stamps: Dictionary
var _air: Array[int]
var _anchor: Vector2
var _expected_hits: Array[Vector2i]
var _visible_tiles: Array[Vector2i]
var _fallback: bool
var _reduced: bool
var _arrival: int
var _release: int
var _label: String

func _take() -> void:
	var base: String = _arg("--base")
	if not _expect(not base.is_empty(), "requires pinned base scripts staged by native.sh"):
		quit(2)
		return
	_verify_asset_and_draw(base)
	var baseline: Dictionary
	if await _open(base):
		baseline = await _matrix()
	await _close()
	if await _open(""):
		var current: Dictionary = await _matrix()
		for key: String in current:
			_expect(current[key] == baseline.get(key), key + " preserves action clock, first losses and floating-text tail")
	await _close()
	print("FX-29 VERIFY: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _verify_asset_and_draw(base: String) -> void:
	var texture: Dictionary = Shot.metadata()["shots"]["lance"]
	_expect(Shot.refraction_shot_id() == "lance" and texture["arc_tiles"] == 0 and texture["ease"] == EASE and texture["hit"] == "hit_glass",
		"approved Ice lance resolves with its authored straight profile")
	var old_source: String = FileAccess.get_file_as_string(base.path_join("reflect_view.gd"))
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy_mechanics/reflect_view.gd")
	_expect(old_source.count("board.draw_line(") == 2 and source.count("board.draw_line(") == 0, "zero Refraction draw lines after two base draw calls")
	var board := Control.new()
	for cancelled: bool in [false, true]:
		for progress: float in [0.0, 0.5, 1.0]:
			_expect(View.draw_effect(board, {"action_type": "refraction", "cancelled": cancelled}, progress), "Refraction never falls through to generic draws")
	board.free()
	_expect(View.refraction_release_frame({"action_type": "refraction"}, LATE_STYLE_TEST_FRAMES, LATE_STYLE_TEST_CONTACT)
		== LATE_STYLE_TEST_CONTACT - 12, "late release uses the 12-sample fallback")

func _matrix() -> Dictionary:
	var results: Dictionary
	for label: String in CASES:
		for reduced: bool in [false, true]:
			for fallback: bool in [false, true]:
				if label == "cancelled" and not fallback: continue
				var key: String = "%s/%s/%s" % [label, "fallback" if fallback else "cutout", "reduced" if reduced else "full"]
				results[key] = await _case(label, reduced, fallback, key)
	return results

func _case(label: String, reduced: bool, fallback: bool, key: String) -> Dictionary:
	_prepare(label, reduced)
	_label = key
	_fallback = fallback
	_reduced = reduced
	_births.clear()
	_seen_stamps.clear()
	_air.clear()
	var cancelled: bool = label == "cancelled"
	var board: Control = _scene.board_view
	var all_tiles: Array = _step["tiles"]
	_visible_tiles.assign(all_tiles.filter(board._board_tile_is_visible_to_player))
	_expected_hits.assign([_before["player"]["pos"]])
	if label == "two_units": _expected_hits.append(FRONT)
	if label == "crate":
		_expect(_after["terrain"][0]["hp"] == CRATE_HP - CRATE_RESOLVED_LOSS and _after["terrain"][0]["hp"] > 0, key + " surviving crate loses HP")
		_expected_hits.append(MID)
	if label == "hidden":
		_expect(_visible_tiles.size() > 0 and _visible_tiles.size() < all_tiles.size(), key + " line is partly hidden under Eclipse")
		var clipped: Dictionary = _scene._visible_umbra_action_step(_before, _step)
		if _expect(clipped.get("umbra_visible_line_segments", []).size() > 0, key + " live Umbra dispatch supplies visibility intervals"):
			_step = clipped
	if label == "past_hero":
		_expect(all_tiles.back() != _before["player"]["pos"], key + " last tile is beyond hero")
	_expect(cancelled == bool(_step["cancelled"]), key + " cancellation comes from resolver context")
	_expect(bool(_adapter.handles(_step, _before["enemies"][0])) != cancelled, key + " adapter excludes cancelled steps")

	_release = 1 if fallback or reduced else CUTOUT_RELEASE
	_arrival = 1 if cancelled or (reduced and not fallback) else FALLBACK_FRAMES + 1 if fallback else CUTOUT_CONTACT
	_scene.proof_observer = _observe
	var final: Dictionary = await _play(fallback)
	_scene.proof_observer = Callable()
	var expected_frames: int = 0 if cancelled else FALLBACK_FRAMES if fallback else 1 if reduced else CUTOUT_FRAMES
	var expected_duration: float = 0.0 if cancelled or (reduced and not fallback) else FALLBACK_SECONDS if fallback else CUTOUT_SECONDS
	var clock: Vector2 = _scene.proof_clock
	_expect(int(clock.x) == expected_frames and is_equal_approx(clock.x * clock.y, expected_duration), key + " preserves authored window")
	_expect(_scene.proof_contact == _arrival, key + " preserves first loss sample")
	_expect(final["player"]["hp"] == _after["player"]["hp"], key + " displays the resolved health")
	if _base.is_empty():
		_verify_arrivals(cancelled, all_tiles)
		var expected_head_frames: int = 0 if reduced or cancelled else _arrival - _release + 1
		_expect(_air.size() == expected_head_frames, key + " visible head stamp runs for release through arrival only")
		print("FX-29 ARRIVALS %s release=%s arrival=%d tiles=%s" % [key, _air.front() if not _air.is_empty() else "-", _arrival, _births.keys().map(func(tile: Vector2i) -> String: return "%s@%d" % [tile, _births[tile]["frame"]])])
	else:
		_expect(_air.is_empty(), key + " base has no retained Refraction head")
		if not fallback:
			_expect(_births.size() == _visible_tiles.size() and _births.values().all(func(entry: Dictionary) -> bool: return entry["reserved"] == _arrival),
				key + " base reserves its FX-12 bursts at contact")
		else:
			_expect(_births.is_empty(), key + " base fallback uses the beam without FX-12")
	return {"clock": clock, "contact": _scene.proof_contact, "floating": _scene.proof_floating}

func _observe(frame: int) -> void:
	var board: Control = _scene.board_view
	var fx: RefCounted = board._single_shot_fx
	var first: Node2D = fx._heads[0]
	var other: Node2D = fx._heads[1]
	var prior_hp: int = _before["player"]["hp"]
	var expected_hp: int = _after["player"]["hp"] if frame >= _arrival else prior_hp
	_expect(board.combat_state["player"]["hp"] == expected_hp, _label + " HP stays at the existing sample boundary")
	if frame <= _arrival:
		_expect(_scene.proof_submitted_texts == (frame == _arrival and not _step["target_losses"].is_empty()),
			_label + " first floating text coincides with arrival")
	_expect(fx._hits.all(func(hit: Node2D) -> bool: return hit.lifetime_start < 0), _label + " no arrival hit_glass")
	_expect(not other.visible, _label + " no second head")
	if first.visible:
		_air.append(frame)
		var to: Vector2 = board._tile_center(_step.get("umbra_original_to", _step["tiles"].back()))
		if frame == _release: _anchor = Contact.chest(board, MIRROR, _step["actor_key"])
		var t: float = pow(float(frame - _release) / (_arrival - _release), EASE)
		_expect(frame >= _release and frame <= _arrival and fx._shot_id == "lance", _label + " uses the Ice lance in the authored window")
		_expect(first.position.is_equal_approx(_anchor.lerp(to, t)), _label + " head is on the straight chest-to-tile path")
		_expect(fx._shadow.visible and fx._shadow.position.is_equal_approx(board._tile_center(MIRROR).lerp(to, t)), _label + " normal lance shadow")
		if bool(_step.get("umbra_action_clipped", false)):
			var segment: Dictionary = _step["umbra_visible_line_segments"][0]
			var span := Vector2(float(segment["start"]), float(segment["end"]))
			_expect(fx._clip_enabled and span != Vector2(0.0, 1.0) and fx._clip_spans[0].is_equal_approx(span),
				_label + " lance uses the FX-14 visibility intervals")
	for stamp: Node2D in board._tile_bursts._stamps:
		if _seen_stamps.has(stamp.get_instance_id()): continue
		_seen_stamps[stamp.get_instance_id()] = true
		var record: Dictionary = _births.get_or_add(stamp.tile, {"reserved": frame, "frame": -1, "samples": [], "rows": []})
		record["rows"].append(stamp.sample.y)
		record["samples"].append(stamp.sample.x)
		if stamp.visible and record["frame"] < 0: record["frame"] = frame

func _verify_arrivals(cancelled: bool, all_tiles: Array) -> void:
	if cancelled:
		_expect(_births.is_empty(), _label + " cancelled Refraction has no bursts")
		return
	_expect(_births.keys() == _visible_tiles, _label + " one burst per visible tile, in line order")
	var metadata: Dictionary = Bursts.metadata()
	for tile: Vector2i in _visible_tiles:
		if not _expect(_births.has(tile), _label + " spawns the visible tile"): continue
		var entry: Dictionary = _births[tile]
		var distance_fraction: float = float(all_tiles.find(tile) + 1) / all_tiles.size()
		var frame: int = _release + ceili((_arrival - _release) * pow(distance_fraction, 1.0 / EASE))
		var row: String = "ice_hit" if tile in _expected_hits else "ice_floor"
		var rows: Dictionary = metadata["rows"]
		var sample: int = metadata["reduced_motion_frame"] if _reduced else 0
		_expect(entry["frame"] == frame and entry["reserved"] == frame, "%s %s starts at sample %d" % [_label, tile, frame])
		_expect(entry["rows"] == [int(rows[row + "_rear"]), int(rows[row + "_front"])],
			"%s %s exactly one rear/front pair with row %s, observed %s" % [_label, tile, row, entry["rows"]])
		_expect(entry["samples"] == [sample, sample], _label + " both stamps start on the expected atlas frame")
