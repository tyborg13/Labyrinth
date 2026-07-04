extends SceneTree

const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://map_travel_probe"
const START_COORD: Vector2i = Vector2i.ZERO
const DESTINATION_COORD: Vector2i = Vector2i(1, 0)
const COMPACT_EDGE_BUFFER: float = 26.0
const EXPANDED_EDGE_BUFFER: float = 56.0
const COMPACT_GRID_SPACING: float = 34.0
const EXPANDED_GRID_SPACING: float = 132.0
const COMPACT_NODE_MAX_SIZE: float = 24.0
const EXPANDED_NODE_MAX_SIZE: float = 64.0
const LEGEND_WIDTH: float = 142.0
const LEGEND_GAP: float = 18.0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_map_travel_case("mini", false, false, Vector2(260.0, 188.0), Vector2i(340, 240))
	await _capture_map_travel_case("large", true, true, Vector2(920.0, 580.0), Vector2i(980, 660))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_map_travel_case(case_name: String, interactive: bool, show_legend: bool, map_size: Vector2, window_size: Vector2i) -> void:
	var in_transit: Image = _draw_map_proof(interactive, show_legend, map_size, window_size, START_COORD, true, 0.52)
	in_transit.save_png("%s/%s_in_transit.png" % [OUTPUT_DIR, case_name])
	var settled: Image = _draw_map_proof(interactive, show_legend, map_size, window_size, DESTINATION_COORD, false, 1.0)
	settled.save_png("%s/%s_settled.png" % [OUTPUT_DIR, case_name])
	await process_frame

func _travel_run_state(current_coord: Vector2i) -> Dictionary:
	return {
		"mode": "room",
		"current_room": current_coord,
		"rooms": {
			"0,0": {
				"coord": START_COORD,
				"type": "start",
				"revealed": true,
				"visited": true,
				"cleared": true,
				"connections": [{"coord": DESTINATION_COORD}]
			},
			"1,0": {
				"coord": DESTINATION_COORD,
				"type": "combat",
				"element": "fire",
				"revealed": true,
				"visited": false,
				"cleared": false,
				"connections": [{"coord": START_COORD}]
			}
		}
	}

func _draw_map_proof(interactive: bool, show_legend: bool, map_size: Vector2, window_size: Vector2i, current_coord: Vector2i, travel_active: bool, travel_progress: float) -> Image:
	var image := Image.create(window_size.x, window_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.045, 0.034, 0.028, 1.0))
	var origin: Vector2 = (Vector2(window_size) - map_size) * 0.5
	image.fill_rect(_rect2i(Rect2(origin, map_size)), Color(0.075, 0.055, 0.045, 0.58))
	var start_position: Vector2 = _coord_position(START_COORD, origin, map_size, interactive, show_legend)
	var destination_position: Vector2 = _coord_position(DESTINATION_COORD, origin, map_size, interactive, show_legend)
	var node_size: float = _base_node_size(map_size, interactive, show_legend)
	_draw_image_line(image, start_position, destination_position, Color(0.025, 0.020, 0.016, 0.68), maxi(3, int(roundf(node_size * 0.34))))
	_draw_image_line(image, start_position, destination_position, Color("9a8062"), maxi(2, int(roundf(node_size * 0.22))))
	_draw_room_node_proof(image, start_position, node_size, Color("766d63"), current_coord == START_COORD)
	_draw_room_node_proof(image, destination_position, node_size, Color("a65a43"), current_coord == DESTINATION_COORD)
	if travel_active:
		_draw_travel_proof(image, start_position, destination_position, node_size, travel_progress, interactive)
	if show_legend:
		_draw_legend_proof(image, origin, map_size)
	return image

