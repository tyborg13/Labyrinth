extends RefCounted

const Fixture = preload("res://tools/grd07/fixture.gd")
const PixelGround = preload("res://scripts/board_pixel_surface_layer.gd")
const Stills = preload("res://scripts/board_pixel_surface_stills.gd")
const Surface = preload("res://scripts/board_surface_presentation.gd")
const LEGACY_LAYERS: Dictionary = {
	"fire": ["SurfaceFire"], "ice": ["SurfaceIce"], "rubble": ["SurfaceRubble"],
	"electrified": ["SurfaceElectric"], "stormcoal": ["SurfaceFire", "SurfaceElectric"],
	"plain": [],
}
const LEGACY_PLANES: Dictionary = {
	"fire": ["tile_local_floor_stamp", "raised_screen_space_particles_and_tongues"],
	"ice": ["tile_local_plate_geometry_with_thickness", "screen_space_shimmer"],
	"rubble": ["tile_local_floor_stamp", "raised_tile_local_chunk_geometry"],
	"electrified": ["tile_local_ribbon_meshes", "screen_space_glow_quads"],
	"stormcoal": ["tile_local_fire_and_electrified", "raised_fire_and_screen_space_glow_quads"],
	"plain": [],
}

static func unit_record(board: Control, unit: Dictionary, ground: String, mode: String) -> Dictionary:
	var pixel: PixelGround = board.get_node_or_null("PixelGround") as PixelGround
	assert((pixel != null) == (mode == "pixel"))
	var tile: Vector2i = unit["pos"]
	var draw_tile: Vector2i = board.call("_effective_unit_tile", unit)
	var tile_layers: Dictionary = board.get("_scene_render_layers_by_tile")
	var owner: Control = tile_layers[draw_tile]
	var actor: Control = owner.get_node("UnitBody_" + str(unit["key"]))
	assert(actor.is_visible_in_tree() and not actor.show_behind_parent)
	var placement: Dictionary = body_placement(board, actor, unit)
	if placement.is_empty(): return {}
	var layers: Array[Dictionary]
	var flags: int = 0
	var projection: Dictionary = {}
	var multiply: bool = pixel != null and ground != "plain"
	if pixel != null:
		flags = pixel.field.tiles.get(tile, 0)
		assert(flags == _pixel_flags(ground))
		if ground == "plain":
			assert(not pixel.visible and pixel._floor == null)
		else:
			var composite: ColorRect = pixel.get_node("SurfaceCells")
			assert(composite.is_visible_in_tree())
			layers.append(_ground_canvas(board, composite, actor))
			assert(not layers.back()["draws_after_body"])
			var physical: Vector2 = (board.get_viewport().get_stretch_transform() * board.get_global_transform_with_canvas()).get_scale()
			var sprite: Texture2D = board.call("_texture_for_unit", unit)
			var unit_texel: Vector2 = (actor.call("_unit_texture_draw_rect", unit, actor.call("_unit_center", unit)) as Rect2).size / sprite.get_size()
			assert(pixel.texel <= minf(unit_texel.x, unit_texel.y) + 0.00001)
			projection = {"texture_texel_px": Fixture.xy(physical * pixel.render_texel),
				"source_texel_px": Fixture.xy(physical * pixel.texel),
				"unit_texel_px": Fixture.xy(physical * unit_texel),
				"tile_to_board_basis": _transform(pixel._tile_projection),
				"depth_elements": _depth_elements(board, pixel, actor, unit, ground)}

	else:
		# These roots are direct children of the occupied tile. They draw
		# behind the tile's own commands and before its normal unit child.
		assert(Surface.retained_cache_enabled and Surface.retained_electric_enabled)
		for name_in_use: String in LEGACY_LAYERS[ground]:
			var node: CanvasItem = tile_layers[tile].get_node(name_in_use)
			assert(node.is_visible_in_tree() and node.show_behind_parent)
			layers.append(_ground_canvas(board, node, actor))
	var footprint: Array[Vector2i] = board.call("_unit_footprint_tiles", unit)
	var polygons: Array = []
	for point_tile: Vector2i in footprint:
		var polygon: Array = []
		for point: Vector2 in board.call("_tile_polygon", point_tile):
			polygon.append(Fixture.xy(point))
		polygons.append(polygon)
	var plane: Array = LEGACY_PLANES[ground] if pixel == null else []
	if flags != 0:
		plane = ["board_density_texels", "ordered_dither_region_boundary", "depth_sorted_atlas_elements"]
	var floor_canvas: CanvasItem = board.get("_static_render_cache_texture")
	assert(floor_canvas.is_visible_in_tree() and not _draws_after(floor_canvas, actor))
	var any_ground_above: bool = layers.any(func(layer: Dictionary) -> bool: return layer["draws_after_body"])
	for element: Dictionary in projection.get("depth_elements", []):
		any_ground_above = any_ground_above or element["draws_after_body"]
	return {
		"actor_key": unit["key"], "type": unit["type"], "role": unit["role"],
		"tile": Fixture.xy(tile), "draw_tile": Fixture.xy(draw_tile),
		"footprint_size": Fixture.xy(board.call("_resolved_unit_footprint", unit)),
		"footprint_diamonds_px": polygons,
		"body": _canvas(board, actor), "body_texture_rect_px": placement["rect_px"], "body_placement": placement,
		"floor": _canvas(board, floor_canvas), "floor_plane": "isometric_tile_diamond", "ground_layers": layers,
		"ground_plane": plane, "ground_projection": projection, "pixel_tile_flags": flags if pixel != null else null,
		"surface_uses_region_mask": flags != 0,
		"ground_layers_draw_above_any_part": any_ground_above,
		"shadow_and_contact": _shadow(board, actor, unit, multiply),
	}

