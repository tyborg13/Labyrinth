extends RefCounted
## Proof-only measurements; never alters player state or presentation tuning.
const Assets = preload("res://scripts/asset_loader.gd")
const PIXEL_CHANGE_THRESHOLD: float = 8.0 / 255.0
const MIN_CHANGED_FRACTION: float = 0.10

static func actors(board: Control) -> Array[Dictionary]:
	var rows: Array[Dictionary]
	var manager: Node = board.get("_occlusion_silhouettes")
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("type", "")) not in ["player", "emaciated_man"]: continue
		var logical: Rect2 = board.call("_unit_draw_rect", unit)
		var texture: Texture2D = board.call("_unit_hud_anchor_texture", unit)
		var used: Rect2i = Assets.texture_used_rect(texture)
		var pixel_scale: Vector2 = logical.size / texture.get_size()
		var paint := Rect2(logical.position + Vector2(used.position) * pixel_scale, Vector2(used.size) * pixel_scale)
		paint = board.get_global_transform_with_canvas() * paint
		var body: Control = manager.team.bodies.get(str(unit["key"]))
		var frame: Rect2 = board.call("_unit_frame_rect", board.call("_unit_center", unit))
		var expected_width: float = frame.size.x * float(board.call("_unit_art_scale", unit))
		var shadow_bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture",texture)
		var shadow_foot: Vector2 = board.call("_unit_shadow_foot_point",texture,logical,shadow_bounds,str(unit["type"]))
		rows.append({"key":unit["key"],"type":unit["type"],"tile":[unit["pos"].x,unit["pos"].y],
			"shadow_foot":[shadow_foot.x,shadow_foot.y],"canvas_ground_y":logical.position.y+254.0*pixel_scale.y,"root_used_for_placement":false,
			"logical_rect":[logical.position.x,logical.position.y,logical.size.x,logical.size.y],
			"paint_rect":[paint.position.x,paint.position.y,paint.size.x,paint.size.y],
			"expected_width":expected_width,"true_scale":is_equal_approx(expected_width,logical.size.x),
			"body_visible":is_instance_valid(body) and body.is_visible_in_tree(),
			"draw_count":int(body.get("_dynamic_draw_count")) if is_instance_valid(body) else 0})
	return rows

static func _draw(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw

static func native_pixels(tree: SceneTree, viewport: SubViewport, board: Control, output: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = actors(board)
	var manager: Node = board.get("_occlusion_silhouettes")
	var processing: bool = manager.is_processing()
	manager.set_process(false)
	await _draw(tree)
	var displayed: Image = viewport.get_texture().get_image()
	for row: Dictionary in rows:
		var body: Control = manager.team.bodies[row["key"]]
		body.hide()
		await _draw(tree)
		var background: Image = viewport.get_texture().get_image()
		background.save_png(output.path_join("central_waypoint_without_" + str(row["type"]) + ".png"))
		body.show()
		await _draw(tree)
		var raw: Array = row["paint_rect"]
		var bounds := Rect2i(Rect2(raw[0],raw[1],raw[2],raw[3]))
		bounds = bounds.intersection(Rect2i(Vector2i.ZERO,displayed.get_size()))
		var changed: int = 0
		for y: int in range(bounds.position.y,bounds.end.y):
			for x: int in range(bounds.position.x,bounds.end.x):
				var on: Color = displayed.get_pixel(x,y)
				var off: Color = background.get_pixel(x,y)
				if maxf(absf(on.r-off.r),maxf(absf(on.g-off.g),absf(on.b-off.b))) >= PIXEL_CHANGE_THRESHOLD: changed += 1
		var minimum: int = ceili(bounds.get_area() * MIN_CHANGED_FRACTION)
		row["changed_pixels"] = changed
		row["minimum_changed_pixels"] = minimum
		row["pixels_visible"] = bounds.has_area() and changed >= minimum
	manager.set_process(processing)
	return rows
