extends SceneTree
## fel-09 production Continue and Pass witness. Only the native branch reads pixels.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Probe = preload("res://tools/fel09/scene_probe.gd")
const Trace = preload("res://tools/fel09/timeline.gd")
const FrameBeats = preload("res://tools/fel09/frame_beats.gd")
const FrameSink = preload("res://tools/steam_trailer_frame_sink.gd")
const Report = preload("res://tools/fel09/witness_report.gd")
const FIXTURE_ROOT := "res://tools/fel01/fixtures"
const FIXTURE_COUNT := 12
const READY_TIMEOUT_MS := 15000
const TURN_TIMEOUT_MS := 90000
const IDLE_SETTLE_MS := 2000
const IDLE_SAMPLE_MS := 1000

var _native: bool
var _capture_path: String
var _viewport: SubViewport
var _collector: Node
var _scene: Control
var _trace
var _beats
var _sink
var _frames: Array[Dictionary]
var _baseline_image: Image
var _variant: String


func _initialize() -> void:
	Runtime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	if not _native:
		process_frame.connect(_headless_boundary.call_deferred)
	call_deferred("_run")


func _headless_boundary() -> void:
	RenderingServer.frame_pre_draw.emit()
	RenderingServer.frame_post_draw.emit()


func _run() -> void:
	_capture_path = OS.get_environment("FEL09_CAPTURE_DIR")
	_variant = OS.get_environment("FEL15_VARIANT")
	if _variant not in ["", "reduced", "hurry"]:
		_fail("unknown FEL15_VARIANT: " + _variant)
		return
	if _native and (_capture_path.is_empty() or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("use native.sh for the native run")
		return
	if not Engine.get_write_movie_path().is_empty():
		root.size = Checkpoint.VIEWPORT_SIZE
		root.content_scale_size = Checkpoint.VIEWPORT_SIZE
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = _variant == "reduced"
	Settings.set_storage_path("user://fel09_settings.json")
	if not Settings.save_settings(settings) or Settings.combat_speed_scale(settings) != 1.0:
		_fail("cannot establish witness settings at 100% UI scale")
		return

	var fixture_ids: PackedStringArray = DirAccess.get_directories_at(FIXTURE_ROOT)
	fixture_ids.sort()
	if fixture_ids.size() != FIXTURE_COUNT:
		_fail("expected %d source fixtures" % FIXTURE_COUNT)
		return
	var single: String = OS.get_environment("FEL09_FIXTURE")
	if _native or not single.is_empty():
		if not fixture_ids.has(single):
			_fail("native run requires a valid fixture ID")
			return
		fixture_ids = PackedStringArray([single])
	var results: Array[Dictionary]
	var turns: int = 0
	var actions: int = 0
	var stacked_frames: int = 0
	for id: String in fixture_ids:
		var row: Dictionary = await _fixture(id)
		if row.is_empty():
			quit(1)
			return
		results.append(row)
		turns += int(row["input_accepted"])
		actions += int(row["action_count"])
		stacked_frames += int(row["stacked_number_frames"])
	var document: Dictionary = {
		"mode": "native" if _native else "headless",
		"settings": {"ui_scale": settings["ui_scale"], "reduced_motion": settings["reduced_motion"],
			"combat_speed": settings["combat_speed"], "cel_look": OS.get_environment("LABYRINTH_CEL_LOOK")},
		"engine": Engine.get_version_info()["string"],
		"variant": _variant,
		"fixtures": results,
	}
	if _native:
		if not Report.write_json(_capture_path.path_join("timeline.json"), document):
			_fail("could not write native timeline")
			return
	elif not _capture_path.is_empty():
		if not Report.write_json(_capture_path.path_join("timeline.json"), document):
			_fail("could not write headless timeline")
			return
	elif OS.get_environment("FEL09_DRY_RUN") != "1":
		if not Report.write_witness(document):
			_fail("could not write census.json or census.md")
			return
	print("FEL09 %s PASS fixtures=%d turns=%d actions=%d" % ["NATIVE" if _native else "PACING", results.size(), turns, actions])
	print("FEL15 STACKED NUMBERS frames=%d" % stacked_frames)
	quit()


func _fixture(id: String) -> Dictionary:
	var source: String = FIXTURE_ROOT.path_join(id)
	var staged: String = ProjectSettings.globalize_path("user://fel09").path_join(id)
	if not Checkpoint.stage(source, staged):
		return _fail(id + " could not stage save and progression")
	_trace = Trace.new()
	_beats = FrameBeats.new()
	_beats.trace = _trace
	_frames = TypedArrays.dictionaries([])
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	# Show the native target without forwarding OS pointer events into the fixture.
	var canvas := TextureRect.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collector = canvas
	root.add_child(canvas)
	canvas.add_child(_viewport)
	canvas.texture = _viewport.get_texture()
	root.set_meta("labyrinth_resume_saved_run", true)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_scene = packed.instantiate() as Control
	_scene.get("_combat_pacing").free()
	_scene.set_script(Probe)
	_scene.census = _trace
	_viewport.add_child(_scene)

	var timeout: int = Time.get_ticks_msec() + READY_TIMEOUT_MS
	var pass_button: Button
	while true:
		await RenderingServer.frame_post_draw
		pass_button = _scene.find_child("PassPreviewChip", true, false) as Button
		if _scene.can_pass() and is_instance_valid(pass_button) and pass_button.is_visible_in_tree() and not pass_button.disabled:
			break
		if Time.get_ticks_msec() >= timeout:
			return _fail(id + " production Continue never offered Pass")
	var differences: Dictionary = Checkpoint.compare(_scene, source)
	if not differences.is_empty():
		return _fail(id + " Continue witness differs in " + ", ".join(differences.keys()))
	print("FEL09 CONTINUE PASS %s" % id)

	if _native:
		_sink = FrameSink.new()
		if _sink.start(_capture_path.path_join("rgb")) != OK:
			return _fail(id + " could not start frame spool")
		if not _capture_frame(0.0, false, true):
			_sink.finish()
			return _fail(id + " could not capture baseline")
	_trace.origin_usec = Time.get_ticks_usec()
	_beats.sample(_scene)
	RenderingServer.frame_pre_draw.connect(_sample_frame)
	_trace.mark("Pass pressed", "retained_pass_preview.gd:48", {}, 0.0)
	var movie_start: int = Engine.get_frames_drawn()
	pass_button.pressed.emit()
	if not _scene._animation_lock:
		return _stop_fixture(id + " did not enter the enemy-turn input lock")
	if _variant == "hurry":
		_hurry(true)
		if (_scene._combat_pacing.get("_hurry_inputs") as Dictionary).is_empty():
			return _stop_fixture(id + " did not register held Space on the production input path")

	var accepted: bool = false
	var endpoint: float = 0.0
	while true:
		await RenderingServer.frame_post_draw
		endpoint = _trace.now_ms()
		accepted = _scene.accepts_hero_input()
		if _native and not _capture_frame(endpoint, _beats.busy):
			return _stop_fixture(id + " frame spool failed, see queue and disk limits")
		if accepted or _scene.round_finished: break
		if endpoint >= TURN_TIMEOUT_MS:
			return _stop_fixture(id + " did not finish the production round")

	RenderingServer.frame_pre_draw.disconnect(_sample_frame)
	var movie_end: int = Engine.get_frames_drawn()
	if _variant == "hurry": _hurry(false)
	_trace.end_action(_trace.step)
	_trace.step = -1
	_trace.actor = ""
	var witness: String = ""
	var outcome: String = str(_scene._run_state.get("mode", ""))
	var final_state: String = var_to_str(Checkpoint.snapshot(_scene))
	if accepted:
		_trace.mark("hero input accepted", "enemy_round_handoff.gd:114", {}, endpoint)
		witness = _scene.witness_hero_input()
		if witness.is_empty():
			return _stop_fixture(id + " unlocked without accepting a move or card selection")
	elif outcome == "combat":
		return _stop_fixture(id + " round finished in combat without returning input")
	else:
		_trace.mark("terminal outcome", "run_scene.gd:24435", {"mode": outcome}, endpoint)
	_trace.finish(endpoint)
	_trace.measure_intervals()
	var spool: Dictionary = _sink.finish() if _native else {}
	_sink = null
	if _native and (spool["written_frames"] != _frames.size() or not str(spool["failure"]).is_empty()):
		return _fail(id + " spool incomplete: " + str(spool))
	if _native:
		var image_path: String = _capture_path.path_join("continue.png")
		if _baseline_image.save_png(image_path) != OK:
			return _fail(id + " could not write baseline PNG")
		_baseline_image = null
		print(image_path)
	var count: int = 0
	for step: Dictionary in _trace.steps:
		count += int(step["action"])
	var result: Dictionary = {
		"fixture": id, "turn_ms": endpoint, "input_accepted": accepted,
		"input_witness": witness, "outcome": outcome, "action_count": count,
		"steps": _trace.steps, "timeline": _trace.events,
		"final_state": final_state, "stacked_number_frames": _beats.stacked_number_frames,
	}
	if _native:
		result["frames"] = _frames
		result["spool"] = spool
		if not Engine.get_write_movie_path().is_empty():
			result["movie_frames"] = [movie_start, movie_end]
		_trace.origin_usec = 0
		if accepted:
			var idle: Dictionary = await _capture_idle_control()
			if idle.is_empty(): return _fail(id + " idle control could not capture a settled hero board")
			result["idle_control"] = idle
	print("FEL09 TURN %s input=%s actions=%d ms=%.1f" % [id, witness if accepted else outcome, count, endpoint])
	# Give speculative hand-off preparation its cancellation boundary after
	# the measurement. Those coroutines check their ownership after a draw.
	_trace.origin_usec = 0
	await RenderingServer.frame_post_draw
	_collector.queue_free()
	await RenderingServer.frame_post_draw
	return result


func _hurry(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = pressed
	_viewport.push_input(event)


func _capture_idle_control() -> Dictionary:
	# Independent from the measured turn. Put the selection witness back at
	# rest using its production cancellation path and let entrance UI finish.
	if _scene._player_movement_selected: _scene._cancel_player_movement_selection()
	if _scene._selected_card_index >= 0: _scene._cancel_card_selection()
	var settle: int = Time.get_ticks_msec() + IDLE_SETTLE_MS
	var timeout: int = settle + READY_TIMEOUT_MS
	while Time.get_ticks_msec() < settle or _scene._turn_banner.visible or _scene._turn_order_animating:
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() >= timeout: return {}
	if not _scene.accepts_hero_input(): return {}
	_sink = FrameSink.new()
	if _sink.start(_capture_path.path_join("idle-rgb")) != OK:
		_sink = null
		return {}
	_frames = TypedArrays.dictionaries([])
	var started: int = Time.get_ticks_usec()
	var elapsed: float = 0.0
	var captured: bool = false
	while true:
		captured = _capture_frame(elapsed, false)
		if not captured or elapsed >= IDLE_SAMPLE_MS: break
		await RenderingServer.frame_post_draw
		elapsed = (Time.get_ticks_usec() - started) / 1000.0
	var spool: Dictionary = _sink.finish()
	_sink = null
	if not captured or not str(spool["failure"]).is_empty() or spool["written_frames"] != _frames.size():
		return {}
	return {"frames": _frames, "spool": spool}


func _sample_frame() -> void:
	_beats.sample(_scene)


func _capture_frame(ms: float, foreground_busy: bool, baseline: bool = false) -> bool:
	var start: int = Time.get_ticks_usec()
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != Checkpoint.VIEWPORT_SIZE: return false
	var index: int = _frames.size()
	if not _sink.append(index, image): return false
	_frames.append({
		"index": index, "ms": ms, "foreground_busy": foreground_busy,
		"readback_ms": (Time.get_ticks_usec() - start) / 1000.0,
	})
	if baseline: _baseline_image = image
	return true


func _stop_fixture(message: String) -> Dictionary:
	if RenderingServer.frame_pre_draw.is_connected(_sample_frame):
		RenderingServer.frame_pre_draw.disconnect(_sample_frame)
	if _sink != null:
		_sink.finish()
		_sink = null
	return _fail(message)


func _fail(message: String) -> Dictionary:
	printerr("FEL09 PACING FAIL " + message)
	quit(1)
	return {}
