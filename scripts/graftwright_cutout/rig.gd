extends "res://scripts/protagonist_cutout/rig.gd"
## Front-only NPC cutout. Same production loader; no experiment dependencies.
const GraftMotion = preload("res://scripts/graftwright_cutout/motion.gd")
const GRAFT_BASE: String = "res://assets/units/graftwright_cutout"

func _layout_path(_which: String) -> String:
	return GRAFT_BASE.path_join("front.json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else GRAFT_BASE.path_join(path)

func load_rig() -> bool:
	var loaded: bool = super.load_rig()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Every mesh is one disjoint paint owner with a shared continuous skin.
	# Keep all on the NPC's ordinary canvas layer so later bench/props occlude it.
	for node: Node in find_children("*", "Polygon2D", true, false):
		(node as Polygon2D).z_index = 0
		(node as Polygon2D).z_as_relative = true
	return loaded

func apply_pose(clip: String, phase: float) -> void:
	var pose: Dictionary = GraftMotion.sample_pose(clip, phase, layout, "front")
	for name: String in bones:
		var bone: Bone2D = bones[name]
		bone.transform = rest_transforms[name]
		bone.position = pose.get(name, {}).get("position", bone.position)
