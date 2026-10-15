extends "res://scripts/protagonist_cutout/rig.gd"

const ShrikeMotion = preload("motion.gd")
const SHRIKE_BASE: String = "res://assets/units/gust_shrike_cutout"

func _layout_path(which: String) -> String:
	return SHRIKE_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else SHRIKE_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	_apply_sampled_pose(ShrikeMotion.sample_pose(clip_name, phase_value, layout, facing))
