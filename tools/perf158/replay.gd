extends "res://tools/hitch_census/driver.gd"
## Record the first New Run and first pre-battle travel on the census demo route.

const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const REPLAY_SEED: int = 7
const START_ROOM := Vector2i.ZERO
const FIRST_ENCOUNTER := Vector2i(1, -1)
const FIRST_ENCOUNTER_NAME: String = "Bleak Grotto"
const WATCHDOG_SECONDS: float = 180.0
const FOCUS_ACQUIRE_USEC: int = 3000000

class PressSession extends "res://tools/hitch_census/demo/session.gd":
	func log_event(kind: String, data: Dictionary = {}) -> void:
		super.log_event(kind, data)
		if kind == "input" and data.get("button") == JOY_BUTTON_A and bool(data.get("pressed")):
			host.note_press()
		elif kind == "deck_configuration" and host.proof_viewport:
			host.apply_proof_viewport.call_deferred()

var capture_pixels: bool = false
var proof_viewport: bool = false
var capture_geometry_smoke: bool = false
var press: Dictionary
var windows: Dictionary = {}
var first_room: Vector2i
var travel_press: Dictionary
var room_generation: int = -1
var pending: String
var last_loading_wait: String
var loading_waits: Array[Dictionary]

func _initialize() -> void:
	Runtime.apply_from_environment()
	driver_name = "demo"
	run_seed = REPLAY_SEED
	seconds = WATCHDOG_SECONDS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg == "--headless-smoke": headless_smoke = true
		elif arg == "--capture": capture_pixels = true
		elif arg == "--capture-geometry-smoke": capture_geometry_smoke = true
		else:
			push_error("PERF158 REPLAY: unknown argument " + arg)
			quit(2)
			return
	_start.call_deferred()

func _start() -> void:
	var native: bool = DisplayServer.get_name() != "headless"
	if output.is_empty() or native == headless_smoke or (capture_pixels and not native) or (capture_geometry_smoke and native):
		push_error("PERF158 REPLAY: supply --output; headless requires --headless-smoke")
		quit(2)
		return
	proof_viewport = capture_pixels or capture_geometry_smoke
	DirAccess.make_dir_recursive_absolute(output)
	Store.set_storage_path(output.path_join("progression.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	Recent.set_storage_path(output.path_join("recent.json"))
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"combat_speed": Settings.COMBAT_NORMAL, "ui_scale": ViewportCheck.TARGET_UI_SCALE,
		"display_mode": "windowed", "edge_smoothing": "off"}, true)
	Settings.save_settings(settings)
	Store.save_data(Store.default_data())
	root.mode = Window.MODE_WINDOWED
	root.size = ViewportCheck.TARGET_SIZE
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = ViewportCheck.TARGET_UI_SCALE
	root.set_meta("labyrinth_performance_probe_seed", run_seed)
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	OS.low_processor_usage_mode = false
	if native and not capture_pixels: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	decisions = FileAccess.open(output.path_join("decisions.jsonl"), FileAccess.WRITE)
	trace = Trace.new()
	root.add_child(trace)
	started_us = Time.get_ticks_usec()
	if native:
		# Ignore the platform's initial focus acquisition, then invalidate the
		# entire take on any later focus loss, including between draw samples.
		while not DisplayServer.window_is_focused():
			if Time.get_ticks_usec() - started_us >= FOCUS_ACQUIRE_USEC:
				finish("focus_lost")
				return
			await process_frame
		root.focus_exited.connect(_focus_lost)
	trace.begin(output.path_join("frames.jsonl"), run_seed)
	started_us = Time.get_ticks_usec()
	if native: await RenderingServer.frame_post_draw
	startup_viewport = ViewportCheck.capture(root)
	if not proof_viewport:
		startup_viewport.merge(ViewportCheck.validate(startup_viewport))
		if not str(startup_viewport["failure"]).is_empty():
			errors.append(str(startup_viewport["failure"]))
			finish("viewport_rejected")
			return
	if native:
		RenderingServer.frame_pre_draw.connect(_observe)
		RenderingServer.frame_post_draw.connect(_presented)
	else:
		process_frame.connect(func() -> void:
			RenderingServer.frame_post_draw.emit()
			_observe()
			_presented()
		)
	var session := PressSession.new()
	session.host = self
	root.add_child(session)
	session.run()

func _focus_lost() -> void:
	if not finished: finish.call_deferred("focus_lost")

func apply_proof_viewport() -> void:
	# The controller route verifies Deck defaults at title before the
	# capture-specific viewport settings take effect.
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	# macOS clamps the physical window to its work area. Keep a fixed-size
	# root render target and letterbox its presentation in the host window.
	root.content_scale_size = PROOF_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

