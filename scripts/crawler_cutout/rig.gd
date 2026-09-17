extends "res://scripts/protagonist_cutout/rig.gd"

## Crawler anatomy and paint use the established production Skeleton2D loader.
const CrawlerMotion = preload("res://scripts/crawler_cutout/motion.gd")
const CRAWLER_BASE: String = "res://assets/units/crawler_cutout"

func _layout_path(which: String) -> String:
	return CRAWLER_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else CRAWLER_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = CrawlerMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose)
