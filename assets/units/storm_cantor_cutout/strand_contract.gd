extends RefCounted

## A source strand and its neck submit one rigid quad. The attachment is the
## existing chain field at the registered source neck; no new motion is keyed.
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")

static func apply(rig: Node2D, presented: bool, _clip: String = "") -> void:
	var inverse: Transform2D = rig.global_transform.affine_inverse()
	for strand: Dictionary in rig.layout.get("rigid_cloth_strands", []):
		var names: Array[String]
		names.assign(["cloak_root", "cloak_mid", "cloak_tip"])
		var at: Vector2 = Motion.point(strand["anchor"])
		var start: Vector2 = Motion.point(rig.layout["joints"][names[0]]["position"])
		var end: Vector2 = Motion.point(rig.layout["joints"][names[-1]]["position"])
		var phase: float = clampf((at-start).dot(end-start)/(end-start).length_squared(),0.0,1.0)*2.0
		var point: Vector2 = Vector2.ZERO
		for i: int in range(names.size()):
			var weight: float = maxf(0.0,1.0-absf(phase-float(i)))
			var pose: Transform2D = inverse * (rig.bones[names[i]] as Bone2D).global_transform
			point += (pose * (at-Motion.point(rig.layout["joints"][names[i]]["position"]))) * weight
		var root_pose: Transform2D = inverse * (rig.bones["cloak_root"] as Bone2D).global_transform
		var world: Transform2D = Transform2D(root_pose.get_rotation(),point)
		var bone: Bone2D = rig.bones[strand["bone"]]
		bone.transform = root_pose.affine_inverse() * world
		if not presented: continue
		var anchor: Transform2D = world # Cloth uses the same source field at its neck; no second anchor rounding.
		for part: Dictionary in rig.layout["parts"]:
			if part["bone"] != strand["bone"]:continue
			var sprite: Sprite2D = bone.get_node(NodePath(part["name"])) as Sprite2D
			var final: Transform2D = anchor * Transform2D(0.0,Motion.point(part["offset"])-at)
			sprite.transform = world.affine_inverse() * final
