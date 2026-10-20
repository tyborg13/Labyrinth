extends RefCounted

## Equal-z CanvasItems follow scene-tree order. Rigid pieces live under bones;
## joint meshes are rig children, so layout order is not a renderer tie-break.
static func parts(rig: Node2D) -> Array[Dictionary]:
	var painted: Dictionary = {}
	for part: Dictionary in rig.layout["parts"]:
		painted[preload("res://assets/units/hollow_mimic_cutout/draw_order.gd").node_for(rig, part)] = part
	var result: Array[Dictionary]
	collect(rig, painted, result)
	return result

static func collect(node: Node, painted: Dictionary, result: Array[Dictionary]) -> void:
	if painted.has(node): result.append(painted[node])
	for child: Node in node.get_children(): collect(child, painted, result)
