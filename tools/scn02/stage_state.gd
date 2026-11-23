extends RefCounted
## Read the stage the production scene actually submitted at the capture boundary.

static func read(screen: Control) -> Dictionary:
	var run: Dictionary = screen.get("_run_state")
	var board: Control = screen.get("board_view")
	var state: Dictionary = board.get("combat_state")
	var presentation: Dictionary = board.get("presentation")
	var props: Array[Dictionary]
	for prop: Dictionary in presentation.get("scene_props", []):
		props.append({"kind": prop["kind"], "tile": str(prop["tile"])})
	var doors: Array[String]
	var grid: Array = state.get("grid", [])
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			if grid[y][x] == "door":
				doors.append(str(Vector2i(x, y)))
	var label: RichTextLabel = screen.get("log_label")
	var message: Control = screen.get("log_overlay")
	var board_rect: Rect2 = screen.call("_contextual_combat_rendered_board_bounds")
	var fit_rect: Rect2 = presentation.get("board_fit_rect", Rect2())
	return {
		"mode": run.get("mode"),
		"room": str(run.get("current_room")),
		"board_visible": board.visible,
		"board_in_tree_visible": board.is_visible_in_tree(),
		"board_state_empty": state.is_empty(),
		"rendered_tiles": (board.call("_rendered_tiles_in_draw_order") as Array).size(),
		"scene_props": props,
		"hero_tile": str(state.get("player", {}).get("pos")),
		"board_rect": [board_rect.position.x, board_rect.position.y, board_rect.size.x, board_rect.size.y],
		"board_fit_size": [fit_rect.size.x, fit_rect.size.y],
		"tile_width": board.call("_tile_width"),
		"door_tiles": doors,
		"active_doors": _tiles(presentation.get("active_door_tiles", {})),
		"locked_doors": _tiles(presentation.get("locked_door_tiles", {})),
		"notice": run.get("notice", ""),
		"message": label.text if message.is_visible_in_tree() else "",
		"shop_visible": (screen.get("_scavenger_shop_view") as Control).is_visible_in_tree(),
	}


static func _tiles(doors: Dictionary) -> Array[String]:
	var result: Array[String]
	for tile: Vector2i in doors:
		result.append(str(tile))
	result.sort()
	return result
