extends "res://tools/fx32/native_capture.gd"

const SHOTS := {"lodestone_reversal": "spark", "yank": "hook", "gust_step": "hook", "area_ranged": "shade"}
const EARTH_CASES: Array[String] = ["root_snare", "root_snare_diagonal", "lash_visible", "lash_hidden"]
const ADJACENT := {"cold_shoulder": "ice", "cold_shoulder_ice": "ice", "cold_shoulder_collision": "impact",
	"sleet_squall_floor": "ice", "rooted_kick": "earth", "hurricane_palm": "air"}
var _checks: int
var _failures: int

func _take() -> void:
	var output: String = _arg("--out")
	var baseline: String = _arg("--compare-before")
	var selected: String = _arg("--case")
	if output.is_empty() or (not selected.is_empty() and not ForceCases.CASES.has(selected)):
		_fail("Use tools/fx32/native.sh --dry-run [--case ID].")
		return
	_plan = true
	_install_plan_clock()
	for id: String in ForceCases.CASES:
		if not selected.is_empty() and selected != id: continue
		for reduced: bool in [false, true]:
			if id == ForceCases.REEL and (reduced or baseline.is_empty()): continue
			var name: String = id + ("_reduced" if reduced else "")
			var report: Dictionary = await take(id, output.path_join(name), reduced)
			if report.is_empty(): return
			for beat: Dictionary in report["beats"]:
				_print_beat(name, beat, report)
			if baseline.is_empty():
				var expected: String = "" if id == "lodestone_reversal" else SHOTS.get(id, "")
				_expect(report["beats"][0]["shot"] == expected, name + " witnesses the original shot mapping")
				if id == "area_ranged":
					var hits: Array = report["beats"][0]["hits"]
					_expect(hits.size() == 1 and hits[0]["row"] == "hit_gloom", name + " witnesses the original double")
				continue
			if id == ForceCases.REEL:
				_expect(report["reel_frames"] == REEL_FRAMES and report["beats"].size() == 4
					and report["beats"][-1]["hidden_source"], "One fight supplies all four reel contacts")
				continue
			var path: String = baseline.path_join(name).path_join("take.json")
			var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_expect(old is Dictionary, name + " has a baseline take")
			if old is Dictionary: _compare(name, old, report)
			_check_beat(name, report["beats"][0], reduced)
	if not baseline.is_empty():
		_check_removed_painters()
		_check_fire_resolver()
	print("FX-32 %s: %s (%d checks, %d failures)" % [
		"BASELINE" if baseline.is_empty() else "VERIFY", "PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _compare(label: String, old: Dictionary, current: Dictionary) -> void:
	for key: String in ["done", "authored_frames", "rendered_frames", "duration_usec"]:
		_expect(old[key] == current[key], "%s preserves %s (%s/%s)" % [label, key, old[key], current[key]])
	var before: Dictionary = old["beats"][0]
	var after: Dictionary = current["beats"][0]
	for key: String in ["start", "release", "contact", "last", "release_phase", "contact_phase", "columns", "text", "phases", "to", "from", "target_hit", "hidden_source"]:
		_expect(before[key] == _json_value(after[key]), label + " preserves " + key)
	if after["id"] in ["yank", "gust_step", "haft_shove"]:
		for key: String in ["shot", "flight", "hits"]:
			_expect(before[key] == _json_value(after[key]), label + " preserves control " + key)
		_expect(_pairs(before) == _json_value(_pairs(after)), label + " preserves control tile bursts")

func _check_beat(label: String, beat: Dictionary, reduced: bool) -> void:
	var id: String = beat["id"]
	_expect(beat["shot"] == SHOTS.get(id, ""), label + " resolves the expected shot")
	_expect(beat["flight"].is_empty() == (reduced or not SHOTS.has(id)), label + " has flight only with a normal-motion shot")
	if id == "area_ranged":
		_expect(beat["hits"].is_empty(), label + " has no Gloom hit at the aim")
	var pairs: Dictionary = _pairs(beat)
	_expect(beat["bursts"].size() == 2 * pairs.size(), label + " has one rear/front pair per burst tile")
	for tile: String in pairs:
		var pair: Array = beat["bursts"].filter(func(row: Dictionary) -> bool: return row["tile"] == tile)
		if pair.size() != 2: continue
		var row: Dictionary = pairs[tile]
		_expect(pair.any(func(layer: Dictionary) -> bool: return layer["front"]) and
			pair.any(func(layer: Dictionary) -> bool: return not layer["front"]) and
			pair[0]["row"].get_slice("_", 0) == pair[1]["row"].get_slice("_", 0) and
			pair[0]["frame"] == pair[1]["frame"] and row["frame"] >= row["submitted"], label + " layers align on " + tile)
		_expect(pair.all(func(layer: Dictionary) -> bool: return layer["tile_visible"]), label + " submits visible tile " + tile)
		if reduced:
			var still: int = Fx.metadata().get("reduced_motion_frame_by_burst", {}).get(row["name"], Fx.metadata()["reduced_motion_frame"])
			_expect(pair.all(func(layer: Dictionary) -> bool: return layer["cell"] == still and layer["frame"] == layer["submitted"]),
				label + " displays the approved still on its start frame on " + tile)
	if ADJACENT.has(id):
		var target: Dictionary = pairs.get(beat["to"], {})
		_expect(target.get("name") == ADJACENT[id] and target.get("row") == ("hit" if beat["target_hit"] else "floor")
			and target.get("submitted") == beat["contact"], label + " has the expected burst at contact")
		if id == "sleet_squall_floor": _expect(not beat["target_hit"], label + " has no qualifying loss")
	if id in EARTH_CASES: _check_earth(label, beat, pairs, reduced)

func _check_earth(label: String, beat: Dictionary, pairs: Dictionary, reduced: bool) -> void:
	var ray: Array[Vector2i] = Paths._supercover_line(_tile(beat["from"]), _tile(beat["to"]))
	_expect(not pairs.has(beat["from"]), label + " excludes its caster")
	_expect(beat["hidden_source"] == (beat["id"] == "lash_hidden"), label + " has the expected caster visibility")
	for index: int in range(1, ray.size()):
		var cell: String = ForceCases.cell(ray[index])
		if beat["hidden_source"] and Paths.manhattan(ray[index], ForceCases.HERO) > 1:
			_expect(not pairs.has(cell), label + " omits the hidden step " + cell)
			continue
		var row: Dictionary = pairs.get(cell, {})
		var target: bool = index == ray.size() - 1
		var phase: float = lerpf(beat["release_phase"], beat["contact_phase"], float(index) / float(ray.size() - 1))
		var due: int = beat["contact"]
		if not reduced and not target:
			for frame: Variant in beat["phases"]:
				if beat["phases"][frame] >= phase or is_equal_approx(beat["phases"][frame], phase):
					due = int(frame)
					break
		_expect(row.get("name") == "earth" and row.get("row") == ("hit" if target and beat["target_hit"] else "floor")
			and row.get("submitted") == due, "%s Earth %s starts at %d, observed %s" % [label, cell, due, row])

func _check_removed_painters() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd")
	var painter: String = source.get_slice("func _draw_ranged_projectile_effect(", 1).get_slice("\nfunc ", 0)
	for symbol: String in ["_draw_projectile_diamond", "_draw_umbra_clipped_ranged_effect", "_draw_umbra_clipped_colored_polygon",
			"_draw_elemental_projectile_trail", "_draw_bezier_glow", "_draw_partial_bezier_glow", "_draw_earth_spike_attack_effect",
			"_draw_air_gust_attack_effect", "_draw_lightning_attack_effect", "_draw_ice_shard_attack_effect", "_draw_fireball_attack_effect"]:
		_expect(not source.contains(symbol), "No function or call remains for " + symbol)
	_expect(painter.contains('if bool(effect.get("preview", false)) and _target_preview_curve_visible(effect):\n\t\t_draw_ranged_target_preview_curve(effect, from_point, to_point)')
		and painter.count("\n\t") == 2, "The ranged painter can submit only the preview curve")
	var marking: String = source.get_slice("func _draw_action_ground_markings()", 1).get_slice("\nfunc ", 0)
	_expect(marking.contains('elif kind == "ranged" and bool(effect.get("preview", false))'), "Force TileGlow can submit only in previews")
	print("FX-32 LIVE LEGACY SUBMISSIONS: 0 (painters removed, preview-only guards)")

func _check_fire_resolver() -> void:
	var future: Dictionary = {"kind": "ranged", "action_type": "push", "element": "fire",
		"from": ForceCases.HERO, "to": ForceCases.FAR}
	_expect(Shot.resolve(future) == "ember", "The ordinary element fallback applies to distant Fire push")
	future["action_type"] = "pull"
	_expect(Shot.resolve(future) == "hook", "The ordinary pull fallback applies to distant Fire pull")
	future["to"] = ForceCases.NEAR
	_expect(Shot.resolve(future).is_empty(), "Adjacent Fire force has no flight")

func _json_value(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _pairs(beat: Dictionary) -> Dictionary:
	var result: Dictionary
	for entry: Dictionary in beat["bursts"]:
		if not entry["front"]: continue
		var name: String = entry["row"].get_slice("_", 0)
		result[entry["tile"]] = {"name": name, "row": entry["row"].get_slice("_", 1), "frame": entry["frame"],
			"submitted": entry["submitted"], "cell": entry["cell"]}
	return result

func _print_beat(label: String, beat: Dictionary, report: Dictionary) -> void:
	print("FX-32 STEP %s/%s shot=%s start=%d release=%d contact=%d last=%d done=%d duration_usec=%d bursts=%s shot_hits=%s" % [
		label, beat["id"], beat["shot"] if not beat["shot"].is_empty() else "none", beat["start"], beat["release"],
		beat["contact"], beat["last"], report["done"], report["duration_usec"], JSON.stringify(_pairs(beat)), JSON.stringify(beat["hits"])])

func _tile(cell: String) -> Vector2i:
	return Vector2i(int(cell.get_slice(":", 0)), int(cell.get_slice(":", 1)))

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)
