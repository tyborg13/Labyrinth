extends "res://scripts/protagonist_cutout/rig.gd"
## Front-only NPC cutout. Same production loader; no experiment dependencies.
const GraftMotion = preload("res://scripts/graftwright_cutout/motion.gd")
var _needle_paint: Polygon2D
const GRAFT_BASE: String = "res://assets/units/graftwright_cutout"

func _layout_path(_which: String) -> String:
	return GRAFT_BASE.path_join("front.json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else GRAFT_BASE.path_join(path)

func load_rig() -> bool:
	var loaded: bool = super.load_rig()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Body paint and the concealed backing follow the torso; the rigid arm
	# stays in sibling order above them. Only its gesture crosses the UI layer.
	for node: Node in find_children("*", "Polygon2D", true, false):
		(node as Polygon2D).z_index = 0 # Preserve mesh sibling order within the actor layer.
		(node as Polygon2D).z_as_relative = true
	_needle_paint = get_node_or_null("Skin_needle_hand") as Polygon2D
	return loaded

func apply_pose(clip: String, phase: float) -> void:
	var pose: Dictionary = GraftMotion.sample_pose(clip, phase, layout, "front")
	if _needle_paint != null:
		_needle_paint.z_index = int(GraftMotion.sample_draw_order(clip, phase, layout, "front")["Skin_needle_hand"])
	for name: String in bones:
		var bone: Bone2D = bones[name]
		bone.transform = rest_transforms[name]
		bone.position = pose.get(name, {}).get("position", bone.position)
		bone.rotation = float(pose.get(name, {}).get("rotation", 0.0))
