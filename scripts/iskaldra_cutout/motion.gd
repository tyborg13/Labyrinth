extends RefCounted

## Crouched crystal dragon: rigid wings/claws, supporting hind legs, curled tail.
const STANCE: float = 0.66
const STRIDE: float = 48.0
const FOOT_LIFT: float = 6.0

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String, travel_per_cycle: float = 0.0) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": point(layout, name) - point(layout, parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var rear: bool = facing == "rear"
	var direction: Vector2 = (Vector2(1, -0.5) if rear else Vector2(-1, 0.5)).normalized()
	var sign: float = -1.0 if rear else 1.0
	if clip == "idle":
		# One shared translation. Legs/tail counter it; all bind bases stay fixed.
		var bob := Vector2(0, -1.7 * (0.5 - 0.5 * cos(TAU * t)))
		pose["pelvis"]["position"] += bob
		for name: String in ["hip_near", "hip_far", "tail"]:
			pose[name]["position"] -= bob
	elif clip == "walk":
		pose["pelvis"]["position"] += Vector2(0, -2.8 * (0.5 - 0.5 * cos(TAU * t * 2.0)))
		pose["arm_near"]["rotation"] = sign * 0.085 * sin(TAU * t)
		pose["arm_far"]["rotation"] = -sign * 0.065 * sin(TAU * t)
		# Wings and tail retain their rigid panels; no mesh flutter is added.
		for side: String in ["near", "far"]:
			var support: Dictionary = walk_foot_state(t, "foot_" + side, layout, facing, travel_per_cycle)
			_solve_hind_leg(pose, layout, side, support["target"], float(support["lift_px"]), rear)
	elif clip == "talon":
		var prep: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.35,1),Vector2(0.50,0),Vector2(1,0)]))
		var rake: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.35,0),Vector2(0.50,1),Vector2(0.62,0.85),Vector2(1,0)]))
		# Corresponding visible foreclaw changes screen-side in the reverse view.
		var arm: String = "arm_far" if rear else "arm_near"
		var claw: String = "talon_far" if rear else "talon_near"
		pose["torso"]["position"] += direction * (-2.5 * prep + 5.0 * rake)
		pose[arm]["rotation"] = sign * (-0.28 * prep + 0.68 * rake)
		pose[claw]["rotation"] = sign * (0.12 * prep + 0.16 * rake)
		pose["head"]["rotation"] = sign * 0.035 * rake
	elif clip == "lance":
		var gather: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.32,1),Vector2(0.35,1),Vector2(0.45,0),Vector2(1,0)]))
		var release: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.35,0),Vector2(0.45,1),Vector2(0.65,0.85),Vector2(1,0)]))
		pose["head"]["position"] += -direction * 2.0 * gather + direction * 5.0 * release
		pose["head"]["rotation"] = sign * (0.055 * gather - 0.06 * release)
		pose["torso"]["position"] += direction * (-1.5 * gather + 2.0 * release)
		_wings(pose, facing, 0.045 * gather - 0.035 * release)
	elif clip == "storm":
		var gather: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.35,1),Vector2(0.50,0),Vector2(1,0)]))
		var release: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.35,0),Vector2(0.50,1),Vector2(0.62,0.8),Vector2(1,0)]))
		pose["torso"]["position"] += Vector2(0, 2.0 * gather - 3.0 * release)
		_wings(pose, facing, 0.10 * gather - 0.14 * release)
		pose["arm_near"]["rotation"] = sign * (-0.07 * gather + 0.13 * release)
		pose["arm_far"]["rotation"] = -sign * (-0.07 * gather + 0.13 * release)
	elif clip == "mantle":
		var guard: float = curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.62,1),Vector2(1,0)]))
		_wings(pose, facing, 0.055 * guard)
		pose["torso"]["position"] += Vector2(0, 1.0 * guard)
	return pose

