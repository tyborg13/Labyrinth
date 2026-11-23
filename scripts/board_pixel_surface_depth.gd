extends RefCounted
## Keep Ice and Rubble motifs in the existing painter passes and resolve
## visual occupancy for the Fire and Lightning sheets.

const Field = preload("res://scripts/board_pixel_surface_field.gd")
const Atlas = preload("res://scripts/board_pixel_surface_stills.gd")
const Draw = preload("res://scripts/board_pixel_surface_stamp.gd")
const Flying = preload("res://scripts/enemy_mechanics/flying.gd")
const ActorDepth = preload("res://scripts/maquette_cutout_runtime/board_depth.gd")

const ICE: int = 2
const REFLECTION_HEIGHT_TEXELS: int = 8
const REFLECTION_OPACITY: float = 0.15

var placements: Array[Dictionary]
var stamps: Dictionary = {}
var _field_image: Image
var occupied_tiles: Dictionary = {}

static func visible_actor(board: Control, unit: Dictionary) -> bool:
	return str(unit.get("role", "")) != "illusion" and _visible_body(board, unit)

static func _visible_body(board: Control, unit: Dictionary) -> bool:
	if str(unit.get("role", "")) == "illusion_preview" or bool(unit.get("burrowed", false)):
		return false
	return board.call("_board_tile_is_visible_to_player", unit["pos"]) and board.call("_umbra_actor_clip_for_unit", unit).is_empty()

static func footprint_center(board: Control, unit: Dictionary) -> Vector2:
	var shown: Dictionary = board.get("presentation")
	if shown.get("unit_footprint_world_positions", {}).has(unit["key"]):
		return ActorDepth.position(board, unit, shown)
	return board.call("_unit_center", unit)

func clear() -> void:
	_clear_stills()
	occupied_tiles.clear()

func _clear_stills() -> void:
	for stamp: Draw in stamps.values():
		if is_instance_valid(stamp):
			stamp.hide()
			stamp.queue_free()
	stamps.clear()
	placements.clear()
	_field_image = null

func sync(board: Control, ground: Node2D, units: Array[Dictionary]) -> void:
	var field: Field = ground.field
	var actors: Array[Dictionary] = _actors(board, units)
	if ground.sheet.ink != null:
		occupied_tiles = _occupants(board, ground._tile_projection.affine_inverse(), field, actors)
		ground.sheet.sync(board, field, ground._tile_projection, occupied_tiles)
	if (field.kind_mask & (1 << ICE)) == 0 and not field.has_rubble:
		if not stamps.is_empty():
			_clear_stills()
		return
	if field.image != _field_image:
		_field_image = field.image
		placements = Atlas.rubble_placements(field, ground._style, ground._atlases, ground.edge_inset())
	var rows: Dictionary = _rows(board)
	var retained: Dictionary = {}
	for placement: Dictionary in placements:
		var tile: Vector2i = placement["tile"]
		var base: Vector2 = ground._tile_projection * (placement["center"] as Vector2)
		if placement["key"][2] == 0:
			base.y = (ground._tile_projection * Vector2(tile)).y + placement["size"].y * ground.render_texel * 0.5
		_present(ground, rows, actors, retained, placement, base, tile)
	for actor: Dictionary in actors:
		if actor["standing"]:
			_present_contact(ground, rows, actors, retained, actor)
	for key: Variant in stamps.keys():
		if retained.has(key):
			continue
		var stamp: Draw = stamps[key]
		if is_instance_valid(stamp):
			stamp.hide()
			stamp.queue_free()
		stamps.erase(key)

