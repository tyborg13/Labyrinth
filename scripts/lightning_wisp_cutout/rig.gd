extends "res://scripts/protagonist_cutout/rig.gd"

const WispMotion = preload("res://scripts/lightning_wisp_cutout/motion.gd")
const WISP_BASE: String = "res://assets/units/lightning_wisp_cutout"

func _layout_path(which: String) -> String:
	return WISP_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else WISP_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = WispMotion.sample_pose(clip_name, phase_value, layout, facing)
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		bone.transform = rest_transforms[bone_name]
		bone.position = (pose.get(bone_name, {}) as Dictionary).get("position", bone.position)
