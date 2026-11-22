extends SceneTree
## Loads the production entry scene. Timing and pixel readback are separate runs.

const Settings = preload("res://scripts/settings_store.gd")
const ViewportCheck = preload("res://tools/hitch_census/viewport.gd")
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const PARTICLE_SEED: int = 167
const READY_TAIL_FRAMES: int = 12
const FIRST_MENU_FRAMES: int = 8
const MID_FADE_FRAME: int = 12
const WINDOW_SETTLE_FRAMES: int = 8
const CANCELLATION_TIMEOUT_MS: int = 5000
const IDLE_RUN_WATCH := "RunSceneIdlePreload"

class RenderPulse extends Node2D:
	const OFFSCREEN_RECT := Rect2(-2, -2, 1, 1)

	func _draw() -> void:
		draw_rect(OFFSCREEN_RECT, Color.TRANSPARENT)

var _startup: Control
var _menu: Control
var _pulse: RenderPulse
var _telemetry: Node
var _output: String
var _capture: bool
var _reduced: bool
var _native: bool
var _trace: bool
var _started_usec: int
var _previous_usec: int
var _process_usec: int
var _pre_draw_usec: int
var _canvas_count: int
var _unfocused: int
var _locked_before_ready: bool = true
var _ready_semantics: bool
var _phase: String = "black"
var _draw_phase: String
var _draw_alpha: float
var _draw_phase_frame: int
var _phase_times: Dictionary = {}
var _phase_frames: Dictionary = {}
var _frames: Array[Dictionary]
var _pixels: Dictionary = {}

