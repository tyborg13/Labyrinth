extends SceneTree

const Analytics = preload("res://scripts/analytics_store.gd")
const CHILD_TIMEOUT_SECONDS: int = 60
const READY_TIMEOUT_SECONDS: float = 20.0
var failures: Array[String]
var stage: String = "parent"
var directory: String = ""

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage = argument.trim_prefix("--stage=")
		if argument.begins_with("--directory="): directory = argument.trim_prefix("--directory=")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("user://perf03-analytics-restart")
	call_deferred("_run")

func _run() -> void:
	if stage == "write":
		_write_interrupted_tail()
		return
	if stage == "verify":
		_verify_restart()
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var ready: String = directory.path_join("ready.json")
	var child: int = OS.create_process("python3", _child_arguments("write"))
	_check(child > 0, "Launch child exclusively through godot_task_runner")
	var deadline: int = Time.get_ticks_usec() + int(READY_TIMEOUT_SECONDS * 1000000)
	while not FileAccess.file_exists(ready) and Time.get_ticks_usec() < deadline:
		await process_frame
	var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(ready)) if FileAccess.file_exists(ready) else null
	if not marker is Dictionary:
		if child > 0: OS.kill(child)
		_check(false, "Interrupted append fixture became ready")
		_finish()
		return
	var child_pid: int = int(marker["pid"])
	_check(OS.kill(child_pid) == OK, "Kill actual engine process with complete prefix and partial tail on disk")
	while OS.is_process_running(child) and Time.get_ticks_usec() < deadline:
		await process_frame
	_check(not OS.is_process_running(child), "Killed subprocess runner exits and reaps its child")
	var output: Array = []
	var result: int = OS.execute("python3", _child_arguments("verify"), output, true)
	for chunk: String in output: print(chunk)
	_check(result == 0, "Fresh process appends after the partial tail and loads both complete events")
	_finish()

func _child_arguments(child_stage: String) -> PackedStringArray:
	return PackedStringArray(["tools/godot_task_runner.py", "--task-id", "perf-03", "--stream", "--timeout", str(CHILD_TIMEOUT_SECONDS),
		"--", "godot", "--headless", "--path", ".", "--script", "tests/perf/analytics_restart_test.gd", "--",
		"--stage=" + child_stage, "--directory=" + directory])

func _write_interrupted_tail() -> void:
	Analytics.set_storage_dir(directory.path_join("analytics"))
	Analytics.clear_storage()
	var store := Analytics.new()
	if not store.write_event("perf03_before_kill", {"run_id": "restart"}, {"value": 1}, "restart:before"):
		push_error("Could not write restart fixture predecessor")
		quit(1)
		return
	var path: String = Analytics._event_file_path()
	var prefix: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"event_type":"interrupted","payload":')
	file.flush()
	file.close()
	var prefix_file: FileAccess = FileAccess.open(directory.path_join("prefix.bin"), FileAccess.WRITE)
	prefix_file.store_buffer(prefix)
	prefix_file.close()
	# The parent polls for existence: publish only the complete, closed marker.
	# Opening ready.json directly lets it read an empty/partial JSON document.
	var ready_path: String = directory.path_join("ready.json")
	var ready_staging_path: String = ready_path + ".tmp"
	var marker: FileAccess = FileAccess.open(ready_staging_path, FileAccess.WRITE)
	marker.store_string(JSON.stringify({"pid": OS.get_process_id(), "path": path}))
	marker.flush()
	marker.close()
	if DirAccess.rename_absolute(ready_staging_path, ready_path) != OK:
		push_error("Could not publish restart fixture readiness marker")
		quit(1)
		return
	# Parent kills this process; no orderly shutdown or store flush can repair it.
	set_auto_accept_quit(false)

func _verify_restart() -> void:
	Analytics.set_storage_dir(directory.path_join("analytics"))
	var store := Analytics.new()
	_check(store.write_event("perf03_after_restart", {"run_id": "restart"}, {"value": 2}, "restart:after"), "Append after restart")
	var events: Array[Dictionary] = Analytics.load_all_events()
	_check(events.size() == 2, "Unterminated malformed tail cannot swallow the next complete event")
	if events.size() == 2:
		_check(events[0]["event_type"] == "perf03_before_kill" and events[1]["event_type"] == "perf03_after_restart", "Complete events retain their original order")
	var prefix: PackedByteArray = FileAccess.get_file_as_bytes(directory.path_join("prefix.bin"))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Analytics._event_file_path())
	_check(bytes.slice(0, prefix.size()) == prefix, "Every completed JSONL prefix byte is unchanged")
	_check(FileAccess.get_file_as_string(Analytics._event_file_path()).contains('"payload":\n{'), "Recovery puts the next record on a fresh line")
	_finish()

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("PERF03 ANALYTICS KILL/RESTART RESULT: %s (%d failures; %s)" % ["PASS" if failures.is_empty() else "FAIL", failures.size(), stage])
	quit(0 if failures.is_empty() else 1)
