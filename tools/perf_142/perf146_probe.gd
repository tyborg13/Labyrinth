extends SceneTree
## Save integrity repros shared by perf-145, the candidate and the historical writers.

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Writer = preload("res://scripts/ordered_background_writer.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const SteamServiceScript = preload("res://scripts/steam_service.gd")
const RUN_SCENE := "res://scenes/run_scene.tscn"
const VIEWPORT := Vector2i(1920, 1080)
const FRAME_LIMIT := 120
const SEED := 83
const TIMEOUT_USEC := 30000000
const STALLED_WRITE_MSEC := 4500
const RECEIPT := "perf146_quit_checkpoint"
const CRASH_PREDECESSOR := "before-rename"
const CLOUD_FIXTURE_STEAM_ID := "76561198000000146"

var _case: String
var _output: String
var _source: String
var _capture: bool
var _deadline: int
var _save: String
var _menu: Control
var _requested_usec: int

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): _case = argument.trim_prefix("--case=")
		elif argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		elif argument.begins_with("--source="): _source = argument.trim_prefix("--source=")
		elif argument == "--capture": _capture = true
	_run.call_deferred()

func _run() -> void:
	if _output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("provide a writable output directory")
		return
	_deadline = Time.get_ticks_usec() + TIMEOUT_USEC
	Engine.max_fps = FRAME_LIMIT
	_save = _output.path_join("current_run.save")
	Store.set_storage_path("user://perf-146-profile.json")
	Store.set_run_storage_path(_save)
	Settings.set_storage_path("user://perf-146-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": true}, true)
	if not Settings.save_settings(settings):
		_fail("could not write settings")
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEWPORT
	match _case:
		"atomic": _atomic()
		"crash-between-renames": _crash_between_renames()
		"corrupt-live", "wrong-build-live": await _recover_good_backup()
		"unavailable-live": await _retry_unavailable_live()
		"stalled-quit": await _stalled_quit()
		"continue-missing": await _continue_missing()
		"reveal-close": await _reveal_close()
		"slow-quit": await _slow_quit()
		"resume", "resume-local-backup", "resume-cloud-backup": await _resume()
		_: _fail("unknown case")

func _atomic() -> void:
	if not _save_new_room(): return
	var previous := FileAccess.get_file_as_bytes(_save)
	var next := _new_room()
	next[RECEIPT] = _case
	var interrupt := func(stage: String) -> bool: return stage != "recovery_ready"
	var succeeded: bool = Store._save_run_state_at(_save, next, interrupt)
	var live_same: bool = FileAccess.file_exists(_save) and FileAccess.get_file_as_bytes(_save) == previous
	var backup_same: bool = FileAccess.file_exists(_save + ".backup") and FileAccess.get_file_as_bytes(_save + ".backup") == previous
	var recovered: bool = Store.load_saved_run().get("seed") == SEED
	if succeeded or not recovered:
		_fail("atomic interruption did not preserve a readable predecessor")
		return
	print("PERF146 ATOMIC live_unchanged=", live_same, " recovered=", recovered, " backup_unchanged=", backup_same)
	var preserved: bool = live_same if OS.get_name() != "Windows" else not FileAccess.file_exists(_save) and backup_same
	quit(0 if preserved else 1)

func _crash_between_renames() -> void:
	var previous := _new_room()
	previous[RECEIPT] = CRASH_PREDECESSOR
	if not Store.save_run_state(previous):
		_fail("could not write the crash predecessor")
		return
	var digest := FileAccess.get_sha256(_save)
	var next := _new_room()
	next[RECEIPT] = "after-rename"
	var crash := func(stage: String) -> bool:
		if stage != "recovery_ready": return true
		if FileAccess.file_exists(_save) or FileAccess.get_sha256(_save + ".backup") != digest:
			return false
		var stamp := FileAccess.open(_output.path_join("before-promotion.sha256"), FileAccess.WRITE)
		if stamp == null: return false
		stamp.store_line(digest)
		stamp.close()
		print("PERF146 CRASH stage=recovery_ready live_missing=true backup_sha256=", digest)
		OS.kill(OS.get_process_id())
		return false
	# Exercise the Windows transaction on every host. The dynamic call keeps
	# the other cases runnable against the historical control.
	var writer: Script = Store
	writer.call("_save_run_state_at", _save, next, crash, true)
	_fail("crash did not terminate the process between renames")

