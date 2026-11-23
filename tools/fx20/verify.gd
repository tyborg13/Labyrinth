extends "res://tools/fx20/native_capture.gd"

const SUITES: Array[String] = ["dragon_area_presentation", "dragon_feedback1", "dragon_pressure_mechanics", "en05_enemies", "illusion_terrain"]
const EnemyClockSuite = preload("res://tests/suites/combat_enemy_action_clock_suite.gd")
const HERO_CELL := "4:4"
const FOE_CELL := "4:2"
const SHOT_HITS: Dictionary = {"frostbolt": "hit_glass", "sunlance": "hit_flash", "hurl_spear": "hit_spark", "snake_eyes": "hit_pale", "dust_bolt": "hit_puff"}
var _failures: int
var _checks: int

func _take() -> void:
	if OS.get_cmdline_user_args().has("--suites"):
		for name: String in SUITES:
			var suite: Script = load("res://tests/suites/" + name + "_suite.gd")
			var before: int = _checks
			var failures: int = _failures
			suite.run(_expect)
			print("FX-20 SUITE %s: %d checks, %d failures" % [name, _checks - before, _failures - failures])
		var before: int = _checks
		var failures: int = _failures
		await EnemyClockSuite._mechanic_views(self, _expect)
		print("FX-20 SUITE combat_enemy_action_clock mechanic views: %d checks, %d failures" % [_checks - before, _failures - failures])
		_finish_verify()
		return
	_install_headless_clock()
	var output: String = _arg("--out")
	var base_dir: String = _arg("--base-dir")
	if output.is_empty() or base_dir.is_empty():
		_fail("Use tools/fx20/native.sh --dry-run to stage exact base sources.")
		return
	_check_source()
	var filter: String = _arg("--case")
	for id: String in Cases20.MATRIX:
		if not filter.is_empty() and filter != id: continue
		var base: Dictionary = await take_case(id, output.path_join("before").path_join(id), base_dir, true)
		var after: Dictionary = await take_case(id, output.path_join("after").path_join(id), "", true)
		if base.is_empty() or after.is_empty():
			_expect(false, "Missing take: " + id)
			continue
		print("FX-20 STEP %s before=%s after=%s" % [id, JSON.stringify(base["bursts"]), JSON.stringify(after["bursts"])])
		_compare(id, base, after)
	if filter.is_empty():
		var reduced: Dictionary = await take_case("bite", output.path_join("after/bite_reduced"), "", true, true)
		_expect(_designs(reduced, HERO_CELL) == ["fire_hit_front"] and reduced.get("stills", {}).get(HERO_CELL) == int(Fx.metadata()["reduced_motion_frame"]),
			"Reduced bite uses the existing tile player still")
	_finish_verify()

func _check_source() -> void:
	var board: String = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd")
	var acolyte: String = FileAccess.get_file_as_string("res://scripts/veilbound_acolyte_cutout/fx.gd")
	var mirror: String = FileAccess.get_file_as_string("res://scripts/enemy_mechanics/reflect_view.gd")
	_expect(not board.contains("_draw_protagonist_charge"), "No cast charge draw entry or submission")
	_expect(not board.contains("_draw_vyraketh_bite_effect"), "No Vyraketh bite-stroke entry or submission")
	_expect(not board.contains("VeilboundAcolyteFx.melee") and not acolyte.contains("draw_polyline"), "No Veilbound slash contour submissions")
	_expect(not mirror.contains("board.draw_line"), "No Refraction beam submissions")

