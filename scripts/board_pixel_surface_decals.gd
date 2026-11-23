extends RefCounted
## World-space anchors and per-destination-tile candidate lists for the field shader.

const Field = preload("res://scripts/board_pixel_surface_field.gd")
const AtlasMotion = preload("res://scripts/board_pixel_surface_atlas_motion.gd")
const KIND_NAMES: Dictionary = {1: "fire", 2: "ice", 3: "electrified", 4: "rubble"}
const DRAW_ORDER: PackedInt32Array = [2, 4, 1, 3]
const FIXTURE_FLAG: String = "LABYRINTH_GRD03_FIXTURE_ATLASES"
const DIAMOND_INTERIOR: float = 0.49999
const PLACEMENT_ATTEMPTS: int = 128
const TABLE_ROW_TEXELS: int = 256
const PLACEMENT_TEXELS: int = 3

var placements: Array[Dictionary]
var bins: Dictionary
var image: Image

static func load_atlases(style: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var editor: bool = OS.has_feature("editor")
	var override_atlases: bool = editor and OS.get_environment(FIXTURE_FLAG) == "1"
	for kind: int in DRAW_ORDER:
		var config: Dictionary = style[KIND_NAMES[kind]]
		var use_fixture: bool = editor and (override_atlases or config["atlas"] == null)
		var atlas: Variant = config["fixture_atlas"] if use_fixture else config["atlas"]
		if not atlas is Dictionary:
			continue
		var path: String = atlas["path"]
		var texture: Texture2D
		if use_fixture:
			var absolute_path: String = ProjectSettings.globalize_path("res://" + path)
			if not FileAccess.file_exists(absolute_path):
				push_warning("Generate the ground decal fixture atlas with tools/grd03/make_fixture_atlases.py: " + path)
				continue
			var fixture: Image = Image.load_from_file(absolute_path)
			if fixture != null and not fixture.is_empty():
				texture = ImageTexture.create_from_image(fixture)
		else:
			texture = load(path) as Texture2D
		if texture == null:
			push_error("Ground decal atlas could not be loaded: " + path)
			continue
		var rects: Array[Rect2i]
		for bounds: Array in atlas["rects"]:
			var rect := Rect2i(bounds[0], bounds[1], bounds[2], bounds[3])
			if not rect.has_area() or not Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(rect):
				push_error("Invalid ground decal rect %s in %s" % [rect, path])
				continue
			rects.append(rect)
		if not rects.is_empty():
			var loaded: Dictionary = {"texture": texture, "rects": rects, "fixture": use_fixture}
			AtlasMotion.prepare(kind, loaded, config)
			result[kind] = loaded
	return result

func rebuild(field: Field, style: Dictionary, atlases: Dictionary,
		tile_to_cell: Transform2D, min_tile_to_cell: Transform2D) -> void:
	placements.clear()
	bins.clear()
	var cell_to_tile: Transform2D = tile_to_cell.affine_inverse()
	for kind: int in DRAW_ORDER:
		if not atlases.has(kind):
			continue
		var config: Dictionary = style[KIND_NAMES[kind]]
		var rects: Array[Rect2i] = atlases[kind]["rects"]
		var group: Array[Dictionary]
		for tile: Vector2i in field.tiles:
			if not Field.tile_kind(field.tiles[tile], kind):
				continue
			var anchors: Array[Vector2] = _anchors(field.seed, tile, kind,
				int(config["decals_per_tile"]), float(config.get("min_spacing_cells", 0.0)), min_tile_to_cell)
			for slot: int in anchors.size():
				var center: Vector2 = Vector2(tile) + anchors[slot]
				var rect: Rect2i = rects[Field.world_hash(field.seed, tile, kind, slot, -1) % rects.size()]
				group.append({"tile": tile, "kind": kind, "slot": slot, "center": center,
					"rect": rect, "screen_y": (tile_to_cell * center).y})
		group.sort_custom(_back_to_front)
		for decal: Dictionary in group:
			_bin_decal(decal, field, cell_to_tile, placements.size())
			placements.append(decal)
	_pack(field.area, atlases)

static func _back_to_front(a: Dictionary, b: Dictionary) -> bool:
	if a["screen_y"] != b["screen_y"]:
		return a["screen_y"] < b["screen_y"]
	if a["tile"] != b["tile"]:
		return a["tile"] < b["tile"]
	return a["slot"] < b["slot"]

static func _anchors(seed: int, tile: Vector2i, kind: int, count: int, spacing: float,
		tile_to_cell: Transform2D, split_depth: bool = false, outer_inset: float = 0.0, front_contact_cells: float = 0.0) -> Array[Vector2]:
	var separations: Vector2 = Field.cells_per_border_normal(tile_to_cell)
	# Half the separation from each edge also protects spacing across tiles.
	var extent: Vector2 = (Vector2.ONE * (DIAMOND_INTERIOR - outer_inset) - Vector2.ONE * spacing * 0.5 / separations).max(Vector2.ZERO)
	var anchors: Array[Vector2]
	if split_depth:
		anchors.append(tile_to_cell.affine_inverse().basis_xform(Vector2(0.0, front_contact_cells)))
	for attempt: int in PLACEMENT_ATTEMPTS:
		if anchors.size() == count:
			return anchors
		var bits: int = Field.world_hash(seed, tile, kind, anchors.size(), attempt)
		var candidate: Vector2 = extent * (Vector2(Field.hash_unit(bits), Field.hash_unit(bits >> 16)) * 2.0 - Vector2.ONE)
		if split_depth and ((candidate.x + candidate.y > 0.0) != (anchors.size() % 2 == 0)):
			continue
		var separated: bool = true
		for anchor: Vector2 in anchors:
			if (tile_to_cell * (candidate - anchor)).length_squared() < spacing * spacing:
				separated = false
				break
		if separated:
			anchors.append(candidate)
	if anchors.size() == count:
		return anchors
	# Pack a centered cell-space lattice if greedy placement got boxed in.
	# Narrow projections first give up the cross-tile inset, then compress
	# the lattice only if the requested separation physically cannot fit it.
	var cell_to_tile: Transform2D = tile_to_cell.affine_inverse()
	var lattice: Vector2 = _best_lattice(count, extent, cell_to_tile)
	if lattice.y < spacing:
		lattice = _best_lattice(count, Vector2.ONE * DIAMOND_INTERIOR, cell_to_tile)
	var columns: int = int(lattice.x)
	var rows: int = ceili(float(count) / columns)
	var step: float = minf(spacing, lattice.y)
	var sign_x: float = -1.0 if Field.world_hash(seed, tile, kind, -1, 0) & 1 else 1.0
	var sign_y: float = -1.0 if Field.world_hash(seed, tile, kind, -1, 1) & 1 else 1.0
	anchors.clear()
	for slot: int in count:
		var point := (Vector2(slot % columns, floori(float(slot) / columns))
			- Vector2(columns - 1, rows - 1) * 0.5)
		anchors.append(cell_to_tile * (point * Vector2(sign_x, sign_y) * step))
	return anchors

static func _best_lattice(count: int, extent: Vector2, cell_to_tile: Transform2D) -> Vector2:
	var best := Vector2(1, -1)
	for columns: int in range(1, count + 1):
		var rows: int = ceili(float(count) / columns)
		var demand: Vector2 = cell_to_tile.x.abs() * (columns - 1) * 0.5 + cell_to_tile.y.abs() * (rows - 1) * 0.5
		var step: float = minf(extent.x / maxf(demand.x, 0.000001), extent.y / maxf(demand.y, 0.000001))
		if step > best.y:
			best = Vector2(columns, step)
	return best

func _bin_decal(decal: Dictionary, field: Field, cell_to_tile: Transform2D, index: int) -> void:
	var rect: Rect2i = decal["rect"]
	var half_size: Vector2 = Vector2(rect.size) * 0.5 + Vector2.ONE
	var extent: Vector2 = cell_to_tile.x.abs() * half_size.x + cell_to_tile.y.abs() * half_size.y
	var center: Vector2 = decal["center"]
	var first := Vector2i((center - extent + Vector2.ONE * 0.5).floor())
	var last := Vector2i((center + extent + Vector2.ONE * 0.5).floor())
	var owner: Vector2i = decal["tile"]
	var neighbors := Rect2i(owner - Vector2i.ONE, Vector2i(3, 3))
	var covered: Rect2i = Rect2i(first, last - first + Vector2i.ONE).intersection(neighbors).intersection(field.area)
	for y: int in range(covered.position.y, covered.end.y):
		for x: int in range(covered.position.x, covered.end.x):
			var tile := Vector2i(x, y)
			if Field.tile_kind(field.tiles.get(tile, 0), decal["kind"]):
				if not bins.has(tile):
					bins[tile] = PackedInt32Array()
				var indices: PackedInt32Array = bins[tile]
				indices.append(index)
				bins[tile] = indices

func _pack(area: Rect2i, atlases: Dictionary) -> void:
	var position_start: int = area.get_area()
	var list_start: int = position_start + placements.size() * PLACEMENT_TEXELS
	var total: int = list_start
	for indices: PackedInt32Array in bins.values():
		total += indices.size()
	var width: int = mini(total, TABLE_ROW_TEXELS)
	image = Image.create_empty(width, ceili(float(total) / width), false, Image.FORMAT_RGBAF)
	for i: int in placements.size():
		var decal: Dictionary = placements[i]
		var center: Vector2 = decal["center"]
		var rect: Rect2i = decal["rect"]
		var address: int = position_start + i * PLACEMENT_TEXELS
		_write(address, Color(center.x, center.y, decal["kind"], decal["slot"]))
		_write(address + 1, Color(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		var motion: Dictionary = atlases[decal["kind"]].get("motion_records", {})
		if motion.has(rect):
			_write(address + 2, motion[rect])
	var cursor: int = list_start
	for tile: Vector2i in bins:
		var pos: Vector2i = tile - area.position
		var indices: PackedInt32Array = bins[tile]
		_write(pos.y * area.size.x + pos.x, Color(cursor, indices.size(), 0, 0))
		for index: int in indices:
			_write(cursor, Color(position_start + index * PLACEMENT_TEXELS, 0, 0, 0))
			cursor += 1

func _write(index: int, value: Color) -> void:
	var width: int = image.get_width()
	@warning_ignore("integer_division")
	image.set_pixel(index % width, index / width, value)
