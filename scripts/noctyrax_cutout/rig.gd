extends "res://scripts/protagonist_cutout/rig.gd"

## Dragon topology and paint reuse the production skeleton loader.
const NoctyraxMotion = preload("res://scripts/noctyrax_cutout/motion.gd")
const NOCTYRAX_BASE: String = "res://assets/units/noctyrax_cutout"
var _paint_facing: String = ""
var _paint: Dictionary = {}
var _default_layers: Dictionary = {}

func _layout_path(which: String) -> String:
	return NOCTYRAX_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else NOCTYRAX_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = NoctyraxMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose)
