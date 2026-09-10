extends "res://scripts/protagonist_cutout/rig.gd"

## Dragon-owned topology and paint, using the shared production skeleton loader.
const IskaldraMotion = preload("res://scripts/iskaldra_cutout/motion.gd")
const ISKALDRA_BASE: String = "res://assets/units/iskaldra_cutout"

func _layout_path(which: String) -> String:
	return ISKALDRA_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else ISKALDRA_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = IskaldraMotion.sample_pose(clip_name,phase_value,layout,facing)
	_apply_dragon_pose(pose)

func apply_walk_pose(phase_value: float, travel_per_cycle: float) -> void:
	_apply_dragon_pose(IskaldraMotion.sample_pose("walk",phase_value,layout,facing,travel_per_cycle))

func _apply_dragon_pose(pose: Dictionary) -> void:
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name,{})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position",bone.position)
		bone.rotation = float(override.get("rotation",0.0))
		bone.scale = override.get("scale",Vector2.ONE)
		bone.skew = float(override.get("skew",0.0))
