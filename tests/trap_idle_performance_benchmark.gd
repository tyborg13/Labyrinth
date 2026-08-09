extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ElementData = preload("res://scripts/element_data.gd")

const WARMUP_SAMPLES: int = 4
const MEASURED_SAMPLES: int = 16
const ITERATIONS_PER_SAMPLE: int = 1000

var _errors: Array[String]

func _initialize() -> void:
	var board: Control = CombatBoardView.new()
	root.add_child(board)
	await process_frame
	board.set_process(false)
	var elements: PackedStringArray = ElementData.all_elements()
	for element_id: String in elements:
		var frames: Array[Texture2D] = board.call("_trap_idle_frames_for_element", element_id) as Array[Texture2D]
		_expect(frames.size() == 16, "%s trap idle animation should expose all 16 authored frames" % element_id)
	for _sample: int in range(WARMUP_SAMPLES):
		_measure_lookup_sample(board, elements)
	var samples: Array[float]
	var digest: int = 0
	for _sample: int in range(MEASURED_SAMPLES):
		var sample: Dictionary = _measure_lookup_sample(board, elements)
		samples.append(float(sample.get("us_per_call", 0.0)))
		digest += int(sample.get("digest", 0))
	board.queue_free()
	await process_frame
	await process_frame
	_expect(digest == MEASURED_SAMPLES * ITERATIONS_PER_SAMPLE * elements.size() * 16, "trap frame lookup benchmark digest must retain every frame")
	var results: Dictionary = {
		"schema_version": 1,
		"workload_id": "trap_idle_frame_registry_lookup_v1",
		"elements": elements.size(),
		"frames_per_element": 16,
		"iterations_per_sample": ITERATIONS_PER_SAMPLE,
		"measured_samples": MEASURED_SAMPLES,
		"lookup_us_per_call": _stats(samples),
		"semantic_errors": _errors
	}
	if _errors.is_empty():
		print("TRAP IDLE PERF RESULT: %s" % JSON.stringify(results))
		quit(0)
	else:
		push_error("TRAP IDLE PERF RESULT: FAIL %s" % JSON.stringify(results))
		quit(1)

func _measure_lookup_sample(board: Control, elements: PackedStringArray) -> Dictionary:
	var digest: int = 0
	var started_usec: int = Time.get_ticks_usec()
	for _iteration: int in range(ITERATIONS_PER_SAMPLE):
		for element_id: String in elements:
			var frames: Array[Texture2D] = board.call("_trap_idle_frames_for_element", element_id) as Array[Texture2D]
			digest += frames.size()
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	return {
		"digest": digest,
		"us_per_call": float(elapsed_usec) / float(ITERATIONS_PER_SAMPLE * maxi(1, elements.size()))
	}

func _stats(source: Array[float]) -> Dictionary:
	var values: Array[float] = source.duplicate()
	values.sort()
	if values.is_empty():
		return {"median": 0.0, "p95": 0.0, "max": 0.0, "mean": 0.0}
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"max": values[values.size() - 1],
		"mean": total / float(values.size())
	}

func _percentile(sorted_values: Array[float], percentile: float) -> float:
	var index: int = clampi(int(ceil(float(sorted_values.size()) * percentile)) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
