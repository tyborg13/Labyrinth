extends SceneTree
## Separate fixture and relaunch processes for terminal, read and quit proof.

const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SEED := 83
const BACKUP_SEED := 144
const HEIRLOOM := "undertaker_plate"
const VIEWPORT := Vector2i(1920, 1080)
const FRAME_LIMIT := 120
const PUMP_FRAMES := 10
const LATE_SAMPLE_USEC := 7_000_000
const MAX_FRAME_GAP_USEC := 1_000_000
const VISUAL_STALL_MSEC := 1500
const SETUP_TIMEOUT_MSEC := 30000

var _case: String
var _mode: String
var _output: String
var _save: String
var _capture := false
var _frames := 0
var _requested_usec := 0
var _last_frame_usec := 0
var _max_frame_gap := 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): _case = argument.trim_prefix("--case=")
		elif argument.begins_with("--mode="): _mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		elif argument == "--capture": _capture = true
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = FRAME_LIMIT
	_save = _output.path_join("current_run.save")
	Store.set_run_storage_path(_save)
	Store.set_storage_path(_output.path_join("progression.json"))
	Settings.set_storage_path("user://perf147-settings.json")
	var settings := Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": true}, true)
	if not Settings.save_settings(settings):
		_fail("could not write proof settings")
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEWPORT
	match _case:
		"prepare": _prepare()
		"relaunch": await _relaunch()
		"clear": _clear()
		"read-failure": _read_failure()
		"save-and-quit", "window-close", "steam-shutdown", "sync-barrier": await _stall_quit()
		_: _fail("unknown case " + _case)

func _prepare() -> void:
	var profile := Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var old := engine.create_new_run(BACKUP_SEED, profile)
	var state := engine.create_new_run(SEED, profile)
	var receipt: String = "room" if _mode.is_empty() else _mode
	state["mode"] = receipt.get_slice("-", 0)
	if state["mode"] in ["victory", "defeat"]:
		state["game_over"] = true
		if receipt.ends_with("-pending") or receipt.ends_with("-chosen"):
			state["equipped_equipment"]["armor"] = HEIRLOOM
			state["heirloom_end"] = {"item": HEIRLOOM, "done": receipt.ends_with("-chosen")}
	if not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		_fail("could not prepare live checkpoint")
		return
	var backup := FileAccess.open(_save + ".backup", FileAccess.WRITE)
	if backup == null or not backup.store_var(old):
		_fail("could not prepare the stale backup")
		return
	backup.close()
	print("PERF147 PREPARED mode=", receipt)
	quit()

func _relaunch() -> void:
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	var checkpoint: Dictionary = Store.read_resumable_checkpoint()
	var seed: int = checkpoint.get("state", {}).get("seed", 0)
	var enabled: bool = not menu.continue_button.disabled
	print("PERF147 RELAUNCH mode=", _mode, " continue=", enabled, " seed=", seed,
		" saved_mode=", checkpoint.get("state", {}).get("mode", ""))
	if _capture and not await _capture_frame("terminal-title.png"): return
	var expected := _mode == "room" or _mode.ends_with("-pending")
	quit(0 if enabled == expected and seed == (SEED if expected else 0) else 1)

func _clear() -> void:
	var backup := _save + ".backup"
	var live_hash := FileAccess.get_sha256(_save)
	var backup_hash := FileAccess.get_sha256(backup)
	# Call dynamically so the same probe runs against the original void API.
	var store: Script = Store
	var cleared: Variant = store.call("clear_saved_run")
	var live_unchanged := FileAccess.file_exists(_save) and FileAccess.get_sha256(_save) == live_hash
	var backup_unchanged := FileAccess.file_exists(backup) and FileAccess.get_sha256(backup) == backup_hash
	print("PERF147 CLEAR reported_failure=", cleared == false, " live_unchanged=", live_unchanged, " backup_unchanged=", backup_unchanged)
	quit(0 if cleared == false and live_unchanged and backup_unchanged else 1)