static func _wings(pose: Dictionary, facing: String, fold: float) -> void:
	# Positive fold closes the two rigid panels toward the dorsal ridge.
	pose["wing_near"]["rotation"] = -fold if facing == "rear" else fold
	pose["wing_far"]["rotation"] = fold if facing == "rear" else -fold

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction":direction, "stride_px":STRIDE, "stance_fraction":STANCE,
		"travel_per_cycle":direction * STRIDE / STANCE, "foot_lift_px":FOOT_LIFT}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String, travel_per_cycle: float = 0.0) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout, facing)
	var stride: float = travel_per_cycle * STANCE if travel_per_cycle > 0.0 else STRIDE
	var t: float = fposmod(phase + (0.5 if foot == "foot_far" else 0.0), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = stride * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -stride * (1.0 - STANCE) / STANCE
		distance = lerpf(-stride * 0.5, stride * 0.5, u*u*(3.0-2.0*u)) + tangent * (2.0*u*u*u-3.0*u*u+u)
		lift = FOOT_LIFT * pow(sin(PI * u), 1.5)
	var sole: Vector2 = _sole(layout, foot)
	# Keep each authored sole's complete rest registration, including its
	# fore/aft offset. Both soles are grounded at phase zero and at whole cycles.
	# A finite segment adjusts stride distance, never the painted paw basis.
	var initial_distance: float = stride * (0.5 - (0.5 if foot == "foot_far" else 0.0) / STANCE)
	var ground_contact: Vector2 = sole + Vector2(info["direction"]) * (distance - initial_distance)
	var target: Vector2 = ground_contact - (sole - point(layout, foot)) - Vector2(0,lift)
	return {"target":target,"ground_contact":ground_contact,"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func _sole(layout: Dictionary, foot: String) -> Vector2:
	var p: Array = layout["landmarks"]["sole_" + foot.trim_prefix("foot_")]
	return Vector2(float(p[0]),float(p[1]))

static func _solve_hind_leg(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, lift: float, rear: bool) -> void:
	var hip_name: String = "hip_" + side
	var knee_name: String = "knee_" + side
	var foot_name: String = "foot_" + side
	var bind_hip: Vector2 = point(layout,hip_name)
	var bind_knee: Vector2 = point(layout,knee_name)
	var bind_foot: Vector2 = point(layout,foot_name)
	var parent_world: Transform2D = world(pose,layout,parent(layout,hip_name))
	var hip: Vector2 = world(pose,layout,hip_name).origin
	# Projected lengths vary independently; painted width and rigid paws do not.
	var knee: Vector2 = bind_knee + (hip-bind_hip)*0.45 + (target-bind_foot)*0.55
	var bend_sign: float = -1.0 if rear else 1.0
	knee += Vector2(bend_sign * 0.40 * lift, -0.35 * lift)
	var hip_world: Transform2D = _segment(bind_knee-bind_hip,knee-hip,hip)
	var knee_world: Transform2D = _segment(bind_foot-bind_knee,target-knee,knee)
	_store(pose,hip_name,parent_world.affine_inverse()*hip_world)
	_store(pose,knee_name,hip_world.affine_inverse()*knee_world)
	_store(pose,foot_name,knee_world.affine_inverse()*Transform2D(0.0,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var result: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO) * Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

static func _store(pose: Dictionary, name: String, value: Transform2D) -> void:
	pose[name] = {"position":value.origin,"rotation":value.get_rotation(),"scale":value.get_scale(),"skew":value.get_skew()}

static func point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))

static func parent(layout: Dictionary, name: String) -> String:
	var p: Variant = layout["joints"][name]["parent"]
	return "" if p == null else str(p)

static func world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():
		return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return world(pose,layout,parent(layout,name)) * Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1,keys.size()):
		if t <= keys[i].x:
			var u: float = inverse_lerp(keys[i-1].x,keys[i].x,t)
			return lerpf(keys[i-1].y,keys[i].y,u*u*(3.0-2.0*u))
	return keys[-1].y
