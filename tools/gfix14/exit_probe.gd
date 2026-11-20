extends SceneTree
## One-off production scene shutdown census. Run in an isolated task home.

const Shutdown = preload("res://scripts/application_shutdown.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const FIXTURE_SEED: int = 82271
const DEADLINE_MS: int = 60000
var _close_started_usec: int
var _close_started_frame: int
var _close_scenario: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if not args.is_empty() else "title"
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	if scenario in ["title", "title-direct", "idle-close", "idle-remove", "idle-direct"]:
		change_scene_to_file("res://scenes/main_menu.tscn")
		await scene_changed
		if scenario == "title-direct":
			var music := current_scene.get_node_or_null("MusicPlayer") as AudioStreamPlayer
			if music == null or not music.has_stream_playback():
				_fail("title music never started")
				return
			print("GFIX14: quitting directly with title music active")
			quit()
			return
		if scenario != "title":
			while SceneLoads.status_for(self, SceneLoads.RUN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				if Time.get_ticks_msec() >= deadline:
					_fail("title never requested the run scene")
					return
				await process_frame
			var status := ResourceLoader.load_threaded_get_status(SceneLoads.RUN_SCENE_PATH)
			if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_fail("request already settled, status=%d" % status)
				return
			print("GFIX14: %s entered with threaded load in progress" % scenario)
			if scenario == "idle-remove":
				var pending: Dictionary = root.get_meta(SceneLoads.REQUESTS_META)
				var request: RefCounted = pending[SceneLoads.RUN_SCENE_PATH]
				var removal_started_usec := Time.get_ticks_usec()
				current_scene.free()
				var removal_elapsed_usec := Time.get_ticks_usec() - removal_started_usec
				if not is_same(pending.get(SceneLoads.RUN_SCENE_PATH), request):
					_fail("title removal consumed the root-owned idle request")
					return
				print("GFIX14: title removal retained the same idle request, elapsed_ms=%.3f" % (removal_elapsed_usec / 1000.0))
			elif scenario == "idle-direct":
				quit()
				return
			else:
				_close_window(scenario)
				return
	elif scenario in ["short", "fight"]:
		if scenario == "fight":
			var saved := RunEngine.new().create_debug_boss_run(Progression.default_data())
			saved["seed"] = FIXTURE_SEED
			saved["debug_boss_run"] = false
			if not Progression.save_run_state(saved):
				_fail("could not save the combat fixture")
				return
			root.set_meta("labyrinth_resume_saved_run", true)
		change_scene_to_file(SceneLoads.RUN_SCENE_PATH)
		await scene_changed
		var state: Dictionary = current_scene.get("_run_state")
		if state.is_empty() or (scenario == "fight" and state.get("combat_state", {}).is_empty()):
			_fail("unexpected run state for %s" % scenario)
			return
		print("GFIX14: %s run initialized, mode=%s" % [scenario, state.get("mode")])
	elif scenario == "startup-fade-direct":
		change_scene_to_file("res://scenes/startup.tscn")
		await scene_changed
		while current_scene.get("phase") != &"fade_in":
			if Time.get_ticks_msec() >= deadline:
				_fail("startup never reached the seal fade")
				return
			await process_frame
		print("GFIX14: quitting during the startup seal fade")
		quit()
		return
	else:
		_fail("unknown scenario %s" % scenario)
		return
	await process_frame
	if scenario == "title":
		if SceneLoads.has_requested_run_scene(self):
			_fail("ordinary close timing requires no pending preload")
			return
		_close_window(scenario)
		return
	print("GFIX14: %s requesting close" % scenario)
	Shutdown.request(self, "gfix14_probe")

func _close_window(scenario: String) -> void:
	root.tree_exiting.connect(_report_close_time, CONNECT_ONE_SHOT)
	print("GFIX14: %s requesting close" % scenario)
	_close_scenario = scenario
	_close_started_frame = Engine.get_process_frames()
	_close_started_usec = Time.get_ticks_usec()
	root.close_requested.emit()

func _report_close_time() -> void:
	var elapsed_ms := (Time.get_ticks_usec() - _close_started_usec) / 1000.0
	var frames := Engine.get_process_frames() - _close_started_frame
	print("GFIX14 CLOSE: scenario=%s elapsed_ms=%.3f frames=%d" % [_close_scenario, elapsed_ms, frames])

func _fail(message: String) -> void:
	push_error("GFIX14: " + message)
	quit(1)
