extends "res://tools/fx18/native_capture.gd"

const Spell = preload("res://scripts/dragon_spell_presentation.gd")
const ShadowCalls = preload("res://tools/fx18/shadow_submissions.gd")
const SUITES: Array[String] = ["dragon_area_presentation", "dragon_feedback1", "dragon_pressure_mechanics"]
const PACING_CASES: Array[String] = ["cinder_breath", "bedrock_breath", "hollow_gale", "whiteout_lance", "overload"]
const PACING_FIELDS: Array[String] = ["authored_frames", "rendered_frames", "attack_frame_count", "authored_duration_usec", "release_frame", "contact_frame", "numbers_frame", "completion_frame"]
const SWEEP_CASES: Array[String] = ["cinder_breath", "whiteout_lance", "starless_breath", "night_coil"]
const DRAGON_ACTION_FRAMES: int = 66
const SAMPLE_SIZE: float = 126.0
const PROOF_SEED: int = 91
const PRIMITIVE_PROGRESSES: Array[float] = [Dragon.RELEASE, 0.42, Dragon.CONTACT, 0.62]
const SHADOW_PROGRESSES: Array[float] = [0.18, Dragon.RELEASE, 0.42, Dragon.CONTACT, 0.62, 0.80]

var _failures: Array[String]
var _after: Dictionary
var _visible: Array[Vector2i]

class OverlapBoard extends Control:
	var specs: Array[Dictionary]
	func _board_tile_is_visible_to_player(_tile: Vector2i) -> bool: return true
	func present_tile_bursts(batch: Array, _before: Dictionary, _after: Dictionary, _reduced: bool) -> void:
		specs.append_array(batch)

func _take() -> void:
	if OS.get_cmdline_user_args().has("--suites"):
		for suite: String in SUITES:
			var before: int = _failures.size()
			await (load("res://tests/suites/%s_suite.gd" % suite) as Script).run(_expect)
			print("FX-18 FOCUSED %s %s" % [suite, "PASS" if before == _failures.size() else "FAIL"])
		_finish("FOCUSED")
		return
	var proof_root: String = _arg("--out")
	var baseline: String = _arg("--base-dir")
	var requested_case: String = _arg("--case")
	if proof_root.is_empty() or baseline.is_empty() or (not requested_case.is_empty() and not Cases.CASES.has(requested_case)):
		_fail("Use tools/fx18/native.sh --dry-run [--case id].")
		return
	_plan = true
	_install_plan_clock()
	var selected: Array = Cases.CASES.keys() if requested_case.is_empty() else [requested_case]
	for id: String in selected:
		_record = id in SWEEP_CASES
		var report: Dictionary = await _dragon_take(id, proof_root.path_join("after/" + id), false)
		if report.is_empty(): return
		_record = false
		_check_case(report, false)
		if id == "cinder_breath": _check_overlap()
		if id == "storm_lash": _check_targeted_overlap()
		if Cases.CASES[id][4] == "shadow": _check_shadow(baseline)
		if id in Cases.STRIPS or Cases.CASES[id][4] == "shadow":
			_base_dir = baseline
			var before: Dictionary = await _dragon_take(id, proof_root.path_join("before/" + id), false)
			_base_dir = ""
			if before.is_empty(): return
			if id in PACING_CASES or Cases.CASES[id][4] == "shadow":
				for field: String in PACING_FIELDS:
					_expect(before[field] == report[field], "%s %s matches base (%s vs %s)" % [id, field, before[field], report[field]])
				print("FX-18 PACING %s base/current authored=%s/%s rendered=%s/%s completion=%s/%s" % [id, before["authored_frames"], report["authored_frames"], before["rendered_frames"], report["rendered_frames"], before["completion_frame"], report["completion_frame"]])
	if requested_case.is_empty() or requested_case == "cinder_breath":
		for witness: String in ["pools", "fog", "reduced"]:
			_witness = witness
			var report: Dictionary = await _dragon_take("cinder_breath", proof_root.path_join(witness), witness == "reduced")
			if report.is_empty(): return
			_check_case(report, witness == "reduced")
			_check_witness(report)
	_finish("VERIFY")

func _observe_dragon() -> Dictionary:
	var before: Dictionary = _run._combat_state
	_after = before.duplicate(true)
	_run._apply_animation_step(_after, _dragon_fixture["step"])
	_visible.assign(_targets.filter(_run.board_view._board_tile_is_visible_to_player))
	return await super._observe_dragon()

