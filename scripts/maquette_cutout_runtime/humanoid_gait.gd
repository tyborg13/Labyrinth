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

static func world_targets(data: Dictionary, layout: Dictionary, facing: String, clip: String, phase: float) -> Dictionary:
	# Read world-step progress directly. Subtracting and adding root travel,
	# then reconstructing a foot through Bone2D, can cross a half-pixel tie.
	var values: Dictionary = {}
	for track: Dictionary in data["view_tracks"][facing][clip]:
		var bone: String = str(track["bone"])
		if not bone.begins_with("foot_"): continue
		if not values.has(bone): values[bone] = {}
		values[bone][track["channel"]] = value_at(track["keys"], phase)
	var forward: Vector2 = Tracks.point(data["projection"][facing]["forward"])
	var step: float = float(layout.get("step_distance_px", 0.0)) / maxf(float(layout.get("screen_pixel_scale", 1.0)), EPSILON)
	var targets: Dictionary = {}
	for foot: String in values:
		var value: Dictionary = values[foot]
		targets[foot] = Tracks.point(layout["joints"][foot]["position"]) + forward * float(value["forward_px"]) * step + Vector2(float(value["lane_px"]), -float(value["lift_px"]))
	return targets

static func snapped_world_target(target: Vector2, bind: Vector2, to_world: Transform2D) -> Vector2:
	# Snap once in the common world, before deriving a root-relative position.
	# The painted bind is the grid's anchor: fractional registered pivots must
	# retain the rr-05 whole-pixel TRANSLATIONS, including at zero travel.
	var anchor: Vector2 = to_world * bind
	return to_world.affine_inverse() * (anchor + (to_world * target - anchor).round())

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

## Same landing clock and half-step envelope as the legacy hand swing. Outside
## the rest-to-rest clip, a delayed forearm samples rest rather than wrapping.
static func arm_wave(gait: Dictionary, side: String, phase: float) -> float:
	if phase <= 0.0 or phase >= 1.0: return 0.0
	var count: int = int(gait["steps_per_tile"]) - 1
	var half_stance: float = float(gait["stance_fraction"]) / float(count)
	var previous_phase: float = 0.0
	var previous_value: float = 0.0
	for step: int in range(1, count + 2):
		var landed_side: String = str(gait["lead"]) if step % 2 == 1 else ("far" if gait["lead"] == "near" else "near")
		var landing: float = float(step) / float(count) - half_stance if step <= count else 1.0
		var amplitude: float = 0.5 if step == 1 or step == count + 1 else 1.0
		var value: float = amplitude * (-1.0 if side == landed_side else 1.0) if step <= count else 0.0
		if phase <= landing:
			return lerpf(previous_value, value, smoothstep(previous_phase, landing, phase))
		previous_phase = landing
		previous_value = value
	return 0.0

static func shoulder_pendulum(world: Dictionary, joints: Dictionary, gait: Dictionary, seconds: float, phase: float, forward: Vector2) -> void:
	var arms: Dictionary = gait.get("arm_swing", {})
	if arms.get("model", "") != "shoulder_pendulum": return
	for side: String in ["near", "far"]:
		if not arms.has(side): continue
		var arm: Dictionary = arms[side]
		var upper: String = "upper_" + side
		var fore: String = "fore_" + side
		var hand: String = "hand_" + side
		var a: Vector2 = Tracks.point(joints[upper]["position"])
		var b: Vector2 = Tracks.point(joints[fore]["position"])
		var c: Vector2 = Tracks.point(joints[hand]["position"])
		var shoulder: Transform2D = world[upper]
		var base_angle: float = shoulder.get_rotation()
		# Positive wave moves the downward arm toward projected facing.
		var direction: float = signf((c - a).cross(forward))
		var wave: float = arm_wave(gait, side, phase)
		var delayed: float = arm_wave(gait, side, phase - float(arm["forearm_lag_s"]) / seconds)
		var upper_angle: float = base_angle + deg_to_rad(float(arm["upper_deg"]) * wave * direction)
		var bend_side: float = signf((b - a).cross(c - b))
		var bend: float = float(arm["forearm_bend_deg"]["forward" if delayed >= 0.0 else "back"]) * absf(delayed)
		var fore_angle: float = base_angle + deg_to_rad(float(arm["upper_deg"]) * delayed * direction + bend * bend_side)
		var elbow: Vector2 = shoulder.origin + (b - a).rotated(upper_angle)
		var wrist: Vector2 = elbow + (c - b).rotated(fore_angle)
		world[upper] = Transform2D(upper_angle, shoulder.origin)
		world[fore] = Transform2D(fore_angle, elbow)
		world[hand] = Transform2D(fore_angle, wrist)

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