func _initialize() -> void:
	_trace = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"
	_capture = OS.get_cmdline_user_args().has("--capture")
	_reduced = OS.get_cmdline_user_args().has("--reduced-motion")
	_native = DisplayServer.get_name() != "headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if _output.is_empty() or (not _native and (_capture or not OS.get_cmdline_user_args().has("--headless-smoke"))):
		_fail("Use --output and a native renderer, or request --headless-smoke explicitly.")
		return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("Could not create proof directory.")
		return
	var settings := Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = _reduced
	Settings.set_storage_path("user://perf167_settings.json")
	if not Settings.save_settings(settings):
		_fail("Could not save private proof settings.")
		return
	var router := root.get_node("InputRouter")
	router.set_forced_state_for_test("controller", "steam_deck")
	_telemetry = root.get_node("PerformanceTelemetry")
	if _native:
		root.mode = Window.MODE_WINDOWED
		root.borderless = true
		root.size = SIZE
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	_pulse = RenderPulse.new()
	root.add_child(_pulse)
	for frame: int in range(WINDOW_SETTLE_FRAMES):
		_pulse.queue_redraw()
		if _native: await RenderingServer.frame_post_draw
		else: await process_frame
	if _native and not _capture and not DisplayServer.window_is_focused():
		_fail("Startup probe window did not acquire focus.")
		return
	if _capture:
		root.get_node("CursorFeedback").hide()
		node_added.connect(_seed_motes)
	if _native:
		process_frame.connect(_on_process)
		RenderingServer.frame_pre_draw.connect(_pre_draw)
		RenderingServer.frame_post_draw.connect(_post_draw)
	else:
		process_frame.connect(_headless_frame)
	if _trace:
		_telemetry.take_hitch_events()
		_telemetry.take_hitch_phases()
	_canvas_count = _canvas_compilations()
	_started_usec = Time.get_ticks_usec()
	_previous_usec = _started_usec
	var entry := load(str(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene
	_startup = entry.instantiate()
	_startup.phase_changed.connect(_phase_changed)
	_startup.finished.connect(_menu_ready)
	root.add_child(_startup)
	current_scene = _startup
	if OS.get_cmdline_user_args().has("--cancel-during-hold"):
		await _cancel_staged_startup()

func _cancel_staged_startup() -> void:
	var deadline := Time.get_ticks_msec() + CANCELLATION_TIMEOUT_MS
	var staged: Control
	while Time.get_ticks_msec() < deadline:
		staged = _startup.get("_prepared_menu") if is_instance_valid(_startup) else null
		if is_instance_valid(staged) and staged.is_inside_tree(): break
		await process_frame
	if not is_instance_valid(staged) or staged.visible or not root.gui_disable_input or staged.has_node("MusicPlayer"):
		_fail("Expected a hidden, silent staged menu while startup owns input.")
		return
	_startup.queue_free()
	while Time.get_ticks_msec() < deadline:
		if not is_instance_valid(staged) and not root.gui_disable_input and not AssetLoader.has_preparation_drains(root): break
		await process_frame
	if is_instance_valid(staged) or root.gui_disable_input or AssetLoader.has_preparation_drains(root):
		_fail("Cancelling the boot left behind the menu, a prep worker or the input lock.")
		return
	print("PERF167 STARTUP CANCELLATION: PASS (staged menu freed, input restored, workers reclaimed)")
	quit()

func _phase_changed(next: StringName) -> void:
	_phase = str(next)
	_phase_times[_phase] = Time.get_ticks_usec() - _started_usec

func _menu_ready(menu: Control) -> void:
	_menu = menu
	var start := menu.get_node("MenuColumn/StartButton") as Button
	_ready_semantics = current_scene == menu and not root.gui_disable_input and is_equal_approx(menu.modulate.a, 1.0) and start.has_focus()
	# Even a very slow tail samples only startup. The later idle run-scene
	# request can interfere with timing and an immediate probe exit.
	var idle := menu.get_node_or_null(IDLE_RUN_WATCH)
	if idle != null: idle.set_process(false)

func _seed_motes(node: Node) -> void:
	if node.name == &"TitleMotes" and node is CPUParticles2D:
		node.use_fixed_seed = true
		node.seed = PARTICLE_SEED
		node.restart(true)

func _on_process() -> void:
	_process_usec = Time.get_ticks_usec()
	_pulse.queue_redraw()
	if not _capture and (not DisplayServer.window_is_focused() or not DisplayServer.window_can_draw()):
		_unfocused += 1

func _pre_draw() -> void:
	_pre_draw_usec = Time.get_ticks_usec()
	_draw_phase = _phase
	_draw_phase_frame = int(_phase_frames.get(_draw_phase, 0)) + 1
	_phase_frames[_draw_phase] = _draw_phase_frame
	if _phase != "complete":
		_locked_before_ready = _locked_before_ready and root.gui_disable_input
	if _capture and is_instance_valid(_startup):
		_draw_alpha = _startup.seal.modulate.a
		if _phase.begins_with("menu_") and is_instance_valid(_startup.menu):
			_draw_alpha = _startup.menu.modulate.a

func _post_draw() -> void:
	_record_frame(Time.get_ticks_usec())
	if _capture:
		_capture_phase()
	if _draw_phase == "complete" and _draw_phase_frame == READY_TAIL_FRAMES:
		_finish.call_deferred()

func _headless_frame() -> void:
	_pre_draw()
	_record_frame(Time.get_ticks_usec())
	if _draw_phase == "complete" and _draw_phase_frame == READY_TAIL_FRAMES:
		_finish.call_deferred()

func _record_frame(now: int) -> void:
	var next_canvas := _canvas_compilations()
	var row := {
		"phase": _draw_phase, "frame_in_phase": _draw_phase_frame,
		"interval_us": now - _previous_usec,
		"previous_draw_to_process_us": _process_usec - _previous_usec if _process_usec >= _previous_usec else null,
		"process_to_pre_draw_us": _pre_draw_usec - _process_usec if _process_usec >= _previous_usec else null,
		"pre_to_post_draw_us": now - _pre_draw_usec if _native else null,
		"canvas_compilations": next_canvas - _canvas_count,
	}
	_previous_usec = now
	_canvas_count = next_canvas
	if _trace:
		row["loads"] = _telemetry.take_hitch_events()
		row["spans_us"] = _telemetry.take_hitch_phases()
	_frames.append(row)

func _canvas_compilations() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) if _native else 0

func _capture_phase() -> void:
	var name := ""
	var save_png := false
	match _draw_phase:
		"black", "menu_black":
			if _draw_phase_frame == 1: name = _draw_phase
		"hold":
			if _draw_phase_frame == 1:
				name = "seal_opaque"
				save_png = true
		"fade_in", "fade_out":
			name = "seal_%s_%02d" % [_draw_phase, _draw_phase_frame]
			save_png = _draw_phase_frame == MID_FADE_FRAME
		"menu_fade_in":
			if _draw_phase_frame <= FIRST_MENU_FRAMES:
				name = "menu_first_%02d" % _draw_phase_frame
				save_png = _draw_phase_frame == FIRST_MENU_FRAMES
		"complete":
			if _draw_phase_frame == 1:
				name = "menu_ready"
				save_png = true
	if name.is_empty(): return
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != SIZE:
		_fail("Capture backing image must be 1920x1080.")
		return
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	_pixels[name] = {"rgba_sha256": hash.finish().hex_encode(), "alpha": _draw_alpha if _draw_phase != "complete" else 1.0}
	var png_name := "seal_" + _draw_phase if _draw_phase in ["fade_in", "fade_out"] else name
	if save_png and image.save_png(_output.path_join(png_name + ".png")) != OK:
		_fail("Could not save capture " + name)

func _finish() -> void:
	if not _locked_before_ready or not _ready_semantics:
		_fail("Startup GUI lock, current scene, opacity or initial controller focus failed.")
		return
	if _native:
		var viewport := ViewportCheck.validate(ViewportCheck.capture(root), SIZE, UI_SCALE)
		if viewport["status"] != "passed" or _unfocused != 0:
			_fail("Unfocused/undrawable frames %d. Viewport: %s" % [_unfocused, viewport])
			return
	var steam := root.get_node("SteamService")
	var result := {
		"native": _native, "capture_only": _capture, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info()["string"],
		"theme": ProjectSettings.get_setting("gui/theme/custom"), "cpu": OS.get_processor_name(),
		"reduced_motion": _reduced, "stage_usec": _phase_times, "pixels": _pixels, "frames": _frames,
		"steam_init_usec": steam.get_meta(&"startup_steam_init_usec", -1), "steam_active": steam.is_steam_active(),
	}
	var file := FileAccess.open(_output.path_join("startup.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write startup report.")
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print(_output)
	print("PERF167 STARTUP: PASS native=%s capture=%s reduced_motion=%s frames=%d" % [_native, _capture, _reduced, _frames.size()])
	quit()

func _fail(message: String) -> void:
	push_error("PERF167 STARTUP: " + message)
	quit(1)
