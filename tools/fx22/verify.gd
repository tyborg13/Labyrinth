extends "res://tools/fx22/native_capture.gd"

const SUITES: Array[String] = ["actor_presentation", "dragon_area_presentation", "dragon_boss", "dragon_feedback1",
	"dragon_pressure_mechanics", "enemy_surface_acceptance"]
const HIT_CHIPS: String = "hit_chips"
var _checks: int
var _failures: int

func _take() -> void:
	if OS.get_cmdline_user_args().has("--suites"):
		for name: String in SUITES:
			var suite: Script = load("res://tests/suites/" + name + "_suite.gd")
			var checks: int = _checks
			var failures: int = _failures
			suite.run(_expect)
			print("FX-22 SUITE %s: %d checks, %d failures" % [name, _checks - checks, _failures - failures])
		_finish()
		return
	_install_headless_clock()
	var output: String = _arg("--out")
	var base_dir: String = _arg("--base-dir")
	var filter: String = _arg("--case")
	if output.is_empty() or base_dir.is_empty() or (not filter.is_empty() and not Cases22.CASES.has(filter)):
		_fail("Run tools/fx22/native.sh --dry-run [--case ID].")
		return
	_check_draw_sources(base_dir)
	for id: String in Cases22.CASES:
		if not filter.is_empty() and filter != id: continue
		var base: Dictionary = await take_case(id, output.path_join("before").path_join(id), base_dir, true)
		var after: Dictionary = await take_case(id, output.path_join("after").path_join(id), "", true)
		if base.is_empty() or after.is_empty():
			_expect(false, id + " has both takes")
			continue
		_compare(id, base, after)
	if filter.is_empty():
		for id: String in ["shale_hit", "cinder_bloom", "vaeloryx_pull"]:
			var base: Dictionary = await take_case(id, output.path_join("reduced-before").path_join(id), base_dir, true, true)
			var reduced: Dictionary = await take_case(id, output.path_join("reduced").path_join(id), "", true, true)
			if not base.is_empty() and not reduced.is_empty():
				for key: String in ["frames", "rendered", "duration_usec"]:
					_expect(base[key] == reduced[key], id + " preserves reduced-motion " + key)
			_check_reduced(id, reduced)
	_finish()

func _check_draw_sources(base_dir: String) -> void:
	var board: String = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd")
	var old_board: String = FileAccess.get_file_as_string(base_dir.path_join("combat_board_view.gd"))
	var markers: Array[String] = ["_draw_bile_bloomer_fragments(", "BileBloomerFx.draw_fragments(", "CinderOozeActionFx.draw_bloom(", "_draw_vaeloryx_wind_feedback(", "VaeloryxWind.draw("]
	for marker: String in markers:
		_expect(old_board.contains(marker) and not board.contains(marker), "Removed draw submission " + marker)
	_expect(Fx.select_enemy({"kind": "aoe", "intent_id": "bile_burst", "element": "earth"}) == "earth", "Shale area lands the Earth burst (director decision)")
	_expect(Shot20.metadata()["shot_for_intent"].get("bile_burst") == "rock", "The Shale intent explicitly selects Rock")
	_expect(preload("res://scripts/vaeloryx_cutout/wind_feedback.gd").handles({"kind": "pull", "enemy_type": "vaeloryx", "umbra_action_clipped": true}),
		"Clipping does not change the wind schedule selector")

func _compare(id: String, base: Dictionary, after: Dictionary) -> void:
	print("FX-22 STEP %s frames=%s/%s done=%s/%s before=%s after=%s" % [
		id, base["frames"], after["frames"], base["done"], after["done"], JSON.stringify(base["bursts"]), JSON.stringify(after["bursts"])])
	for key: String in ["frames", "rendered", "duration_usec", "losses", "player_from", "player_to"]:
		_expect(after[key] == base[key], "%s preserves %s" % [id, key])
	for key: String in ["rig", "slide"]:
		_expect(_distinct_samples(after[key].values()) == _distinct_samples(base[key].values()), "%s preserves the %s samples" % [id, key])
	for tile: String in after["bursts"]:
		_expect(after["bursts"][tile].size() == 1, "%s has one impact on %s" % [id, tile])
	for cell: String in after["hidden"]:
		_expect(not after["tile_pairs"].has(cell + "_front"), "%s skips hidden tile %s" % [id, cell])
	match id:
		"shale_hit", "shale_blocked":
			var target: String = after["player_from"]
			var shots: Array = after["shots"]
			var blocked: bool = id == "shale_blocked"
			_expect(after["losses"]["hp"] == 0 and after["losses"]["block"] > 0 if blocked else after["losses"]["hp"] > 0,
				id + " exercises the intended loss")
			_expect(not shots.is_empty() and shots[0]["from_socket"] and shots[0]["design"] == "rock", id + " launches Rock from the existing rig socket")
			_expect(_distinct_samples(shots.map(_shot_clock)) == _distinct_samples((base["shots"] as Array).map(_shot_clock)), id + " preserves each authored flight sample")
			_expect(_design(after, target) == HIT_CHIPS and _impact_frame(after, target) == after["contact"], id + " plays the Rock hit at contact")
		"shale_aoe":
			_expect(after["shots"] == base["shots"] and after["bursts"] == base["bursts"] and after["targets"].size() > 1,
				"Preserved Shale's resolved area and empty baked mapping")
		"cinder_bloom", "cinder_bloom_terrain":
			var terrain: String = Cases20.coords(Cases22.TERRAIN_TILE) if id == "cinder_bloom_terrain" else ""
			_expect(after["targets"].size() == 4 and after["tile_pairs"].size() == base["tile_pairs"].size(),
				"Cinder Bloom already submits all four Fire pairs")
			if not terrain.is_empty():
				_expect(_design(base, terrain) == "fire_hit_front" and not after["terrain_losses"].is_empty(),
					"The shared tile player uses the hit row for a surviving prop")
			for tile: String in after["targets"]:
				_check_pair(after, tile, "fire_hit" if tile in [after["player_from"], terrain] else "fire_floor")
				var entry: Dictionary = after["tile_pairs"].get(tile + "_front", {})
				var before: Dictionary = base["tile_pairs"].get(tile + "_front", {})
				_expect(is_equal_approx(entry.get("clock_delay", -1.0), float(Fx.metadata()["delay_per_tile_seconds"])),
					"Cinder Bloom retains Fx-12's one-tile delay on " + tile)
				_expect(entry.get("added") == before.get("added") and entry.get("start") == before.get("start"),
					"Cinder Bloom starts the same pair on the existing clock at " + tile)
		_:
			_check_sweep(id, after)

