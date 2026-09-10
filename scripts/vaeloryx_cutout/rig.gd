extends "res://scripts/protagonist_cutout/rig.gd"

## Vaeloryx owns its dragon graph and paint; the shared production loader owns
## Skeleton2D/Polygon2D construction and source-space mesh binding.
const DragonMotion = preload("res://scripts/vaeloryx_cutout/motion.gd")
const DRAGON_BASE: String = "res://assets/units/vaeloryx_cutout"

func _layout_path(which: String) -> String:
	return DRAGON_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else DRAGON_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = DragonMotion.sample_pose(clip_name, phase_value, layout, facing)
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position", bone.position)
		bone.rotation = float(override.get("rotation", 0.0))
		bone.scale = override.get("scale", Vector2.ONE)
		bone.skew = float(override.get("skew", 0.0))
		bone.visible = bool(override.get("visible", true))
