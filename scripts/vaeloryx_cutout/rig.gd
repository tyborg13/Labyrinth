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
	_apply_sampled_pose(pose, true)
