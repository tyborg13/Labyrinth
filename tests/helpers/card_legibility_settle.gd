extends RefCounted

const STABLE_FRAMES: int = 3
const TIMEOUT_SECONDS: float = 3.0
const TRANSFORM_EPSILON: float = 0.0

# Delayed Tweeners are already running before their first transform write.
# Drain finite tweens, including their delays, before accepting stable frames.
static func wait_for(tree: SceneTree, faces: Array) -> Dictionary:
	var start: int = Time.get_ticks_msec()
	var stable: int = 0
	var previous: Array = []
	while Time.get_ticks_msec() - start < int(TIMEOUT_SECONDS * 1000.0):
		await tree.process_frame
		var current: Array = snapshot(faces)
		var pending: bool = false
		for tween: Tween in tree.get_processed_tweens():
			if not tween.is_running(): continue
			# Infinite cosmetic loops cannot be awaited. Any transform changes
			# they cause are still caught by the ancestor snapshots below.
			if tween.has_method("get_loops_left") and int(tween.call("get_loops_left")) < 0: continue
			pending = true
		stable = stable + 1 if not pending and same(previous, current) else 0
		previous = current
		if stable >= STABLE_FRAMES:
			return {"settled": true, "stable_frames": stable, "elapsed_ms": Time.get_ticks_msec() - start, "ancestors": current}
	return {"settled": false, "stable_frames": stable, "elapsed_ms": Time.get_ticks_msec() - start, "ancestors": previous, "error": "Transforms did not settle within 3 s"}

static func snapshot(faces: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for face: Node in faces:
		var node: Node = face
		while node != null:
			if not seen.has(node.get_instance_id()):
				seen[node.get_instance_id()] = true
				if node is CanvasItem or node is CanvasLayer:
					var t: Transform2D = node.get_global_transform_with_canvas() if node is CanvasItem else node.transform
					result.append({"path": str(node.get_path()), "transform": [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]})
			node = node.get_parent()
	return result

static func same(left: Array, right: Array) -> bool:
	if left.size() != right.size() or left.is_empty(): return false
	for index: int in range(left.size()):
		if left[index]["path"] != right[index]["path"]: return false
		for axis: int in range(6):
			if absf(float(left[index]["transform"][axis]) - float(right[index]["transform"][axis])) > TRANSFORM_EPSILON: return false
	return true
