extends RefCounted
## Compare native framebuffer readbacks of the same stationary board.
## Hiding an actor's own paint leaves its retained shadow and stamps intact.

const Fixture = preload("res://tools/grd07/fixture.gd")
const Order = preload("res://tools/grd07/draw_order.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const MIN_OPAQUE_ACTOR_ALPHA: float = 0.85
const COVERAGE_MIN: float = 0.70
const COVERAGE_MAX: float = 0.85
const FIRE_HARRIER_FRONT_PIXELS: int = 200
const ELECTRIFIED_FRONT_PIXELS: int = 120
const ELECTRIFIED_REGION_LUMA := Vector2(70.0, 95.0)
# Keep the r1 luminance comparison for the receipt only.
const HISTORICAL_ACCENT_REFERENCE: float = 1.10

static func column(board: Control, mode: String, units: Array[Dictionary], records: Array[Dictionary],
		source: Image, read_frame: Callable) -> Dictionary:
	var pixel: Order.PixelGround = board.get_node_or_null("PixelGround")
	var surfaces: Array[CanvasItem]
	var fronts: Array[CanvasItem]
	var fire_fronts: Array[CanvasItem]
	var reflections: Array[CanvasItem]
	var stamps: Array[CanvasItem]
	if pixel != null:
		surfaces.append(pixel)
		for key: Array in pixel.depth.stamps:
			var stamp: CanvasItem = pixel.depth.stamps[key]
			stamps.append(stamp)
			if key.has("reflection"): reflections.append(stamp)
			elif not pixel.is_ancestor_of(stamp): surfaces.append(stamp)
		for stamp: CanvasItem in pixel.sheet.stamps.values():
			stamps.append(stamp)
			surfaces.append(stamp)
		for record: Dictionary in records:
			for element: Dictionary in record["ground_projection"].get("depth_elements", []):
				if element["draws_after_body"]:
					var layer: CanvasItem = board.get_node(element["canvas"]["path"])
					if not fronts.has(layer): fronts.append(layer)
					if element["kind"] == Order.Stills.FIRE and not fire_fronts.has(layer):
						fire_fronts.append(layer)
	else:
		var tile_layers: Dictionary = board.get("_scene_render_layers_by_tile")
		for record: Dictionary in records:
			for tile: Vector2i in _tiles(record):
				for label: String in Order.LEGACY_LAYERS[record["ground"]]:
					var layer: CanvasItem = tile_layers[tile].get_node(label)
					surfaces.append(layer)

	var front_hidden: Image = source
	if not fronts.is_empty():
		_set_visible(fronts, false)
		front_hidden = await read_frame.call()
		_set_visible(fronts, true)
	var fire_hidden: Image = front_hidden
	if not fire_fronts.is_empty() and fire_fronts.size() != fronts.size():
		_set_visible(fire_fronts, false)
		fire_hidden = await read_frame.call()
		_set_visible(fire_fronts, true)
	var reflection_hidden: Image = source
	if not reflections.is_empty():
		_set_visible(reflections, false)
		reflection_hidden = await read_frame.call()
		_set_visible(reflections, true)

	var bodies: Dictionary = {}
	var outlines: Array[CanvasItem]
	for record: Dictionary in records:
		var body: CanvasItem = board.get_node(record["body"]["path"])
		bodies[body] = body.self_modulate
		var outline: CanvasItem = body.get_node_or_null("TeamOutline")
		if outline != null and outline.visible: outlines.append(outline)
	_set_visible(outlines, false)
	_set_visible(surfaces, false)
	var actors_only: Image = await read_frame.call()
	for body: CanvasItem in bodies:
		var transparent: Color = bodies[body]
		transparent.a = 0.0
		body.self_modulate = transparent
	var bare_floor: Image = await read_frame.call()
	_set_visible(surfaces, true)
	var ground_only: Image = bare_floor
	if not surfaces.is_empty():
		ground_only = await read_frame.call()
	var flat: Image = ground_only
	var outline: Image = flat
	var outline_floor: Image = bare_floor
	if pixel != null and pixel.visible:
		_set_visible(stamps, false)
		flat = await read_frame.call()
		# The outline-only pair also hides child contact shadows and any
		# retained actor commands that ignore self-modulation.
		for body: CanvasItem in bodies:
			body.hide()
		pixel.hide()
		outline_floor = await read_frame.call()
		pixel._material.set_shader_parameter("proof_outline", true)
		pixel.show()
		outline = await read_frame.call()
		pixel._material.set_shader_parameter("proof_outline", false)
		for body: CanvasItem in bodies:
			body.show()
		_set_visible(stamps, true)
	for body: CanvasItem in bodies:
		body.self_modulate = bodies[body]
	_set_visible(outlines, true)

	var regions: Array[Dictionary]
	var total := _counts()
	for i: int in records.size():
		var record: Dictionary = records[i]
		var texture: Texture2D = board.call("_texture_for_unit", units[i])
		var actor_luma: float = _actor_luma(actors_only, texture, _rect(record["body_texture_rect_px"]))
		var budget: float = actor_luma * HISTORICAL_ACCENT_REFERENCE
		var region: Dictionary = _region(board, record, flat, ground_only, bare_floor, outline, outline_floor, budget)
		_total(total, region["counts"])
		region.erase("counts")
		var bounds: Rect2i = Fixture.crop_for(board, _tiles(record))
		var parts: Dictionary = _depth_pixels(source, front_hidden, fire_hidden, reflection_hidden, bounds, record)
		var front_pixels: int = parts["front"]
		var fire_pixels: int = parts["fire_front"]
		var reflected_pixels: int = parts["reflection"]
		regions.append({
			"ground": record["ground"], "unit": record["type"], "unit_mean_luminance": actor_luma,
			"unit_mean_plus_10_percent": budget, "front_layer_texels_at_feet": front_pixels,
			"fire_front_layer_pixels_at_feet": fire_pixels,
			"reflection_texels": reflected_pixels, "elements": parts["elements"], "region": region,
			"targets": _targets(mode, record, region, front_pixels, fire_pixels, reflected_pixels),
		})
	var summary: Dictionary = _summary(total)
	var result := {"region": summary, "regions": regions}
	if mode == "pixel" and not records.is_empty() and records[0]["ground"] == "electrified":
		var mean: Variant = summary["region_mean_luminance"]
		var within_range: bool = mean != null and (
			float(mean) >= ELECTRIFIED_REGION_LUMA.x and float(mean) <= ELECTRIFIED_REGION_LUMA.y
		)
		result["targets"] = {"region_luminance_70_to_95": within_range}
	return result

static func _set_visible(items: Array[CanvasItem], visible: bool) -> void:
	for item: CanvasItem in items:
		item.visible = visible

static func _tiles(record: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	if record.has("region"):
		for entry: Dictionary in record["region"]["tiles"]:
			tiles.append(Vector2i(entry["tile"][0], entry["tile"][1]))
	else:
		tiles.append(Vector2i(record["tile"][0], record["tile"][1]))
	return tiles

static func _counts() -> Dictionary:
	return {"pixels": 0, "ground": 0, "outline": 0, "accent": 0, "luma": 0.0,
		"luma_squared": 0.0, "patch_luma": 0.0, "bare_patch_luma": 0.0}

static func _total(total: Dictionary, region: Dictionary) -> void:
	for key: String in total:
		total[key] += region[key]

static func _summary(counts: Dictionary) -> Dictionary:
	var area: int = counts["pixels"]
	var ground: int = counts["ground"]
	var mean: float = counts["luma"] / ground if ground > 0 else 0.0
	var variance: float = maxf(0.0, counts["luma_squared"] / ground - mean * mean) if ground > 0 else 0.0
	var floor_luma: float = counts["bare_patch_luma"]
	return {"region_mean_luminance": mean if ground > 0 else null,
		"region_luminance_stdev": sqrt(variance) if ground > 0 else null,
		"patch_mean_luminance": counts["patch_luma"] / ground if ground > 0 else null,
		"bare_floor_patch_mean_luminance": floor_luma / ground if ground > 0 else null,
		"patch_to_floor_luminance_ratio": counts["patch_luma"] / floor_luma if floor_luma > 0 else null,
		"coverage": float(ground) / area if area > 0 else 0.0,
		"accent_share": float(counts["accent"]) / ground if ground > 0 else 0.0,
		"ground_texels": ground, "footprint_texels": area,
		"outline_coverage": float(counts["outline"]) / area if area > 0 else 0.0}

static func _region(board: Control, record: Dictionary, flat: Image, paint: Image, bare: Image, outline: Image, outline_floor: Image, accent_limit: float) -> Dictionary:
	var tiles: Array[Vector2i] = _tiles(record)
	var transform: Transform2D = board.get_viewport().get_stretch_transform() * board.get_global_transform_with_canvas()
	var counts := _counts()
	var tile_metrics: Array[Dictionary]
	var footprint: Dictionary = {}
	var mask: Dictionary = {}
	var outline_mask: Dictionary = {}
	var vertices: PackedVector2Array
	for tile: Vector2i in tiles:
		var local: PackedVector2Array = board.call("_tile_polygon", tile)
		var diamond := PackedVector2Array()
		var bounds := Rect2(transform * local[0], Vector2.ZERO)
		for i: int in 4:
			var point: Vector2 = transform * local[i]
			bounds = bounds.expand(point)
			diamond.append(point)
			vertices.append(point)
		var tile_counts := _counts()
		for y: int in range(floori(bounds.position.y), ceili(bounds.end.y)):
			for x: int in range(floori(bounds.position.x), ceili(bounds.end.x)):
				var sample := Vector2i(x, y)
				if footprint.has(sample) or not Geometry2D.is_point_in_polygon(Vector2(sample) + Vector2(0.5, 0.5), diamond):
					continue
				footprint[sample] = true
				tile_counts["pixels"] += 1
				var floor_color: Color = bare.get_pixelv(sample)
				if outline.get_pixelv(sample) != outline_floor.get_pixelv(sample):
					outline_mask[sample] = true
					tile_counts["outline"] += 1
				if flat.get_pixelv(sample) == floor_color:
					continue
				mask[sample] = true
				tile_counts["ground"] += 1
				tile_counts["patch_luma"] += Pixel.luminance(flat.get_pixelv(sample)) * 255.0
				tile_counts["bare_patch_luma"] += Pixel.luminance(floor_color) * 255.0
				var value: float = Pixel.luminance(paint.get_pixelv(sample)) * 255.0
				tile_counts["luma"] += value
				tile_counts["luma_squared"] += value * value
				tile_counts["accent"] += int(value > accent_limit)
		_total(counts, tile_counts)
		var tile_summary: Dictionary = _summary(tile_counts)
		tile_summary["tile"] = Fixture.xy(Vector2(tile))
		tile_metrics.append(tile_summary)
	var summary: Dictionary = _summary(counts)
	summary["counts"] = counts
	summary["tiles"] = tile_metrics
	summary["outer_corners_show_floor"] = _corners(footprint, mask, vertices)
	summary["longest_straight_edge_px"] = _longest_edge(footprint, mask)
	summary["outline_outer_corners_show_floor"] = _corners(footprint, outline_mask, vertices)
	summary["outline_longest_straight_edge_px"] = _longest_edge(footprint, outline_mask)
	return summary

static func _corners(footprint: Dictionary, mask: Dictionary, vertices: PackedVector2Array) -> Array[bool]:
	var results: Array[bool]
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var vertex: Vector2 = vertices[0]
		for candidate: Vector2 in vertices:
			if candidate.dot(direction) > vertex.dot(direction): vertex = candidate
		var closest: float = INF
		var exposed: bool = true
		for cell: Vector2i in footprint:
			var distance: float = vertex.distance_squared_to(Vector2(cell) + Vector2(0.5, 0.5))
			if distance < closest:
				closest = distance
				exposed = not mask.has(cell)
		results.append(exposed)
	return results

static func _longest_edge(footprint: Dictionary, mask: Dictionary) -> float:
	var longest: float = 0.0
	var boundary: Dictionary = {}
	for cell: Vector2i in mask:
		for step: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if not mask.has(cell + step):
				# The edge of a cropped footprint can cut a legacy effect.
				if footprint.has(cell + step): boundary[cell] = true
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(1, -1), Vector2i(2, 1), Vector2i(2, -1)]
	for direction: Vector2i in directions:
		for cell: Vector2i in boundary:
			if _edge_step(boundary, cell - direction, direction): continue
			var cursor: Vector2i = cell
			while _edge_step(boundary, cursor, direction):
				cursor += direction
			longest = maxf(longest, (cursor - cell).length())
	return longest

static func _edge_step(boundary: Dictionary, from: Vector2i, direction: Vector2i) -> bool:
	if not boundary.has(from) or not boundary.has(from + direction):
		return false
	if direction.x < 2:
		return true
	# A 2:1 isometric step must include a continuous intervening edge
	# pixel. Aligned but disconnected dither flecks are separate runs.
	return boundary.has(from + Vector2i.RIGHT) or boundary.has(from + Vector2i(1, direction.y))

static func _actor_luma(frame: Image, texture: Texture2D, rect: Rect2) -> float:
	var alpha: Image = texture.get_image()
	assert(alpha != null and not alpha.is_empty(), "Native actor texture is needed for its luminance mask")
	var bounds := Rect2i(Vector2i(rect.position.floor()), Vector2i(rect.end.ceil() - rect.position.floor()))
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	var count: int = 0
	var sum: float = 0.0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var uv: Vector2 = (Vector2(x + 0.5, y + 0.5) - rect.position) / rect.size
			if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0: continue
			if alpha.get_pixelv(Vector2i(uv * Vector2(alpha.get_size()))).a < MIN_OPAQUE_ACTOR_ALPHA: continue
			sum += Pixel.luminance(frame.get_pixel(x, y)) * 255.0
			count += 1
	assert(count > 0, "Native actor mask is empty")
	return sum / count

static func _depth_pixels(source: Image, front_hidden: Image, fire_hidden: Image,
		reflection_hidden: Image, bounds: Rect2i, record: Dictionary) -> Dictionary:
	var front: Dictionary = {}
	var fire: Dictionary = {}
	var reflection: int = 0
	var elements: Array[Dictionary]
	for element: Dictionary in record["ground_projection"].get("depth_elements", []):
		var is_reflection: bool = element["reflection"]
		if not is_reflection and not element["draws_after_body"]: continue
		var is_fire: bool = element["kind"] == Order.Stills.FIRE
		var comparison: Image = reflection_hidden if is_reflection else front_hidden
		var rect: Rect2 = _rect(element["rect_px"])
		var sample := Rect2i(Vector2i(rect.position.floor()), Vector2i(rect.end.ceil() - rect.position.floor()))
		sample = sample.intersection(bounds)
		var visible: int = 0
		for y: int in range(sample.position.y, sample.end.y):
			for x: int in range(sample.position.x, sample.end.x):
				var color: Color = source.get_pixel(x, y)
				if color != comparison.get_pixel(x, y):
					visible += 1
					if not is_reflection: front[Vector2i(x, y)] = true
				if is_fire and color != fire_hidden.get_pixel(x, y):
					fire[Vector2i(x, y)] = true
		if is_reflection: reflection = visible
		elements.append({"key": element["key"], "visible_texels": visible})
	return {"front": front.size(), "fire_front": fire.size(), "reflection": reflection, "elements": elements}

static func _rect(data: Array) -> Rect2:
	return Rect2(data[0], data[1], data[2], data[3])

static func _targets(mode: String, record: Dictionary, region: Dictionary, front: int, fire_front: int,
		reflection: int) -> Dictionary:
	var ground: String = record["ground"]
	if mode != "pixel" or ground == "plain":
		return {}
	var tiles: Array = region["tiles"]
	var front_visible: bool = front > 0
	if ground == "electrified":
		front_visible = front >= ELECTRIFIED_FRONT_PIXELS
	elif ground == "fire" and record["type"] == "harrier":
		front_visible = fire_front >= FIRE_HARRIER_FRONT_PIXELS
	return {"coverage": _all_tiles_in_range(tiles, "coverage"),
		"outline_coverage": _all_tiles_in_range(tiles, "outline_coverage"),
		"edge": region["outline_longest_straight_edge_px"] <= Order.PixelGround.EDGE_RUN_TEXELS,
		"outer_corners": not region["outline_outer_corners_show_floor"].has(false),
		"front_visible": front_visible,
		"reflection_visible": reflection > 0 if ground == "ice" else null}

static func _all_tiles_in_range(tiles: Array, key: String) -> bool:
	return tiles.all(func(tile: Dictionary) -> bool:
		return float(tile[key]) >= COVERAGE_MIN and float(tile[key]) <= COVERAGE_MAX)

static func pair(off: Variant, pixel: Variant) -> Variant:
	if off is Dictionary and pixel is Dictionary:
		var paired: Dictionary = {}
		var keys: Dictionary = off.duplicate(false)
		keys.merge(pixel)
		for key: Variant in keys:
			paired[key] = pair(off.get(key), pixel.get(key))
		return paired
	# Regions and tiles have matching fixture order. Element lists can differ.
	if off is Array and pixel is Array and off.size() == pixel.size() and not off.is_empty() and off[0] is Dictionary and pixel[0] is Dictionary:
		var entries: Array
		for i: int in off.size():
			entries.append(pair(off[i], pixel[i]))
		return entries
	return {"off": off, "pixel": pixel}
