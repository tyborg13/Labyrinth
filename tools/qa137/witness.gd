extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Play = preload("res://scripts/play_stats.gd")
const Lifecycle = preload("res://scripts/run_persistence.gd")
const FakeSteam = preload("res://tests/suites/steam_service_suite.gd").FakeSteam
const ROOT := "user://qa137-witness"
const SUCCESS_DIR := ROOT + "/successful"
const PROFILE := SUCCESS_DIR + "/progression.json"
const RUN := SUCCESS_DIR + "/current_run.save"
const BLOCKER := ROOT + "/blocker"
const RETRY_BLOCKER := ROOT + "/retry-blocker"
const RUN_SEED := 88100
const PROFILE_EMBERS := 37
const STAT := "play_v1_save_errors"
const CAPTURES := ["progression.json", "01-departure.save", "02-pre-battle.save", "03-combat.save", "04-retry.save"]

var _steam: Node
var _fake: FakeSteam
var _play := ThreadCheckedPlay.new()
var _failures: Array[String]

class ThreadCheckedPlay extends Play:
	var save_signal_threads: Array[int]

	func emit_stats(deltas: Dictionary) -> void:
		if deltas.has("save_errors"):
			save_signal_threads.append(OS.get_thread_caller_id())
		super.emit_stats(deltas)

func _initialize() -> void:
	call_deferred("_prove")