func _recover_good_backup() -> void:
	var previous := _new_room()
	previous[RECEIPT] = CRASH_PREDECESSOR
	if not _write_variant(_save + ".backup", previous):
		_fail("could not write good backup")
		return
	var bad: Dictionary = {"build_kind": "demo"} if _case == "corrupt-live" else _new_room()
	if _case == "wrong-build-live": bad.erase("build_kind")
	if not _write_variant(_save, bad):
		_fail("could not write bad live file")
		return
	var backup_sha := FileAccess.get_sha256(_save + ".backup")
	var live_sha := FileAccess.get_sha256(_save)
	_open_title()
	var offered: bool = not _menu.continue_button.disabled
	_menu.start_button.pressed.emit()
	var confirmed: bool = _menu._replacement_confirmation_open
	_menu.replacement_cancel_button.pressed.emit()
	var interrupt := func(stage: String) -> bool: return stage != "recovery_ready"
	var writer: Script = Store
	var promoted: bool = writer.call("_save_run_state_at", _save, _new_room(), interrupt, true)
	var protected: bool = not promoted and FileAccess.get_sha256(_save + ".backup") == backup_sha and FileAccess.get_sha256(_save) == live_sha
	if not offered or not confirmed or not protected:
		_fail("good backup was hidden or at risk of being overwritten")
		return
	_menu.continue_button.pressed.emit()
	if not await _until(_cover_finished, "waiting for backed-up run"): return
	if current_scene == _menu or current_scene._run_state.get(RECEIPT) != CRASH_PREDECESSOR:
		_fail("Continue did not install the backup")
		return
	print("PERF146 ", _case, " offered=true replacement_prompt=true backup_unchanged=true resumed_backup=true")
	quit()

func _retry_unavailable_live() -> void:
	var live := _new_room()
	live[RECEIPT] = "newer-live"
	var backup := _new_room()
	backup[RECEIPT] = "older-backup"
	if not _write_variant(_save, live) or not _write_variant(_save + ".backup", backup):
		_fail("could not write lock fixtures")
		return
	var live_sha := FileAccess.get_sha256(_save)
	var backup_sha := FileAccess.get_sha256(_save + ".backup")
	var permissions: int = FileAccess.get_unix_permissions(_save) if OS.get_name() != "Windows" else 0
	if not await _change_checkpoint_lock(true, permissions):
		_fail("could not deny access to the live checkpoint")
		return
	var reader: Script = Store
	var unavailable: Dictionary = reader.call("read_resumable_checkpoint")
	var unavailable_status: int = reader.get_script_constant_map()["RunFile"]["UNAVAILABLE"]
	_open_title()
	var offered: bool = not _menu.continue_button.disabled
	_menu.start_button.pressed.emit()
	var blocked_new_run: bool = current_scene == _menu and is_instance_valid(_menu._loading_error) and _menu._loading_error.visible
	if blocked_new_run: _menu._loading_error.hide()
	var attempted: bool = Store._save_run_state_at(_save, _new_room())
	if offered: _menu.continue_button.pressed.emit()
	var settled: bool = await _until(_cover_finished, "waiting for unavailable-checkpoint error")
	var retry_dialog: bool = current_scene == _menu and is_instance_valid(_menu._loading_error) and _menu._loading_error.visible
	if not await _change_checkpoint_lock(false, permissions):
		_fail("could not restore access to the live checkpoint")
		return
	var untouched: bool = FileAccess.get_sha256(_save) == live_sha and FileAccess.get_sha256(_save + ".backup") == backup_sha
	if not settled or not offered or not blocked_new_run or not retry_dialog or attempted or not untouched or (
		unavailable["status"] != unavailable_status or unavailable.has("state")
	):
		_fail("unavailable live checkpoint was not deferred")
		return
	_menu._loading_error.hide()
	_menu.continue_button.pressed.emit()
	if not await _until(_cover_finished, "waiting for newer live checkpoint"): return
	if current_scene == _menu or current_scene._run_state.get(RECEIPT) != "newer-live":
		_fail("retry did not install the newer live checkpoint")
		return
	print("PERF146 unavailable-live deferred=true files_unchanged=true resumed_newer_live=true")
	quit()

