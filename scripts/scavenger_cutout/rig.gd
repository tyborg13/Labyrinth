extends "res://scripts/protagonist_cutout/rig.gd"
const ScavengerMotion = preload("res://scripts/scavenger_cutout/motion.gd")
const IDLE_SECONDS: float = ScavengerMotion.IDLE_SECONDS
const SCAVENGER_BASE: String = "res://assets/units/scavenger_cutout"
func _layout_path(_which: String) -> String: return SCAVENGER_BASE.path_join("front.json")
func _resolve(path: String) -> String: return path if path.begins_with("res://") else SCAVENGER_BASE.path_join(path)
func apply_pose(clip: String, phase: float) -> void:
	var pose: Dictionary = ScavengerMotion.sample_pose(clip, phase, layout, "front")
	for name: String in bones:
		var bone: Bone2D = bones[name]
		bone.transform = rest_transforms[name]
		bone.position = pose.get(name, {}).get("position", bone.position)
		bone.rotation = pose.get(name, {}).get("rotation", bone.rotation)

func load_rig() -> bool:
	var loaded: bool = super.load_rig()
	for node: Node in find_children("*", "Polygon2D", true, false):
		(node as Polygon2D).z_as_relative = true
		(node as Polygon2D).z_index = 0
	return loaded
