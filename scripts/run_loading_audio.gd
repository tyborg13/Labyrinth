extends Node

## Optional prewarming only on the scene request's existing wait frames. No
## coroutine, frame request or completion barrier belongs to this job. When the
## scene is ready, the ordinary bank synchronously handles any remaining cues.
const Assets = preload("res://scripts/asset_loader.gd")
const Bank = preload("res://scripts/sfx_bank.gd")
const Alignment = preload("res://scripts/sfx_peak_alignment.gd")

var complete: bool = false
var _stopped: bool = false
var _paths := PackedStringArray()
var _next_path: int = 0
var _last_step_frame: int = -1
var _drain: Node

static func start_for(cover: Node) -> Node:
	var job := new()
	job.name = "LoadingAudioPreparation"
	cover.add_child(job)
	# Reuse the bank's alias/fallback resolution; no voices or RNG are created.
	var reader := Bank.new()
	reader.data = JSON.parse_string(FileAccess.get_file_as_string(Bank.DATA_PATH))
	for cue_id: String in reader.data.get("cues", {}):
		var entry: Dictionary = reader.data["cues"][cue_id]
		if not bool(entry.get("sync_warm_up", false)): continue
		var source: Dictionary = reader._source_entry(cue_id)
		if source.is_empty(): source = entry
		var variants: Array = source.get("variants", [])
		if variants.is_empty(): variants = source.get("fallback", [])
		for path: String in variants:
			if not job._paths.has(path): job._paths.append(path)
	reader.free()
	job._drain = Assets.SourceImageDrain.new()
	job.add_child(job._drain)
	for path: String in job._paths:
		if Assets._audio_cache.has(path): continue
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path, "AudioStream") == OK:
			job._drain.imports.append(path)
	return job

static func step_for(job: Node) -> void:
	if not is_instance_valid(job) or job.complete or job._stopped or job.is_queued_for_deletion(): return
	var frame: int = Engine.get_process_frames()
	if job._last_step_frame == frame: return
	job._last_step_frame = frame
	while job._next_path < job._paths.size():
		var path: String = job._paths[job._next_path]
		if not Assets._audio_cache.has(path):
			# A status check never joins an unfinished load. Leave a failed or
			# unrequested source to the bank's normal loader and fallback policy.
			if not job._drain.imports.has(path):
				job._next_path += 1
				continue
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				job._next_path += 1
				continue
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource != null: job._drain.resources.append(resource)
			job._drain.imports.erase(path)
		var stream: AudioStream = Assets.load_audio_stream(path)
		job._next_path += 1
		if stream == null or Alignment._decoded.has(stream.get_instance_id()): continue
		Alignment.decoded(stream)
		job.complete = job._next_path >= job._paths.size()
		# At most one cold decode on an already-existing scene-wait frame.
		return
	job.complete = true

static func stop_for(job: Node) -> void:
	if is_instance_valid(job): job._stopped = true
	# Keep the drain under the cover. SfxBank consumes every remaining stream
	# at its original first-use point; teardown then reclaims accepted requests.
	# Joining here would turn optional prewarming into a loading deadline.
