extends RefCounted

const Route = preload("res://tools/perf138/controller_route.gd")
const Receipts = preload("res://tools/perf148/paint_receipts.gd")

static func run(probe: SceneTree) -> Dictionary:
	var trace: RefCounted = probe._board.get("_board_redraw_trace")
	return await Route.run(probe, Receipts if trace != null and trace.resolve_inputs else null, true)