static func body_placement(board: Control, actor: Control, unit: Dictionary) -> Dictionary:
	# UnitBody paints the sprite and contact using its own retained layout.
	# The board's layout can already be current while that layout is stale.
	var painted_unit: Dictionary = actor.get("_unit_outline_actor")
	assert(painted_unit.get("key") == unit["key"] and actor.call("_texture_for_unit", painted_unit) != null)
	var stretch: Transform2D = board.get_viewport().get_stretch_transform()
	var transform: Transform2D = stretch * actor.get_global_transform_with_canvas()
	var board_transform: Transform2D = stretch * board.get_global_transform_with_canvas()
	var center: Vector2 = actor.call("_unit_center", painted_unit)
	var anchor: Vector2 = transform * center
	var rect: Rect2 = transform * (actor.call("_unit_texture_draw_rect", painted_unit, center) as Rect2)
	var body_polygon := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	var overlap_area: float = 0.0
	var anchor_on_footprint: bool = false
	for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
		var local: PackedVector2Array = board.call("_tile_polygon", tile)
		var diamond := PackedVector2Array()
		# The board closes the path by repeating the first vertex.
		for index: int in range(4):
			diamond.append(board_transform * local[index])
		anchor_on_footprint = anchor_on_footprint or Geometry2D.is_point_in_polygon(anchor, diamond)
		for intersection: PackedVector2Array in Geometry2D.intersect_polygons(body_polygon, diamond):
			for index: int in range(1, intersection.size() - 1):
				overlap_area += absf((intersection[index] - intersection[0]).cross(intersection[index + 1] - intersection[0])) * 0.5
	assert(overlap_area > 0.0 and anchor_on_footprint,
		"%s drawn body misses footprint %s (rect %s, anchor %s, overlap %.2f px²)" %
		[unit["key"], unit["pos"], rect, anchor, overlap_area])
	var outline: Sprite2D = actor.get_node("TeamOutline")
	var outline_rect: Rect2 = (stretch * outline.get_global_transform_with_canvas()) * outline.get_rect()
	assert(outline.is_visible_in_tree() and outline_rect.is_equal_approx(rect),
		"%s body and production team outline use different placements" % unit["key"])
	var hud: Control = board.get_node("HudRenderLayer")
	var hud_transform: Transform2D = stretch * hud.get_global_transform_with_canvas()
	for entry: Dictionary in hud.get("_hud_layout_entries_cache"):
		if entry["actor_key"] != unit["key"]: continue
		var hud_anchor: Vector2 = hud_transform * (entry["center"] as Vector2)
		assert(hud_anchor.is_equal_approx(anchor), "%s body and HUD use different anchors" % unit["key"])
		return {"rect_px": Fixture.rect_pixels(rect), "anchor_px": Fixture.xy(anchor),
			"footprint_overlap_px2": overlap_area, "anchor_on_footprint": anchor_on_footprint,
			"outline_rect_px": Fixture.rect_pixels(outline_rect), "hud_anchor_px": Fixture.xy(hud_anchor)}
	assert(false, "Missing HUD layout for %s" % unit["key"])
	return {}

