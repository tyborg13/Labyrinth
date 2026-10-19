extends RefCounted

## Snap the deformation relative to bind, so fractional native joints preserve
## exact rest and idle pixels. Meshes use these same snapped Bone2D transforms.
const Pixels = preload("pixel_presentation.gd")
const Motion = preload("motion.gd")
const Humanoid = preload("humanoid_motion.gd")
const Gait = preload("humanoid_gait.gd")

static func apply(rig: Node2D, clip: String) -> void:
	var source: Transform2D = rig.global_transform.affine_inverse()
	var world: Dictionary = {}
	var gait: bool = Motion.data_for(rig.layout).get("clips", {}).get(clip, {}).has("gait")
	preload("humanoid_continuations.gd").apply(rig, gait, clip)
	var targets: Dictionary = rig.layout["_gait_world_targets"] if gait else {}
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		var pose: Transform2D = source * bone.global_transform
		var bind: Vector2 = Motion.point(rig.layout["joints"][name]["position"])
		var angle: float = snappedf(pose.get_rotation(), Pixels.ROTATION_STEP)
		# The simultaneous limits and 1.5-degree presentation require the nearest
		# in-limit step (4 degrees therefore presents at 3, never at 4.5).
		if name == "torso":
			var limit: float = deg_to_rad(25.0 if clip == "death" else 4.0)
			limit = floorf(limit / Pixels.ROTATION_STEP) * Pixels.ROTATION_STEP
			angle = clampf(angle, -limit, limit)
		world[name] = Transform2D(angle, bind + (pose.origin - bind).round())
		if targets.has(name):
			world[name] = Transform2D(angle, Gait.snapped_world_target(targets[name], bind, rig.global_transform))
		if gait and (name.begins_with("thigh_") or name.begins_with("shin_")) and Gait.skinned(rig.layout, name.get_slice("_", 1)):
			var projected: Transform2D = Transform2D(angle - pose.get_rotation(), Vector2.ZERO) * pose
			projected.origin = bind + (pose.origin - bind).round()
			world[name] = projected
	# Independent world snapping can add one step to the head's relative
	# angle when the torso rounds down. Enforce the same authored limit.
	if world.has("head") and world.has("torso"):
		var head: Transform2D = world["head"]
		var torso: Transform2D = world["torso"]
		var limit: float = deg_to_rad(20.0 if clip == "death" else 6.0)
		limit = floorf(limit / Pixels.ROTATION_STEP) * Pixels.ROTATION_STEP
		var relative: float = wrapf(head.get_rotation() - torso.get_rotation(), -PI, PI)
		if absf(relative) > limit:
			world["head"] = Transform2D(torso.get_rotation() + clampf(relative, -limit, limit), head.origin)
	for name: String in rig.bones:
		var parent: String = Humanoid.parent_name(rig.layout["joints"][name])
		var local: Transform2D = world[name]
		if not parent.is_empty(): local = (world[parent] as Transform2D).affine_inverse() * local
		(rig.bones[name] as Bone2D).transform = local
	var replaced: Dictionary = {}
	for mesh: Dictionary in rig.layout.get("joint_meshes", []): replaced[mesh["replaces_part"]] = true
	for part: Dictionary in rig.layout["parts"]:
		if replaced.has(part["name"]): continue
		var bone: Bone2D = rig.bones[part["bone"]]
		var sprite: Sprite2D = bone.get_node(NodePath(part["name"]))
		var pose: Transform2D = world[part["bone"]]
		var bind: Vector2 = Motion.point(rig.layout["joints"][part["bone"]]["position"])
		var reference: Vector2 = Motion.point(part.get("presentation_anchor", part["offset"]))
		var anchor: Transform2D = Pixels.snapped_transform(pose * Transform2D(0.0, reference - bind))
		var final: Transform2D = anchor * Transform2D(0.0, Motion.point(part["offset"]) - reference)
		sprite.transform = pose.affine_inverse() * final
