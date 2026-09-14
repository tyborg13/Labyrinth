extends RefCounted
const Shared = preload("res://scripts/guardian_cutout/motion.gd")
static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	return Shared.sample_pose(clip, phase, layout, facing)
static func walk_cycle_info(layout: Dictionary, facing: String) -> Dictionary:
	return Shared.walk_cycle_info(layout, facing)
static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	return Shared.walk_foot_state(phase, foot, layout, facing)
static func sample_draw_order(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	return Shared.sample_draw_order(clip, phase, layout, facing)
