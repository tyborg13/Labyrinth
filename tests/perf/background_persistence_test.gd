extends SceneTree

const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Lifecycle = preload("res://scripts/run_persistence.gd")
const Writer = preload("res://scripts/ordered_background_writer.gd")
const SAVE_PATH: String = "user://perf03-background.save"
const ANALYTICS_PATH: String = "user://perf03-background-analytics"
const CHECKPOINT_COUNT: int = 24
var failures: Array[String]

class Host extends Node:
	var _analytics_store = Analytics.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _state(index: int) -> Dictionary:
	return {"surface_rules_version": Progression.SURFACE_RULES_VERSION, "checkpoint": index,
		"nested": {"items": [index, {"value": index}]}, "mode": "combat"}

func _run() -> void:
	await _queue_cadence()
	Progression.set_run_storage_path(SAVE_PATH)
	Progression.clear_saved_run()
	_check(Progression.save_run_state(_state(-1)), "Initial durable checkpoint")
	var completed_before: int = Progression._run_writer.completed
	for index: int in range(CHECKPOINT_COUNT):
		var state: Dictionary = _state(index)
		_check(Progression.queue_run_state(state), "Queue checkpoint")
		state["nested"]["items"][1]["value"] = -999
	_check(Progression.flush_pending_run_saves(), "Ordered queue flush succeeds")
	_check(Progression.load_saved_run() == _state(CHECKPOINT_COUNT - 1), "Newest deep-owned snapshot wins")
	_check(Progression._run_writer.completed == completed_before + 1, "Unattempted older snapshots superseded by one newest write")
	Progression.queue_run_state(_state(100))
	_check(Progression.save_run_state(_state(101)), "Synchronous API flushes/supersedes older writes")
	_check(Progression.load_saved_run() == _state(101), "Synchronous newer save cannot be overwritten")
	Progression.clear_saved_run()
	Progression.queue_run_state(_state(102))
	_check(Progression._run_writer.busy() and not FileAccess.file_exists(SAVE_PATH), "Read fixture really has a pending write and no durable file")
	_check(Progression.has_saved_run(), "has_saved_run is a read barrier, not a stale disk check")
	_check(not Progression._run_writer.busy() and Progression.load_saved_run() == _state(102), "Read barrier writes and returns the pending snapshot")
	Progression.queue_run_state(_state(103))
	_check(Progression.load_saved_run() == _state(103), "Direct load also flushes a newer pending write")
	await _failed_checkpoint_retry()
	print("PERF03 CHECKPOINT ORDER/OWNERSHIP: PASS" if failures.is_empty() else "PERF03 CHECKPOINT ORDER/OWNERSHIP: FAIL")
	var before: int = failures.size()
	for interrupted_stage: String in ["temporary_validated", "recovery_ready", "promoted"]:
		_check(Progression.save_run_state(_state(200)), "Crash fixture durable predecessor")
		var stop: Callable = func(stage: String) -> bool: return stage != interrupted_stage
		_check(not Progression._save_run_state_at(SAVE_PATH, _state(201), stop), "Interrupt exact atomic transaction at " + interrupted_stage)
		var recovered: Dictionary = Progression.load_saved_run()
		_check(recovered == _state(201 if interrupted_stage == "promoted" else 200), "Last completed promotion remains valid after " + interrupted_stage)
		_check(Progression.save_run_state(_state(202)), "Next atomic transaction recovers after " + interrupted_stage)
		_check(not FileAccess.file_exists(SAVE_PATH + ".tmp") and not FileAccess.file_exists(SAVE_PATH + ".backup"), "Successful recovery cleans transaction artifacts")
	print("PERF03 CHECKPOINT CRASH SAFETY: %s (3 transaction boundaries)" % ("PASS" if failures.size() == before else "FAIL"))
	before = failures.size()
	Analytics.set_storage_dir(ANALYTICS_PATH)
	Analytics.clear_storage()
	var store := Analytics.new()
	store.deferred_writes = true
	for index: int in range(CHECKPOINT_COUNT):
		var context: Dictionary = {"run_id": "perf03", "turn": index, "card_id": "hobnail_drive"}
		var payload: Dictionary = {"index": index, "nested": {"items": [index]}}
		_check(store.write_event("perf03_fixture", context, payload, "perf03:%d" % index), "Queue analytics")
		context["turn"] = -999
		payload["nested"]["items"][0] = -999
	_check(store.write_event("perf03_fixture", {}, {}, "perf03:0"), "Pending idempotency key deduplicates")
	# A peer store/read is a durability barrier, preserving the pre-existing API.
	var peer := Analytics.new()
	_check(peer.write_event("perf03_fixture", {}, {}, "perf03:0"), "Peer store observes reserved/durable key")
	var events: Array[Dictionary] = Analytics.load_all_events()
	_check(events.size() == CHECKPOINT_COUNT, "All records append exactly once")
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		_check(event["sequence"] == index + 1 and event["turn"] == index, "Sequence/context created at logical boundary")
		_check(event["payload"] == JSON.parse_string(JSON.stringify({"index": index, "nested": {"items": [index]}})), "Queue owns immutable event fields")
		_check(event["card_id"] == "hobnail_drive" and not str(event["timestamp_utc"]).is_empty(), "Existing fields retained")
	var files: PackedStringArray = DirAccess.get_files_at(ProjectSettings.globalize_path(ANALYTICS_PATH))
	var prefix: Dictionary = {}
	for filename: String in files:
		if filename.ends_with(".jsonl"): prefix[filename] = FileAccess.get_file_as_bytes(ANALYTICS_PATH.path_join(filename))
	store.write_events([{"event_type": "perf03_batch", "payload": {"index": 24}}, {"event_type": "perf03_batch", "payload": {"index": 25}}])
	_check(Analytics.flush_pending_events(), "Batch flush succeeds")
	for filename: String in prefix:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ANALYTICS_PATH.path_join(filename))
		_check(bytes.slice(0, prefix[filename].size()) == prefix[filename], "Completed JSONL prefix is append-only")
	# Explicit durable outbox APIs must propagate an actual append failure,
	# rather than acknowledging its queue acceptance. Retry the same stable key.
	var blocked_path: String = "user://perf03-blocked-analytics"
	var blocker: FileAccess = FileAccess.open(blocked_path, FileAccess.WRITE)
	blocker.store_string("directory blocked")
	blocker.close()
	Analytics.set_storage_dir(blocked_path)
	_check(not store.write_event_durable("perf03_durable_retry", {}, {"value": 1}, "retry:1"), "Durable append returns the actual deferred failure")
	_check(Analytics._writer.busy(), "Failed analytics batch remains queued")
	_check(not store.has_idempotency_key("retry:1"), "A pending reservation cannot acknowledge a durable receipt")
	_check(not Analytics.flush_pending_events() and Analytics._writer.busy(), "Every barrier retries and reports a still-failing append")
	var failed_attempt: int = Analytics._writer.last_write_started_usec
	_check(store.write_event("perf03_durable_retry", {}, {"value": 1}, "retry:1"), "Failed batch still reserves its idempotency key")
	_check(Analytics._writer.last_write_started_usec == failed_attempt, "Dedup cache invalidation never flushes a write from an ordinary emitter")
	var failed_writer: RefCounted = Analytics._writer
	Analytics.set_storage_dir(ANALYTICS_PATH)
	_check(Analytics._writer != failed_writer and failed_writer.busy(), "Changing test/storage namespaces retains the failed batch in its original FIFO")
	Analytics.set_storage_dir(blocked_path)
	_check(Analytics._writer == failed_writer, "Returning to the namespace restores its pending retries")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	# Model bytes left by a failed append: the first queued record completed,
	# followed by a partial tail. Retry must preserve that prefix and skip the
	# already-completed event ID, including when no idempotency key is available.
	var pending_record: Dictionary = Analytics._open_batch["records"][0]
	var completed_prefix: String = JSON.stringify(pending_record) + "\n"
	var partial: FileAccess = FileAccess.open(Analytics._event_file_path(), FileAccess.WRITE)
	partial.store_string(completed_prefix + '{"interrupted":')
	partial.flush()
	partial.close()
	_check(store.write_event_durable("perf03_durable_retry", {}, {"value": 1}, "retry:1"), "Failed durable append remains retryable")
	var retry_count: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("idempotency_key", "")) == "retry:1": retry_count += 1
	_check(retry_count == 1, "Retry of failed buffered append occurs exactly once")
	_check(FileAccess.get_file_as_string(Analytics._event_file_path()).begins_with(completed_prefix + '{"interrupted":\n'), "Failure recovery preserves the completed prefix and terminates the partial tail")
	_check(store.write_event_durable("perf03_after_failed_tail"), "Next complete event appends after recovered tail")
	_check(Analytics.load_all_events().size() == 2, "Both complete events survive failed-append tail recovery")
	Analytics.clear_storage()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
	Analytics.set_storage_dir(ANALYTICS_PATH)
	print("PERF03 ANALYTICS ORDER/FIELDS/APPEND/IDEMPOTENCY: %s" % ("PASS" if failures.size() == before else "FAIL"))
	before = failures.size()
	var host := Host.new()
	root.add_child(host)
	Lifecycle.attach(host)
	Progression.queue_run_state(_state(300))
	host._analytics_store.write_event("perf03_exit")
	Lifecycle.mark_resolution_frame()
	host.get_node("RunPersistence").call("_drain_idle")
	_check(Progression._run_writer.busy() and Analytics._writer.busy(), "Production lifecycle excludes a marked rule-resolution frame")
	Lifecycle.expect_resolution_after_draw(host)
	await _next_frame()
	host.get_node("RunPersistence").call("_drain_idle")
	_check(Progression._run_writer.busy() and Analytics._writer.busy(), "Post-draw rule continuation reserves its frame before an idle drain can run")
	Lifecycle.resume_resolution_after_draw(host)
	host.free() # Actual Node._exit_tree path, with both queues still pending.
	_check(not Progression._run_writer.busy() and not Analytics._writer.busy(), "Scene exit flushes every pending job")
	_check(Progression.load_saved_run() == _state(300), "Scene exit flushes last snapshot")
	events = Analytics.load_all_events()
	_check(events.back()["event_type"] == "perf03_exit", "Scene exit flushes final event")
	Progression.queue_run_state(_state(301))
	Progression.clear_saved_run()
	_check(not Progression.has_saved_run(), "Run-end clear flushes queue; no checkpoint resurrection")
	print("PERF03 EXIT/RUN-END FLUSH: %s" % ("PASS" if failures.size() == before else "FAIL"))
	for failure: String in failures: push_error(failure)
	print("PERF03 DEFERRED PERSISTENCE RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _queue_cadence() -> void:
	var writer := Writer.new()
	var calls: Array = []
	for index: int in range(3):
		writer.submit(func() -> bool:
			calls.append([index, Engine.get_process_frames(), OS.get_thread_caller_id()])
			return true)
	writer.poll()
	_check(calls.is_empty(), "Enqueue frame never executes deferred writes")
	await _next_frame()
	writer.poll(false)
	_check(calls.is_empty(), "Rule-resolution frame never executes deferred writes")
	writer.poll()
	writer.poll()
	_check(calls.size() == 1 and int(calls[0][0]) == 0, "At most one FIFO job per idle frame")
	if not calls.is_empty(): _check(int(calls[0][2]) == OS.get_main_thread_id(), "Write callback runs on the main thread")
	if preload("res://tests/helpers/perf_group.gd").enabled():
		_check(writer.last_wait_usec <= Writer.MAX_DELAY_USEC, "First available idle write lands within 0.5 seconds")
	await _next_frame()
	writer.poll()
	_check(calls.size() == 2 and int(calls[1][0]) == 1, "Next job waits until the next frame")
	_check(writer.flush() and calls.size() == 3 and int(calls[2][0]) == 2, "Barrier drains remaining jobs synchronously in FIFO order")
	var replacement := Writer.new()
	var values: Array = []
	replacement.submit(func() -> bool: values.append("old"); return true, true)
	var queued_at: int = replacement._pending[0]["queued_usec"]
	await _next_frame()
	replacement.submit(func() -> bool: values.append("new"); return true, true)
	_check(int(replacement._pending[0]["queued_usec"]) == queued_at, "Replacement inherits the original deadline")
	replacement.poll()
	_check(values == ["new"] and not replacement.busy(), "Continuous superseding cannot starve the next idle write")
	print("PERF03 DEFERRED CADENCE: main thread, later frame, one/frame, busy exclusion, deadline, FIFO barriers")

func _failed_checkpoint_retry() -> void:
	var blocked: String = "user://perf03-checkpoint-blocker"
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	Progression.set_run_storage_path(blocked.path_join("run.save"))
	Progression.queue_run_state(_state(110))
	_check(not Progression.flush_pending_run_saves() and Progression._run_writer.busy(), "Failed checkpoint stays queued")
	_check(not Progression.flush_pending_run_saves() and Progression._run_writer.busy(), "Barrier retries failure and returns false again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	await _next_frame()
	Progression.poll_pending_run_saves()
	_check(not Progression._run_writer.busy() and Progression.load_saved_run() == _state(110), "Next idle frame retries the exact failed snapshot without requeueing")
	var probe := Writer.new()
	var attempts: Array = []
	probe.submit(func() -> bool: attempts.append("old"); return false, true)
	_check(not probe.flush(), "Old snapshot failure fixture")
	probe.submit(func() -> bool: attempts.append("new-failed"); return false, true)
	_check(not probe.flush() and probe._pending.size() == 2, "A failed newer write does not retire the older failed snapshot")
	probe.submit(func() -> bool: attempts.append("newest"); return true, true)
	_check(probe.flush() and not probe.busy() and attempts == ["old", "new-failed", "newest"], "Successful newest checkpoint retires every failed predecessor without writing stale state")
	Progression.clear_saved_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked))
	Progression.set_run_storage_path(SAVE_PATH)
	print("PERF03 CHECKPOINT FAILURE RETENTION/RETRY: PASS" if failures.is_empty() else "PERF03 CHECKPOINT FAILURE RETENTION/RETRY: FAIL")

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _next_frame() -> void:
	var frame: int = Engine.get_process_frames()
	while Engine.get_process_frames() <= frame: await process_frame
