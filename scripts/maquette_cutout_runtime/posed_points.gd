extends RefCounted

const Motion = preload("motion.gd")

## Read the painted rigid node after presentation snapping, including reflection.
## Bone origins alone omit the crop's independently snapped presentation anchor.
static func source_point(renderer: Node, item: String) -> Vector2:
	var rig: Node2D = renderer.rigs[renderer.facing]
	var part: Dictionary = {}
	for candidate: Dictionary in rig.layout["parts"]:
		if candidate["name"] == item:
			part = candidate
			break
	var sprite: Node2D = rig.bones[part["bone"]].get_node(NodePath(item))
	var point: Vector2 = Motion.point(rig.layout["strike_points"][item])
	var offset: Vector2 = Motion.point(part["offset"])
	return sprite.global_transform * (point - offset) - (renderer.canvas_geometry()["offset"] as Vector2)
