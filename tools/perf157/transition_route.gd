extends RefCounted

const Route = preload("res://tools/perf138/controller_route.gd")
const Paint = preload("res://tools/perf148/paint_receipts.gd")
const Transitions = preload("res://tools/perf157/transition_receipts.gd")

static func run(probe: SceneTree) -> Dictionary:
	var trace: RefCounted = probe._board._board_redraw_trace
	var receipts: bool = trace != null and trace.resolve_inputs
	return await Route.run(probe, Paint if receipts else null, true, Transitions if receipts else null, true)
