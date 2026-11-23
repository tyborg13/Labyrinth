extends RefCounted

const VIEW_SIZE := Vector2i(1920, 1080)
const BRANCH_HEADERS: Array = [
	"SkillBranchHeader_Foresight", "SkillBranchHeader_Resolve",
	"SkillBranchHeader_Tactics", "SkillBranchHeader_Traverse", "SkillBranchHeader_Radiance",
]
const TYPE_FLOOR_PX: float = 14.0


static func capture(viewport: Viewport, scene: Node) -> Dictionary:
	var rects: Dictionary = {}
	_collect(scene, "", viewport.get_stretch_transform(), rects)
	var stretch: Vector2 = viewport.get_stretch_transform().get_scale()
	var logical: Vector2 = viewport.get_visible_rect().size
	return {
		"geometry": {"path": "subviewport", "logical_size": [logical.x, logical.y], "stretch": [stretch.x, stretch.y]},
		"control_rects": rects,
	}


# Same output-pixel rects and stable anonymous paths as pol-68's census.
static func _collect(node: Node, path: String, stretch: Transform2D, rects: Dictionary) -> void:
	if node.is_queued_for_deletion() or node is Viewport or node.name == &"DialogueContinueDiamond":
		return
	if (node is CanvasItem and not node.is_visible_in_tree()) or (node is CanvasLayer and not node.visible):
		return
	var part: String = str(node.name)
	if part.begins_with("@"):
		part = "@%s[%d]" % [node.get_class(), node.get_index(true)]
	var key: String = path.path_join(part)
	if node is Control:
		var rect: Rect2 = stretch * node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
		if rect.has_area():
			rects[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	for child: Node in node.get_children(true):
		_collect(child, key, stretch, rects)
