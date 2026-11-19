extends Node

## Optional prewarming on existing loading-cover frames. The bank handles the
## remainder if the cover finishes before this job.
const Assets = preload("res://scripts/asset_loader.gd")
const Bank = preload("res://scripts/sfx_bank.gd")
const Alignment = preload("res://scripts/sfx_peak_alignment.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")

var complete: bool = false
var _stopped: bool = false
var _paths := PackedStringArray()
var _align: Dictionary = {}
var _imports: PackedStringArray
var _next_path: int = 0
var _last_step_frame: int = -1

static func start_for(cover: Node) -> Node:
	var job := new()
	job.name = "LoadingAudioPreparation"
	cover.add_child(job)
	# Reuse the bank's alias/fallback resolution; no voices or RNG are created.
	var reader := Bank.new()
	reader.data = JSON.parse_string(FileAccess.get_file_as_string(Bank.DATA_PATH))
	for cue_id: String in reader.data.get("cues", {}):
		var entry: Dictionary = reader.data["cues"][cue_id]
		var source: Dictionary = reader._source_entry(cue_id)
		if source.is_empty(): source = entry
		var variants: Array = source.get("variants", [])
		if variants.is_empty(): variants = source.get("fallback", [])
		for path: String in variants:
			if not job._paths.has(path): job._paths.append(path)
			if bool(entry.get("sync_warm_up", false)): job._align[path] = true
	reader.free()
	for entry: Dictionary in RunSfx.SFX.values():
		var path: String = str(entry.get("path", ""))
		if not path.is_empty() and not job._paths.has(path): job._paths.append(path)
	# First-service contact sounds need both a stream and its PCM alignment.
	# Keep them at the front even when the scene starts from a warm request.
	var ordered := PackedStringArray(job._align.keys())
	for path: String in job._paths:
		if not job._align.has(path): ordered.append(path)
	job._paths = ordered
	for path: String in job._align:
		if Assets._audio_cache.has(path) or Assets._should_prefer_source_file(path, Assets.AUDIO_EXTENSIONS): continue
		if ResourceLoader.exists(path) and SceneLoads.request_for(cover.get_tree(), path, "AudioStream") == OK:
			job._imports.append(path)
	return job

static func step_for(job: Node) -> void:
	if not is_instance_valid(job) or job.complete or job._stopped or job.is_queued_for_deletion(): return
	var frame: int = Engine.get_process_frames()
	if job._last_step_frame == frame: return
	job._last_step_frame = frame
	while job._next_path < job._paths.size():
		var path: String = job._paths[job._next_path]
		var cold: bool = not Assets._audio_cache.has(path)
		if job._imports.has(path):
			if not _publish_import(job, path): return
			# Give the audio decode its own slice after a cold import.
			return
		var stream: AudioStream = Assets.load_audio_stream(path)
		job._next_path += 1
		if job._align.has(path) and stream != null and not Alignment._decoded.has(stream.get_instance_id()):
			Alignment.decoded(stream)
			return
		if cold: return
	job.complete = true

static func finish_required_imports_for(job: Node, present: Callable, active: Callable) -> void:
	while is_instance_valid(job) and not job._imports.is_empty() and bool(active.call()):
		for path: String in job._imports.duplicate():
			if Assets.preparation_slice_full(): break
			var started := Time.get_ticks_usec()
			_publish_import(job, path)
			Assets.count_preparation_work(started)
		if job._imports.is_empty(): return
		await present.call()

static func _publish_import(job: Node, path: String) -> bool:
	var tree := job.get_tree()
	if SceneLoads.status_for(tree, path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return false
	var imported := SceneLoads.take_for(tree, path) as AudioStream
	if imported != null and not Assets._audio_cache.has(path): Assets._audio_cache[path] = imported
	job._imports.erase(path)
	return true

static func stop_for(job: Node) -> void:
	if is_instance_valid(job): job._stopped = true

func _exit_tree() -> void:
	for path: String in _imports:
		SceneLoads.abandon_for(get_tree(), path)
