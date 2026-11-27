extends "res://tools/fel03/capture.gd"
## The same Continue, card, and Pass inputs on either revision. Sample the
## existing CPU render-section counter after the renderer draws each frame.

const TIMING_FIXTURE := "01-s0-seed15-0-0_2-t2"
const TIMING_ACTIONS := ["Quick Stab", "Stone Warden: Crushing Step"]

var _trail_rows: Array[Dictionary]
var _previous_total: int
var _previous_draw_count: int
var _previous_key: Array
var _trail_number: int
var _trail_action: String
var _previous_submit: int
var _previous_raster: int
var _previous_draw: int

func _resume(id: String) -> bool:
	if not await super._resume(id): return false
	var painter: Control = _run_scene.board_view.get("_effects_render_layer")
	var trail: Node2D = painter.get("_strike_trail_layer")
	if is_instance_valid(trail) and trail.get("measure_trail") != null:
		trail.set("measure_trail", true)
	return true

func _capture_fight(id: String, fallback: bool) -> bool:
	if id != TIMING_FIXTURE or fallback: return true
	_trail_rows.clear()
	_previous_total = 0
	_previous_draw_count = 0
	_previous_key.clear()
	_trail_number = 0
	_previous_submit = 0
	_previous_raster = 0
	_previous_draw = 0
	return await super._capture_fight(id, fallback)

func _record_frame() -> void:
	if _evidence == null: return
	# Keep the native clock and renderer. Skip GPU readbacks during timing.
	_evidence.sample(_run_scene, _viewport, true)
	var painter: Control = _run_scene.board_view.get("_effects_render_layer")
	if not is_instance_valid(painter): return
	var totals: Dictionary = painter.get("_render_section_total_usec")
	var total: int = int(totals.get("effect_overlay", 0))
	var elapsed: int = total - _previous_total
	_previous_total = total
	var trail: Node2D = painter.get("_strike_trail_layer")
	if not is_instance_valid(trail): return
	var draws: int = trail.get("draw_count")
	var new_draw: bool = draws != _previous_draw_count
	_previous_draw_count = draws
	var measured: bool = trail.get("measure_trail") == true
	var breakdown: Dictionary
	if measured:
		var submit: int = trail.get("trail_submit_usec")
		var raster: int = trail.get("trail_raster_usec")
		var draw: int = trail.get("trail_draw_usec")
		breakdown = {"submit_usec": submit - _previous_submit, "raster_usec": raster - _previous_raster,
			"draw_usec": draw - _previous_draw}
		breakdown["other_usec"] = maxi(0, elapsed - breakdown["submit_usec"] - breakdown["raster_usec"] - breakdown["draw_usec"])
		_previous_submit = submit
		_previous_raster = raster
		_previous_draw = draw
	if trail.get("_batches").is_empty(): return
	if trail.get("drawn_submission_revision") != trail.get("submission_revision"): return
	var key: Array = _evidence._melee_key
	if key != _previous_key:
		_previous_key = key.duplicate()
		_trail_number += 1
		var shown: Dictionary = _run_scene.board_view.presentation
		var effect: Dictionary = shown.get("strike_trail_effect", shown.get("effect", {}))
		_trail_action = _evidence.hero_action if effect.get("protagonist_melee", false) else _run_scene.action_banner.text
	if _trail_number <= TIMING_ACTIONS.size():
		_trail_rows.append({"frame": _evidence.frame, "strike": _trail_number, "action": _trail_action,
			"effect_overlay_usec": elapsed, "redrawn": new_draw, "breakdown": breakdown})

func _report(id: String, _sample: Evidence) -> bool:
	var first: Dictionary = _summarize(1)
	var second: Dictionary = _summarize(2)
	if first.is_empty() or second.is_empty():
		return _fail("expected rendered Quick Stab and Crushing Step frames in one " + id + " fight")
	var totals := {"fixture": id, "first": first, "second": second, "frames": _trail_rows}
	print("FEL05 EFFECT_OVERLAY " + JSON.stringify(totals))
	print("FEL05 TIMING PAIR PASS fixture=%s first_frames=%d second_frames=%d" % [id, first["frames"], second["frames"]])
	var destination: String = OS.get_environment("FEL03_CAPTURE_DIR")
	if _dry and destination.is_empty(): return true
	var file := FileAccess.open(destination.path_join(id + "-effect-overlay.json"), FileAccess.WRITE)
	if file == null: return _fail("cannot write effect_overlay times for " + id)
	return file.store_string(JSON.stringify(totals, "	"))

func _summarize(strike: int) -> Dictionary:
	var action: String = TIMING_ACTIONS[strike - 1]
	var values := PackedInt32Array()
	var redrawn := PackedInt32Array()
	for row: Dictionary in _trail_rows:
		if row["strike"] != strike: continue
		if row["action"] != action: return {}
		values.append(row["effect_overlay_usec"])
		if row["redrawn"]: redrawn.append(row["effect_overlay_usec"])
	if values.is_empty() or redrawn.is_empty(): return {}
	var first_frame: int = redrawn[0]
	values.sort()
	redrawn.sort()
	return {"action": action, "frames": values.size(), "redrawn_frames": redrawn.size(),
		"first_frame_usec": first_frame, "live_median_usec": values[values.size() / 2],
		"median_usec": redrawn[redrawn.size() / 2], "max_usec": redrawn[-1]}