func _draw_room_node_proof(image: Image, center: Vector2, base_node_size: float, fill: Color, current: bool) -> void:
	var node_size: float = base_node_size * (1.22 if current else 1.0)
	var rect := Rect2(center - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	image.fill_rect(_rect2i(rect.grow(3.0)), Color(0.0, 0.0, 0.0, 0.28))
	image.fill_rect(_rect2i(rect), fill)
	_draw_rect_outline(image, rect, Color("f3e6c5"), 2)
	if current:
		_draw_rect_outline(image, rect.grow(5.0), Color("f2c978"), 3)

func _draw_travel_proof(image: Image, start_position: Vector2, destination_position: Vector2, node_size: float, progress: float, interactive: bool) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var token_position: Vector2 = start_position.lerp(destination_position, clamped_progress)
	var trace_width: int = maxi(2, int(roundf(node_size * 0.11)))
	_draw_image_line(image, start_position, token_position, Color(0.035, 0.018, 0.004, 0.78), trace_width + 5)
	_draw_image_line(image, start_position, token_position, Color("ff9d39"), trace_width + 2)
	_draw_image_line(image, start_position, token_position, Color("ffe39a"), maxi(1, trace_width))
	_draw_ring(image, destination_position, node_size * (0.64 + 0.08 * sin(clamped_progress * PI)), 2 if interactive else 1, Color(1.0, 0.70, 0.27, 0.58))
	var mote_count: int = 5 if interactive else 3
	for index: int in range(mote_count):
		var mote_t: float = clampf(clamped_progress - float(index) * 0.085, 0.0, 1.0)
		if mote_t <= 0.0:
			continue
		_draw_circle(image, start_position.lerp(destination_position, mote_t), maxf(1.8, node_size * 0.055), Color(1.0, 0.74, 0.28, 0.82))
	var token_radius: float = clampf(node_size * 0.16, 3.0, 9.0)
	_draw_circle(image, token_position, token_radius * 1.95, Color(1.0, 0.34, 0.08, 0.34))
	_draw_circle(image, token_position, token_radius * 1.18, Color("ff9d39"))
	_draw_circle(image, token_position, token_radius * 0.56, Color("fff0b8"))

func _draw_legend_proof(image: Image, origin: Vector2, map_size: Vector2) -> void:
	var rect := Rect2(origin + Vector2(map_size.x - EXPANDED_EDGE_BUFFER - LEGEND_WIDTH, EXPANDED_EDGE_BUFFER), Vector2(LEGEND_WIDTH, 256.0))
	image.fill_rect(_rect2i(rect), Color(0.08, 0.06, 0.05, 0.82))
	_draw_rect_outline(image, rect, Color(0.93, 0.85, 0.70, 0.36), 1)
	var swatches: Array[Color] = [Color("d8b96f"), Color("a65a43"), Color("d9854c"), Color("89a862"), Color("7e65b7"), Color("b75643")]
	for index: int in range(swatches.size()):
		var row_y: float = rect.position.y + 16.0 + float(index) * 30.0
		image.fill_rect(_rect2i(Rect2(Vector2(rect.position.x + 14.0, row_y), Vector2(18.0, 18.0))), swatches[index])
		image.fill_rect(_rect2i(Rect2(Vector2(rect.position.x + 42.0, row_y + 6.0), Vector2(70.0, 5.0))), Color("d9cbb2"))

func _coord_position(coord: Vector2i, origin: Vector2, map_size: Vector2, interactive: bool, show_legend: bool) -> Vector2:
	var map_rect: Rect2 = _map_rect(origin, map_size, interactive, show_legend)
	var spacing: float = _grid_spacing(map_size, interactive, show_legend)
	var coord_offset := Vector2(float(coord.x), float(coord.y)) - Vector2(0.5, 0.0)
	return map_rect.get_center() + coord_offset * spacing

func _map_rect(origin: Vector2, map_size: Vector2, interactive: bool, show_legend: bool) -> Rect2:
	var padding: float = COMPACT_EDGE_BUFFER if not interactive else EXPANDED_EDGE_BUFFER
	var legend_width: float = LEGEND_WIDTH + LEGEND_GAP if show_legend else 0.0
	return Rect2(origin + Vector2(padding, padding), Vector2(maxf(12.0, map_size.x - padding * 2.0 - legend_width), maxf(12.0, map_size.y - padding * 2.0)))

func _grid_spacing(map_size: Vector2, interactive: bool, show_legend: bool) -> float:
	var map_rect: Rect2 = _map_rect(Vector2.ZERO, map_size, interactive, show_legend)
	var desired: float = COMPACT_GRID_SPACING if not interactive else EXPANDED_GRID_SPACING
	return maxf(12.0, minf(desired, map_rect.size.x))

func _base_node_size(map_size: Vector2, interactive: bool, show_legend: bool) -> float:
	var base: float = _grid_spacing(map_size, interactive, show_legend) * 0.56
	return clampf(base, 14.0 if not interactive else 20.0, COMPACT_NODE_MAX_SIZE if not interactive else EXPANDED_NODE_MAX_SIZE)

func _rect2i(rect: Rect2) -> Rect2i:
	return Rect2i(int(roundf(rect.position.x)), int(roundf(rect.position.y)), int(roundf(rect.size.x)), int(roundf(rect.size.y)))

func _draw_rect_outline(image: Image, rect: Rect2, color: Color, width: int) -> void:
	var r: Rect2i = _rect2i(rect)
	image.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, width), color)
	image.fill_rect(Rect2i(r.position.x, r.end.y - width, r.size.x, width), color)
	image.fill_rect(Rect2i(r.position.x, r.position.y, width, r.size.y), color)
	image.fill_rect(Rect2i(r.end.x - width, r.position.y, width, r.size.y), color)

func _draw_ring(image: Image, center: Vector2, radius: float, width: int, color: Color) -> void:
	var outer: int = int(ceil(radius))
	var inner_radius: float = maxf(0.0, radius - float(width))
	for y_offset: int in range(-outer, outer + 1):
		for x_offset: int in range(-outer, outer + 1):
			var distance: float = Vector2(float(x_offset), float(y_offset)).length()
			if distance <= radius and distance >= inner_radius:
				_set_image_pixel_blend(image, int(roundf(center.x)) + x_offset, int(roundf(center.y)) + y_offset, color)

func _draw_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var rounded_radius: int = int(ceil(radius))
	for y_offset: int in range(-rounded_radius, rounded_radius + 1):
		for x_offset: int in range(-rounded_radius, rounded_radius + 1):
			if Vector2(float(x_offset), float(y_offset)).length() <= radius:
				_set_image_pixel_blend(image, int(roundf(center.x)) + x_offset, int(roundf(center.y)) + y_offset, color)

func _draw_image_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width: int) -> void:
	var steps: int = maxi(1, int(from_point.distance_to(to_point)))
	for step: int in range(steps + 1):
		var point: Vector2 = from_point.lerp(to_point, float(step) / float(steps))
		_draw_circle(image, point, float(width), color)

func _set_image_pixel_blend(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var alpha: float = clampf(color.a, 0.0, 1.0)
	var existing: Color = image.get_pixel(x, y)
	image.set_pixel(x, y, existing.lerp(Color(color.r, color.g, color.b, 1.0), alpha))

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
