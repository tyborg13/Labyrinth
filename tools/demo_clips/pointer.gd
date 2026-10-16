extends RefCounted

static func hover_tile(board: Control, tile: Vector2i, warp_pointer: bool = false) -> Dictionary:
	var local_position: Vector2 = board.call("world_position_for_tile", tile)
	var viewport_position: Vector2 = board.get_global_transform_with_canvas() * local_position
	var viewport: Viewport = board.get_viewport()
	# SubViewport GUI picking is gated by mouse entry. push_input alone still
	# reaches _input listeners, but cannot select a Control when the physical
	# pointer has never entered this container. No host/backing-scale transform
	# belongs here: the event is already in the board's own viewport coordinates.
	if viewport is SubViewport: viewport.notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.position = viewport_position
	motion.global_position = viewport_position
	if warp_pointer: Input.warp_mouse(viewport_position)
	viewport.push_input(motion, true)
	return {"board_local_position": local_position, "viewport_position": viewport_position}