func _check_case(report: Dictionary, reduced: bool) -> void:
	var id: String = report["case"]
	var config: Array = Cases.CASES[id]
	var step: Dictionary = _dragon_fixture["step"]
	var profile: Dictionary = Dragon.profile(step)
	_expect(profile.get("geometry") == config[3] and profile.get("element") == config[4], id + " has the expected resolver profile")
	var name: String = Spell.burst_name(profile)
	var stamps: Dictionary = report["stamps"]
	_expect(name == config[4], id + " has the expected sheet")
	# The same guard serves both depth passes. Any procedural submission would
	# raise on a null canvas, which the task runner reports as a failing script.
	for progress: float in PRIMITIVE_PROGRESSES:
		Spell.draw_source(null, profile, Vector2.ONE, Vector2.ZERO, SAMPLE_SIZE, progress)
		for front: bool in [false, true]:
			Spell.draw_target(null, profile, Vector2.ZERO, Vector2.ZERO, Vector2.ONE, SAMPLE_SIZE, progress, reduced, front, true, true, PROOF_SEED)
	var before: Dictionary = _dragon_fixture["run"]["combat_state"]
	var hits: Dictionary = Fx.hit_tiles(before, _after)
	var grid: Array = before["grid"]
	var expected: Array[Vector2i]
	for tile: Vector2i in _visible:
		if Paths.is_passable(grid, tile) and Paths.tile_id(grid, tile) != "void": expected.append(tile)
	_expect(not expected.is_empty() and stamps.size() == expected.size(), id + " has exactly the visible resolved tile set")
	var data: Dictionary = Fx.metadata()
	var first_ring: float = INF
	var last_ring: float = -INF
	var actual_rings: Dictionary
	var max_ring: int = 1
	var actor: Dictionary = _dragon_fixture["actor"]
	var center: Vector2i = step.get("center", step.get("to", step["from"]))
	for tile: Vector2i in _targets: max_ring = maxi(max_ring, _ring(tile, actor))
	for tile: Vector2i in expected:
		var key: String = _coord(tile)
		_expect(stamps.has(key), id + " has tile " + key)
		if not stamps.has(key): continue
		var stamp: Dictionary = stamps[key]
		var rows: Dictionary = data["rows"]
		var row: String = name + ("_hit" if hits.has(tile) else "_floor")
		_expect(stamp["rows"] == {"rear": int(rows[row + "_rear"]), "front": int(rows[row + "_front"])}, id + " has both rows for " + key)
		_expect(stamp["instances"].size() == 2 and stamp["depth"], id + " has one depth pair at " + key)
		_expect(stamp["visible"] >= stamp["submitted"], id + " plays " + key)
		var delay: float = 0.0
		if config[3] == "ground" and not reduced:
			delay = minf(float(data["max_delay_seconds"]), Paths.manhattan(center, tile) * float(data["delay_per_tile_seconds"]))
		_expect(is_equal_approx(stamp["delay"], delay), id + " has fx-12 offset at " + key)
		if reduced:
			_expect(stamp["submitted"] == report["contact_frame"] and stamp["cell"] == data["reduced_motion_frame"], id + " shows the still at contact")
		elif config[3] == "ground" or _targets.size() == 1:
			_expect(stamp["submitted"] == report["contact_frame"], id + " submits at contact")
		else:
			var ring: int = _ring(tile, actor)
			var start: float = Dragon.RELEASE + (Dragon.CONTACT - Dragon.RELEASE) * (ring - 1) / maxi(1, max_ring - 1)
			var expected_frame: int = ceili(start * DRAGON_ACTION_FRAMES)
			_expect(roundi(float(stamp["progress"]) * DRAGON_ACTION_FRAMES) == expected_frame, id + " starts ring %d on frame %d" % [ring, expected_frame])
			actual_rings[ring] = stamp["submitted"]
			first_ring = minf(first_ring, stamp["submitted"])
			last_ring = maxf(last_ring, stamp["submitted"])
	if id in SWEEP_CASES and _witness.is_empty() and not reduced:
		_expect(first_ring == report["release_frame"] and last_ring == report["contact_frame"], id + " sweeps from release to contact")
		_expect(last_ring == report["numbers_frame"], id + " final ring coincides with numbers")
		var rings: Array = actual_rings.keys()
		rings.sort()
		for index: int in range(1, rings.size()):
			_expect(actual_rings[rings[index]] >= actual_rings[rings[index - 1]], id + " advances monotonically by ring")
	print("FX-18 SPELL %s %s/%s %d pairs%s" % [id, config[3], name, stamps.size(), " (" + _witness + ")" if not _witness.is_empty() else ""])

func _ring(tile: Vector2i, actor: Dictionary) -> int:
	var origin: Vector2i = actor["pos"]
	var footprint: Vector2i = actor["footprint"]
	var distance: int = 1000
	for y: int in footprint.y:
		for x: int in footprint.x:
			var delta: Vector2i = (tile - (origin + Vector2i(x, y))).abs()
			distance = mini(distance, maxi(delta.x, delta.y))
	return maxi(1, distance)

