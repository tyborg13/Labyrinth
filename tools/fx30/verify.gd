extends "res://tools/fx30/native_capture.gd"

const Spell = preload("res://scripts/dragon_spell_presentation.gd")
const Shot = preload("res://scripts/shot_fx.gd")
const PROBE_TILE_WIDTH: float = 126.0
const PROBE_SEED: int = 91
const SAMPLE_PROGRESS: Array[float] = [0.0, Dragon.RELEASE, (Dragon.RELEASE + Dragon.CONTACT) / 2.0, Dragon.CONTACT, 0.8, 1.0]
const TIMING_FIELDS: Array[String] = ["done", "authored_frames", "rendered_frames", "authored_duration_usec", "columns", "reel_frames", "steps", "summons"]

var _checks: int
var _failures: int

func _take() -> void:
	var output: String = _arg("--out")
	var comparison: String = _arg("--compare-before")
	var only: String = _arg("--case")
	if output.is_empty() or (not only.is_empty() and only not in NoctyraxCases.WITNESSES and only != NoctyraxCases.REEL):
		_fail("Use tools/fx30/native.sh --dry-run [--case id].")
		return
	_plan = true
	_install_plan_clock()
	var ids: Array[String] = NoctyraxCases.WITNESSES.duplicate()
	ids.append(NoctyraxCases.REEL)
	for id: String in ids:
		if not only.is_empty() and id != only: continue
		var report: Dictionary = await take_case(id, output.path_join(id))
		if report.is_empty(): return
		_print_report(report)
		if comparison.is_empty():
			for beat: Dictionary in report["beats"]:
				_expect(beat["stamps"].is_empty(), id + " base has no tile bursts")
			continue
		var path: String = comparison.path_join(id).path_join("take.json")
		var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_expect(before is Dictionary, id + " has the exact base take")
		if before is Dictionary: _compare(before, report)
		_check_case(id, report)
	if not comparison.is_empty(): _check_removed_painters()
	print("FX-30 %s %s (%d checks, %d failures)" % [
		"BASELINE" if comparison.is_empty() else "VERIFY", "PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _compare(before: Dictionary, current: Dictionary) -> void:
	var after: Dictionary = JSON.parse_string(JSON.stringify(current))
	var id: String = after["case"]
	for field: String in TIMING_FIELDS:
		_expect(before[field] == after[field], "%s preserves %s (%s / %s)" % [id, field, before[field], after[field]])
	_expect(before["beats"].size() == after["beats"].size(), id + " preserves the resolved attacks")
	for index: int in mini(before["beats"].size(), after["beats"].size()):
		var old: Dictionary = before["beats"][index].duplicate()
		var new: Dictionary = after["beats"][index].duplicate()
		for key: String in ["stamps", "area_active"]:
			old.erase(key)
			new.erase(key)
		_expect(old == new, id + " preserves the attack, contact, visible hit set, floating text and every phase sample")
	print("FX-30 PACING %s base/current authored=%s/%s rendered=%s/%s done=%s/%s" % [
		id, before["authored_frames"], after["authored_frames"], before["rendered_frames"], after["rendered_frames"], before["done"], after["done"]])

func _check_case(id: String, report: Dictionary) -> void:
	var first: Dictionary = report["beats"][0]
	match id:
		"starless_breath":
			_expect(first["hp_loss"] > 0 and first["terrain_before"].size() == 1 and first["terrain_after"].size() == 1
				and first["terrain_after"][0] < first["terrain_before"][0], "Real Starless Breath damages the hero and a surviving crate")
		"night_coil":
			_expect(first["player_from"] != first["player_to"], "Real Night Coil pulls the hero")
		"night_coil_blocked":
			_expect(first["hp_loss"] == 0 and first["block_loss"] > 0 and first["hit_tiles"].has(first["player_from"]), "Spent Block alone is a hit")
		"starless_hidden":
			_expect(not first["hidden_at_contact"].is_empty() and not first["stamps"].is_empty(), "Fog case has both visible and hidden Breath tiles")
		"last_eclipse", "eclipse_reduced", "eclipse_hidden":
			_expect(first["hit_tiles"].size() == 2 and first["hp_loss"] > 0 and first["illusions_after"] == 0, "Real Eclipse hurts the hero and defeats an Illusion")
			_expect(first["eclipse_activations"] == 2 and report["summons"] == [["veilbound_acolyte"]], "Eclipse applies the authored darkness and summons a Veilbound Acolyte")
			var expected: int = 1 if id == "eclipse_hidden" else 2
			_expect(first["visible_hits"].size() == expected, id + " has the expected visible hit count after darkening")
		"eclipse_miss":
			_expect(first["hit_tiles"].is_empty() and first["eclipse_activations"] == 2, "Protected hero has no hit and Eclipse still darkens the board")
		"refuge":
			_expect(first["profile"]["clip"] == "eclipse" and not first["hit_tiles"].is_empty(), "Saved refuge resolves as a damaging Eclipse")
		"ranged":
			_expect(first["tiles"].size() == 1 and first["kind"] == "ranged" and first["shot_frames"] == 0, "Legacy ranged resolves a single tile without a shot")
		"void_claw":
			_expect(report["steps"].has("move") and first["profile"]["geometry"] == "physical", "Void Claw still moves and plays as a physical attack")
		NoctyraxCases.REEL:
			_expect(report["beats"].size() == 2 and report["reel_frames"] == REEL_FRAMES
				and report["beats"][1]["contact"] > first["contact"] and report["beats"][1]["contact"] < REEL_FRAMES,
				"Both contacts fit the same 300-frame take")
	for beat: Dictionary in _beats: _check_beat(id, beat)

func _check_beat(id: String, beat: Dictionary) -> void:
	var report: Dictionary = beat["report"]
	var step: Dictionary = beat["step"]
	var profile: Dictionary = report["profile"]
	var stamps: Dictionary = report["stamps"]
	if profile.get("geometry") == "physical":
		_expect(stamps.is_empty(), id + " physical claw has no Shadow burst")
		return
	var eclipse: bool = profile.get("geometry") == "ground"
	_expect(report["shot_frames"] == 0 and Shot.resolve(step).is_empty(), id + " uses no shot painter")
	_expect(not eclipse or report["area_active"], id + " Eclipse uses darkening for its area signal")
	var actor: Dictionary = beat["before"]["enemies"][0]
	var tiles: Array[Vector2i] = beat["tiles"]
	var max_ring: int = 1
	for tile: Vector2i in tiles: max_ring = maxi(max_ring, _ring(tile, actor))
	var metadata: Dictionary = Fx.metadata()
	var center: Vector2i = step.get("center", step["to"])
	var expected: int = 0
	for tile: Vector2i in tiles:
		var key: String = _coord(tile)
		var hit: bool = report["hit_tiles"].has(key)
		var phase: float = Dragon.CONTACT
		if not _reduced and not eclipse and tiles.size() > 1:
			phase = lerpf(Dragon.RELEASE, Dragon.CONTACT, float(_ring(tile, actor) - 1) / maxi(1, max_ring - 1))
		var submitted: int = report["contact"]
		if phase < Dragon.CONTACT:
			for frame: int in report["phases"]:
				if report["phases"][frame] < phase: continue
				submitted = frame
				break
		var display: Dictionary = beat["before"] if submitted < report["contact"] else beat["after"]
		var grid: Array = display["grid"]
		var visible: bool = _combat_engine.is_tile_visible_to_player(display, tile)
		var drawable: bool = Paths.is_passable(grid, tile) and Paths.tile_id(grid, tile) != "void" and visible
		if not drawable or (eclipse and not hit):
			_expect(not stamps.has(key), id + " omits " + key)
			continue
		expected += 1
		_expect(stamps.has(key), id + " plays " + key)
		if not stamps.has(key): continue
		var stamp: Dictionary = stamps[key]
		var row: String = "shadow_hit" if hit else "shadow_floor"
		_expect(stamp["rows"] == {"rear": int(metadata["rows"][row + "_rear"]), "front": int(metadata["rows"][row + "_front"])}
			and stamp["instances"].size() == 2, id + " has one " + row + " depth pair at " + key)
		var delay: float = 0.0
		if eclipse and not _reduced:
			delay = minf(metadata["max_delay_seconds"], Paths.manhattan(center, tile) * metadata["delay_per_tile_seconds"])
		_expect(stamp["visible_at_submission"] and stamp["submitted"] == submitted and is_equal_approx(stamp["delay"], delay)
			and stamp["visible"] >= stamp["submitted"], id + " uses the shared schedule and visibility at " + key)
		if _reduced:
			_expect(stamp["submitted"] == report["contact"] and stamp["cell"] == metadata["reduced_motion_frame_by_burst"]["shadow"],
				id + " shows the authored Shadow still at contact on " + key)
	_expect(stamps.size() == expected, id + " has exactly the expected tile set")
	for progress: float in SAMPLE_PROGRESS:
		# These guards must return before calling any painters on a canvas.
		Spell.draw_source(null, profile, Vector2.ONE, Vector2.ZERO, PROBE_TILE_WIDTH, progress)
		for front: bool in [false, true]:
			Spell.draw_target(null, profile, Vector2.ONE, Vector2.ZERO, Vector2.ONE, PROBE_TILE_WIDTH, progress, _reduced, front, true, true, PROBE_SEED)

func _check_removed_painters() -> void:
	var callers: int = 0
	for script: String in ["dragon_spell_presentation", "combat_board_view", "run_scene", "shot_fx"]:
		var source: String = FileAccess.get_file_as_string("res://scripts/" + script + ".gd")
		for symbol: String in ["dragon_shadow_fx", "_draw_noctyrax_breath", "\"noctyrax_breath\""]: callers += source.count(symbol)
	_expect(callers == 0 and not FileAccess.file_exists("res://scripts/dragon_shadow_fx.gd"), "There are no Shadow painter calls or ranged painter draw sites")
	print("FX-30 PAINTERS DragonShadowFx calls=%d; Noctyrax ranged painter draws=%d (guard and source audit)" % [callers, callers])

func _ring(tile: Vector2i, actor: Dictionary) -> int:
	var origin: Vector2i = actor["pos"]
	var footprint: Vector2i = actor["footprint"]
	var closest: Vector2i = tile.clamp(origin, origin + footprint - Vector2i.ONE)
	var delta: Vector2i = (tile - closest).abs()
	return maxi(1, maxi(delta.x, delta.y))

func _print_report(report: Dictionary) -> void:
	for beat: Dictionary in report["beats"]:
		print("FX-30 STEP %s %s release=%d contact=%d numbers=%d action_frames=%d area_tiles=%d hit_tiles=%d visible_hits=%d burst_tiles=%d" % [
			report["case"], beat["intent"], beat["release"], beat["contact"], beat["numbers"], beat["phases"].size(),
			beat["tiles"].size(), beat["hit_tiles"].size(), beat["visible_hits"].size(), beat["stamps"].size()])
		for key: String in beat["stamps"]:
			var stamp: Dictionary = beat["stamps"][key]
			var row: String = "hit" if stamp["rows"]["front"] == Fx.metadata()["rows"]["shadow_hit_front"] else "floor"
			print("FX-30 TILE %s %s shadow %s start=%d submitted=%d cell=%d" % [
				report["case"], key, row, stamp["visible"], stamp["submitted"], stamp.get("cell", -1)])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FX-30 FAIL: " + message)
