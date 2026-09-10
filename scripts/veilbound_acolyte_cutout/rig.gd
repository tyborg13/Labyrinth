extends "res://scripts/protagonist_cutout/rig.gd"

const VeilboundMotion = preload("res://scripts/veilbound_acolyte_cutout/motion.gd")
const VEILBOUND_BASE: String = "res://assets/units/veilbound_acolyte_cutout"

func _layout_path(which: String) -> String:
	return VEILBOUND_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else VEILBOUND_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = VeilboundMotion.sample_pose(clip_name, phase_value, layout, facing)
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position", bone.position)
		bone.rotation = float(override.get("rotation", 0.0))
		bone.scale = override.get("scale", Vector2.ONE)
		bone.skew = float(override.get("skew", 0.0))
		bone.visible = bool(override.get("visible", true))
