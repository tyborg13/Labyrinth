extends RefCounted
## Capture-only lossless RGB spool. PNG compression runs after gameplay exits,
## so compression cannot stretch production wall-clock animation durations.
const MAX_QUEUED_FRAMES: int = 8
var _thread := Thread.new()
var _mutex := Mutex.new()
var _signal := Semaphore.new()
var _queue: Array[Dictionary] = _empty_queue()
var _directory: String
var _stopping: bool = false
var _failure: String = ""
var _peak_queued: int = 0
var _written: int = 0

static func _empty_queue() -> Array[Dictionary]:
	var result: Array[Dictionary]
	return result

func start(directory: String) -> Error:
	_directory = directory
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	return _thread.start(_write_frames)

func append(frame: int, image: Image) -> bool:
	image.convert(Image.FORMAT_RGB8)
	_mutex.lock()
	if not _failure.is_empty():
		_mutex.unlock()
		return false
	if _queue.size() >= MAX_QUEUED_FRAMES:
		_failure = "Native RGB spool exceeded its bounded queue; reject this timing-sensitive take"
		_mutex.unlock()
		return false
	_queue.append({"frame": frame, "data": image.get_data()})
	_peak_queued = maxi(_peak_queued, _queue.size())
	_mutex.unlock()
	_signal.post()
	return true

func finish() -> Dictionary:
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_signal.post()
	if _thread.is_started():
		_thread.wait_to_finish()
	return {"written_frames": _written, "peak_queued_frames": _peak_queued, "queue_limit_frames": MAX_QUEUED_FRAMES, "failure": _failure}

func _write_frames() -> void:
	while true:
		_signal.wait()
		_mutex.lock()
		if _queue.is_empty():
			var done: bool = _stopping
			_mutex.unlock()
			if done:
				return
			continue
		var entry: Dictionary = _queue.pop_front()
		_mutex.unlock()
		var output := FileAccess.open("%s/frame%08d.rgb" % [_directory, int(entry["frame"])], FileAccess.WRITE)
		if output == null:
			_mutex.lock()
			_failure = "Failed to open native RGB frame"
			_mutex.unlock()
			continue
		output.store_buffer(entry["data"] as PackedByteArray)
		output.flush()
		var write_error: Error = output.get_error()
		output.close()
		if write_error != OK:
			_mutex.lock()
			_failure = "Failed to write complete native RGB frame (error %d)" % write_error
			_mutex.unlock()
			continue
		_written += 1