static func _shadow(board: Control, actor: Control, unit: Dictionary, expected_multiply: bool) -> Dictionary:
	var shadow: CanvasItem = actor.get_node_or_null("PixelContactShadow")
	var multiply: bool = shadow != null and shadow.is_visible_in_tree()
	assert(multiply == expected_multiply)
	var meshes: Array = shadow.get("meshes") if multiply else actor.get("_submitted_shadow_meshes")
	if multiply: assert(shadow.show_behind_parent)
	# All four requested subjects use a native projected shadow mesh; the
	# separate authored sole mesh is currently used by other unit types.
	assert(not meshes.is_empty(), "Expected a submitted projected shadow mesh for %s" % unit["type"])
	var authored_contact: bool = meshes.size() > 1
	var has_pool: bool = bool(actor.get("_art_treatment_enabled"))
	var sequence: Array = []
	if authored_contact:
		sequence.append("authored_contact_mesh")
	if has_pool:
		sequence.append("contact_pool_texture")
	sequence.append_array(["projected_shadow_mesh", "body_texture"])
	return {"canvas": _canvas(board, shadow if multiply else actor), "multiply": multiply, "mesh_submissions": meshes.size(),
		"projected_shadow_mesh": true, "contact_pool_texture": has_pool,
		"authored_contact_mesh": authored_contact, "command_order_back_to_front": sequence}

static func _canvas(board: Control, item: CanvasItem) -> Dictionary:
	var indices: Array[int]
	var node: Node = item
	while node != board:
		indices.push_front(node.get_index())
		node = node.get_parent()
	return {"path": str(board.get_path_to(item)), "sibling_indices": indices,
		"z_index": item.z_index, "relative_z": item.z_as_relative, "effective_z": 0,
		"behind_parent": item.show_behind_parent, "canvas_layer": 0}

static func _ground_canvas(board: Control, ground: CanvasItem, body: CanvasItem) -> Dictionary:
	var result: Dictionary = _canvas(board, ground)
	result["draws_after_body"] = _draws_after(ground, body)
	result["shadow_contact_and_body_order"] = "ground_after" if result["draws_after_body"] else "ground_before"
	return result

static func _draws_after(a: CanvasItem, b: CanvasItem) -> bool:
	assert(a.get_canvas() == b.get_canvas())
	for item: CanvasItem in [a, b]:
		var node: Node = item
		while node is CanvasItem:
			var canvas := node as CanvasItem
			assert(canvas.z_index == 0 and not canvas.y_sort_enabled and not canvas.top_level)
			node = node.get_parent()
	# For equal z on this canvas, compare the siblings where the paths split.
	var a_branch: CanvasItem = a
	var b_branch: CanvasItem = b
	assert(a != b and not a.is_ancestor_of(b) and not b.is_ancestor_of(a))
	while not a_branch.get_parent().is_ancestor_of(b):
		a_branch = a_branch.get_parent() as CanvasItem
	while a_branch.get_parent() != b_branch.get_parent():
		b_branch = b_branch.get_parent() as CanvasItem
	if a_branch.show_behind_parent != b_branch.show_behind_parent:
		return b_branch.show_behind_parent
	return a_branch.get_index() > b_branch.get_index()