func note_press() -> void:
	press = _boundary()
	if is_instance_valid(current_scene): press["scene"] = current_scene.scene_file_path.get_file()

func _boundary() -> Dictionary:
	return {"frame": Engine.get_process_frames(), "usec": Time.get_ticks_usec(), "decision": trace.decision}

func _observe() -> void:
	if finished or not is_instance_valid(current_scene): return
	var run: Node = current_scene
	if not run.has_method("initial_presentation_is_ready"):
		var transition: Node = root.get_node_or_null("MenuRunTransition")
		if transition != null and not windows.has("run_start") and press.get("scene") == "main_menu.tscn":
			windows["run_start"] = {"start": press}
		if transition != null and "hitch_wait" in transition and not capture_pixels:
			var wait: String = transition.hitch_wait
			if wait != last_loading_wait:
				last_loading_wait = wait
				var sample := _boundary()
				sample["stage"] = wait
				loading_waits.append(sample)
		return
	if root.gui_disable_input or not run.initial_presentation_is_ready(): return
	var state: Dictionary = run._run_state
	var coord: Vector2i = state.get("current_room", Vector2i.ZERO)
	if not windows.has("run_start"): return
	if not windows["run_start"].has("end"):
		if coord != START_ROOM or state.get("mode") != "room":
			errors.append("New Run did not reveal the seed-7 threshold")
			finish.call_deferred("unexpected_start_room")
			return
		first_room = coord
		pending = "run_start"
		return
	var generation: int = run._encounter_preparation_generation
	if generation != room_generation:
		room_generation = generation
		travel_press = press
	if coord != first_room and state.get("mode") == "pre_battle" and run._pre_battle_scrim.is_visible_in_tree():
		if travel_press.get("scene") != "run_scene.tscn":
			errors.append("First pre-battle had no controller A press")
			finish.call_deferred("controller_press_missing")
			return
		windows["room_entry"] = {"start": travel_press}
		pending = "room_entry"

func _presented() -> void:
	if finished or pending.is_empty(): return
	var run: Node = current_scene
	var state: Dictionary = run._run_state
	var receipt: Dictionary = windows[pending]
	receipt["end"] = _boundary()
	receipt["room"] = str(state.get("current_room"))
	receipt["mode"] = str(state.get("mode"))
	if pending == "run_start": receipt["loading_waits"] = loading_waits
	if pending == "room_entry":
		receipt["destination"] = str(run._pre_battle_destination)
		receipt["preview"] = str(run._pre_battle_preview_run_state.get("combat_state", {}).get("room_name", ""))
		if state.get("current_room") != FIRST_ENCOUNTER or run._pre_battle_destination != FIRST_ENCOUNTER or receipt["preview"] != FIRST_ENCOUNTER_NAME:
			errors.append("Room entry did not reveal the seed-7 Bleak Grotto preview")
	if proof_viewport:
		var logical_size: Vector2 = root.get_visible_rect().size
		receipt["logical_size"] = str(logical_size)
		if not logical_size.is_equal_approx(Vector2(PROOF_SIZE)) or not is_equal_approx(root.content_scale_factor, PROOF_UI_SCALE):
			errors.append("Proof viewport has logical size %s at scale %.2f" % [logical_size, root.content_scale_factor])
	if capture_pixels and errors.is_empty():
		var backing: Image = root.get_texture().get_image()
		var capture_path: String = output.path_join(pending + ".png")
		if backing == null or backing.get_size() != PROOF_SIZE:
			var backing_size: Vector2i = backing.get_size() if backing != null else Vector2i.ZERO
			errors.append("Expected 1920x1080 backing pixels, got %s in window %s" % [backing_size, root.size])
		elif backing.save_png(capture_path) != OK:
			errors.append("Could not write " + capture_path)
		else:
			# visual_probe_runner discovers images from their absolute paths.
			print(capture_path)
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(backing.get_data())
			receipt["pixel_sha256"] = hash.finish().hex_encode()
	var done: bool = pending == "room_entry" or not errors.is_empty()
	pending = ""
	if done:
		FileAccess.open(output.path_join("windows.json"), FileAccess.WRITE).store_string(JSON.stringify(windows, "\t"))
		print("PERF158 REPLAY: %s run_start=%s room_entry=%s" % ["PASS" if errors.is_empty() else "FAIL", windows["run_start"]["room"], windows.get("room_entry", {}).get("room", "")])
		finish.call_deferred("first_pre_battle")