func _shot_clock(shot: Dictionary) -> Array:
	return [shot["progress"], shot["design"], shot["target"]]

func _distinct_samples(samples: Array) -> Array:
	var result: Array = []
	for sample: Variant in samples:
		if result.is_empty() or result.back() != sample: result.append(sample)
	return result

func _check_sweep(id: String, report: Dictionary) -> void:
	var tiles: Array = report["targets"]
	_expect(tiles.size() >= 3 and report["player_from"] != report["player_to"] and _distinct_samples(report["slide"].values()).size() > 1,
		id + " sweeps multiple tiles and plays the displacement")
	var target_hit: bool = id != "vaeloryx_pull_floor"
	var losses: Dictionary = report["losses"]
	_expect((losses["hp"] > 0 or losses["block"] > 0) == target_hit, id + " exercises the intended target row")
	_expect(report["shots"].is_empty(), id + " uses only the retained Air line")
	_expect(report["bursts"].keys().all(func(tile: String) -> bool: return tiles.has(tile)),
		id + " submits its impact at the starting tile and no second impact at the landing tile")
	if id == "vaeloryx_pull_fog":
		_expect(not report["hidden"].is_empty(), "The fog witness hides part of the sweep")
	for index: int in tiles.size():
		var tile: String = tiles[index]
		if report["hidden"].has(tile): continue
		var hit: bool = tile == report["player_from"] and target_hit
		_check_pair(report, tile, "air_hit" if hit else "air_floor")
		var phase: float = lerpf(Dragon.RELEASE, Dragon.CONTACT, float(index) / maxi(1, tiles.size() - 1))
		var frame_for_phase: int = -1
		for frame: int in report["samples"]:
			if float(report["samples"][frame]) >= phase:
				frame_for_phase = frame
				break
		_expect(_impact_frame(report, tile) == frame_for_phase, "%s starts %s on expected sweep frame %d" % [id, tile, frame_for_phase])

func _check_pair(report: Dictionary, tile: String, family: String) -> void:
	var front: Dictionary = report["tile_pairs"].get(tile + "_front", {})
	var rear: Dictionary = report["tile_pairs"].get(tile + "_rear", {})
	_expect(front.get("design") == family + "_front" and rear.get("design") == family + "_rear", "%s plays the %s pair at %s" % [report["case"], family, tile])
	_expect(front.get("added") == rear.get("added") and front.get("start") == rear.get("start"), "%s aligns depth layers on %s" % [report["case"], tile])

func _check_reduced(id: String, report: Dictionary) -> void:
	if report.is_empty():
		_expect(false, id + " has a reduced take")
		return
	if id == "shale_hit":
		_expect(report["shots"].is_empty() and _design(report, report["player_from"]) == HIT_CHIPS and report["shot_still"] == Shot20.hit_frame(0.0, true),
			"Reduced Shale uses the Rock player's still hit")
		return
	for tile: String in report["targets"]:
		_expect(report["stills"].get(tile, -1) == int(Fx.metadata()["reduced_motion_frame"]), id + " uses the tile player's existing still at " + tile)

func _design(report: Dictionary, tile: String) -> String:
	var entries: Array = report["bursts"].get(tile, [])
	return entries[0]["design"] if entries.size() == 1 else ""

func _impact_frame(report: Dictionary, tile: String) -> int:
	var entries: Array = report["bursts"].get(tile, [])
	return entries[0]["frame"] if entries.size() == 1 else -1

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)

func _finish() -> void:
	print("FX-22 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
