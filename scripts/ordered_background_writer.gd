extends RefCounted

const Disk = preload("res://scripts/persistence_disk_worker.gd")
const MAX_DELAY_USEC: int = 500000

class Receipt extends RefCounted:
	var queued: bool = false
	var finished: bool = false
	var succeeded: bool = false

	func resolve(result: bool) -> void:
		succeeded = result
		finished = true

	func wait_in_tree(tree: SceneTree) -> bool:
		var deadline := Time.get_ticks_usec() + Disk.SAVE_DEADLINE_USEC
		while not finished:
			Disk.Job.enforce_wait_deadline(deadline)
			await tree.process_frame
		return succeeded

var _pending: Array[Dictionary]
var _active: Disk.Job
var _active_entry: Dictionary
var _last_attempt_frame: int = -1
var _failed: bool = false
var _draining_in_tree: bool = false
var completed: int = 0
var last_write_usec: int = 0
var last_wait_usec: int = 0
var last_write_frame: int = -1
var last_write_started_usec: int = 0
var last_serialize_usec: int = 0
var last_worker_started_usec: int = 0
var last_worker_usec: int = 0
var _samples: Array[Dictionary]
var track_performance: bool = false
var probe_delay_msec: int = 0

func submit(owned_job: Callable, supersedes: bool = false) -> void:
	submit_prepared(func() -> Callable: return owned_job, supersedes)

func submit_prepared(prepare: Callable, supersedes: bool = false, settled: Callable = Callable(), receipt: Receipt = null) -> void:
	var queued_usec: int = Time.get_ticks_usec()
	var queued_frame: int = Engine.get_process_frames()
	if supersedes:
		# Replacement inherits its queue position/deadline. Keep both in-flight
		# and failed snapshots until a newer transaction actually succeeds.
		if not _pending.is_empty():
			queued_usec = int(_pending[0]["queued_usec"])
			queued_frame = int(_pending[0]["queued_frame"])
		for index: int in range(_pending.size() - 1, -1, -1):
			var entry: Dictionary = _pending[index]
			if entry["receipt"] != null: break
			if bool(entry["supersedes"]) and not bool(entry["failed"]) and not is_same(entry, _active_entry):
				_pending.remove_at(index)
	if receipt != null: receipt.queued = true
	_pending.append({"prepare": prepare, "settled": settled, "supersedes": supersedes,
		"receipt": receipt, "failed": false, "queued_usec": queued_usec, "queued_frame": queued_frame})

func poll(idle: bool = true) -> bool:
	var succeeded: bool = collect()
	var frame: int = Engine.get_process_frames()
	if not can_dispatch() or _last_attempt_frame == frame: return succeeded
	if not idle and oldest_wait_usec() < MAX_DELAY_USEC: return succeeded
	if frame <= int(_pending[_next_index()]["queued_frame"]): return succeeded
	_dispatch(false)
	return succeeded

func flush() -> bool:
	# Joining an existing attempt commits its result before preparing the next.
	# As before, each explicit barrier retries jobs left by prior failures.
	if _active != null:
		_wait_for_active()
	while not _pending.is_empty():
		_dispatch(true)
		if not _wait_for_active(): return false
	return true

func flush_in_tree(tree: SceneTree) -> bool:
	_draining_in_tree = true
	if _active != null: await _wait_for_active_in_tree(tree)
	while not _pending.is_empty():
		_dispatch(true)
		if not await _wait_for_active_in_tree(tree):
			_draining_in_tree = false
			return false
	_draining_in_tree = false
	return true

func collect() -> bool:
	if _active == null or _draining_in_tree: return true
	var result: Dictionary = _active.result(false)
	return result.is_empty() or _finish(result)

func can_dispatch() -> bool:
	return not _draining_in_tree and _active == null and not _pending.is_empty()

func take_failure() -> bool:
	var failed: bool = _failed
	_failed = false
	return failed

func take_samples() -> Array[Dictionary]:
	if _samples.is_empty(): return _samples
	var samples: Array[Dictionary] = _samples
	var empty: Array[Dictionary]
	_samples = empty
	return samples

func busy() -> bool:
	return not _pending.is_empty()

func cancel_pending() -> void:
	if _active != null: _finish(_active.result(true))
	for entry: Dictionary in _pending:
		var receipt: Receipt = entry["receipt"]
		if receipt != null: receipt.resolve(false)
	_pending.clear()

func oldest_wait_usec() -> int:
	return 0 if _pending.is_empty() else Time.get_ticks_usec() - int(_pending[0]["queued_usec"])

func service_wait_usec() -> int:
	if _pending.is_empty(): return 0
	# A failed checkpoint remains due, but cannot starve an analytics batch.
	var since: int = last_write_started_usec if bool(_pending[0]["failed"]) else int(_pending[0]["queued_usec"])
	return Time.get_ticks_usec() - since

func _next_index() -> int:
	if not bool(_pending[0]["supersedes"]): return 0
	for index: int in _pending.size():
		# A receipt pins this exact checkpoint before a dependent append.
		if _pending[index]["receipt"] != null: return index
	return _pending.size() - 1

func _dispatch(barrier: bool) -> void:
	var entry: Dictionary = _pending[_next_index()]
	_last_attempt_frame = Engine.get_process_frames()
	last_write_started_usec = Time.get_ticks_usec()
	last_wait_usec = last_write_started_usec - int(entry["queued_usec"])
	var operation: Callable = entry["prepare"].call()
	last_serialize_usec = Time.get_ticks_usec() - last_write_started_usec
	_active_entry = entry
	_active = Disk.submit(operation, probe_delay_msec)
	last_write_usec = Time.get_ticks_usec() - last_write_started_usec
	last_write_frame = _last_attempt_frame
	if track_performance:
		_samples.append({"started_usec": last_write_started_usec, "elapsed_usec": last_write_usec,
			"serialize_usec": last_serialize_usec, "barrier": barrier})

func _wait_for_active() -> bool:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = _active.result(true)
	if track_performance: _samples.append({"barrier_wait_usec": Time.get_ticks_usec() - started})
	return _finish(result)

func _wait_for_active_in_tree(tree: SceneTree) -> bool:
	var started: int = Time.get_ticks_usec()
	var active := _active
	var result := await active.wait_in_tree(tree)
	# A synchronous reader may already have collected this job.
	if _active != active: return bool(result["succeeded"])
	if track_performance: _samples.append({"barrier_wait_usec": Time.get_ticks_usec() - started})
	return _finish(result)

func _finish(result: Dictionary) -> bool:
	var entry: Dictionary = _active_entry
	_active = null
	_active_entry = {}
	var succeeded: bool = result["succeeded"]
	last_worker_started_usec = result["started_usec"]
	last_worker_usec = result["elapsed_usec"]
	if track_performance:
		_samples.append({"worker_usec": last_worker_usec})
	if succeeded:
		var index: int = _pending.find(entry)
		for _index: int in range(index + 1): _pending.pop_front()
		completed += 1
	else:
		entry["failed"] = true
		_failed = true
	var receipt: Receipt = entry["receipt"]
	entry["receipt"] = null
	var settled: Callable = entry["settled"]
	if receipt != null:
		entry["settled"] = Callable()
		receipt.resolve(succeeded)
	if settled.is_valid(): settled.call(succeeded)
	return succeeded
