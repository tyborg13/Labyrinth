extends "res://tools/scn01/census.gd"
## Add candidate census header typography and pol-68 rectangles to scn01's
## existing checkpoint, navigation, settling and capture.

const SkillGeometry = preload("geometry.gd")
const HEADER_ROOTS: Dictionary = {
	"SkillBranchHeader_Foresight": "discerning_eye",
	"SkillBranchHeader_Resolve": "measured_breath",
	"SkillBranchHeader_Tactics": "quick_wits",
	"SkillBranchHeader_Traverse": "ghost_stride",
	"SkillBranchHeader_Radiance": "long_dawn",
}


func _finish(error: String) -> void:
	if error.is_empty():
		_result.merge(SkillGeometry.capture(_viewport, _screen))
		var metrics: Dictionary = {}
		var hits: Array[Dictionary]
		var tree: Control = _screen.find_child("CharacterSkillTree", true, false)
		for header: String in SkillGeometry.BRANCH_HEADERS:
			var label: Label = tree.find_child(header, true, false)
			var transform: Transform2D = _viewport.get_stretch_transform() * label.get_global_transform_with_canvas()
			var source_px: int = label.get_theme_font_size("font_size")
			var font_px: float = float(source_px) * transform.y.length()
			var label_rect: Rect2 = transform * Rect2(Vector2.ZERO, label.size)
			var root_rect: Rect2 = _viewport.get_stretch_transform() * tree._graph_canvas.get_global_transform_with_canvas() * tree._node_visual_rect(HEADER_ROOTS[header])
			var gap_px: float = root_rect.position.y - label_rect.end.y
			metrics[header] = {"source_px": source_px, "font_px": font_px, "gap_px": gap_px}
			if font_px + 0.001 < SkillGeometry.TYPE_FLOOR_PX:
				hits.append({"kind": "small_font", "node": header, "font_px": font_px, "source_px": source_px})
			print("POL69 CENSUS %s source=%d px rendered=%.2f px node_gap=%.2f px" % [header, source_px, font_px, gap_px])
			if gap_px < 0.0: error = "A branch header overlaps its first node."
		_result["headers"] = metrics
		_result["layout_hits"] = hits
		print("POL69 CENSUS combat_character_skills: %d branch-header small_font hits" % hits.size())
	super._finish(error)
