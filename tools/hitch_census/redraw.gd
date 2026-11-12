extends RefCounted
## Signal-gap estimates, never exclusive _draw CPU timers.
var counts: Dictionary = {}
var estimates: Dictionary = {}
var polygons: Dictionary = {}
var totals: Dictionary = {}
var frames_with_redraw: Dictionary = {}
var first_us: int = 0
var last_us: int = 0
var pending_key: String = ""
var pending_end_us: int = 0

func register(node: Node, callback: Callable) -> void:
	if node is CanvasItem:
		var connection: Callable = callback.bind(node)
		if not node.draw.is_connected(connection): node.draw.connect(connection)

func key(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null and not script.resource_path.is_empty(): return script.resource_path
	return "builtin:" + node.get_class()

func record(node: CanvasItem, now: int) -> void:
	close(now)
	var label: String = key(node)
	counts[label] = int(counts.get(label, 0)) + 1
	if node is Polygon2D:
		var entry: Dictionary = polygons.get(label, {"vertices": 0, "internal_polygons": 0})
		entry["vertices"] += node.polygon.size()
		entry["internal_polygons"] += node.polygons.size()
		polygons[label] = entry
	if first_us == 0: first_us = now
	last_us = now
	pending_key = label

func close(now: int) -> void:
	if pending_key.is_empty() or now < pending_end_us: return
	estimates[pending_key] = float(estimates.get(pending_key, 0.0)) + float(now - pending_end_us) / 1000.0
	pending_key = ""

func drain(now: int) -> Array:
	close(now)
	for label: String in counts:
		totals[label] = int(totals.get(label, 0)) + int(counts[label])
		frames_with_redraw[label] = int(frames_with_redraw.get(label, 0)) + 1
	var result: Array = [counts, estimates, float(last_us - first_us) / 1000.0 if first_us > 0 else 0.0, polygons]
	counts = {}
	estimates = {}
	polygons = {}
	first_us = 0
	last_us = 0
	return result