func _compare(id: String, base: Dictionary, after: Dictionary) -> void:
	_expect([base["frames"], base["duration_usec"], base["done"]] == [after["frames"], after["duration_usec"], after["done"]],
		"%s keeps %s/%s authored frames and %s/%s completion frames" % [id, base["frames"], after["frames"], base["done"], after["done"]])
	_expect(base["losses"] == after["losses"], id + " resolves the same hero outcome")
	if Cases20.NATIVE.has(id):
		_expect(after["columns"].size() == 5 and base["columns"].size() == 5, id + " schedules five samples on both revisions")
	if id != "recording":
		for tile: String in after["bursts"]:
			_expect(after["bursts"][tile].size() == 1, "%s claims %s exactly once" % [id, tile])
	if SHOT_HITS.has(id):
		var tile: String = HERO_CELL if id == "dust_bolt" else FOE_CELL
		_expect(_designs(after, tile) == [SHOT_HITS[id]], id + " plays only its mapped shot hit")
	match id:
		"skybreak", "board_lightning", "meteorfall", "icefall":
			_expect(not after["strikes"].is_empty() and not after["bursts"].is_empty(), id + " uses a falling strike and an impact")
		"bite", "bite_blocked":
			_expect(_designs(after, HERO_CELL) == ["fire_hit_front"], id + " stamps Fire hit on the hero")
			_expect(_frame(after, HERO_CELL) == after["numbers"], id + " starts on the number frame")
			_expect(after["losses"]["block" if id == "bite_blocked" else "hp"] > 0 and (id != "bite_blocked" or after["losses"]["hp"] == 0),
				id + " inflicts the intended pool loss")
		"rake":
			_expect(after["targets"].size() == 3 and after["bursts"].size() == 1 and _designs(after, HERO_CELL) == ["earth_hit_front"], "Worldspine Claw contacts the hero and skips empty tiles")
			_expect(_frame(after, HERO_CELL) == after["numbers"], "Worldspine Claw starts on the number frame")
		"veilbound":
			_expect(after["trail"] == "presented_pose", "Veilbound uses the live rig path")
			_expect(_designs(after, HERO_CELL) == ["shadow_hit_front"], "Veilbound Shadow plays the tendril contact (fx-25)")
		"refraction", "refraction_fallback":
			_expect(after["targets"].size() == 4 and after["targets"][2] == HERO_CELL, "Refraction targets four tiles with the hero on tile 3")
			var last: int = -1
			for tile: String in after["targets"]:
				_expect(_designs(after, tile) == ["ice_hit_front" if tile == HERO_CELL else "ice_floor_front"], "Refraction uses the resolved row at " + tile)
				var submitted: int = _frame(after, tile)
				# The short sprite fallback can cross two sweep thresholds on
				# one sample of the unchanged action clock.
				_expect(submitted >= last if id == "refraction_fallback" else submitted > last, "Refraction sweeps in line order")
				last = submitted
			_expect(last > _frame(after, after["targets"][0]), "Refraction has distinct release and final impact samples")
		"refraction_fog":
			_expect(not after["hidden"].is_empty() and _designs(after, HERO_CELL) == ["ice_hit_front"], "Refraction stamps the visible hero from inside the Umbra")
			for tile: String in after["hidden"]:
				_expect(_designs(after, tile).is_empty(), "Refraction skips hidden tile " + tile)
		"refraction_cancelled":
			_expect(after["bursts"].is_empty() and not after["effects"].has("refraction"), "Cancelled Refraction submits no effect")
		"reflect_spear", "reflect_frostbolt":
			var spear: bool = id == "reflect_spear"
			_expect(after["bounces"] == 1 and _designs(after, HERO_CELL) == ["hit_spark" if spear else "hit_glass"], id + " submits one designed hit on return")
			_expect(_frame(after, HERO_CELL) == after["numbers"], id + " lands with the number")
			_expect(after["headings"].size() == 2 and after["headings"]["outbound"]["design"] == ("spear" if spear else "lance") and after["headings"]["outbound"]["cell"] != after["headings"]["return"]["cell"],
				id + " submits the card design on both legs with a reversed heading")
		"trap_area":
			_expect(after["triggered"] == 1 and base["bursts"].values().any(func(entries: Array) -> bool: return entries.size() > 1), "Trap/area overlap comes from a real Detonate resolution")
			_expect(_designs(after, Cases20.coords(Cases20.NEAR)) == ["fire_hit_front"], "The primary area owns the overlapping trap tile")
		"recording":
			_expect(after["clip_frames"] == RECORD_FRAMES and after["effects"].has("reflected_projectile") and after["effects"].has("refraction"), "Five-second plan contains both Mirror actions")
		"cinder_breath", "crownfire":
			_expect(not after["bursts"].is_empty(), id + " stamps its resolved dragon spell")

func _designs(report: Dictionary, tile: String) -> Array:
	return report.get("bursts", {}).get(tile, []).map(func(entry: Dictionary) -> String: return entry["design"])

func _frame(report: Dictionary, tile: String) -> int:
	var entries: Array = report["bursts"].get(tile, [])
	return entries[0]["frame"] if not entries.is_empty() else -1

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)

func _finish_verify() -> void:
	print("FX-20 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
