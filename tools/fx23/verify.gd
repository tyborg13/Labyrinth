extends "res://tools/fx23/native.gd"

var _checks: int
var _failures: int

func _take() -> void:
	var cases: Dictionary = Cases23.HERO_CASES.duplicate()
	cases.merge(Cases23.inventory())
	if "--list-cases" in OS.get_cmdline_user_args():
		print("FX-23 CASES: " + " ".join(cases.keys()))
		quit()
		return
	var output: String = _arg("--out")
	var before_dir: String = _arg("--base-dir")
	var after_dir: String = _arg("--after-dir")
	if output.is_empty() or before_dir.is_empty() or after_dir.is_empty():
		_fail("Use tools/fx23/native.sh --dry-run to stage the exact base.")
		return
	_install_headless_clock()
	_check_selection()
	var filter: String = _arg("--case")
	if not filter.is_empty() and not cases.has(filter):
		_fail("Unknown FX-23 case " + filter)
		return
	for id: String in cases:
		if not filter.is_empty() and id != filter: continue
		var before: Dictionary = await take_case(id, output.path_join("before").path_join(id), before_dir, true)
		var after: Dictionary = await take_case(id, output.path_join("after").path_join(id), after_dir, true)
		if before.is_empty() or after.is_empty(): return
		var expected: String = cases[id][1] if Cases23.HERO_CASES.has(id) else cases[id][3]
		_compare(id, before, after, expected)
	if filter.is_empty():
		var reduced: Dictionary = await take_case("fire_hit", output.path_join("after/fire_reduced"), after_dir, true, true)
		_expect(reduced.get("shot") == "ember" and reduced.get("draw_frames", [0]).is_empty()
			and _rows(reduced) == ["fire_hit_front"] and not reduced.get("legacy_flight") and not reduced.get("legacy_release"),
			"Reduced motion hides the shot and keeps the contact")
		var reel: Dictionary = await take_case(Cases23.RECORDING, output.path_join("after/recording"), after_dir, true)
		_expect(reel.get("reel_frames") == REEL_FRAMES and reel.get("recorded_shots") == ["ember", "spark"], "The 240-frame reel plays Fire then Lightning")
		_fog_proof = true
		var fog: Dictionary = await take_case("lightning_wisp_static_lash", output.path_join("after/wisp_fog"), after_dir, true)
		_expect(not fog.get("caster_visible", true) and fog.get("clip_start", -1.0) > 0.0 and _rows(fog) == ["lightning_hit_front"],
			"The hidden Wisp's shot clips its origin and contacts the visible hero")
	print("FX-23 VERIFY: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _check_selection() -> void:
	for element: String in Cases23.SHOT_FOR:
		var effect: Dictionary = {"kind": "aoe", "range": 2, "element": element}
		for action: String in ["aoe", "ranged", "terrain_burst"]:
			effect["action_type"] = action
			_expect(Shot20.resolve(effect) == Cases23.SHOT_FOR[element], "%s %s ranged area resolves" % [element, action])
		for guard: String in ["preview", "ground_burst", "chain_index"]:
			effect[guard] = true
			_expect(Shot20.resolve(effect).is_empty(), "%s %s keeps its renderer" % [element, guard])
			effect.erase(guard)
		effect["action_type"] = "lightning_strikes"
		_expect(Shot20.resolve(effect).is_empty(), "Board lightning stays on its sky-strike renderer")
		effect["kind"] = "lightning_strikes"
		_expect(Shot20.resolve(effect).is_empty(), "Sky strikes never resolve to shots")
		effect.merge({"kind": "aoe", "action_type": "aoe", "range": 0}, true)
		_expect(Shot20.resolve(effect).is_empty(), "Centred areas keep their renderer")
	for element: String in ["ice", "air", "earth"]:
		_expect(Shot20.resolve({"kind": "aoe", "action_type": "aoe", "range": 2, "element": element}).is_empty(),
			"%s area keeps procedural travel" % element)
	var palette: PackedColorArray = Shot20._palette
	_expect(Shot20._shader_for_palette().code.contains("uniform vec4 palette[%d]" % palette.size()) and palette.size() == 65,
		"The installed shader has room for the full indexed palette")

func _compare(id: String, before: Dictionary, after: Dictionary, expected: String) -> void:
	print("FX-23 CASE %s before=%s after=%s" % [id, _summary(before), _summary(after)])
	for field: String in ["contact", "action_contact", "action_frames", "frames", "duration_usec", "done", "loss", "bursts"]:
		_expect(before[field] == after[field], "%s keeps %s (%s → %s)" % [id, field, before[field], after[field]])
	_expect(before["shot"] == "" and before["draw_frames"].is_empty(), id + " has no base shot")
	_expect(after["shot"] == expected and after["draw_frames"].is_empty() == expected.is_empty(), id + " resolves its expected shot")
	if expected.is_empty():
		_expect(before["legacy_flight"] == after["legacy_flight"] and before["legacy_release"] == after["legacy_release"],
			id + " keeps the existing legacy submissions")
	else:
		_expect(before["legacy_flight"] and before["legacy_release"] == (id != Cases23.ARC_BOLT), id + " observes the base legacy submissions")
		_expect(not after["legacy_flight"] and not after["legacy_release"], id + " submits neither legacy draw after")
		_expect(not Shot20.has_hit(expected), id + " has no separate shot-atlas hit")
		_expect(not after["draw_frames"].is_empty() and after["draw_frames"][-1] < after["contact"], id + " clears flight at contact")
	if id in ["fire_area", "lightning_area"]:
		_expect(after["ends_at_center"] and not after["bursts"].is_empty(), id + " flies to tile centre and keeps area bursts")
	if id in ["fire_hit", "fire_blocked", "fire_floor", "lightning_hit"]:
		var element: String = "lightning" if id == "lightning_hit" else "fire"
		_expect(_rows(after) == [element + ("_floor_front" if id == "fire_floor" else "_hit_front")], id + " keeps its outcome-specific contact row")
	if id == "slag_mortar_scatter_shot":
		# The resolver aims the effect at the shove destination. The original
		# fx-17 contact has no damage-pool loss on that tile.
		_expect(_rows(after) == ["fire_floor_front"], "Scatter Shot keeps the fx-17 floor burst on the shove destination")
	if id == "fire_blocked":
		_expect(after["loss"][0] == 0 and after["loss"][1] > 0, "Fully blocked Fire removes Block and spares health")
	if id == "fire_floor":
		_expect(after["loss"] == [0, 0, 0], "Empty aimed tile loses no pools")
	if id == "lightning_chain":
		_expect(before["electrical_trace"] and after["electrical_trace"], "The baked primary flight precedes an actual chain trace")

func _rows(report: Dictionary) -> Array:
	return report.get("bursts", {}).get(report.get("aim", ""), []).map(func(entry: Dictionary) -> String: return entry["design"])

func _summary(report: Dictionary) -> String:
	return "shot=%s draw=%s action_draw=%s contact=%s action_contact=%s length=%s schedule=%s/%sus legacy_flight=%s legacy_release=%s" % [
		report["shot"] if not report["shot"].is_empty() else "none", report["draw_frames"], report["action_draw_frames"], report["contact"],
		report["action_contact"], report["action_frames"], report["frames"], report["duration_usec"], report["legacy_flight"], report["legacy_release"],
	]

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if ok: return
	_failures += 1
	push_error(message)
