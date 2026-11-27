extends RefCounted
## Geometry from production renderers. All returned rectangles are viewport pixels.

static func screen(canvas: CanvasItem, local: Rect2) -> Rect2:
	return canvas.get_viewport().get_stretch_transform() * canvas.get_global_transform_with_canvas() * local


static func points(vertices: PackedVector2Array) -> Rect2:
	if vertices.is_empty(): return Rect2()
	var bounds := Rect2(vertices[0], Vector2.ZERO)
	for vertex: Vector2 in vertices: bounds = bounds.expand(vertex)
	return bounds


static func burst(stamp: Node2D, player: RefCounted) -> Rect2:
	var center: Vector2 = (screen(stamp, Rect2()).position).round()
	var size := Vector2(player.ink.get_shader_parameter("frame_cells"))
	var origin := Vector2(player.ink.get_shader_parameter("centre_cell"))
	if stamp.sample.z != 0: origin.x = size.x - origin.x
	return Rect2(center - origin * player.cell_px, size * player.cell_px)


static func control(node: Control) -> Rect2:
	return screen(node, Rect2(Vector2.ZERO, node.size))


static func terrain_destruction(board: Control, terrain: Dictionary) -> Rect2:
	var kind: String = str(terrain.get("kind", ""))
	var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
	var progress: float = float(terrain.get("destruction_progress", 0.0))
	if progress >= 1.0 or tile.x < 0 or not board._board_tile_is_visible_to_player(tile): return Rect2()
	var texture: Texture2D = board._terrain_destruction_texture(terrain)
	if kind == "bramble": texture = board._terrain_textures.get(kind)
	if texture == null: return Rect2()
	return screen(board, board._terrain_rect_for_tile(tile, texture, kind))


static func light(marker: Control, source: Dictionary) -> Rect2:
	# Outermost ellipses from _draw_umbra_light_orb and
	# _draw_umbra_light_source_reach. The outer orb halo contains its core and motes.
	var tile: Vector2i = source["pos"]
	var t: float = marker._umbra_visual_time_seconds()
	var seed: float = marker._umbra_light_source_seed(source)
	var width: float = marker._tile_width()
	var height: float = marker._tile_height()
	var breath: float = marker._umbra_light_orb_breath(seed, t)
	var brightness: float = 0.94 + 0.10 * (0.5 + 0.5 * sin(t * 2.15 + seed * 0.37))
	var orb: Vector2 = marker._umbra_light_orb_center(tile, seed, t)
	var orb_radius: float = clampf(width * 0.115, 11.0, 20.0) * breath
	var bounds: Rect2 = _ellipse(orb, Vector2(1.08, 0.86) * orb_radius * 4.45 * brightness)
	var radius: int = maxi(1, int(source.get("radius", 1)))
	for reach_tile: Vector2i in marker._umbra_light_source_tiles(source):
		var distance: int = marker._umbra_light_source_distance(tile, reach_tile)
		var weight: float = 1.0 - float(distance) / (float(radius) + 0.90)
		var phase: float = float(reach_tile.x * 17 + reach_tile.y * 31)
		var drift := Vector2(sin(t * 0.47 + phase) * width * 0.010, cos(t * 0.39 + phase) * height * 0.018)
		var reach: Vector2 = marker._tile_center(reach_tile) + drift
		bounds = bounds.merge(_ellipse(reach, Vector2(1.02, 0.48) * width * (0.64 + weight * 0.10)))
	var home: Vector2 = marker._tile_center(tile) + Vector2(0.0, height * 0.10)
	var reach_radii: Vector2 = Vector2(1.32, 0.62) * width * (0.78 + float(radius) * 0.18)
	var x: Vector2 = Vector2(reach_radii.x, 0.0).rotated(-0.04)
	var y: Vector2 = Vector2(0.0, reach_radii.y).rotated(-0.04)
	var extent := Vector2(Vector2(x.x, y.x).length(), Vector2(x.y, y.y).length())
	return screen(marker, bounds.merge(_ellipse(home, extent)))


static func _ellipse(center: Vector2, extent: Vector2) -> Rect2:
	return Rect2(center - extent, extent * 2.0)


static func recorded(canvas: CanvasItem, commands: Array) -> Rect2:
	var offset := Vector2.ZERO
	var result := Rect2()
	for command: Array in commands:
		var rect := Rect2()
		match str(command[0]):
			"transform":
				offset = command[1]
			"texture", "region":
				rect = command[2]
			"polygon", "colored_polygon":
				rect = points(command[1])
			"line":
				rect = Rect2(command[1], Vector2.ZERO).expand(command[2]).grow(float(command[4]) * 0.5)
			"polyline":
				rect = points(command[1]).grow(float(command[3]) * 0.5)
		if rect.has_area():
			rect.position += offset
			result = result.merge(rect) if result.has_area() else rect
	return screen(canvas, result)