func _change_checkpoint_lock(locked: bool, permissions: int) -> bool:
	if OS.get_name() != "Windows":
		return FileAccess.set_unix_permissions(_save, 0 if locked else permissions) == OK
	# On Windows the Python proof driver owns a native exclusive handle.
	var action: String = "lock" if locked else "unlock"
	var request := FileAccess.open(_output.path_join(action + ".request"), FileAccess.WRITE)
	if request == null: return false
	request.close()
	return await _until(func() -> bool: return FileAccess.file_exists(_output.path_join(action + ".ready")),
		"waiting for native checkpoint " + action)

func _stalled_quit() -> void:
	var previous := _new_room()
	previous[RECEIPT] = "before-stall"
	if not Store.save_run_state(previous):
		_fail("could not write the pre-stall checkpoint")
		return
	var live_sha := FileAccess.get_sha256(_save)
	_open_title()
	var next := _new_room()
	next[RECEIPT] = "uncommitted"
	var stall := func(stage: String) -> bool:
		if stage != "temporary_started": return true
		var stamp := FileAccess.open(_output.path_join("stalled-write.sha256"), FileAccess.WRITE)
		stamp.store_line(live_sha)
		stamp.close()
		Semaphore.new().wait()
		return false
	var writer := Store._run_writer
	writer.submit_prepared(Store._prepare_run_state_at.bind(_save, next, stall), true)
	if not await _until(func() -> bool:
		Store.poll_pending_run_saves()
		return FileAccess.file_exists(_output.path_join("stalled-write.sha256"))
	, "waiting for temporary write to stall"): return
	var request := FileAccess.open(_output.path_join("quit-request.json"), FileAccess.WRITE)
	request.store_string(JSON.stringify({"unix_seconds": Time.get_unix_time_from_system()}))
	request.close()
	print("PERF146 STALLED_QUIT temporary_started=true")
	_request_close()

