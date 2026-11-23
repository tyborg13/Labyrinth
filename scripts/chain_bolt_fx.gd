extends Sprite2D
## A retained contact texture, sampled on Spark's framebuffer cell grid.

const Paths = preload("res://scripts/path_utils.gd")
const DATA_PATH: String = "res://data/chain_bolt.json"
# The Spark baker uses these ordered thresholds and the same miter limit.
const BAYER: PackedInt32Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const MITER_LIMIT: float = 2.0
const CLOCK_EPSILON: float = 0.000001
# A consistent tie-break at a texel center gives an even-width stroke two
# rows when both of its edges fall exactly on centers.
const RASTER_SAMPLE := Vector2(0.5001, 0.5001)

static var _data: Dictionary

var from_tile: Vector2i
var to_tile: Vector2i
var from_point: Vector2
var to_point: Vector2
var start_frame: int
var cell_px: int
var phase: int = -1

var _board: Control
var _room: Variant
var _seed: int
var _reduced: bool
var _seconds: float
var _basis: Transform2D
var _span: Vector2
var _cell_span: Vector2
var _raster_origin: Vector2i
var _raster_stage: int = -1

static func metadata() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data

static func present(board: Control, from: Vector2i, to: Vector2i, reduced: bool) -> void:
	if from == to or board._single_shot_fx == null or not board._board_tile_is_visible_to_player(from) or not board._board_tile_is_visible_to_player(to):
		return
	var from_slot: CanvasItem = _endpoint_slot(board, from)
	var to_slot: CanvasItem = _endpoint_slot(board, to)
	if from_slot == null or to_slot == null: return
	var slot: CanvasItem = from_slot if from_slot.get_index() > to_slot.get_index() else to_slot

	var bolt = new()
	bolt.name = "ChainBolt"
	bolt._board = board
	bolt._room = board.combat_state.get("room_coord")
	bolt._seed = hash([from, to, Engine.get_process_frames()])
	bolt._reduced = reduced
	bolt.from_tile = from
	bolt.to_tile = to
	bolt.start_frame = Engine.get_process_frames()
	bolt.centered = false
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.add_child(bolt, true)
	bolt._sample()

static func _endpoint_slot(board: Control, tile: Vector2i) -> CanvasItem:
	# Match the front burst's depth for both empty relays and unit footprints.
	var layers: Dictionary = board._scene_front_effect_render_layers_by_tile
	var slot: CanvasItem = layers.get(tile)
	if slot == null: return null
	for unit: Dictionary in board._visible_units_cache:
		var footprint := Rect2i(unit["pos"], board._resolved_unit_footprint(unit))
		if not footprint.has_point(tile): continue
		var unit_slot: CanvasItem = layers.get(board._scene_render_tile_for_unit(unit))
		if unit_slot != null and unit_slot.get_index() > slot.get_index(): slot = unit_slot
	return slot

func _process(delta: float) -> void:
	if start_frame != Engine.get_process_frames(): _seconds += delta
	var data: Dictionary = metadata()
	var lifetime: float = float(data["reduced_motion_seconds"]) if _reduced else (float(data["full_frames"]) + float(data["fade_frames"])) / float(data["fps"])
	if _seconds + CLOCK_EPSILON >= lifetime or _board.combat_state.is_empty() or _board.combat_state.get("room_coord") != _room:
		hide()
		queue_free()
		return
	visible = _board._board_tile_is_visible_to_player(from_tile) and _board._board_tile_is_visible_to_player(to_tile)
	if visible: _sample()

func _sample() -> void:
	var data: Dictionary = metadata()
	var next: int = 0 if _reduced else floori((_seconds + CLOCK_EPSILON) * float(data["fps"]))
	var stretch: Transform2D = _board.get_viewport().get_stretch_transform()
	var framebuffer: Transform2D = stretch * _board.get_global_transform_with_canvas()
	var pixel_scale: Vector2 = framebuffer.get_scale().abs()
	var cell: int = maxi(1, _board._single_shot_fx._cells_px)
	# TileBurstFx anchors both retained rows on this same board point.
	from_point = _board._tile_center(from_tile)
	to_point = _board._tile_center(to_tile)
	var span: Vector2 = to_point - from_point
	if span.is_zero_approx(): return
	var basis := Transform2D(framebuffer.x, framebuffer.y, Vector2.ZERO)
	var start_cell: Vector2 = ((framebuffer * from_point) / float(cell)).floor()
	var end_cell: Vector2 = ((framebuffer * to_point) / float(cell)).floor()
	var cell_span: Vector2 = end_cell - start_cell
	var fade_stage: int = maxi(0, next - int(data["full_frames"]) + 1)
	phase = next
	if fade_stage != _raster_stage or cell != cell_px or cell_span != _cell_span or not basis.is_equal_approx(_basis) or not span.is_equal_approx(_span):
		_raster_stage = fade_stage
		cell_px = cell
		_basis = basis
		_span = span
		_cell_span = cell_span
		var hop_seed: int = _seed + int(phase >= int(data["rejag_frame"]) - 1)
		var strength: float = 1.0 - float(fade_stage) / (int(data["fade_frames"]) + 1)
		var geometry: Array[PackedVector2Array] = paths(Vector2.ZERO, span, Paths.manhattan(from_tile, to_tile), hop_seed)
		var snap_adjustment: Vector2 = cell_span - (basis * span) / float(cell)
		for index: int in geometry.size():
			var path: PackedVector2Array = geometry[index]
			for i: int in path.size():
				var along: float = path[i].dot(span) / span.length_squared()
				path[i] = (basis * path[i]) / float(cell) + Vector2(0.5, 0.5) + snap_adjustment * along
			geometry[index] = path
		var raster: Dictionary = rasterize(geometry, strength)
		_raster_origin = raster["origin"]
		texture = ImageTexture.create_from_image(raster["image"])
	position = framebuffer.affine_inverse() * ((start_cell + Vector2(_raster_origin)) * cell)
	scale = Vector2.ONE * cell / pixel_scale