func _check_witness(report: Dictionary) -> void:
	var stamps: Dictionary = report["stamps"]
	if _witness == "pools":
		var before: Dictionary = _dragon_fixture["run"]["combat_state"]
		var tile: Vector2i = before["illusions"][0]["pos"]
		var hero: Dictionary = before["player"]
		var hit_front: int = Fx.metadata()["rows"]["fire_hit_front"]
		_expect(hero["hp"] == _after["player"]["hp"] and hero["block"] > _after["player"]["block"], "Cinder Breath was fully blocked")
		_expect(_after["illusions"].is_empty() or _after["illusions"][0]["hp"] <= 0, "Cinder Breath defeated the illusion")
		_expect(stamps.get(_coord(hero["pos"]), {}).get("rows", {}).get("front") == hit_front, "Fully blocked tile plays hit")
		_expect(stamps.get(_coord(tile), {}).get("rows", {}).get("front") == hit_front, "Defeated illusion tile plays hit")
		var floor_front: int = Fx.metadata()["rows"]["fire_floor_front"]
		_expect(stamps.values().any(func(stamp: Dictionary) -> bool: return stamp["rows"]["front"] == floor_front), "Empty fan tile plays floor")
	elif _witness == "fog":
		var hidden: Array = _targets.filter(func(tile: Vector2i) -> bool: return not _visible.has(tile))
		_expect(not hidden.is_empty() and not stamps.is_empty(), "Fog witness contains hidden and visible fan tiles")
		for tile: Vector2i in hidden: _expect(not stamps.has(_coord(tile)), "Hidden fan tile has no stamp")

func _check_overlap() -> void:
	var step: Dictionary = _dragon_fixture["step"]
	var before: Dictionary = _dragon_fixture["run"]["combat_state"]
	if _targets.size() < 2:
		_expect(false, "Overlap witness needs at least two tiles")
		return
	var fx12_tile: Vector2i = _targets[0]
	var fx15_tile: Vector2i = _targets[1]
	var existing: Dictionary = {"name": "impact", "center": fx12_tile, "tiles": [fx12_tile]}
	var strike := Fx.StrikeCue.new()
	strike.tiles.append(fx15_tile)
	var board := OverlapBoard.new()
	var cue: Spell.BurstCue = Spell.burst_cue(step, _dragon_fixture["actor"], before, _after, false, [existing], strike)
	cue.present(board, Dragon.CONTACT)
	cue.present(board, 1.0)
	var submitted: Array[Vector2i]
	for spec: Dictionary in board.specs: submitted.append_array(spec["tiles"])
	_expect(submitted.size() == _targets.size() - 2 and not submitted.has(fx12_tile) and not submitted.has(fx15_tile), "Previously claimed fx-12 and fx-15 tiles are skipped once per step")
	board.free()
	print("FX-18 OVERLAP fx-12 and fx-15 plans checked")

func _check_targeted_overlap() -> void:
	var step: Dictionary = _dragon_fixture["step"].duplicate(false)
	step[Fx.REPLACE_TARGETED] = true
	var before: Dictionary = _dragon_fixture["run"]["combat_state"]
	var board := OverlapBoard.new()
	var cue: Spell.BurstCue = Spell.burst_cue(step, _dragon_fixture["actor"], before, _after, false, [], null)
	cue.present(board, Dragon.CONTACT)
	_expect(board.specs.is_empty(), "A direct shot with an existing targeted burst submits no dragon burst")
	board.free()
	print("FX-18 OVERLAP targeted replacement marker checked")

func _check_shadow(base_dir: String) -> void:
	var baseline: GDScript = _recording_script(base_dir.path_join("dragon_spell_presentation.gd"))
	var current: GDScript = _recording_script("res://scripts/dragon_spell_presentation.gd")
	if baseline == null or current == null: return
	var profile: Dictionary = Dragon.profile(_dragon_fixture["step"])
	var before: Array = _shadow_calls(baseline, profile, true)
	var after: Array = _shadow_calls(current, profile, false)
	_expect(not before.is_empty() and after.is_empty(), _case + " replaces the base shadow primitives")
	print("FX-18 SHADOW %s %d base / %d current primitive submissions" % [_case, before.size(), after.size()])

func _recording_script(path: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace(path.get_base_dir().path_join("dragon_shadow_fx.gd"), "res://tools/fx18/shadow_submissions.gd")
	if script.reload() == OK: return script
	_expect(false, "Could not load shadow submission recorder from " + path)
	return null

func _shadow_calls(renderer: GDScript, profile: Dictionary, baseline: bool) -> Array:
	ShadowCalls.calls.clear()
	for progress: float in SHADOW_PROGRESSES:
		renderer.draw_source(null, profile["element"] if baseline else profile, Vector2.ONE, Vector2.ZERO, SAMPLE_SIZE, progress)
		for front: bool in [false, true]:
			for reduced: bool in [false, true]:
				renderer.draw_target(null, profile, Vector2.ONE, Vector2.ZERO, Vector2(32, 16), SAMPLE_SIZE, progress, reduced, front, true, true, PROOF_SEED)
	return ShadowCalls.calls.duplicate()

func _expect(ok: bool, detail: String) -> void:
	if not ok: _failures.append(detail)

func _finish(label: String) -> void:
	for failure: String in _failures: printerr(failure)
	print("FX-18 %s %s (%d failures)" % [label, "PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)
