extends SceneTree

const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Lifecycle = preload("res://scripts/run_persistence.gd")
const Writer = preload("res://scripts/ordered_background_writer.gd")
const DEBUG_FRAME_RATE: int = 100
const SECOND_QUEUE_DELAY_USEC: int = 250000
const TEST_TIMEOUT_USEC: int = 2000000
var failures: Array[String]

class BusyHost extends Node:
	var _analytics_store = Analytics.new()
	func _process(_delta: float) -> void:
		Lifecycle.mark_resolution_frame()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Engine.max_fps = DEBUG_FRAME_RATE
	call_deferred("_run")

func _run() -> void:
	# Staggered queues share frames one write at a time; simultaneous overdue queues both meet the cap.
	await _busy_deadline(SECOND_QUEUE_DELAY_USEC, true)
	await _busy_deadline(0, false)
	await _failed_save_cannot_starve_events()
	for failure: String in failures: push_error(failure)
	print("PERF03 DEADLINE RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _busy_deadline(second_queue_delay_usec: int, one_write_per_frame: bool) -> void:
	Store.set_run_storage_path("user://perf03-deadline.save")
	Store.clear_saved_run()
	Analytics.set_storage_dir("user://perf03-deadline-analytics")
	Analytics.clear_storage()
	var host := BusyHost.new()
	root.add_child(host)
	Lifecycle.attach(host)
	Lifecycle.expect_resolution_after_draw(host)
	Store.queue_run_state({"surface_rules_version": Store.SURFACE_RULES_VERSION, "checkpoint": 701})
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var max_frame_usec: int = 0
	var events_queued: bool = false
	if second_queue_delay_usec == 0:
		# Same frame as the checkpoint, so both queues pass the cap on the same frame.
		host._analytics_store.write_event("perf03_busy_deadline")
		events_queued = true
	var writes_by_frame: Dictionary = {}
	while Time.get_ticks_usec() - started < TEST_TIMEOUT_USEC:
		await process_frame
		var now: int = Time.get_ticks_usec()
		max_frame_usec = maxi(max_frame_usec, now - previous)
		previous = now
		if not events_queued and now - started >= second_queue_delay_usec:
			host._analytics_store.write_event("perf03_busy_deadline")
			events_queued = true
		for writer: RefCounted in [Store._run_writer, Analytics._writer]:
			if writer.completed > 0:
				writes_by_frame[writer.last_write_frame] = int(writes_by_frame.get(writer.last_write_frame, 0)) | (1 if writer == Store._run_writer else 2)
		if events_queued and not Store._run_writer.busy() and not Analytics._writer.busy(): break
	var waits: Dictionary = {"checkpoint": Store._run_writer.last_wait_usec, "analytics": Analytics._writer.last_wait_usec}
	for kind: String in waits:
		_check(int(waits[kind]) >= Writer.MAX_DELAY_USEC, kind + " remains deferred before the cap on every busy frame")
		if preload("res://tests/helpers/perf_group.gd").enabled():
			_check(int(waits[kind]) <= Writer.MAX_DELAY_USEC + max_frame_usec, kind + " lands within 0.5 seconds plus one observed frame")
	_check(not Store._run_writer.busy() and not Analytics._writer.busy(), "Both writes run while resolution/post-draw exclusion stays continuously active")
	if one_write_per_frame:
		for mask: int in writes_by_frame.values(): _check(mask != 3, "At most one checkpoint OR analytics batch per automatic frame")
	else:
		_check(writes_by_frame.values().has(3), "Queues that pass the cap together are both written on that frame")
	Lifecycle.resume_resolution_after_draw(host)
	host.free()
	print("PERF03 BUSY FRAME DEADLINE: second_queue_delay_usec=%d waits_usec=%s max_frame_usec=%d" % [second_queue_delay_usec, JSON.stringify(waits), max_frame_usec])

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _failed_save_cannot_starve_events() -> void:
	var path: String = "user://perf03-deadline-failing.save"
	Store.set_run_storage_path(path)
	Store.save_run_state({"surface_rules_version": Store.SURFACE_RULES_VERSION, "checkpoint": 700})
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	var host := BusyHost.new()
	root.add_child(host)
	Lifecycle.attach(host)
	Lifecycle.expect_resolution_after_draw(host)
	Store.queue_run_state({"surface_rules_version": Store.SURFACE_RULES_VERSION, "checkpoint": 701})
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var max_frame_usec: int = 0
	var queued: bool = false
	while Time.get_ticks_usec() - started < TEST_TIMEOUT_USEC:
		await process_frame
		var now: int = Time.get_ticks_usec()
		max_frame_usec = maxi(max_frame_usec, now - previous)
		previous = now
		if not queued and now - started >= SECOND_QUEUE_DELAY_USEC:
			host._analytics_store.write_event("perf03_deadline_behind_failed_save")
			queued = true
		if queued and not Analytics._writer.busy(): break
	_check(Store._run_writer.busy(), "Faulted checkpoint remains queued while unrelated analytics completes")
	_check(queued and not Analytics._writer.busy(), "Repeated failing writes cannot starve another overdue writer")
	if preload("res://tests/helpers/perf_group.gd").enabled():
		_check(Analytics._writer.last_wait_usec <= Writer.MAX_DELAY_USEC + max_frame_usec, "Analytics behind a failed checkpoint still meets its cap")
	print("PERF03 FAILED SAVE FAIRNESS: analytics_wait_usec=%d max_frame_usec=%d" % [Analytics._writer.last_wait_usec, max_frame_usec])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	Lifecycle.resume_resolution_after_draw(host)
	host.free()
	_check(int(Store.load_saved_run().get("checkpoint", -1)) == 701, "Repair/barrier finally writes the retained checkpoint")
