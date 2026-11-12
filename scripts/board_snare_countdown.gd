extends RefCounted

## Existing door chips participate in the same fixed-status input map as icons.
## Their Control geometry remains authoritative through pan, zoom and UI scale.
const Rules = preload("res://scripts/snare_room_rules.gd")

static func entries(board: Control, unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if str(unit.get("role", "")) != "enemy" or str(unit.get("intent", {}).get("id", "")) != "snare_seal": return result
	if not Rules.active(board.combat_state): return result
	var holder: Control = board.get_node_or_null("SnareSealChips")
	if holder == null: return result
	for exit: Dictionary in board.combat_state["objective"].get("exits", []):
		if int(exit.get("sealbinder_id", -1)) != int(unit.get("id", -2)): continue
		if str(exit.get("role", "")) != "sealing" or bool(exit.get("sealed", false)) or bool(exit.get("kept_open", false)): continue
		var chip: Control = holder.get_node_or_null("Door%d" % int(unit["id"]))
		if chip == null or not chip.is_visible_in_tree(): continue
		var local_transform: Transform2D = board.get_global_transform_with_canvas().affine_inverse() * chip.get_global_transform_with_canvas()
		var rect: Rect2 = local_transform * Rect2(Vector2.ZERO, chip.size)
		if not rect.has_area(): continue
		result.append({"rect": rect, "tooltip": Rules.seal_tooltip(board.combat_state["objective"], unit), "countdown_chip": true})
	return result
