extends RefCounted

# Historical filename; callbacks run synchronously on the main thread.
# Polling executes at most one job per frame, after its enqueue frame.
# Barriers bypass that cadence, stop on failure, and retain the failing job.
const MAX_DELAY_USEC: int = 500000
var _pending: Array[Dictionary]
var _last_attempt_frame: int = -1
var _failed: bool = false
var completed: int = 0
var last_write_usec: int = 0
var last_wait_usec: int = 0
var last_write_frame: int = -1
var last_write_started_usec: int = 0

func submit(owned_job: Callable, supersedes: bool = false) -> void:
	var queued_usec: int = Time.get_ticks_usec()
	var queued_frame: int = Engine.get_process_frames()
	if supersedes:
		# Replacement inherits its queue position/deadline. A stream of newer
		# snapshots must not postpone the first available idle write forever.
		if not _pending.is_empty():
			queued_usec = int(_pending[0]["queued_usec"])
			queued_frame = int(_pending[0]["queued_frame"])
		# Retain failed snapshots until a newer write actually succeeds.
		for index: int in range(_pending.size() - 1, -1, -1):
			if bool(_pending[index]["supersedes"]) and not bool(_pending[index]["failed"]):
				_pending.remove_at(index)
	_pending.append({"job": owned_job, "supersedes": supersedes, "failed": false,
		"queued_usec": queued_usec, "queued_frame": queued_frame})

func poll(idle: bool = true) -> bool:
	var frame: int = Engine.get_process_frames()
	if _pending.is_empty() or _last_attempt_frame == frame: return true
	if not idle and oldest_wait_usec() < MAX_DELAY_USEC: return true
	var index: int = _next_index()
	if frame <= int(_pending[index]["queued_frame"]): return true
	return _attempt(index)

func flush() -> bool:
	while not _pending.is_empty():
		if not _attempt(_next_index()): return false
	return true

func take_failure() -> bool:
	var failed: bool = _failed
	_failed = false
	return failed

func busy() -> bool:
	return not _pending.is_empty()

func cancel_pending() -> void:
	# Explicit run deletion cancels its remaining writes, including failed jobs.
	# Ordinary failure/retry paths never call this.
	_pending.clear()

func oldest_wait_usec() -> int:
	return 0 if _pending.is_empty() else Time.get_ticks_usec() - int(_pending[0]["queued_usec"])

func service_wait_usec() -> int:
	if _pending.is_empty(): return 0
	# A failed checkpoint remains due, but cannot starve an analytics batch.
	var since: int = last_write_started_usec if bool(_pending[0]["failed"]) else int(_pending[0]["queued_usec"])
	return Time.get_ticks_usec() - since

func _next_index() -> int:
	return _pending.size() - 1 if bool(_pending[0]["supersedes"]) else 0

func _attempt(index: int) -> bool:
	var entry: Dictionary = _pending[index]
	_last_attempt_frame = Engine.get_process_frames()
	var started: int = Time.get_ticks_usec()
	last_write_started_usec = started
	last_wait_usec = started - int(entry["queued_usec"])
	var succeeded: bool = bool((entry["job"] as Callable).call())
	last_write_usec = Time.get_ticks_usec() - started
	last_write_frame = _last_attempt_frame
	if succeeded:
		for _index: int in range(index + 1): _pending.pop_front()
		completed += 1
	else:
		entry["failed"] = true
		_failed = true
	return succeeded