static func _occupants(board: Control, to_tile: Transform2D, field: Field, actors: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for actor: Dictionary in actors:
		if not actor["occupies"]:
			continue
		var size: Vector2i = actor["footprint"]
		var foot: Vector2 = actor["foot"]
		var origin := Vector2i((to_tile * foot - Vector2(size - Vector2i.ONE) * 0.5 + Vector2.ONE * 0.5).floor())
		for y: int in size.y:
			for x: int in size.x:
				var tile := origin + Vector2i(x, y)
				if _has_sheet(field, tile):
					result[tile] = actor
	var shown: Dictionary = board.get("presentation")
	for prop: Dictionary in shown.get("scene_props", []):
		var tile: Vector2i = prop.get("tile", Vector2i(-1, -1))
		if not _has_sheet(field, tile) or bool(result.get(tile, {}).get("grounded", false)):
			continue
		var texture: Texture2D = board.call("_texture_for_scene_prop", prop)
		if texture == null:
			continue
		var rect: Rect2 = board.call("_scene_prop_rect", texture, prop)
		var foot := Vector2(rect.get_center().x, rect.end.y)
		if Geometry2D.is_point_in_polygon(foot, board.call("_tile_polygon", tile)):
			_add_grounded_prop(result, tile)
	var state: Dictionary = board.get("combat_state")
	var terrain_textures: Dictionary = board.get("_terrain_textures")
	for terrain: Dictionary in state.get("terrain", []):
		var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		if (_has_sheet(field, tile) and not bool(result.get(tile, {}).get("grounded", false))
				and Field.Rules.terrain_is_live(terrain) and terrain_textures.get(str(terrain.get("kind", ""))) != null):
			_add_grounded_prop(result, tile)
	return result

static func _add_grounded_prop(occupants: Dictionary, tile: Vector2i) -> void:
	# A flying actor leaves the grounded choice to the prop beneath it.
	occupants[tile] = (occupants.get(tile, {}) as Dictionary).merged({"grounded": true}, true)

static func _has_sheet(field: Field, tile: Vector2i) -> bool:
	var flags: int = field.tiles.get(tile, 0)
	return Field.tile_kind(flags, Atlas.FIRE) or Field.has_electrified_decal(flags)

func _present(ground: Node2D, rows: Dictionary, actors: Array[Dictionary],
		retained: Dictionary, placement: Dictionary, base: Vector2, tile: Vector2i) -> void:
	var kind: int = placement["kind"]
	var source: Rect2i = placement["rect"]
	var footprint: Vector2 = Vector2(placement["size"]) * ground.render_texel
	var rect := Rect2(base - Vector2(footprint.x * 0.5, footprint.y), footprint)
	var slot: Dictionary = _painter_slot(rows, actors, tile, base, rect, ground._tile_projection)
	if slot.is_empty():
		return
	var stamp: Draw = _stamp(retained, placement["key"], slot["parent"], slot["behind"])
	stamp.visible = not placement["key"].has("rim_glint") or ground.reduced_motion
	stamp.present_atlas(ground, ground._atlases[kind]["texture"], source, rect, ground.ramp(kind),
		kind, placement.get("core", Vector2i(-1, -1)))

func _present_contact(ground: Node2D, rows: Dictionary, actors: Array[Dictionary],
		retained: Dictionary, actor: Dictionary) -> void:
	var foot: Vector2 = actor["foot"]
	var board_point: Vector2 = ground._tile_projection.affine_inverse() * foot
	var tile := Vector2i((board_point + Vector2.ONE * 0.5).floor())
	var flags: int = ground.field.tiles.get(tile, 0)
	var key: String = actor["key"]
	var seed: int = ground.field.seed
	if Field.tile_kind(flags, ICE) and ground._atlases.has(ICE):
		var glint_key: Array = [tile, ICE, "rim_glint"]
		if not retained.has(glint_key):
			var glint: Dictionary = Atlas.ice_contact(ground._atlases[ICE], ground._style, seed, tile)
			if not glint.is_empty():
				glint["key"] = glint_key
				var base: Vector2 = foot + Vector2(0, glint["size"].y * 0.5 * ground.render_texel)
				_present(ground, rows, actors, retained, glint, base, tile)
		var body: Texture2D = actor["texture"]
		if body != null:
			var reflection: Draw = _stamp(retained, [key, "reflection"], ground, false)
			reflection.present_reflection(ground, body, actor["rect"], foot, tile,
				REFLECTION_HEIGHT_TEXELS, REFLECTION_OPACITY)

func _stamp(retained: Dictionary, key: Variant, parent: CanvasItem, behind: bool) -> Draw:
	var stamp: Draw = stamps.get(key)
	if not is_instance_valid(stamp):
		stamp = Draw.new()
		stamp.name = "GroundReflection" if key.has("reflection") else "GroundElement"
		parent.add_child(stamp, true)
		stamps[key] = stamp
	elif stamp.get_parent() != parent:
		stamp.reparent(parent, false)
	stamp.show_behind_parent = behind
	if behind:
		var shadow: Node = parent.get_node_or_null("PixelContactShadow")
		if shadow != null and stamp.get_index() > shadow.get_index():
			parent.move_child(stamp, shadow.get_index())
	retained[key] = true
	return stamp

static func _painter_slot(rows: Dictionary, actors: Array[Dictionary], tile: Vector2i,
		base: Vector2, rect: Rect2, tile_projection: Transform2D) -> Dictionary:
	var row: Vector2i = rows.get(tile.x + tile.y, Vector2i(-1, -1))
	if not rows.has(tile.x + tile.y):
		return {}
	var front: bool = base.y > (tile_projection * Vector2(tile)).y
	var parents: Dictionary = rows["front"] if front else rows["back"]
	var parent: CanvasItem = parents.get(Vector2i(row.y, tile.x + tile.y - row.y) if front else Vector2i(row.x, tile.x + tile.y - row.x))
	# Decals paint before effects in a shared retained slot.
	var behind: bool = true
	# Large or moving footprints can use a different retained painter slot
	# from their center. Use the real body canvas wherever pixels overlap.
	for actor: Dictionary in actors:
		if not actor["contact"] or not rect.intersects(actor["rect"]):
			continue
		var body: CanvasItem = actor["canvas"]
		if body == null:
			continue
		parent = body
		behind = base.y <= actor["foot"].y
		if behind:
			break
	return {"parent": parent, "behind": behind} if is_instance_valid(parent) else {}

static func _rows(board: Control) -> Dictionary:
	var result: Dictionary = {
		"front": board.get("_scene_front_effect_render_layers_by_tile"),
		"back": board.get("_scene_back_effect_render_layers_by_tile"),
	}
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		var row: int = tile.x + tile.y
		var span: Vector2i = result.get(row, Vector2i(tile.x, tile.x))
		result[row] = Vector2i(span.x, tile.x)
	return result

static func _actors(board: Control, units: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var occlusion: Node = board.get("_occlusion_silhouettes")
	var team: Variant = occlusion.get("team") if is_instance_valid(occlusion) else null
	var shown: Dictionary = board.get("presentation")
	for unit: Dictionary in units:
		if not _visible_body(board, unit):
			continue
		var key: String = unit["key"]
		var center: Vector2 = board.call("_unit_center", unit)
		var foot: Vector2 = footprint_center(board, unit)
		var rect: Rect2 = board.call("_unit_texture_draw_rect", unit, center)
		var canvas: CanvasItem = team.bodies.get(key) if team != null and occlusion.get("tool_enabled") else null
		var standing: bool = not bool(unit.get("death_animation", false)) and not (shown.get("unit_throw_ground_positions", {}) as Dictionary).has(key)
		var occupies: bool = standing and not board.call("_unit_is_preview_echo", unit) and not bool(unit.get("preview", false))
		var contact: bool = str(unit.get("role", "")) != "illusion"
		result.append({"key": key, "foot": foot, "rect": rect, "canvas": canvas, "standing": standing and contact,
			"contact": contact, "occupies": occupies, "grounded": not Flying.flying(unit),
			"footprint": board.call("_resolved_unit_footprint", unit),
			"texture": board.call("_texture_for_unit", unit)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_body: CanvasItem = a["canvas"]
		var b_body: CanvasItem = b["canvas"]
		if a_body == null or b_body == null: return a_body != null
		if a_body.get_parent() == b_body.get_parent(): return a_body.get_index() < b_body.get_index()
		return a_body.get_parent().get_index() < b_body.get_parent().get_index())
	return result