func _read_failure() -> void:
	var live_hash := FileAccess.get_sha256(_save)
	var backup := _save + ".backup"
	var backup_hash := FileAccess.get_sha256(backup)
	var inspection := Store.read_resumable_checkpoint()
	var no_rollback: bool = inspection["status"] == Store.RunFile.UNAVAILABLE and Store.load_saved_run().is_empty()
	var replacement := Run.new().create_new_run(SEED + 1, Store.default_data())
	var replaced := Store._save_run_state_at(_save, replacement, Callable(), true)
	var unchanged := FileAccess.get_sha256(_save) == live_hash and FileAccess.file_exists(backup) and FileAccess.get_sha256(backup) == backup_hash
	print("PERF147 READ unavailable=", no_rollback, " rotation_rejected=", not replaced,
		" files_unchanged=", unchanged, " selected_seed=", inspection.get("state", {}).get("seed", 0))
	quit(0 if no_rollback and not replaced and unchanged else 1)

func _stall_quit() -> void:
	root.set_meta("labyrinth_resume_saved_run", true)
	var run: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(run)
	current_scene = run
	if not run.has_installed_run():
		_fail("run fixture did not install")
		return
	run._close_dialogue()
	run._open_menu_overlay()
	if _capture and not await _capture_frame("save-and-quit.png"): return
	var live_hash := FileAccess.get_sha256(_save)
	var stamp_path := _output.path_join("stalled.sha256")
	var stall_msec := VISUAL_STALL_MSEC if _capture else 0
	var stall := func(stage: String) -> bool:
		if stage != "temporary_started": return true
		var stamp := FileAccess.open(stamp_path, FileAccess.WRITE)
		stamp.store_line(live_hash)
		stamp.close()
		if stall_msec > 0: OS.delay_msec(stall_msec)
		else: Semaphore.new().wait()
		return true
	Store._run_writer.submit_prepared(Store._prepare_run_state_at.bind(_save, run._committed_run_state(), stall), true)
	var setup_deadline := Time.get_ticks_msec() + SETUP_TIMEOUT_MSEC
	while not FileAccess.file_exists(stamp_path):
		if Time.get_ticks_msec() > setup_deadline:
			_fail("checkpoint worker did not reach the targeted stall")
			return
		await process_frame
		Store.poll_pending_run_saves()
	var request := FileAccess.open(_output.path_join("request.json"), FileAccess.WRITE)
	request.store_string(JSON.stringify({"unix_seconds": Time.get_unix_time_from_system()}))
	request.close()
	print("PERF147 QUIT requested=", _case)
	_requested_usec = Time.get_ticks_usec()
	_last_frame_usec = _requested_usec
	process_frame.connect(_count_frames)
	match _case:
		"save-and-quit": run._on_save_and_quit_pressed()
		"window-close":
			root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			root.close_requested.emit()
		"steam-shutdown": root.get_node("SteamService")._on_steam_shutdown()
		"sync-barrier":
			Store.flush_pending_run_saves()
			_fail("a stalled synchronous write returned to gameplay")
	if _capture and _case == "save-and-quit":
		await scene_changed
		if not await _capture_frame("after-save-title.png"): return
		quit(0 if _frames >= PUMP_FRAMES else 1)

func _count_frames() -> void:
	_frames += 1
	var now := Time.get_ticks_usec()
	_max_frame_gap = maxi(_max_frame_gap, now - _last_frame_usec)
	_last_frame_usec = now
	if now - _requested_usec >= LATE_SAMPLE_USEC:
		print("PERF147 QUIT remained_responsive=", _frames >= PUMP_FRAMES and _max_frame_gap < MAX_FRAME_GAP_USEC,
			" frames=", _frames, " longest_usec=", _max_frame_gap)
		process_frame.disconnect(_count_frames)

func _capture_frame(filename: String) -> bool:
	await RenderingServer.frame_post_draw
	if root.size != VIEWPORT or not is_equal_approx(root.content_scale_factor, 1.0):
		_fail("expected 1920x1080 at 100% UI scale")
		return false
	var path := _output.path_join(filename)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_fail("could not capture " + path)
		return false
	print(path)
	return true

func _fail(message: String) -> void:
	push_error("PERF147 " + message)
	quit(1)
