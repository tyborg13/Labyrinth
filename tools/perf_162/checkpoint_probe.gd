extends SceneTree
## Replays the review's stalls against the live release boundary.

const Fixtures = preload("confirm_fixtures.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const Disk = preload("res://scripts/persistence_disk_worker.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const CHECKPOINT_STALL_MSEC := 500
const DISK_TAIL_STALL_MSEC := 1500
const READY_TIMEOUT_USEC := 10_000_000

var _scene: Node
var _case: String
var _fixture_dir: String

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): _case = arg.trim_prefix("--case=")
		if arg.begins_with("--output="): _fixture_dir = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	var cases: Dictionary = {"embrace": "campfire_embrace", "embrace-in-flight": "campfire_embrace",
		"trophy-close": "treasure_claim", "history-kill": "event_choice", "event-start": "event_choice"}
	if not cases.has(_case) or _fixture_dir.is_empty() or DisplayServer.get_name() != "headless":
		_fail("Use headless with --case and a fresh --output directory")
		return
	if DirAccess.make_dir_recursive_absolute(_fixture_dir) != OK:
		_fail("Could not create fixture directory")
		return
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	Store.set_storage_path(_fixture_dir.path_join("profile.json"))
	Store.set_run_storage_path(_fixture_dir.path_join("current_run.save"))
	Recent.set_storage_path(_fixture_dir.path_join("recent_events.json"))
	Analytics.set_storage_dir(_fixture_dir.path_join("analytics"))
	var state: Dictionary = Fixtures.state_for(cases[_case], 0)
	var relic: String = ""
	if _case == "trophy-close":
		relic = state["pending_relics"].front()
		state["guardian_reward"] = {"guardian_id": "review_guardian", "relic_id": relic,
			"room": state["current_room"], "claimed": false}
	var profile: Dictionary = state["progression"]
	if _case.begins_with("embrace"): profile = Store.set_embers(profile, 0)
	if not Store.save_data(profile) or not Store.save_run_state(state):
		_fail("Could not write the original fixture")
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline: int = Time.get_ticks_usec() + READY_TIMEOUT_USEC
	while not _scene.initial_presentation_is_ready():
		if Time.get_ticks_usec() >= deadline:
			_fail("The fixture did not install")
			return
		await process_frame
	Store._run_writer.probe_delay_msec = CHECKPOINT_STALL_MSEC
	match _case:
		"embrace", "embrace-in-flight":
			if _case == "embrace-in-flight":
				# An independent observer can kill during the inherited two-file
				# transaction even while the game's main thread waits on storage.
				var completed_before: int = Store.completed_run_results(Store.load_data()).size()
				WorkerThreadPool.add_task(_kill_after_profile_banks.bind(completed_before), true, "Observe Embrace profile")
			_scene._on_campfire_embrace_pressed(true)
			var bank: int = int(Store.load_data()["embers"])
			var resumable: bool = Store.has_saved_run()
			if _case == "embrace-in-flight" or bank != Fixtures.WALLET or resumable:
				_fail("Embrace did not reach the expected terminal boundary")
				return
			print("PERF162 EMBRACE bank=", bank, " resumable=", resumable)
			_kill()
		"trophy-close":
			_scene._treasure_reveal_active = false
			_scene._claim_relic_with_deferred(relic, "", Rect2())
			print("PERF162 TROPHY closing after confirm relic=", relic)
			Shutdown.request(self, "window_close")
		"history-kill":
			_scene._on_section_map_event("embers")
			Disk.submit(func() -> bool:
				OS.delay_msec(DISK_TAIL_STALL_MSEC)
				return true)
			var page: String = Store._inspect_run_file(Store._run_storage_path).get("state", {}).get("event_state", {}).get("page", "")
			var recent: Array[String] = Recent.load_recent_events()
			if page != "result" or not recent.has(Fixtures.EVENT_ID):
				_fail("The event checkpoint and rotation history must exist before control returns")
				return
			print("PERF162 HISTORY page=", page, " recent=", recent)
			_kill()
		"event-start":
			_scene._on_section_map_event("embers")
			var menu := InputEventAction.new()
			menu.action = &"controller_menu"
			menu.pressed = true
			root.push_input(menu, true)
			if not _scene._menu_scrim.visible or _scene._event_view.page != "result":
				_fail("Queued Start must open pause after the event result")
				return
			print("PERF162 EVENT START menu_open=true page=result")
			quit()

func _kill_after_profile_banks(completed_before: int) -> void:
	var deadline: int = Time.get_ticks_usec() + READY_TIMEOUT_USEC
	while Time.get_ticks_usec() < deadline:
		var bank: Dictionary = Store.load_data()
		if int(bank["embers"]) == Fixtures.WALLET and Store.completed_run_results(bank).size() > completed_before:
			var held: Dictionary = Store._inspect_run_file(Store._run_storage_path).get("state", {})
			print("PERF162 EMBRACE IN FLIGHT bank=", bank["embers"], " checkpoint=", held.get("mode"), " held=", held.get("held_embers"))
			_kill()
			return
		OS.delay_msec(1)

func _kill() -> void:
	if OS.kill(OS.get_process_id()) != OK:
		push_error("Could not terminate the isolated probe")

func _fail(detail: String) -> void:
	push_error(detail)
	print("TEST RESULT: FAIL — " + detail)
	quit(1)