static func paths(from: Vector2, to: Vector2, tiles: int, seed_value: int) -> Array[PackedVector2Array]:
	var data: Dictionary = metadata()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var length: float = from.distance_to(to)
	var forward: Vector2 = from.direction_to(to)
	var side: Vector2 = forward.orthogonal()
	var straight: float = float(data["straight_end_px"])
	var main := PackedVector2Array([from])
	if length > 2.0 * straight:
		main.append(from + forward * straight)
		var station: float = float(data["kink_interval_px"])
		var offset: float = float(data["kink_offset_px"])
		while station < length - straight:
			main.append(from + forward * station + side * random.randf_range(-offset, offset))
			station += float(data["kink_interval_px"])
		main.append(to - forward * straight)
	main.append(to)
	var result: Array[PackedVector2Array]
	result.append(main)
	if tiles <= int(data["fork_over_tiles"]): return result
	var interval: Array = data["fork_start_fraction"]
	var fork_at: float = random.randf_range(float(interval[0]), float(interval[1])) * length
	var angles: Array = data["fork_angle_degrees"]
	var angle: float = deg_to_rad(random.randf_range(float(angles[0]), float(angles[1])))
	if random.randi() & 1: angle = -angle
	for i: int in range(1, main.size()):
		var end: float = (main[i] - from).dot(forward)
		if end < fork_at: continue
		var begin: float = (main[i - 1] - from).dot(forward)
		var root: Vector2 = main[i - 1].lerp(main[i], (fork_at - begin) / (end - begin))
		var direction: Vector2 = main[i - 1].direction_to(main[i]).rotated(angle)
		result.append(PackedVector2Array([root, root + direction * length * float(data["fork_length_fraction"])]))
		break
	return result

static func rasterize(geometry: Array[PackedVector2Array], strength: float) -> Dictionary:
	var data: Dictionary = metadata()
	var widths: Dictionary = data["width_cells"]
	var palette: Dictionary = data["palette"]
	var bounds := Rect2(geometry[0][0], Vector2.ZERO)
	for path: PackedVector2Array in geometry:
		for point: Vector2 in path: bounds = bounds.expand(point)
	bounds = bounds.grow(float(widths["halo"]) * MITER_LIMIT * 0.5)
	var origin := Vector2i(bounds.position.floor())
	var extent := Vector2i(bounds.end.ceil()) - origin
	var image: Image = Image.create_empty(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	for layer: String in ["halo", "body", "core"]:
		var coverage: float = strength * (float(data["halo_coverage"]) if layer == "halo" else 1.0)
		var color := Color(palette[layer])
		_paint(image, origin, geometry[0], float(widths[layer]) * 0.5, color, coverage)
		if geometry.size() > 1 and layer != "halo":
			_paint(image, origin, geometry[1], float(widths[layer]) * 0.5, color, coverage)
	if strength == 1.0:
		for endpoint: Vector2 in [geometry[0][0], geometry[0][-1]]:
			image.set_pixelv(Vector2i(endpoint.floor()) - origin, Color(palette["core"]))
	return {"image": image, "origin": origin}

static func _paint(image: Image, origin: Vector2i, path: PackedVector2Array, half_width: float, color: Color, coverage: float) -> void:
	var offsets := PackedVector2Array()
	for i: int in path.size():
		var before: Vector2 = path[maxi(0, i - 1)].direction_to(path[maxi(1, i)]).orthogonal()
		var after: Vector2 = path[mini(i, path.size() - 2)].direction_to(path[mini(i + 1, path.size() - 1)]).orthogonal()
		var miter: Vector2 = (before + after).normalized()
		offsets.append(miter * minf(half_width / miter.dot(before), half_width * MITER_LIMIT))
	for i: int in range(1, path.size()):
		var quad := PackedVector2Array([
			path[i - 1] + offsets[i - 1], path[i] + offsets[i],
			path[i] - offsets[i], path[i - 1] - offsets[i - 1],
		])
		var bounds := Rect2(quad[0], Vector2.ZERO)
		for vertex: Vector2 in quad: bounds = bounds.expand(vertex)
		for y: int in range(floori(bounds.position.y), ceili(bounds.end.y)):
			for x: int in range(floori(bounds.position.x), ceili(bounds.end.x)):
				var threshold: float = (float(BAYER[posmod(y, 4) * 4 + posmod(x, 4)]) + 0.5) / BAYER.size()
				if threshold < coverage and Geometry2D.is_point_in_polygon(Vector2(x, y) + RASTER_SAMPLE, quad):
					image.set_pixel(x - origin.x, y - origin.y, color)
