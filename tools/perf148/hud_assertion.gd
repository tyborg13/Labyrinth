extends RefCounted

const Hud = preload("res://scripts/board_hud_retention.gd")
const PAINT_FRAMES: int = 2

# Keep both forced repaints outside the measured input window. Receipt
# collection is enabled only while this separate draw trace is active.
static func verify(probe: SceneTree) -> Dictionary:
	var board: Control = probe._board
	var trace: RefCounted = board.get("_board_redraw_trace")
	if trace == null or trace.confirm_baseline or not trace.resolve_inputs: return {}
	await probe._wait_frames(PAINT_FRAMES)
	var rows: Array[Dictionary]
	trace.begin()
	for record: Dictionary in board._aim_focus.canvases.values():
		if not bool(record.hud) or not is_instance_valid(record.canvas): continue
		var canvas: Control = record.canvas
		if not canvas.is_visible_in_tree() or canvas._render_slice_ops.is_empty(): continue
		var wanted: Variant = _current(canvas, record.unit)
		if wanted == null or wanted != record.get("paint_inputs"): continue
		rows.append({"canvas": canvas, "wanted": wanted, "unit": record.unit,
			"prior": canvas.get_meta("perf148_painted_receipt", [])})
		canvas.remove_meta("perf148_painted_receipt")
		canvas.queue_redraw()
	await probe._wait_frames(PAINT_FRAMES)
	var stable: Array[Dictionary]
	var tabs: Array[Dictionary]
	for row: Dictionary in rows:
		var canvas: Control = row.canvas
		if not is_instance_valid(canvas) or not canvas.is_visible_in_tree(): continue
		if _current(canvas, row.unit) != row.wanted: continue
		var operation: Array = canvas._render_slice_ops[0]
		var receipt: Array = canvas.get_meta("perf148_painted_receipt", [])
		if receipt.slice(0, 2) != row.wanted:
			probe._errors.append("HUD repaint disagrees with the scheduled %s inputs" % operation[0])
			continue
		if row.prior.slice(0, 2) == row.wanted and row.prior != receipt:
			probe._errors.append("HUD retained receipt differs from forced %s repaint" % operation[0])
		if operation[0] == "_draw_slice_intent_chip":
			var badge: Dictionary = operation[1][0]
			if canvas._tooltip_regions != Hud.badge_tooltip(canvas.get_parent(), badge):
				probe._errors.append("Retained intent tooltip disagrees with current inputs")
			if bool(badge.get("contextual", false)):
				var tab: Control = canvas.get_node_or_null(NodePath("IntentTab_" + str(badge["key"])))
				if not is_instance_valid(tab):
					probe._errors.append("Missing retained contextual intent tab")
				else:
					tabs.append(_repaint_tab(probe, tab, badge))
		row["receipt"] = receipt
		stable.append(row)
		canvas.remove_meta("perf148_painted_receipt")
		canvas.queue_redraw()
	await probe._wait_frames(PAINT_FRAMES)
	trace.finish()
	var counts: Dictionary = {}
	for row: Dictionary in stable:
		if not is_instance_valid(row.canvas) or not row.canvas.is_visible_in_tree(): continue
		var canvas: Control = row.canvas
		if _current(canvas, row.unit) != row.wanted: continue
		var method: String = canvas._render_slice_ops[0][0]
		if canvas.get_meta("perf148_painted_receipt", []) != row.receipt:
			probe._errors.append("Retained HUD receipt changed on forced %s repaint for %s" % [method, row.unit.get("key", "")])
		counts[method] = int(counts.get(method, 0)) + 1
	for tab: Dictionary in tabs:
		if tab.get("painted") != tab["retained"]:
			probe._errors.append("Retained contextual intent tab changed on forced repaint")
		counts["intent_tab"] = int(counts.get("intent_tab", 0)) + 1
	return counts

static func _repaint_tab(probe: SceneTree, tab: Control, badge: Dictionary) -> Dictionary:
	var ink: Control = tab.ink
	var retained: Array = Hud.tab_inputs(ink.badge)
	if retained != Hud.tab_inputs(badge):
		probe._errors.append("Retained contextual intent tab disagrees with current inputs")
	var receipt: Dictionary = {"retained": retained}
	ink.draw.connect(func() -> void: receipt["painted"] = Hud.tab_inputs(ink.badge), CONNECT_ONE_SHOT)
	ink.queue_redraw()
	return receipt

static func _current(canvas: Control, unit: Dictionary) -> Variant:
	var source: Control = canvas.get_parent() as Control
	var operation: Array = canvas._render_slice_ops[0]
	var paint: Variant = Hud.piece_inputs(source, operation[0], operation[1], unit)
	return [Hud.environment(source), paint] if paint != null else null
