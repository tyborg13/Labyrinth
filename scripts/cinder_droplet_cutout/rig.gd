extends "res://scripts/protagonist_cutout/rig.gd"

## Creature-owned topology and paint with the shared production skeleton loader.
const CinderDropletMotion = preload("res://scripts/cinder_droplet_cutout/motion.gd")
const CINDER_DROPLET_BASE: String = "res://assets/units/cinder_droplet_cutout"

func _layout_path(which: String) -> String:
	return CINDER_DROPLET_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else CINDER_DROPLET_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = CinderDropletMotion.sample_pose(clip_name,phase_value,layout,facing)
	_apply_sampled_pose(pose)
