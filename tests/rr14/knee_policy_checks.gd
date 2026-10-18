extends RefCounted

const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const EPSILON: float = 0.0001
const KNEE_SCREEN_SIGN = {"front": -1.0, "rear": 1.0}

static func run(layout: Dictionary, view: String, expect: Callable) -> void:
	var bent: Dictionary = layout.duplicate(true)
	var data: Dictionary = Motion.data_for(layout).duplicate(true)
	bent["joints"]["shin_near"]["position"] = [20.0 + KNEE_SCREEN_SIGN[view] * 3.0, 24.0]
	bent["joints"]["foot_near"]["position"] = [20.0, 28.0]
	var with_policy: Dictionary = Humanoid.world_transforms(data, "move", 0.0, bent, view)
	expect.call(not with_policy.is_empty(), view + ": agreeing bent policy is accepted")
	if with_policy.is_empty(): return
	data["legs"]["near"].erase(view)
	var rest_derived: Dictionary = Humanoid.world_transforms(data, "move", 0.0, bent, view)
	expect.call(not rest_derived.is_empty(), view + ": bent rest policy can be omitted")
	if rest_derived.is_empty(): return
	var a: Vector2 = (rest_derived["thigh_near"] as Transform2D).origin
	var b: Vector2 = (rest_derived["shin_near"] as Transform2D).origin
	var c: Vector2 = (rest_derived["foot_near"] as Transform2D).origin
	expect.call((b.x - a.x) * KNEE_SCREEN_SIGN[view] > EPSILON, view + ": bent rest knee retains its side without policy")
	expect.call(b.distance_to((with_policy["shin_near"] as Transform2D).origin) < EPSILON, view + ": agreeing policy preserves bent rest solve")
	expect.call(absf(a.distance_to(b) - 5.0) < EPSILON and absf(b.distance_to(c) - 5.0) < EPSILON, view + ": bent rest lengths preserved")
