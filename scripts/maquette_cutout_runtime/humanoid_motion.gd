extends RefCounted

## Source-pixel v2 sampler. Opt-in only; legacy semantic rigs keep their sampler.
const Tracks = preload("motion.gd")
const SOLVE_EPSILON: float = 0.000001

static func channels(data: Dictionary, clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var values: Dictionary = {}
	var step: float = float(layout.get("step_distance_px", 0.0)) / maxf(float(layout.get("screen_pixel_scale", 1.0)), SOLVE_EPSILON)
	var root_progress: float = 0.0
	for track: Dictionary in data["view_tracks"][facing][clip]:
		if track["bone"] == "root" and track["channel"] == "forward_px":
			root_progress = Tracks.value_at(track["keys"], phase)
	for track: Dictionary in data["view_tracks"][facing][clip]:
		var bone: String = str(track["bone"])
		if not values.has(bone): values[bone] = {}
		var value: float = Tracks.value_at(track["keys"], phase)
		if track["channel"] == "forward_px":
			match str(track["forward_mode"]):
				"fraction_of_step": value *= step
				"world_step": value = (value - root_progress) * step
		values[bone][track["channel"]] = value
	return values

static func offset(value: Dictionary, forward: Vector2, pivot: Vector2, root: Vector2) -> Vector2:
	return forward * float(value.get("forward_px", 0.0)) + Vector2(
		signf(root.x - pivot.x) * float(value.get("inward_px", 0.0)), -float(value.get("lift_px", 0.0)))

static func parent_name(joint: Dictionary) -> String:
	return "" if joint.get("parent") == null else str(joint["parent"])

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var data: Dictionary = Tracks.data_for(layout)
	if clip == "rest" or not data.get("clips", {}).has(clip): return {}
	var transforms: Dictionary = world_transforms(data, clip, clampf(phase, 0.0, 1.0), layout, facing)
	var result: Dictionary = {}
	for name: String in transforms:
		var parent: String = parent_name(layout["joints"][name])
		var local: Transform2D = transforms[name]
		if not parent.is_empty(): local = (transforms[parent] as Transform2D).affine_inverse() * local
		result[name] = {"position": local.origin, "rotation": local.get_rotation(), "scale": Vector2.ONE}
	return result

static func world_transforms(data: Dictionary, clip: String, phase: float, layout: Dictionary, facing: String, released: bool = true) -> Dictionary:
	var values: Dictionary = channels(data, clip, phase, layout, facing)
	var joints: Dictionary = layout["joints"]
	var forward: Vector2 = Tracks.point(data["projection"][facing]["forward"])
	var root: Vector2 = Tracks.point(joints["root"]["position"])
	var result: Dictionary = {}
	var pending: Array = joints.keys()
	while not pending.is_empty():
		for raw_name: Variant in pending.duplicate():
			var name: String = str(raw_name)
			var joint: Dictionary = joints[name]
			var parent: String = parent_name(joint)
			if not parent.is_empty() and not result.has(parent): continue
			var pivot: Vector2 = Tracks.point(joint["position"])
			var origin: Vector2 = pivot - (Vector2.ZERO if parent.is_empty() else Tracks.point(joints[parent]["position"]))
			var value: Dictionary = values.get(name, {})
			var local := Transform2D(deg_to_rad(float(value.get("lean_deg", 0.0))), origin + offset(value, forward, pivot, root))
			result[name] = local if parent.is_empty() else (result[parent] as Transform2D) * local
			pending.erase(raw_name)
	# The unrotated FK chain supplies each hand's parent-relative target. Solve
	# only keyed hands; unkeyed arms retain their complete FK translation.
	for side: String in ["near", "far"]:
		var hand: String = "hand_" + side
		var value: Dictionary = values.get(hand, {})
		if value.has("forward_px") or value.has("lift_px") or value.has("inward_px"):
			_solve_two_bone(result, joints, "upper_" + side, "fore_" + side, hand)
		var foot: String = "foot_" + side
		value = values.get(foot, {})
		# Hem-parented feet retain their existing FK behaviour. A visible leg
		# is identified by its actual hierarchy, never by the creature's name.
		if joints.has(foot) and parent_name(joints[foot]) == "shin_" + side and joints.has("thigh_" + side) and parent_name(joints["shin_" + side]) == "thigh_" + side:
			if value.has("forward_px") or value.has("lift_px") or value.has("inward_px"):
				_solve_two_bone(result, joints, "thigh_" + side, "shin_" + side, foot, true)
	# Held items keep their rest world orientation, independent of solved hands.
	for chain: Dictionary in layout.get("ik_chains", []):
		var target: String = str(chain["target"])
		var value: Dictionary = values.get(target, {})
		if value.has("forward_px") or value.has("lift_px") or value.has("inward_px"):
			_solve_two_bone(result, joints, str(chain["first"]), str(chain["second"]), target)
	for item: String in layout.get("held_items", {}):
		var attachment: Dictionary = layout["held_items"][item]
		var hand: String = str(attachment["hand"])
		var angle: float = deg_to_rad(float(values.get(item, {}).get("angle_deg", 0.0)))
		var pivot: Vector2 = (result[hand] as Transform2D).origin
		var release: float = float(data["clips"][clip].get("release_at", {}).get(item, INF))
		if released and phase >= release:
			var at_release: Dictionary = world_transforms(data, clip, release, layout, facing, false)
			var before: Transform2D = at_release[item]
			var rest_grip: Vector2 = Tracks.point(joints[item]["position"])
			var foot_local: Vector2 = Tracks.point(attachment["floor_end"]) - rest_grip
			var floor_pivot: Vector2 = before * foot_local
			pivot = floor_pivot - foot_local.rotated(angle)
		result[item] = Transform2D(angle, pivot)
	return result

static func _solve_two_bone(world: Dictionary, joints: Dictionary, upper: String, fore: String, hand: String, full_extension: bool = false) -> void:
	var a: Vector2 = Tracks.point(joints[upper]["position"])
	var b: Vector2 = Tracks.point(joints[fore]["position"])
	var c: Vector2 = Tracks.point(joints[hand]["position"])
	var shoulder: Vector2 = (world[upper] as Transform2D).origin
	var target: Vector2 = (world[hand] as Transform2D).origin
	var first: float = a.distance_to(b)
	var second: float = b.distance_to(c)
	var ray: Vector2 = target - shoulder
	# Keep the established arm arithmetic byte-stable. Legs may reach exact
	# full extension; neither chain ever stretches beyond its rest lengths.
	var distance: float = clampf(ray.length(), absf(first - second) + SOLVE_EPSILON, first + second if full_extension else first + second - SOLVE_EPSILON)
	var axis: Vector2 = ray.normalized() if ray.length() > SOLVE_EPSILON else (c - a).normalized()
	var along: float = (first * first - second * second + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, first * first - along * along))
	var bend_side: float = signf((c - a).cross(b - a))
	if is_zero_approx(bend_side): bend_side = 1.0
	var elbow: Vector2 = shoulder + axis * along + Vector2(-axis.y, axis.x) * height * bend_side
	var wrist: Vector2 = shoulder + axis * distance
	var upper_angle: float = (elbow - shoulder).angle() - (b - a).angle()
	var fore_angle: float = (wrist - elbow).angle() - (c - b).angle()
	world[upper] = Transform2D(wrapf(upper_angle, -PI, PI), shoulder)
	world[fore] = Transform2D(wrapf(fore_angle, -PI, PI), elbow)
	world[hand] = Transform2D(wrapf(fore_angle, -PI, PI), wrist)
	# Non-target attachments (for example a rigid claw) follow the solved
	# chain. Held items receive their world-angle policy in the next pass.
	for name: String in joints:
		if name in [upper, fore, hand]: continue
		var parent: String = parent_name(joints[name])
		if parent == hand:
			var local: Vector2 = Tracks.point(joints[name]["position"]) - c
			world[name] = (world[hand] as Transform2D) * Transform2D(0.0, local)