static func _depth_elements(board: Control, pixel: PixelGround, body: CanvasItem, unit: Dictionary, ground: String) -> Array[Dictionary]:
	var tile: Vector2i = unit["pos"]
	var actor_key: String = unit["key"]
	var result: Array[Dictionary]
	var reflections: int = 0
	var glints: int = 0
	for key: Array in pixel.depth.stamps:
		if not key.has(tile) and not key.has(actor_key): continue
		var stamp: CanvasItem = pixel.depth.stamps[key]
		var is_reflection: bool = key.has("reflection")
		var kind: int = key[1] if not is_reflection else 0
		var after: bool = not stamp.show_behind_parent if stamp.get_parent() == body else _draws_after(stamp, body)
		if key.has("rim_glint"):
			glints += 1
			assert(after)
		elif key.has(tile):
			if ground == "rubble" and key[2] == 0:
				var foot: Vector2 = body.call("_unit_center", unit)
				var motif: Rect2 = stamp.get("rect")
				assert(after and motif.has_point(foot), "The centered front motif must overlap the footprint anchor")
		elif is_reflection:
			reflections += 1
			assert(not after)
		var stretch: Transform2D = board.get_viewport().get_stretch_transform()
		var local: Rect2 = stamp.get("rect")
		var rect: Rect2 = stretch * stamp.get_global_transform_with_canvas() * local
		result.append({"key": str(key), "kind": kind, "canvas": _canvas(board, stamp), "draws_after_body": after,
			"reflection": is_reflection, "rect_px": Fixture.rect_pixels(rect)})
	for pass_index: int in 2:
		var key := Vector3i(tile.x, tile.y, pass_index)
		var stamp: Node2D = pixel.sheet.stamps.get(key)
		var has_sheet: bool = ground in ["fire", "stormcoal", "electrified"]
		assert(is_instance_valid(stamp) == has_sheet)
		if not has_sheet:
			continue
		var after: bool = not stamp.show_behind_parent if stamp.get_parent() == body else _draws_after(stamp, body)
		assert(after == (pass_index == 1))
		var rows: Vector2i = stamp.rows_at(pixel.sheet.tick)
		var stretch: Transform2D = board.get_viewport().get_stretch_transform()
		var center: Vector2 = (stretch * stamp.get_global_transform_with_canvas()).origin
		var rect: Rect2 = pixel.sheet.framebuffer_rect(center)
		result.append({"key": str(key), "kind": Stills.FIRE if rows.x >= 0 else Stills.ELECTRIFIED,
			"canvas": _canvas(board, stamp), "draws_after_body": after, "reflection": false,
			"rows": Fixture.xy(rows), "rect_px": Fixture.rect_pixels(rect)})
	if ground == "rubble":
		assert(result.any(func(stamp: Dictionary) -> bool: return stamp["draws_after_body"]))
		assert(result.any(func(stamp: Dictionary) -> bool: return not stamp["draws_after_body"]))
	assert(glints == int(ground == "ice"))
	assert(reflections == int(ground == "ice"))
	return result

static func raised_stills(board: Control) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var pixel: PixelGround = board.get_node_or_null("PixelGround")
	if pixel == null: return result
	for key: Vector3i in pixel.sheet.stamps:
		var stamp: Node2D = pixel.sheet.stamps[key]
		var tile := Vector2i(key.x, key.y)
		result.append({"tile": Fixture.xy(tile), "front_half": key.z == 1,
			"occupied": pixel.depth.occupied_tiles.has(tile), "rows": Fixture.xy(stamp.rows_at(pixel.sheet.tick)),
			"size_cells": Fixture.xy(pixel.sheet.bounds.size)})
	return result

static func merged_region(board: Control, tiles: Array[Vector2i], ground: String, mode: String) -> Dictionary:
	assert(tiles.size() == 4)
	var pixel: PixelGround = board.get_node_or_null("PixelGround")
	var records: Array[Dictionary]
	for tile: Vector2i in tiles:
		var paths: Array = []
		if mode == "pixel":
			var address: Vector2i = pixel.field.address_of(tile)
			var record: Color = pixel.field.image.get_pixelv(address)
			var flags: int = _pixel_flags(ground)
			assert(int(record.r) == flags)
			for i: int in PixelGround.Field.NEIGHBORS.size():
				var adjacent: Vector2i = tile + PixelGround.Field.NEIGHBORS[i]
				assert(bool(int(record.g) & (1 << i)) == tiles.has(adjacent))
				if tiles.has(adjacent): paths.append(Fixture.xy(adjacent))
			assert(is_equal_approx(pixel.region_inset(tile, flags), pixel.region_inset(tiles[0], flags)))
		records.append({"tile": Fixture.xy(tile), "same_kind_neighbors": paths})
	return {"ground": ground, "tiles": records}

static func _pixel_flags(ground: String) -> int:
	if ground == "stormcoal":
		return PixelGround.Field.ELEMENT_IDS["fire"] | PixelGround.Field.STORMCOAL
	if ground == "rubble":
		return PixelGround.Field.RUBBLE
	return PixelGround.Field.ELEMENT_IDS.get(ground, 0)

static func _transform(value: Transform2D) -> Dictionary:
	return {"x": Fixture.xy(value.x), "y": Fixture.xy(value.y), "origin": Fixture.xy(value.origin)}
