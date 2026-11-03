extends RefCounted

## Opt-in release translation. Existing held items retain their floor-end path.
const Tracks = preload("res://scripts/maquette_cutout_runtime/motion.gd")

static func angle_at(keys: Array, phase: float, drop: Dictionary) -> float:
	# Falling stays vertical. Landing replaces the first angular interval's
	# start, while every subsequent director key retains its original clock.
	var start: float = float(drop["start"])
	var land: float = float(drop["land"])
	if phase <= land: return Tracks.value_at(keys, minf(phase, start))
	var landed: Array[Dictionary]
	landed.append({"at": land, "value": Tracks.value_at(keys, start), "interpolation": "smoothstep"})
	for key: Dictionary in keys:
		if float(key["at"]) > land: landed.append(key)
	var value: float = Tracks.value_at(landed, phase) * float(drop.get("rotation_sign", 1.0))
	if drop.has("floor_travel_deg"):
		value *= float(drop["floor_travel_deg"]) / float(drop["floor_key_limit_deg"])
	if drop.has("floor_limit_deg"):
		var limit: float = float(drop["floor_limit_deg"])
		value = clampf(value, minf(0.0, limit), maxf(0.0, limit))
	return value

static func transform(before: Transform2D, foot_local: Vector2, floor_y: float, angle: float, phase: float, drop: Dictionary) -> Transform2D:
	var contact: Vector2 = before * foot_local
	var distance: float = maxf(0.0, floor_y - contact.y)
	var weight: float = clampf(inverse_lerp(float(drop["start"]), float(drop["land"]), phase), 0.0, 1.0)
	# Constant acceleration from rest: distance is proportional to elapsed².
	if phase < float(drop["land"]):
		return Transform2D(before.get_rotation(), before.origin + Vector2(0.0, distance * weight * weight))
	contact.y += distance
	var pose := Transform2D(angle, contact - foot_local.rotated(angle))
	# The long staff rolls across its tiny butt bevel before lying flat. Keep
	# the live silhouette support on the floor instead of stopping at that bevel.
	if drop.has("support_points_local"):
		var lowest: float = -INF
		for point: Array in drop["support_points_local"]:
			lowest = maxf(lowest, (pose * Vector2(float(point[0]), float(point[1]))).y)
		pose.origin.y += floor_y - lowest
	return pose

## Called only for this case's explicitly declared painted floor contract.
## Restore the exact support angle after the ordinary 1.5-degree quantizer.
static func presented(world: Dictionary, layout: Dictionary, clip: String, item: String) -> bool:
	if clip != "death": return false
	var state: Dictionary = layout.get("_painted_floor_pose", {})
	if not state.get("landed", false): return false
	var points: Array = layout["held_items"][item]["painted_floor"]["points_local"]
	var pose: Transform2D = state["transform"]
	var lowest: float = -INF
	for point: Array in points:
		lowest = maxf(lowest, (pose * Vector2(float(point[0]), float(point[1]))).y)
	pose.origin.y += float(layout["held_items"][item]["floor_line_y"]) - lowest
	world[item] = pose
	return true