func _write_variant(path: String, state: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_var(state, false)
	file.close()
	return true

func _cover_finished() -> bool:
	return current_scene != null and current_scene.name != &"MenuRunTransition"

func _continue_missing() -> void:
	if not _save_new_room(): return
	var before := FileAccess.get_sha256(_save)
	_open_title()
	if _menu.continue_button.disabled:
		_fail("valid checkpoint did not enable Continue")
		return
	_menu.continue_button.pressed.emit()
	var cover := root.get_node_or_null("MenuRunTransition")
	if cover == null or DirAccess.rename_absolute(_save, _save + ".held") != OK:
		_fail("could not withdraw the save after Continue was pressed")
		return
	if not await _until(func() -> bool:
		return current_scene.name != &"MenuRunTransition", "waiting for Continue outcome"): return
	var dialog: bool = current_scene == _menu and is_instance_valid(_menu._loading_error) and _menu._loading_error.visible
	var replacement: bool = FileAccess.file_exists(_save)
	var unchanged: bool = FileAccess.get_sha256(_save + ".held") == before
	if not replacement:
		unchanged = unchanged and DirAccess.rename_absolute(_save + ".held", _save) == OK
		unchanged = unchanged and FileAccess.get_sha256(_save) == before
	print("PERF146 CONTINUE dialog=", dialog, " replacement=", replacement, " original_unchanged=", unchanged)
	if _capture and dialog and not await _capture_frame(): return
	quit(0 if dialog and not replacement and unchanged else 1)

func _reveal_close() -> void:
	if not _save_new_room(): return
	_open_title()
	_menu.continue_button.pressed.emit()
	var cover := root.get_node_or_null("MenuRunTransition")
	if cover == null:
		_fail("Continue did not enter the cover")
		return
	cover.finished.connect(func(run: Node) -> void:
		if not is_instance_valid(cover) or cover.is_queued_for_deletion() or current_scene != run:
			_fail("close missed the installed reveal frame")
			return
		if _capture and not _save_capture(): return
		run._run_state[RECEIPT] = _case
		print("PERF146 REVEAL installed=true cover_present=true")
		_request_close()
	, CONNECT_ONE_SHOT)
	await _until(func() -> bool: return _requested_usec > 0, "waiting for the reveal-frame close")

func _slow_quit() -> void:
	var engine := Run.new()
	var state := _new_room()
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	for coord: Vector2i in engine.available_moves(state):
		var candidate: Dictionary = engine.move_to_room(state.duplicate(true), coord)
		if str(candidate.get("mode")) == "combat":
			state = candidate
			break
	if state.get("mode") != "combat" or not Store.save_run_state(state):
		_fail("could not create a combat checkpoint")
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	var run: Node = (load(RUN_SCENE) as PackedScene).instantiate()
	root.add_child(run)
	current_scene = run
	if not run.has_installed_run():
		_fail("combat fixture did not install")
		return
	run._close_dialogue()
	if _capture and not await _capture_frame(): return
	run._run_state[RECEIPT] = _case
	var writer: RefCounted = Store._run_writer
	var snapshot: Dictionary = run._committed_run_state()
	var payload := var_to_bytes(snapshot)
	var receipt := Writer.Receipt.new()
	writer.probe_delay_msec = STALLED_WRITE_MSEC
	Store.queue_owned_run_state(snapshot, "", receipt, func(saved: bool) -> void:
		var bytes := FileAccess.get_file_as_bytes(_save)
		var complete: bool = saved and bytes.size() == payload.size() + 4 and (
			bytes.decode_u32(0) == payload.size() and bytes.slice(4) == payload
		)
		print("PERF146 IN_FLIGHT byte_exact=", complete)
	)
	await process_frame
	Store.poll_pending_run_saves()
	if not await _until(func() -> bool: return writer._active != null and writer._active.has_started(), "waiting for in-flight checkpoint"): return
	writer.probe_delay_msec = 0
	print("PERF146 SLOW_QUIT write_started=true injected_msec=", STALLED_WRITE_MSEC)
	_request_close()

func _resume() -> void:
	if _source.is_empty():
		_fail("missing resume source")
		return
	var source_sha256 := FileAccess.get_sha256(_source)
	var from_backup: bool = _case != "resume"
	if _case == "resume-local-backup":
		_save = _source.trim_suffix(".backup")
		Store.set_run_storage_path(_save)
	elif _case == "resume-cloud-backup":
		if not _stage_steam_backup(): return
	elif DirAccess.copy_absolute(_source, _save) != OK:
		_fail("could not copy checkpoint for Continue")
		return
	if from_backup and FileAccess.file_exists(_save):
		_fail("expected a backup-only checkpoint")
		return
	var file := FileAccess.open(_save + ".backup" if from_backup else _save, FileAccess.READ)
	if file == null:
		_fail("could not open checkpoint fixture")
		return
	var payload_size := file.get_32()
	var byte_complete := file.get_length() == payload_size + 4
	file.seek(0)
	var saved: Dictionary = file.get_var(false)
	file.close()
	if not byte_complete or saved.get("seed") != SEED:
		_fail("checkpoint seed or frame length is wrong")
		return
	var marker: String = saved.get(RECEIPT, "")
	if _case == "resume-cloud-backup":
		change_scene_to_file("res://scenes/startup.tscn")
		if not await _until(func() -> bool:
			return current_scene is Control and "continue_button" in current_scene and not root.gui_disable_input
		, "waiting for the Steam account's first title"): return
		_menu = current_scene
	else:
		_open_title()
	var enabled: bool = not _menu.continue_button.disabled
	if enabled: _menu.continue_button.pressed.emit()
	if enabled and not await _until(func() -> bool:
		return current_scene.name != &"MenuRunTransition", "waiting for resume outcome"): return
	var resumed: bool = current_scene != _menu and current_scene.has_method("has_installed_run") and current_scene.has_installed_run()
	var installed: Dictionary = current_scene._run_state if resumed else {}
	var same_run: bool = resumed and installed.get("seed") is int and installed.get("seed") == SEED and (
		installed.get(RECEIPT, "") == marker and installed.get("mode") == saved.get("mode") and installed.get("current_room") == saved.get("current_room")
	)
	print("PERF146 RESUME enabled=", enabled, " resumed=", resumed, " same_run=", same_run,
		" byte_complete=", byte_complete, " receipt=", marker, " sha256=", source_sha256)
	quit(0 if same_run else 1)

func _stage_steam_backup() -> bool:
	var service := SteamServiceScript.new()
	service._initialized = true
	service._logged_on = true
	service._steam_id = CLOUD_FIXTURE_STEAM_ID
	var user_base := ProjectSettings.globalize_path("user://").trim_suffix("/").get_base_dir()
	var account_dir := user_base.path_join(service.steam_user_dir_name())
	var name := Store.DEFAULT_RUN_STORAGE_PATH.get_file()
	# Model Auto-Cloud delivering only the backup before the first launch.
	var staged: bool = DirAccess.make_dir_recursive_absolute(account_dir) == OK and (
		DirAccess.copy_absolute(_source, account_dir.path_join(name + ".backup")) == OK
	)
	Parallel._namespace = ""
	if staged: service._apply_steam_user_directory()
	service.free()
	_save = ProjectSettings.globalize_path(Store.DEFAULT_RUN_STORAGE_PATH)
	if not staged or _save != account_dir.path_join(name):
		_fail("could not stage the backup in the Steam account directory")
		return false
	Store.set_storage_path(Store.DEFAULT_STORAGE_PATH)
	Store.set_run_storage_path(Store.DEFAULT_RUN_STORAGE_PATH)
	print("PERF146 CLOUD account_path=true backup_only=true")
	return true

func _new_room() -> Dictionary:
	return Run.new().create_new_run(SEED, Store.default_data())

func _save_new_room() -> bool:
	if Store.save_run_state(_new_room()): return true
	_fail("could not save the initial checkpoint")
	return false

func _open_title() -> void:
	_menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(_menu)
	current_scene = _menu

func _request_close() -> void:
	_requested_usec = Time.get_ticks_usec()
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	root.close_requested.emit()

func _finalize() -> void:
	if _requested_usec > 0:
		print("PERF146 FINALIZE usec=", Time.get_ticks_usec() - _requested_usec)

func _capture_frame() -> bool:
	await RenderingServer.frame_post_draw
	return _save_capture()

func _save_capture() -> bool:
	var path := _output.path_join(_case + ".png")
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_fail("could not capture " + path)
		return false
	print(path)
	return true

func _until(condition: Callable, label: String) -> bool:
	while not bool(condition.call()):
		if Time.get_ticks_usec() >= _deadline:
			_fail(label)
			return false
		await process_frame
	return true

func _fail(message: String) -> void:
	push_error("PERF146 " + _case + ": " + message)
	quit(2)
