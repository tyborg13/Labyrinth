extends SceneTree

const FrameSink = preload("res://tools/steam_trailer_frame_sink.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color(0.1, 0.2, 0.3, 1.0))
	var directory: String = ProjectSettings.globalize_path("user://frame_sink_success")
	var success = FrameSink.new()
	assert(success.start(directory) == OK)
	for frame: int in range(3):
		assert(success.append(frame, image))
	var result: Dictionary = success.finish()
	assert(result["failure"] == "" and result["written_frames"] == 3)
	for frame: int in range(3):
		assert(FileAccess.get_file_as_bytes("%s/frame%08d.rgb" % [directory, frame]) == image.get_data())
	print("PASS frame sink: threaded drain preserves all native RGB bytes")

	var failure_directory: String = ProjectSettings.globalize_path("user://frame_sink_write_failure")
	assert(DirAccess.make_dir_recursive_absolute(failure_directory.path_join("frame00000000.rgb")) == OK)
	var failure = FrameSink.new()
	assert(failure.start(failure_directory) == OK)
	assert(failure.append(0, image))
	var failed: Dictionary = failure.finish()
	assert(failed["written_frames"] == 0 and not str(failed["failure"]).is_empty())
	assert(not failure.append(1, image))
	assert(failure.get("_failure") == failed["failure"])
	print("PASS frame sink: actual failed file open rejects capture and retains first diagnostic")

	# An unstarted consumer deliberately saturates the public producer queue.
	# The ninth frame must be rejected instead of allocating an unbounded backlog.
	var stalled = FrameSink.new()
	for frame: int in range(FrameSink.MAX_QUEUED_FRAMES):
		assert(stalled.append(frame, image))
	assert(not stalled.append(FrameSink.MAX_QUEUED_FRAMES, image))
	var bounded: Dictionary = stalled.finish()
	assert(bounded["peak_queued_frames"] == FrameSink.MAX_QUEUED_FRAMES)
	assert(not str(bounded["failure"]).is_empty())
	print("PASS frame sink: stalled consumer cannot exceed eight queued frames")
	quit()
