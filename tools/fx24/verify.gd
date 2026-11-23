extends "res://tools/fx24/native_capture.gd"

const SUITES: Array[String] = ["combat_outcome_feedback", "forced_movement", "enemy_surface_acceptance",
	"actor_presentation", "illusion_terrain", "dragon_area_presentation"]
var _checks: int
var _failures: int

func _take() -> void:
	if OS.get_cmdline_user_args().has("--suites"):
		for name: String in SUITES:
			var suite: Script = load("res://tests/suites/" + name + "_suite.gd")
			var checks: int = _checks
			var failures: int = _failures
			suite.run(_expect)
			print("FX-24 SUITE %s: %d checks, %d failures" % [name, _checks - checks, _failures - failures])
		_finish()
		return
	var output: String = _arg("--out")
	var base_dir: String = _arg("--base-dir")
	var filter: String = _arg("--case")
	if output.is_empty() or base_dir.is_empty() or (not filter.is_empty() and not Cases24.CASES.has(filter)):
		_fail("Run tools/fx24/native.sh --dry-run [--case ID].")
		return
	_install_headless_clock()
	_check_painters(base_dir)
	for id: String in Cases24.CASES:
		if not filter.is_empty() and id != filter: continue
		await _compare_takes(id, output, base_dir, false)
		if id in Cases24.REDUCED:
			await _compare_takes(id, output, base_dir, true)
	_finish()

