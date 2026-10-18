extends RefCounted

const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const EPSILON: float = 0.0001
const CHILD_LIFT_PX: float = 1.0
const CHILD_ANGLE_DEG: float = 17.0
const GRANDCHILD_LIFT_PX: float = 0.5
const GRANDCHILD_ANGLE_DEG: float = -7.0
const ITEM_ANGLE_DEG: float = 13.0

static func run(layout: Dictionary, view: String, expect: Callable) -> void:
	var attached: Dictionary = layout.duplicate(true)
	var data: Dictionary = Motion.data_for(layout).duplicate(true)
	# Intentionally put a grandchild before its parent in JSON order. Both a
	# solved terminal and a held item with a final world angle carry a subtree.
	for parent: String in ["claw", "tube"]:
		var base: Vector2 = Motion.point(layout["joints"][parent]["position"])
		var child: String = parent + "_keyed_child"
		var grandchild: String = parent + "_grandchild"
		attached["joints"][grandchild] = {"position": [base.x + 3.0, base.y + 4.0], "parent": child}
		attached["joints"][child] = {"position": [base.x + 2.0, base.y + 1.0], "parent": parent}
		key(data, view, child, "lift_px", CHILD_LIFT_PX)
		key(data, view, child, "lean_deg", CHILD_ANGLE_DEG)
		key(data, view, grandchild, "lift_px", GRANDCHILD_LIFT_PX)
		key(data, view, grandchild, "lean_deg", GRANDCHILD_ANGLE_DEG)
	key(data, view, "tube", "angle_deg", ITEM_ANGLE_DEG)
	var world: Dictionary = Humanoid.world_transforms(data, "move", 0.5, attached, view)
	expect.call(absf((world["tube"] as Transform2D).get_rotation() - deg_to_rad(ITEM_ANGLE_DEG)) < EPSILON, view + ": held item final world angle")
	for parent: String in ["claw", "tube"]:
		var child: String = parent + "_keyed_child"
		var grandchild: String = parent + "_grandchild"
		var expected_local := Transform2D(deg_to_rad(CHILD_ANGLE_DEG), Vector2(2.0, 1.0 - CHILD_LIFT_PX))
		var expected_grandchild := Transform2D(deg_to_rad(GRANDCHILD_ANGLE_DEG), Vector2(1.0, 3.0 - GRANDCHILD_LIFT_PX))
		var local: Transform2D = (world[parent] as Transform2D).affine_inverse() * (world[child] as Transform2D)
		var expected: Transform2D = (world[parent] as Transform2D) * expected_local * expected_grandchild
		expect.call(local.origin.distance_to(expected_local.origin) < EPSILON, view + ": keyed child keeps its one-pixel local lift: " + parent)
		expect.call(absf(local.get_rotation() - expected_local.get_rotation()) < EPSILON, view + ": keyed child keeps authored local rotation: " + parent)
		expect.call((world[grandchild] as Transform2D).origin.distance_to(expected.origin) < EPSILON, view + ": grandchild follows the final parent transform: " + parent)
		expect.call(absf((world[grandchild] as Transform2D).get_rotation() - expected.get_rotation()) < EPSILON, view + ": grandchild keeps authored local rotation: " + parent)

static func key(data: Dictionary, view: String, bone: String, channel: String, value: float) -> void:
	data["view_tracks"][view]["move"].append({"bone": bone, "channel": channel, "forward_mode": "pixels",
		"keys": [{"at": 0.0, "value": value, "interpolation": "hold"}]})
