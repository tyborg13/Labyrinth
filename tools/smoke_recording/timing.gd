extends RefCounted
## Movie Maker supplies fixed simulation deltas. Feed the production sampler
## elapsed monotonic time so its JSONL windows still contain measured hitches.

const LIMIT_USEC: int = 33_000
const MAX_SAMPLED_USEC: int = 2_000_000 # The production sampler's upper bound.
const CLOCK: String = "monotonic_process_frame_including_movie_writer"

var tree: SceneTree
var sampler: Node
var last_usec: int
var cohorts: Dictionary = {}
var discarded_intervals: int = 0

func _init(owner: SceneTree, output: String) -> void:
	tree = owner
	sampler = tree.root.get_node("PerformanceTelemetry")
	sampler.call("set_storage_dir_for_test", output.path_join("telemetry"))
	sampler.set_process(false)
	tree.process_frame.connect(_sample)

func _sample() -> void:
	var now: int = Time.get_ticks_usec()
	var elapsed: int = now - last_usec
	var initialized: bool = last_usec > 0
	last_usec = now
	if not initialized or elapsed <= 0: return
	if elapsed > MAX_SAMPLED_USEC:
		discarded_intervals += 1
	else:
		for cohort: String in sampler.get("_active_frame_cohorts"):
			if not cohorts.has(cohort): cohorts[cohort] = {"samples": 0, "over_33_ms": 0}
			var bucket: Dictionary = cohorts[cohort]
			bucket["samples"] += 1
			if elapsed > LIMIT_USEC: bucket["over_33_ms"] += 1
	sampler.call("_process", float(elapsed) / 1_000_000.0)

func finish(output: String) -> bool:
	tree.process_frame.disconnect(_sample)
	sampler.call("flush_now", "smoke_recording_end")
	var file := FileAccess.open(output.path_join("frame-cohorts.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({
		"clock": CLOCK,
		"threshold_usec": LIMIT_USEC,
		"discarded_intervals": discarded_intervals,
		"cohorts": cohorts,
	}, "\t"))
	file.flush()
	return file.get_error() == OK
