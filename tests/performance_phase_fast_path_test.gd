extends SceneTree
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Partitioner = preload("res://scripts/performance_phase_partitioner.gd")
const Reference = preload("res://tests/fixtures/performance_phase_partitioner_reference.gd")
func _initialize() -> void:
	Runtime.apply_from_environment()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260918
	var comparisons: int = 0
	for fixture: int in range(1600):
		var intervals: Array = [null, "ignored", {}]
		for index: int in range(rng.randi_range(0, 30)):
			var start: int = rng.randi_range(-40, 140)
			var end: int = start + rng.randi_range(-10, 60)
			if fixture % 2 == 0:
				start = index * 3
				end = 190 - index * 3
			intervals.append({"phase": "p%d" % (index % 7), "start_usec": start, "end_usec": end, "priority": rng.randi_range(-1, 3), "diagnostic_only": index % 11 == 0, "exclude_covered_cpu": index % 22 == 0})
		for window: Vector2i in [Vector2i(-1000, 1000), Vector2i(20, 85), Vector2i(40, 40)]:
			assert(Partitioner.partition(intervals, window.x, window.y) == Reference.partition(intervals, window.x, window.y), "Exact totals, tie-breaks, ambiguity, exclusions and segment counts")
			comparisons += 1
	var nested: Array[Dictionary]
	for index: int in range(300):
		nested.append({"phase": "p%d" % (index % 7), "start_usec": index, "end_usec": 1200 - index, "priority": index % 3})
	var timings: Dictionary = {}
	for variant: String in ["reference", "candidate", "candidate_repeat", "reference_repeat"]:
		var started: int = Time.get_ticks_usec()
		for repeat: int in range(80):
			if variant.begins_with("reference"): Reference.partition(nested)
			else: Partitioner.partition(nested)
		timings[variant] = Time.get_ticks_usec() - started
	print("PHASE FAST PATH RESULT: " + JSON.stringify({"comparisons": comparisons, "timings_usec": timings}))
	print("TEST RESULT: PASS")
	quit()
