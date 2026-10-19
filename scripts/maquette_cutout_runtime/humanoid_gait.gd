extends RefCounted

## Gait-only projected legs. World targets are independent of authored pelvis
## offsets. The hero's projected basis preserves width, including oblique bones.
const Tracks = preload("motion.gd")
const EPSILON: float = 0.000001

static func value_at(keys: Array, phase: float) -> float:
	for index: int in range(1, keys.size()):
		var a: Dictionary = keys[index - 1]
		var b: Dictionary = keys[index]
		if phase >= float(a["at"]) and phase <= float(b["at"]) and b["interpolation"] == "sine_power":
			var u: float = inverse_lerp(float(a["at"]), float(b["at"]), phase)
			var weight: float = pow(sin(PI * 0.5 * (u if float(b["value"]) > float(a["value"]) else 1.0 - u)), 1.35)
			return maxf(float(a["value"]), float(b["value"])) * weight
	return Tracks.value_at(keys, phase)

static func skinned(layout: Dictionary, side: String) -> bool:
	for mesh: Dictionary in layout.get("joint_meshes", []):
		if mesh.get("weights", {}).has("thigh_" + side) and mesh.get("weights", {}).has("shin_" + side): return true
	return false

static func prepare(world: Dictionary, authored: Dictionary, order: Array[String], layout: Dictionary, values: Dictionary, forward: Vector2, gait: Dictionary) -> Dictionary:
	var joints: Dictionary = layout["joints"]
	var root: Vector2 = Tracks.point(joints["root"]["position"])
	var scales: Dictionary = {}
	var targets: Dictionary = {}
	var drop: float = 0.0
	for side: String in ["near", "far"]:
		var foot: String = "foot_" + side
		var a: Vector2 = Tracks.point(joints["thigh_" + side]["position"])
		var b: Vector2 = Tracks.point(joints["shin_" + side]["position"])
		var c: Vector2 = Tracks.point(joints[foot]["position"])
		var value: Dictionary = values[foot]
		var anchor: Vector2 = c + Vector2(float(value.get("lane_px", 0.0)), 0.0)
		var ground: Vector2 = anchor + forward * float(value["forward_px"])
		var target: Vector2 = (world["root"] as Transform2D) * (ground - root - Vector2(0.0, float(value["lift_px"])))
		targets[foot] = target
		var length: float = a.distance_to(b) + b.distance_to(c)
		var projection: float = clampf(1.0 + (ground.y - anchor.y) / length, 0.78, float(gait.get("leg_scale_max", 1.22)))
		scales[side] = projection
		var start: Vector2 = (world["thigh_" + side] as Transform2D).origin
		var reach: float = length * projection - 0.10
		var horizontal: float = target.x - start.x
		var vertical: float = sqrt(maxf(0.01, reach * reach - horizontal * horizontal))
		drop = maxf(drop, target.y - start.y - vertical)
	# Fit AFTER all authored offsets, then propagate the translated pelvis.
	var pelvis: Transform2D = authored["pelvis"]
	pelvis.origin.y += drop
	authored["pelvis"] = pelvis
	for name: String in order:
		var parent: String = "" if joints[name].get("parent") == null else str(joints[name]["parent"])
		world[name] = authored[name] if parent.is_empty() else (world[parent] as Transform2D) * (authored[name] as Transform2D)
	for foot: String in targets:
		world[foot] = Transform2D(0.0, targets[foot])
	return scales

static func segment_transform(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var old_axis: Vector2 = original.normalized()
	var new_axis: Vector2 = projected.normalized()
	var basis := Transform2D(old_axis, old_axis.orthogonal(), Vector2.ZERO)
	var result: Transform2D = Transform2D(projected / original.length(), new_axis.orthogonal(), Vector2.ZERO) * basis.affine_inverse()
	result.origin = origin
	return result

static func solve(world: Dictionary, joints: Dictionary, side: String, projection: float, bend: float, skin: bool) -> void:
	var upper: String = "thigh_" + side
	var lower: String = "shin_" + side
	var foot: String = "foot_" + side
	var a: Vector2 = Tracks.point(joints[upper]["position"])
	var b: Vector2 = Tracks.point(joints[lower]["position"])
	var c: Vector2 = Tracks.point(joints[foot]["position"])
	var start: Vector2 = (world[upper] as Transform2D).origin
	var target: Vector2 = (world[foot] as Transform2D).origin
	var first: float = a.distance_to(b) * projection
	var second: float = b.distance_to(c) * projection
	var ray: Vector2 = target - start
	var reach: float = clampf(ray.length(), absf(first - second) + EPSILON, first + second - EPSILON)
	var cosine: float = clampf((first * first + reach * reach - second * second) / (2.0 * first * reach), -1.0, 1.0)
	# Same cross-product convention as the existing humanoid knee policy.
	var knee: Vector2 = start + Vector2.from_angle(ray.angle() + bend * acos(cosine)) * first
	var end: Vector2 = start + ray.normalized() * reach
	world[upper] = segment_transform(b - a, knee - start, start) if skin else Transform2D((knee - start).angle() - (b - a).angle(), start)
	world[lower] = segment_transform(c - b, end - knee, knee) if skin else Transform2D((end - knee).angle() - (c - b).angle(), knee)
	# Feet stay rigid and level; never inherit segment stretch or shear.
	world[foot] = Transform2D(0.0, end)
