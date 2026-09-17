extends "res://scripts/protagonist_cutout/rig.gd"

## Creature-owned topology and paint on the production Skeleton2D loader.
const OozeMotion = preload("res://scripts/cinder_ooze_cutout/motion.gd")
const OOZE_BASE: String = "res://assets/units/cinder_ooze_cutout"

func _layout_path(which: String) -> String:
	return OOZE_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else OOZE_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = OozeMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose)
