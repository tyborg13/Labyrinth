extends "res://scripts/protagonist_cutout/rig.gd"

## Production-owned Zekarion topology and paint reuse the maintained loader.
const DragonMotion = preload("res://scripts/zekarion_cutout/motion.gd")
const DRAGON_BASE: String = "res://assets/units/zekarion_cutout"

func _layout_path(which: String) -> String:
	return DRAGON_BASE.path_join(which+".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else DRAGON_BASE.path_join(path)

func apply_pose(clip_name: String, phase: float) -> void:
	var pose: Dictionary = DragonMotion.sample_pose(clip_name, phase, layout, facing)
	_apply_sampled_pose(pose, true)
