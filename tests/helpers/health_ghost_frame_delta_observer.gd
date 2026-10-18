extends Node

# Test-only observer: run immediately before the clock so its final active
# frame is counted even when it disables processing after draining the ghost.
const PROCESS_PRIORITY_OFFSET: int = 1

var clock: Node
var total_delta: float = 0.0
var frame_count: int = 0

func _init(presentation_clock: Node) -> void:
	clock = presentation_clock
	process_priority = clock.process_priority - PROCESS_PRIORITY_OFFSET

func _process(delta: float) -> void:
	if clock.is_processing():
		total_delta += delta
		frame_count += 1

func reset() -> void:
	total_delta = 0.0
	frame_count = 0
