extends "res://scripts/protagonist_cutout/rig.gd"

## Creature-specific topology and paint, loaded by the common production skeleton.
const BloomerMotion = preload("res://scripts/bile_bloomer_cutout/motion.gd")
const BLOOMER_BASE: String = "res://assets/units/bile_bloomer_cutout"

func _layout_path(which: String) -> String:
	return BLOOMER_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else BLOOMER_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = BloomerMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose, true)
