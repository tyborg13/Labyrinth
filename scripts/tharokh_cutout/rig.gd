extends "res://scripts/protagonist_cutout/rig.gd"

## Dragon-owned joints and paint, loaded by the established Skeleton2D loader.
const TharokhMotion = preload("res://scripts/tharokh_cutout/motion.gd")
const THAROKH_BASE: String = "res://assets/units/tharokh_cutout"

func _layout_path(which: String) -> String:
	return THAROKH_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else THAROKH_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = TharokhMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose)
