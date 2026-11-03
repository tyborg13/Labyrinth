extends RefCounted

const MONITORS: Dictionary = {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

static func read() -> Dictionary:
	var result: Dictionary = {}
	for name: String in MONITORS: result[name] = int(Performance.get_monitor(MONITORS[name]))
	return result

static func difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name: String in MONITORS: result[name] = int(after[name]) - int(before[name])
	return result

static func total(counts: Dictionary) -> int:
	var result: int = 0
	for value: int in counts.values(): result += absi(value)
	return result