func _compare_takes(id: String, output: String, base_dir: String, reduced: bool) -> void:
	var tag: String = "reduced-" if reduced else ""
	var before: Dictionary = await take_case(id, output.path_join(tag + "before").path_join(id), base_dir, true, reduced)
	var after: Dictionary = await take_case(id, output.path_join(tag + "after").path_join(id), "", true, reduced)
	if before.is_empty() or after.is_empty():
		_expect(false, id + " produced both takes")
		return
	print("FX-24 STEP %s%s frames=%s/%s contact=%s/%s before=%s after=%s legacy_before=%s legacy_after=%s" % [
		tag, id, before["frames"], after["frames"], before["contact"], after["contact"],
		JSON.stringify(before["bursts"]), JSON.stringify(after["bursts"]),
		JSON.stringify(before["legacy"]), JSON.stringify(after["legacy"])])
	# The 60 Hz capture can skip different sub-frame authored samples. Compare
	# the production clock totals and the exact contact on both clocks.
	# The push's pre-action pause can shift the entire take by one capture tick.
	# Compare its authored frame and confirm the burst lands on that frame.
	var contact_key: String = "authored_contact" if id == "push_wall" else "contact"
	for key: String in ["frames", "duration_usec", "rendered", contact_key, "contact_progress", "losses", "fades"]:
		_expect(before[key] == after[key], "%s%s preserves %s (%s / %s)" % [tag, id, key, before[key], after[key]])
	_expect(after["legacy"].is_empty(), id + " has no eligible legacy contact")
	var pairs: Dictionary
	for stamp: Dictionary in after["pairs"]:
		var layers: Array = pairs.get_or_add(stamp["tile"], [])
		layers.append(stamp["layer"])
		if reduced:
			_expect(stamp["first_sample"] == int(Fx.metadata()["reduced_motion_frame"]), id + " has the FX-12 still")
	for tile: String in pairs:
		var layers: Array = pairs[tile]
		layers.sort()
		_expect(layers == ["front", "rear"], id + " has exactly one rear/front pair on " + tile)
	for tile: String in after["bursts"]:
		var hits: Array = after["bursts"][tile]
		_expect(hits.size() == 1 and not hits[0]["design"].begins_with("legacy"), id + " has one baked contact on " + tile)
	var stop: String = Cases20.coords(Cases24.STOP)
	var ground: String = Cases20.coords(Cases24.GROUND)
	if Cases24.SURFACES.has(id):
		var element: String = {"ice": "ice", "rubble": "earth", "fire": "fire", "electrified": "lightning"}[Cases24.SURFACES[id]]
		_check_contact(after, ground, element + "_floor_front")
	match id:
		"collision_hit":
			_expect(after["losses"]["hp"] > 0, id + " resolves collision damage")
			_check_contact(after, stop, "impact_hit_front")
		"push_wall":
			_expect(after["losses"]["hp"] == GameData.fixed_point_amount(Cases24.PUSH_DAMAGE), id + " loses only the push attack's damage")
			_expect(after["authored_contact"] > 0, id + " captures its authored contact frame")
			print("FX-24 PUSH CONTACT authored frame=%d/%d" % [before["authored_contact"], after["authored_contact"]])
			_check_contact(after, stop, "impact_hit_front")
		"collision_floor":
			_expect(after["losses"]["hp"] == 0 and after["losses"]["block"] == 0 and after["losses"]["stoneskin"] == 0, id + " resolves a stop with no pool loss")
			_check_contact(after, stop, "impact_floor_front")
		"fire_entry":
			_expect(after["losses"]["hp"] > 0, id + " resolves Fire entry damage")
			_check_contact(after, stop, "fire_hit_front")
		"surface_paint":
			_check_contact(after, ground, "ice_floor_front")
		"trap_unmapped":
			_expect(after["losses"]["hp"] > 0 and after["bursts"].size() == 5, id + " resolves Shadow damage and stamps its five-tile cross")
			_check_contact(after, stop, "shadow_hit_front")
			for offset: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				_check_contact(after, Cases20.coords(Cases24.STOP + offset), "shadow_floor_front")
		"ice_trap", "elementless_trap":
			_expect(after["losses"]["hp"] > 0, id + " resolves trap damage")
			var name: String = "ice" if id == "ice_trap" else "impact"
			_check_contact(after, stop, name + "_hit_front")
		"ooze_melee", "droplet_melee":
			_check_contact(after, stop, "fire_hit_front")
		"shale_aoe":
			_check_contact(after, stop, "earth_hit_front")
		"targeted_fire":
			_check_contact(after, Cases20.coords(Cases20.FAR), "fire_hit_front")
			_expect(after["pairs"].size() == 2 * after["targets"].size(), id + " has a pair on every affected tile")
		"targeted_fog":
			_expect(not after["bursts"].has("4:1"), id + " omits a tile behind Umbra")
		"ground_burst":
			_check_contact(after, Cases20.coords(Cases20.NEAR), "fire_hit_front")
		"terrain_burst":
			_check_contact(after, Cases20.coords(Cases24.GROUND), "impact_hit_front")
		"illusion_burst":
			_check_contact(after, Cases20.coords(Cases24.GROUND), "light_hit_front")
		"steel_melee":
			_check_contact(after, Cases20.coords(Cases20.NEAR), "steel_hit_front")
		"veil_melee":
			_check_contact(after, Cases20.coords(Cases20.HERO), "shadow_hit_front")
		"veil_needle":
			_check_contact(after, stop, Shot20.hit_for("shade"))
			_expect(not before["flight"].is_empty() or reduced, "Shade flight already resolves on the base")
			if not reduced:
				print("FX-24 FLIGHT before=%s after=%s" % [JSON.stringify(before["flight"]), JSON.stringify(after["flight"])])
				_expect(after["flight"].get("name") == "shade" and after["flight"].get("same_socket"),
					"Shade launches from the existing Veilbound socket")
				_expect(before["flight"] == after["flight"], "Shade preserves flight release and endpoints")

func _check_contact(report: Dictionary, tile: String, design: String) -> void:
	var entries: Array = report["bursts"].get(tile, [])
	_expect(entries.size() == 1 and entries[0]["design"] == design,
		"%s has %s on %s (observed %s)" % [report["case"], design, tile, entries])
	if entries.size() == 1:
		_expect(entries[0]["frame"] == report["contact"], "%s submits %s on its original contact" % [report["case"], design])

func _check_painters(base_dir: String) -> void:
	for file: String in ["combat_board_view.gd", "board_surface_presentation.gd"]:
		var before: String = FileAccess.get_file_as_string(base_dir.path_join(file))
		var after: String = FileAccess.get_file_as_string("res://scripts/" + file)
		var markers: Array[String]
		if file == "combat_board_view.gd":
			markers.assign(["VeilboundAcolyteFx.ranged(", "CinderOozeActionFx.draw_contact(", "_draw_trap_elemental_depth_effect("])
		else:
			markers.assign(["_draw_surface_break(", "_draw_fire_burnout(", "_draw_collision_feedback("])
		for marker: String in markers:
			_expect(before.contains(marker) and not after.contains(marker), "Removed canvas submission " + marker)

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)

func _finish() -> void:
	print("FX-24 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
