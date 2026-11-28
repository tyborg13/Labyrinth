extends RefCounted
## Spool unaltered RGBA frames on a worker. The companion process reads only
## closed spools, counts changed pixels and turns them into wall-clock video.

const SIZE := Vector2i(1920, 1080)
const QUEUE_LIMIT := 16

var problem: String
var _previous: PackedByteArray
var _image: Image
var _directory: String
var _file: FileAccess
var _recorder: AudioEffectRecord
var _worker := Thread.new()
var _mutex := Mutex.new()
var _pending := Semaphore.new()
var _queue: Array[PackedByteArray]
var _closed: bool = false
var _write_failed: bool = false


func begin(output: String, action: int, viewport: Viewport, recorder: AudioEffectRecord) -> bool:
	_directory = output.path_join("spool/%05d" % action)
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		problem = "cannot create " + _directory
		return false
	_file = FileAccess.open(_directory.path_join("frames.rgba"), FileAccess.WRITE)
	if _file == null or _worker.start(_write_frames) != OK:
		problem = "cannot start framebuffer spool"
		return false
	_recorder = recorder
	frame(viewport)
	if not problem.is_empty(): return false
	_recorder.set_recording_active(true)
	return true


func frame(viewport: Viewport) -> bool:
	_image = viewport.get_texture().get_image()
	if _image == null or _image.get_size() != SIZE:
		problem = "expected 1920x1080 renderer frame"
		return false
	_image.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = _image.get_data()
	var changed: bool = bytes != _previous
	_previous = bytes
	_mutex.lock()
	if _write_failed or _queue.size() >= QUEUE_LIMIT:
		problem = "framebuffer spool failed or could not keep up"
	else:
		_queue.append(bytes)
		_pending.post()
	_mutex.unlock()
	return changed


func finish(result: Dictionary) -> bool:
	_recorder.set_recording_active(false)
	var audio: AudioStreamWAV = _recorder.get_recording()
	_join()
	if _write_failed:
		problem = "could not write framebuffer spool"
		return false
	if audio == null or audio.save_to_wav(_directory.path_join("audio.wav")) != OK:
		problem = "could not save the native master bus recording"
		return false
	var poster: String = _directory.path_join("../../renderer-proof.png").simplify_path()
	if not FileAccess.file_exists(poster):
		if _image.save_png(poster) != OK:
			problem = "could not save native proof image"
			return false
		print(poster)
	var record: String = _directory.path_join("record.tmp")
	var file := FileAccess.open(record, FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(result) + "\n"):
		problem = "could not save native capture index"
		return false
	file.close()
	if DirAccess.rename_absolute(record, _directory.path_join("record.json")) != OK:
		problem = "could not publish native capture index"
	return problem.is_empty()


func discard() -> void:
	if _recorder != null: _recorder.set_recording_active(false)
	_join()


func _join() -> void:
	if not _worker.is_started(): return
	_mutex.lock()
	_closed = true
	_mutex.unlock()
	_pending.post()
	_worker.wait_to_finish()
	_file = null


func _write_frames() -> void:
	while true:
		_pending.wait()
		_mutex.lock()
		var bytes: PackedByteArray
		if not _queue.is_empty(): bytes = _queue.pop_front()
		var done: bool = _closed and bytes.is_empty()
		_mutex.unlock()
		if done: return
		if not bytes.is_empty() and not _file.store_buffer(bytes):
			_mutex.lock()
			_write_failed = true
			_mutex.unlock()
