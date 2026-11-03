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
	return Tracks.value_at(landed, phase)

static func transform(before: Transform2D, foot_local: Vector2, floor_y: float, angle: float, phase: float, drop: Dictionary) -> Transform2D:
	var contact: Vector2 = before * foot_local
	var distance: float = maxf(0.0, floor_y - contact.y)
	var weight: float = clampf(inverse_lerp(float(drop["start"]), float(drop["land"]), phase), 0.0, 1.0)
	# Constant acceleration from rest: distance is proportional to elapsed².
	if phase < float(drop["land"]):
		return Transform2D(before.get_rotation(), before.origin + Vector2(0.0, distance * weight * weight))
	contact.y += distance
	return Transform2D(angle, contact - foot_local.rotated(angle))
