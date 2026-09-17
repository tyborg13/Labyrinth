extends "res://scripts/protagonist_cutout/rig.gd"

## Dust Acolyte paint/topology reuse the production Skeleton2D loader.
const AcolyteMotion = preload("res://scripts/acolyte_cutout/motion.gd")
const ACOLYTE_BASE: String = "res://assets/units/acolyte_cutout"

func _layout_path(which: String) -> String:
	return ACOLYTE_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else ACOLYTE_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = AcolyteMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose, true)
