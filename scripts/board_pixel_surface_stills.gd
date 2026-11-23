extends RefCounted
## Select Ice and Rubble motifs from the approved indexed atlases.

const Field = preload("res://scripts/board_pixel_surface_field.gd")
const Decals = preload("res://scripts/board_pixel_surface_decals.gd")
const FIRE: int = 1
const ICE: int = 2
const ELECTRIFIED: int = 3
const RUBBLE: int = 4

static func rubble_placements(field: Field, style: Dictionary, atlases: Dictionary, inset: float) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var half_width: float = Field.HERO_TEXELS_PER_TILE * 0.5
	var projection := Transform2D(Vector2(half_width, half_width * 0.5),
		Vector2(-half_width, half_width * 0.5), Vector2.ZERO)
	if atlases.has(RUBBLE):
		var config: Dictionary = style["rubble"]
		var rects: Array[Rect2i] = atlases[RUBBLE]["rects"]
		for tile: Vector2i in field.tiles:
			if not Field.tile_kind(field.tiles[tile], RUBBLE): continue
			var count: int = int(config["decals_per_tile"])
			var slot_zero: int = Field.world_hash(field.seed, tile, RUBBLE, 0, -1) % rects.size()
			var anchors: Array[Vector2] = Decals._anchors(field.seed, tile, RUBBLE, count,
				float(config["min_spacing_cells"]), projection, true, inset, rects[slot_zero].size.y * 0.5)
			for slot: int in anchors.size():
				var variant: int = Field.world_hash(field.seed, tile, RUBBLE, slot, -1) % rects.size()
				var rect: Rect2i = rects[variant]
				result.append({"key": [tile, RUBBLE, slot], "tile": tile, "kind": RUBBLE,
					"center": Vector2(tile) + anchors[slot], "rect": rect, "size": rect.size})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2 = a["center"]
		var pb: Vector2 = b["center"]
		return pa.x + pa.y < pb.x + pb.y)
	return result

static func ice_contact(atlas: Dictionary, style: Dictionary, seed: int, tile: Vector2i) -> Dictionary:
	var rects: Array[Rect2i] = atlas["rects"]
	if not atlas.has("contact_rects"):
		var image: Image = atlas["texture"].get_image()
		var distance: int = int(style["ice"]["rim_depth_texels"])
		var crops: Array[Dictionary]
		for rect: Rect2i in rects:
			crops.append(_ice_contact_crop(image, rect, distance))
		atlas["contact_rects"] = crops
	var variant: int = Field.world_hash(seed, tile, ICE, 0, -1) % rects.size()
	var crop: Dictionary = atlas["contact_rects"][variant]
	if crop.is_empty(): return {}
	var rect: Rect2i = crop["rect"]
	return {"kind": ICE, "rect": rect, "size": rect.size, "core": crop["core"]}

static func _ice_contact_crop(image: Image, rect: Rect2i, distance: int) -> Dictionary:
	var best := Vector2i.ZERO
	var score: float = INF
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var point := Vector2i(x, y)
			var pixel: Color = image.get_pixelv(point)
			if pixel.a == 0.0:
				continue
			# Favor the brightest authored rim texel nearest the center.
			var rank: float = (1.0 - pixel.r) * 2.0 + (1.0 - pixel.g) * 0.5
			rank += Vector2(point - rect.get_center()).length() / Vector2(rect.size).length() * 0.1
			if rank < score:
				best = point
				score = rank
	if score == INF:
		return {}
	var extent := Vector2i.ONE * distance
	return {"rect": Rect2i(best - extent, extent * 2 + Vector2i.ONE).intersection(rect), "core": best}
