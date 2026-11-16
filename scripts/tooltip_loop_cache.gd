extends Node
## Indexed WebP frames. Both file IO and decode happen on workers.
const Format = preload("res://scripts/tooltip_loop_format.gd")
## Only a bounded working set is resident, never the entire recording. File IO
## happens on workers; the main thread uploads one bounded frame per tick.
const FRAME_LIMIT: int = 8
const READ_AHEAD: int = 4
const RELEASE_SECONDS: float = 10.0
const MAX_FRAME_BYTES: int = 282 * 168 * 4
static var _instance: Node
var streams: Dictionary = {}
var upload_max_usec: int = 0
var acquire_max_usec: int = 0
var decode_max_usec: int = 0

static func shared() -> Node:
	if not is_instance_valid(_instance):
		_instance = load("res://scripts/tooltip_loop_cache.gd").new()
		_instance.name = "TooltipLoopCache"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_instance)
	return _instance

static func resident_stream_count() -> int:
	return _instance.streams.size() if is_instance_valid(_instance) else 0

func acquire(path: String) -> void:
	var started: int = Time.get_ticks_usec()
	if not streams.has(path):
		streams[path] = {"users": 0, "release_at_usec": 0, "frames": {}, "order": [], "task": -1, "request": -1, "result": {}, "header": {}, "failed": false}
	streams[path]["users"] += 1
	streams[path]["release_at_usec"] = 0
	acquire_max_usec = maxi(acquire_max_usec, Time.get_ticks_usec() - started)

func release(path: String) -> void:
	if streams.has(path):
		streams[path]["users"] = maxi(0, int(streams[path]["users"]) - 1)
		if int(streams[path]["users"]) == 0: streams[path]["release_at_usec"] = Time.get_ticks_usec() + int(RELEASE_SECONDS * 1000000.0)

func header(path: String) -> Dictionary:
	return streams.get(path, {}).get("header", {})

func frame(path: String, index: int) -> Texture2D:
	if not streams.has(path): return null
	var stream: Dictionary = streams[path]
	if stream["frames"].has(index): return stream["frames"][index]
	if int(stream["task"]) < 0 and stream["result"].is_empty() and not bool(stream["failed"]):
		var result: Dictionary = {}
		stream["result"] = result
		stream["request"] = index
		stream["task"] = WorkerThreadPool.add_task(_read.bind(path, index, result))
	return null

static func _read(path: String, index: int, result: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: result["error"] = "Missing recording: " + path; return
	var info: Dictionary = Format.header(file)
	if info.is_empty(): result["error"] = "Invalid TLW2 recording"; return
	result["header"] = info
	var count: int = int(info["count"])
	var actual: int = clampi(index, 0, count - 1)
	var started: int = Time.get_ticks_usec()
	var wanted: int = mini(READ_AHEAD, count - actual)
	var pictures: Dictionary = Format.read_frames(file, info, actual, wanted)
	if pictures.size() != wanted: result["error"] = "Invalid WebP chunk"; return
	result["decode_usec"] = Time.get_ticks_usec() - started
	result["images"] = pictures

func _process(_delta: float) -> void:
	var uploaded: bool = false
	for path: String in streams.keys():
		var stream: Dictionary = streams[path]
		var task: int = int(stream["task"])
		if task >= 0 and WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			stream["task"] = -1
			var completed: Dictionary = stream["result"]
			if completed.has("error"):
				stream["failed"] = true
				push_warning(str(completed["error"]))
				stream["result"] = {}
			else:
				stream["header"] = completed["header"]
				decode_max_usec = maxi(decode_max_usec, int(completed["decode_usec"]))
		if int(stream["task"]) < 0 and not stream["result"].is_empty() and not uploaded:
			var pictures: Dictionary = stream["result"]["images"]
			var index: int = int(pictures.keys()[0])
			var started: int = Time.get_ticks_usec()
			# One upload per tick bounds main-thread first-open work, including
			# the first ever WebP decode (which never runs on this thread).
			stream["frames"][index] = ImageTexture.create_from_image(pictures[index])
			stream["order"].erase(index)
			stream["order"].append(index)
			while stream["order"].size() > FRAME_LIMIT:
				stream["frames"].erase(stream["order"].pop_front())
			pictures.erase(index)
			if pictures.is_empty(): stream["result"] = {}
			upload_max_usec = maxi(upload_max_usec, Time.get_ticks_usec() - started)
			uploaded = true
		if int(stream["users"]) == 0:
			if Time.get_ticks_usec() >= int(stream["release_at_usec"]) and int(stream["task"]) < 0: streams.erase(path)

func resident_bound_bytes() -> int:
	# Conservative CPU+GPU RGBA copies for cached textures, worker RGBA images,
	# read buffer and two display-held textures (cross-fade/current frame).
	var bound: int = 0
	for stream: Dictionary in streams.values():
		bound += (FRAME_LIMIT + 1 + 2 * maxi(1, int(stream["users"]))) * 282 * 168 * 8 + MAX_FRAME_BYTES * READ_AHEAD + Format.MAX_CHUNK_BYTES * 2 + Format.MAX_FRAMES * 16
	return bound

func _exit_tree() -> void:
	for stream: Dictionary in streams.values():
		if int(stream["task"]) >= 0: WorkerThreadPool.wait_for_task_completion(int(stream["task"]))
	streams.clear()