func _prove() -> void:
	OS.set_environment("LABYRINTH_DEMO", "1")
	var args := OS.get_cmdline_user_args()
	var release := args == PackedStringArray(["--capture-release"])
	if not release and (args.size() != 2 or args[0] != "--release-dir"):
		push_error("Use --capture-release on release, then --release-dir <capture directory> on the implementation.")
		quit(2)
		return
	_check(DirAccess.make_dir_recursive_absolute(SUCCESS_DIR) == OK, "Create witness output directory")
	Analytics.set_storage_dir(ROOT + "/analytics")
	Store.set_storage_path(PROFILE)
	Store.set_run_storage_path(RUN)
	if not release: _install_stat_probe()

	var profile := Store.set_embers(Store.default_data(), PROFILE_EMBERS)
	_check(Store.save_data(profile), "Save real demo profile")
	var disk_profile := Store.load_data()
	_check(int(disk_profile.get("embers", -1)) == PROFILE_EMBERS, "Read back the real profile")
	var combat := await _play_opening(disk_profile)
	if not combat.is_empty():
		if release:
			Store.set_run_storage_path(SUCCESS_DIR + "/04-retry.save")
			_check(Store.save_run_state(combat), "Save retry fixture bytes on release")
		else:
			_check(_stat() == 0 and _events().is_empty(), "Normal saves leave both counters at zero")
			print("QA137 normal opening saves: save_errors=%d save_failed=%d" % [_stat(), _events().size()])
			await _prove_retry(combat)
			await _prove_failures(profile, combat)
			await _prove_shutdown(combat)
			_compare_release(args[1])
	print("QA137 capture directory: %s" % ProjectSettings.globalize_path(SUCCESS_DIR))
	if _fake != null:
		_steam._steam = null
		_steam._stats_dirty = false
		_fake.free()
	for failure: String in _failures: push_error(failure)
	print("QA137 RESULT: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _play_opening(profile: Dictionary) -> Dictionary:
	var engine := preload("res://scripts/run_engine.gd").new()
	var departure: Dictionary = engine.create_new_run(RUN_SEED, profile)
	_check(Store.install_replacement_run(departure), "Install a generated demo run")
	_capture_run("01-departure.save")
	for coord: Vector2i in engine.available_moves(departure):
		var prepared: Dictionary = engine.move_to_pre_battle(departure, coord)
		if prepared.get("mode") != "pre_battle": continue
		_check(Store.save_run_state(prepared), "Save the real pre-battle state")
		_capture_run("02-pre-battle.save")
		var combat: Dictionary = engine.begin_pre_battle_combat(prepared)
		_check(combat.get("mode") == "combat" and not combat.get("combat_state", {}).is_empty(), "Enter a real fight")
		Store.queue_run_state(combat)
		_check(await Store.flush_pending_run_saves_in_tree(self), "Write the combat checkpoint on the disk worker")
		_capture_run("03-combat.save")
		return combat
	_check(false, "The fixed seed exposes a real pre-battle destination")
	return {}

func _prove_retry(combat: Dictionary) -> void:
	_block_writes(RETRY_BLOCKER)
	var path := RETRY_BLOCKER + "/current_run.save"
	Store.set_run_storage_path(path)
	Store.queue_run_state(combat, "qa137_retry")
	_check(not await Store.flush_pending_run_saves_in_tree(self), "First checkpoint attempt hits the blocker")
	_check(_stat() == 0 and _events().is_empty(), "A retryable checkpoint failure stays silent")
	_check(DirAccess.remove_absolute(RETRY_BLOCKER) == OK, "Remove retry blocker")
	_check(DirAccess.make_dir_recursive_absolute(RETRY_BLOCKER) == OK, "Make the retry destination writable")
	_check(await Store.flush_pending_run_saves_in_tree(self), "Retry the same queued checkpoint successfully")
	_check(DirAccess.copy_absolute(path, SUCCESS_DIR + "/04-retry.save") == OK, "Capture bytes written by the retry")
	_check(Store.clear_saved_run(), "Clear the retry checkpoint through the normal API")
	await process_frame
	_check(_stat() == 0 and _events().is_empty(), "Recovery gives zero Steam and local events")
	print("QA137 failed attempt then successful retry: save_errors=%d save_failed=%d" % [_stat(), _events().size()])

func _prove_failures(profile: Dictionary, combat: Dictionary) -> void:
	_block_writes(BLOCKER)
	Store.set_storage_path(BLOCKER + "/progression.json")
	_check(not await Store.save_data_in_tree(self, profile), "Profile save fails against the blocker")
	await process_frame
	_check_failure_counts(1, ["profile"])
	print("QA137 terminal profile failure: save_errors=%d save_failed=%d" % [_stat(), _events().size()])

	Store.set_run_storage_path(BLOCKER + "/current_run.save")
	Store.queue_run_state(combat, "qa137_checkpoint")
	_check(not await Store.flush_pending_run_saves_in_tree(self), "First worker attempt fails")
	_check(not await Store.flush_pending_run_saves_in_tree(self), "Second worker attempt fails")
	_check(_stat() == 1, "Repeated failure of the pending request leaves the counter unchanged")
	Store.clear_saved_run() # Its existing final attempt fails before it cancels pending saves.
	await process_frame
	_check_failure_counts(2, ["profile", "run_checkpoint"])
	_check(_play.save_signal_threads == [OS.get_main_thread_id(), OS.get_main_thread_id()], "Both signals were delivered on the main thread")
	print("QA137 terminal worker failure: save_errors=%d save_failed=%d main_thread=%s" % [
		_stat() - 1, _events().size() - 1, str(_play.save_signal_threads == [OS.get_main_thread_id(), OS.get_main_thread_id()])])
	Store.set_storage_path(PROFILE)

func _prove_shutdown(combat: Dictionary) -> void:
	_check(not Store.install_replacement_run(combat), "A replacement write fails against the blocker without entering the queue")
	await process_frame
	_check_failure_counts(3, ["profile", "run_checkpoint", "run_checkpoint"])
	print("QA137 terminal replacement failure: save_errors=%d save_failed=%d" % [_stat() - 2, _events().size() - 2])

	Store.queue_run_state(combat, "qa137_shutdown")
	_check(not await Lifecycle.flush_in_tree(self), "The application's final barrier cannot write the queued checkpoint")
	_check(_stat() == 3, "The failed attempt remains retryable until shutdown finalizes it")
	Lifecycle.set_application_drained()
	_check_failure_counts(4, ["profile", "run_checkpoint", "run_checkpoint", "run_checkpoint"])
	Store._run_writer.cancel_pending()
	await process_frame
	_check_failure_counts(4, ["profile", "run_checkpoint", "run_checkpoint", "run_checkpoint"])
	print("QA137 final shutdown failure and cleanup: save_errors=%d save_failed=%d" % [_stat() - 3, _events().size() - 3])
	Store.set_run_storage_path(RUN)

func _check_failure_counts(expected: int, kinds: Array) -> void:
	var events := _events()
	_check(_stat() == expected and events.size() == expected, "Exactly %d Steam and local failures" % expected)
	var actual: Array = []
	for event: Dictionary in events:
		var payload: Dictionary = event["payload"]
		actual.append(payload.get("kind"))
		_check(int(payload.get("reason", OK)) != OK, "Local row includes a file error")
	_check(actual == kinds, "Local failure kinds match the requests")

func _install_stat_probe() -> void:
	var performance := root.get_node("PerformanceTelemetry")
	performance._sampling_enabled = false
	performance._steam_stats_enabled = false
	performance._frame_samples_ms.clear()
	_steam = root.get_node("SteamService")
	_fake = FakeSteam.new()
	_fake.app_id = 5575620
	_steam._set_stats_queue_path_for_test(ROOT + "/steam-queue.json")
	_steam._initialize_with_steam_for_test(_fake, {"status": 0})
	_play.closing = true # Sample the real Steam batch only at proof boundaries.
	_steam._play = _play
	_check(_steam.is_steam_active(), "In-memory demo Steam adapter is active")

func _stat() -> int:
	_steam._flush_play_batches()
	return int(_fake.stats.get(STAT, 0))

func _events() -> Array[Dictionary]:
	return Analytics.load_all_events().filter(func(event: Dictionary) -> bool: return event["event_type"] == "save_failed")

func _block_writes(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Create file-in-the-way blocker")
	if file != null:
		file.store_string("file in place of a directory")
		file.close()

func _capture_run(name: String) -> void:
	_check(DirAccess.copy_absolute(RUN, SUCCESS_DIR.path_join(name)) == OK, "Capture " + name)

func _compare_release(directory: String) -> void:
	for name: String in CAPTURES:
		var current := SUCCESS_DIR.path_join(name)
		var actual := FileAccess.get_file_as_bytes(current)
		var baseline := FileAccess.get_file_as_bytes(directory.path_join(name))
		_check(not actual.is_empty() and actual == baseline, name + " matches release byte for byte")
		print("QA137 bytes %s: %s (%d bytes, SHA-256 %s)" % [name,
			"identical" if not actual.is_empty() and actual == baseline else "different", actual.size(), FileAccess.get_sha256(current)])

func _check(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
