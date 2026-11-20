extends SceneTree
## Hanged Knight checkpoint and immediate close timing from qa-115's exits.gd.

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Music = preload("res://scripts/music_library.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const RUN := "res://scenes/run_scene.tscn"
const SEED: int = 82271
const EVENT_ROOM := Vector2i(3, 0)
const EVENT_ID: String = "hanged_knight"
const DEADLINE_MSEC: int = 25000
const DESKTOP := Vector2i(1920, 1080)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var keep_open: bool = OS.get_cmdline_user_args().has("--keep-open")
	root.size = DESKTOP
	root.content_scale_size = DESKTOP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	if DisplayServer.get_name() == "headless":
		process_frame.connect(_present_headless_frame)
	var fixtures: SceneTree = load("res://tools/hitch_census/fixtures.gd").new()
	var state: Dictionary = fixtures.make("event", SEED, {})
	fixtures.free()
	if state.get("mode") != "event" or state.get("current_room") != EVENT_ROOM or state.get("event_state", {}).get("event_id") != EVENT_ID:
		_fail("Unexpected event fixture")
		return
	if not Store.save_run_state(state) or not Store.save_data(state["progression"]):
		_fail("Could not save event fixture")
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	change_scene_to_file(RUN)
	await scene_changed
	var deadline: int = Time.get_ticks_msec() + DEADLINE_MSEC
	while not _ready() and Time.get_ticks_msec() < deadline: await process_frame
	if not _ready():
		_fail("RunScene did not install the event")
		return
	print("GFIX16 EVENT FIXTURE: seed=%d room=%s event=%s" % [SEED, EVENT_ROOM, EVENT_ID])
	if keep_open:
		while not _event_music_playing() and Time.get_ticks_msec() < deadline: await process_frame
		if not _event_music_playing():
			_fail("The Turning Key did not play with the event open")
			return
		print("GFIX16 EVENT MUSIC: PASS (The Turning Key playing)")
	else:
		if not current_scene.get("_music_context_refresh_queued") or _event_music_playing():
			_fail("Immediate close requires a queued refresh before event playback")
			return
		print("GFIX16 EVENT MUSIC REFRESH: pending before close")
	print("GFIX16 EVENT CLOSE REQUEST")
	root.tree_exiting.connect(_report_exit, CONNECT_ONE_SHOT)
	root.close_requested.emit()

func _ready() -> bool:
	return current_scene._run_state.get("mode") == "event" and current_scene.has_installed_run() and not current_scene._animation_lock

func _event_music_playing() -> bool:
	var player: AudioStreamPlayer = current_scene.get("_music_player")
	return current_scene.get("_active_music_id") == Music.TURNING_KEY_TRACK_ID and player != null and player.playing and player.has_stream_playback()

func _present_headless_frame() -> void:
	RenderingServer.frame_post_draw.emit()

func _report_exit() -> void:
	print("GFIX16 EVENT CLOSE COMPLETE")

func _fail(message: String) -> void:
	push_error("GFIX16 EVENT: " + message)
	Shutdown.request(self, "gfix16_event_probe", 1)
