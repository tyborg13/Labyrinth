extends RefCounted

# LargeMapScrim is an opaque full-viewport surface in the production scene.
# Suppress only the board's RenderingServer item while that exact contract
# holds. CanvasItem.visible stays untouched: board logic, animations, clocks,
# visibility queries and offscreen preparation continue as before.
var _board: CanvasItem
var _suppressed: bool = false

func sync(map: Control) -> void:
	var scrim: ColorRect
	var ancestor: Node = map.get_parent()
	while ancestor != null:
		if ancestor is ColorRect and ancestor.name == "LargeMapScrim": scrim = ancestor
		if not is_instance_valid(_board):
			_board = ancestor.get_node_or_null("BoardUnderlay/CombatBoard") as CanvasItem
		ancestor = ancestor.get_parent()
	var covered: bool = is_instance_valid(_board) and scrim != null and map.is_visible_in_tree() and scrim.color.a == 1.0 and scrim.self_modulate.a == 1.0 and scrim.get_global_rect().encloses(map.get_viewport_rect())
	# A transition may fade any ancestor without changing its visible flag.
	ancestor = scrim
	while covered and ancestor != null:
		if ancestor is CanvasItem and ancestor.modulate.a != 1.0: covered = false
		ancestor = ancestor.get_parent()
	if covered:
		# Board refreshes may submit their own visibility in the same frame.
		# Reassert after those updates without changing the node's own flag.
		RenderingServer.canvas_item_set_visible(_board.get_canvas_item(), false)
		_suppressed = true
	else:
		restore()

func restore() -> void:
	if _suppressed and is_instance_valid(_board):
		RenderingServer.canvas_item_set_visible(_board.get_canvas_item(), _board.visible)
	_suppressed = false
