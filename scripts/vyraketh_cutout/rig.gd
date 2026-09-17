extends "res://scripts/protagonist_cutout/rig.gd"

## Vyraketh owns its dragon topology/paint; the shared loader owns Godot meshes.
const VyrakethMotion = preload("res://scripts/vyraketh_cutout/motion.gd")
const VYRAKETH_BASE: String = "res://assets/units/vyraketh_cutout"

func _layout_path(which: String) -> String:
	return VYRAKETH_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else VYRAKETH_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = VyrakethMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose, true)
