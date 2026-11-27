extends RefCounted

# Production rest-pose alpha sources in the same painter order as the board.
# Live rim drawing remains separate: idle/walk phase never rebuilds rest masks.
const Assets = preload("res://scripts/asset_loader.gd")
const StaticFacing = preload("res://scripts/static_enemy_facing.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Field = preload("res://scripts/board_pixel_surface_field.gd")
const SurfacePaint = preload("res://scripts/board_surface_presentation.gd")
const DragonProps = preload("res://scripts/dragon_board_props.gd")
const Pathing = preload("res://scripts/path_utils.gd")
const DEATH_SITE_ID := "death_site_embers"
const FILL_SURFACES := ["fire", "electrified", "ice"]

static func noctyrax_refuge_centers(state: Dictionary) -> Array[Vector2i]:
	var centers: Array[Vector2i]
	var has_noctyrax: bool = false
	var snuffed_id: int = -1
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) != "noctyrax" or int(enemy.get("hp", 0)) <= 0: continue
		has_noctyrax = true
		for action: Dictionary in enemy.get("intent", {}).get("actions", []):
			if bool(action.get("snuff_brazier", false)): snuffed_id = int(action.get("brazier_id", -1))
	if not has_noctyrax: return centers
	for brazier: Dictionary in state.get("guardian_braziers", []):
		if bool(brazier.get("lit", true)) and int(brazier.get("id", -1)) != snuffed_id:
			centers.append(brazier["pos"])
	return centers

static func noctyrax_refuge_edges(grid: Array, tile: Vector2i, centers: Array[Vector2i]) -> PackedInt32Array:
	var edges := PackedInt32Array()
	if centers.is_empty() or not Pathing.is_passable(grid, tile): return edges
	for center: Vector2i in centers:
		if Pathing.manhattan(tile, center) > 2: continue
		for index: int in Pathing.DIRS_4.size():
			if Pathing.manhattan(tile + Pathing.DIRS_4[index], center) > 2: edges.append(index)
	return edges

# Rule decals and exit targets have a board-wide floor pass. Their lifted
# medallions and HUD passes are separate and need no show-through.
static func _floor_sources(board: Control, entries: Array[Dictionary]) -> void:
	var state: Dictionary = board.get("combat_state")
	var shown: Dictionary = board.get("presentation")
	var exits: Dictionary = board.get("exit_tiles")
	var danger: Dictionary = board.get("_rest_threat_tile_alphas")
	var marks: Dictionary = {}
	var decals: Dictionary = {}
	for decal: Dictionary in shown.get("impact_decals", []):
		if not bool(decal.get("baked_strike", false)): decals[decal.get("tile", Vector2i(-1, -1))] = true
	for mark: Dictionary in state.get("meteor_marks", []):
		for tile: Vector2i in mark.get("tiles", []): marks[tile] = true
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if not board.call("_board_tile_is_visible_to_player", tile): continue
		if danger.has(tile) or marks.has(tile): _add_floor(board, entries, "danger", tile)
		if exits.has(tile) or tile in shown.get("objective_exit_target_tiles", []):
			_add_floor(board, entries, "exit", tile)
		if decals.has(tile) or board.call("_tile_has_moss", "floor", tile):
			_add_floor(board, entries, "decorative_decal", tile)

static func _add_floor(board: Control, entries: Array[Dictionary], kind: String, tile: Vector2i, parts: Array[Dictionary] = [], surface_kind: String = "") -> void:
	var diamond: PackedVector2Array = board.call("_tile_polygon", tile)
	var bounds := Rect2(diamond[0], Vector2.ZERO)
	for point: Vector2 in diamond: bounds = bounds.expand(point)
	for part: Dictionary in parts: bounds = bounds.merge(part["rect"])
	entries.append({"key": "%s:%s" % [kind, tile], "kind": kind, "tile": tile, "data": {},
		"eligible": true, "fill": kind in ["exit", "refuge"] or surface_kind in FILL_SURFACES,
		"surface_kind": surface_kind, "rect": bounds, "diamond": diamond, "parts": parts})

static func _add_surface(board: Control, entries: Array[Dictionary], state: Dictionary, tile: Vector2i) -> void:
	var ground: Node = board.get("_pixel_ground")
	var flags: int = ground.field.tiles.get(tile, 0) if is_instance_valid(ground) else 0
	var surface: Dictionary = Surface.surface_at(state, tile)
	var kind: String = Surface.kind(str(surface.get("elemental", "")))
	if flags == 0 and not bool(surface.get("rubble", false)) and kind not in Surface.ELEMENTAL_KINDS: return
	var parts: Array[Dictionary]
	if is_instance_valid(ground) and flags != 0:
		for key: Variant in ground.depth.stamps:
			if not key is Array or key.size() < 3 or not key[0] is Vector2i or key[0] != tile: continue
			var stamp: Node = ground.depth.stamps[key]
			if not is_instance_valid(stamp) or not stamp.visible: continue
			var ink: ShaderMaterial = stamp.material
			var region: Vector4 = ink.get_shader_parameter("art_rect")
			parts.append({"rect": stamp.rect, "mask_texture": ink.get_shader_parameter("art_texture"),
				"mask_region": Rect2i(int(region.x), int(region.y), int(region.z), int(region.w))})
		if ground.sheet.ink != null and (Field.tile_kind(flags, 1) or Field.has_electrified_decal(flags)):
			var sheet: Variant = ground.sheet
			var atlas: Texture2D = sheet.ink.get_shader_parameter("atlas")
			var scale: Vector2 = (ground.get_viewport().get_stretch_transform() * ground.get_global_transform()).get_scale().abs()
			var cell: Vector2 = Vector2.ONE * sheet.cell_px / scale
			var cells := Vector2i(sheet.bounds.size)
			for pass_index: int in 2:
				var stamp: Node = sheet.stamps.get(Vector3i(tile.x, tile.y, pass_index))
				if not is_instance_valid(stamp): continue
				var rows: Vector2i = stamp.rows_at(sheet.tick)
				for row: int in [rows.x, rows.y]:
					if row < 0: continue
					parts.append({"rect": Rect2(stamp.position + sheet.bounds.position * cell, sheet.bounds.size * cell),
						"mask_texture": atlas, "mask_region": Rect2i(Vector2i(0, row * cells.y), Vector2i(sheet.frames * cells.x, cells.y)),
						"sheet_cells": cells, "sheet_frames": sheet.frames})
	var surface_kind: String = kind if not kind.is_empty() else ("rubble" if bool(surface.get("rubble", false)) else "")
	_add_floor(board, entries, "surface", tile, parts, surface_kind)


static func collect(board: Control) -> Array[Dictionary]:
	var entries: Array[Dictionary]
	var units: Array = board.call("_visible_units")
	var state: Dictionary = board.get("combat_state")
	var shown: Dictionary = board.get("presentation")
	var grid: Array = state.get("grid", [])
	_floor_sources(board, entries)
	var death_site: Dictionary = shown.get("death_site_embers", {})
	if not death_site.is_empty():
		_add_object(board, entries, "loot", {"id": DEATH_SITE_ID, "kind": "dropped_embers", "pos": death_site.get("tile", Vector2i(-1, -1))}, true)
	var refuges: Array[Vector2i] = noctyrax_refuge_centers(state)
	for loot: Dictionary in state.get("loot", []):
		if board.call("_loot_renders_below_path", loot): _add_object(board, entries, "loot", loot, true)
	for trap: Dictionary in state.get("traps", []):
		_add_object(board, entries, "trap", trap, true)
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		# Rendered tiles can briefly describe a previous board while a new state lands.
		if tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= (grid[tile.y] as Array).size(): continue
		if board.call("_board_tile_is_visible_to_player", tile):
			_add_surface(board, entries, state, tile)
			if not refuges.is_empty() and not noctyrax_refuge_edges(grid, tile, refuges).is_empty():
				_add_floor(board, entries, "refuge", tile)
			for prop: Dictionary in shown.get("scene_props", []):
				if prop.get("tile", Vector2i(-1, -1)) != tile: continue
				var texture: Texture2D = board.call("_texture_for_scene_prop", prop)
				if texture != null: entries.append(_blocker(tile, board.call("_scene_prop_rect", texture, prop), str(prop.get("kind", "scene_prop")), texture))
			var tile_id: String = board.call("_display_tile_id", str(grid[tile.y][tile.x]), tile)
			if tile_id == "wall" and not board.call("_is_outer_boundary_tile", grid, tile): tile_id = "pillar"
			if tile_id == "pillar":
				var texture: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar")
				if texture != null: entries.append(_blocker(tile, board.call("_prop_draw_rect", texture, board.call("_prop_rect_for_tile", tile)), "pillar", texture))
			elif tile_id == "wall":
				for segment: Dictionary in board.call("_boundary_prop_segments", tile_id, grid, tile):
					entries.append(_blocker(tile, segment["draw_rect"], "wall", segment["texture"], Rect2i(segment.get("source_rect", Rect2()))))
			elif tile_id == "door":
				var texture: Texture2D = board.call("_door_texture_for_tile", grid, tile)
				if texture != null: entries.append(_blocker(tile, board.call("_prop_draw_rect", texture, board.call("_door_rect_for_tile", tile, grid)), "door", texture))
		for terrain: Dictionary in state.get("terrain", []):
			if terrain.get("pos", Vector2i(-1, -1)) == tile: _add_object(board, entries, "terrain", terrain)
		for loot: Dictionary in state.get("loot", []):
			if loot.get("pos", Vector2i(-1, -1)) == tile and not board.call("_loot_renders_below_path", loot): _add_object(board, entries, "loot", loot)
		for unit: Dictionary in units:
			if board.call("_effective_unit_tile", unit) != tile or board.call("_unit_is_preview_echo", unit): continue
			if not board.call("_board_tile_is_visible_to_player", unit.get("pos", Vector2i(-1, -1))): continue
			# Privacy is stricter than an animated Umbra edge: never reconstitute
			# a clipped/hidden actor through the topmost outline pass.
			if not board.call("_umbra_actor_clip_for_unit", unit).is_empty() or bool(unit.get("burrowed", false)): continue
			var entry: Dictionary = _blocker(tile, board.call("_unit_draw_rect", unit))
			entry.merge({"key": str(unit.get("key", "")), "kind": "unit", "data": unit,
				"eligible": int(unit.get("hp", 0)) > 0 and not bool(unit.get("death_animation", false))}, true)
			entry.merge(_unit_mask(board, unit), true)
			entries.append(entry)
	return entries

static func _blocker(tile: Vector2i, rect: Rect2, prop_kind: String = "", texture: Texture2D = null, region: Rect2i = Rect2i()) -> Dictionary:
	return {"tile": tile, "rect": rect, "kind": "prop", "prop_kind": prop_kind, "eligible": false, "mask_texture": texture, "mask_region": region, "mask_pose": "rest"}

static func _add_object(board: Control, entries: Array[Dictionary], kind: String, data: Dictionary, ground: bool = false) -> void:
	var tile: Vector2i = data.get("pos", Vector2i(-1, -1))
	if not board.call("_board_tile_is_visible_to_player", tile): return
	if kind == "loot" and (bool(data.get("claimed", false)) or float(board.call("_missed_equipment_disintegration_progress", data)) >= 0.0): return
	if kind == "terrain" and not Surface.terrain_is_live(data): return
	var entry: Dictionary = {"key": "%s:%s:%s" % [kind, str(data.get("id", "")), str(tile)],
		"tile": tile, "kind": kind, "data": data, "ground": ground, "eligible": true, "fill": kind in ["trap", "loot"]}
	var draw: Dictionary = drawing(board, entry)
	if draw.is_empty(): return
	entry["rect"] = draw["rect"]
	entry["mask_texture"] = draw["texture"]
	entry["mask_pose"] = "rest"
	if kind == "terrain": entry["eligible"] = false
	entries.append(entry)

static func _unit_mask(board: Control, unit: Dictionary) -> Dictionary:
	var texture: Texture2D = board.call("_unit_hud_anchor_texture", unit)
	var renderer: Node = board.call("unit_cutout_renderer", unit)
	var facing: String = "front"
	var mirrored: bool = false
	var pose_set: String = "rest"
	if is_instance_valid(renderer):
		pose_set = str(renderer.get("clip"))
		facing = str(renderer.get("facing"))
		mirrored = bool(renderer.get("mirrored"))
		# Hero rest_texture is the production's gear-aware neutral rest, also
		# used by HUD/obstruction registration. Enemy layouts declare both views.
		if str(unit.get("type", "")) == "player":
			texture = renderer.call("rest_texture")
		else:
			var rigs: Dictionary = renderer.get("rigs")
			var rig: Node = rigs.get(facing)
			if is_instance_valid(rig):
				var source: String = str((rig.get("layout") as Dictionary).get("rest_source", ""))
				if not source.is_empty():
					texture = Assets.load_texture_source_first(rig.call("_resolve", source))
				else:
					# Older dedicated rigs predate rest_source in their layout.
					# Their renderer still declares the production rest asset.
					var constants: Dictionary = renderer.get_script().get_script_constant_map()
					var rest_path: String = str(constants.get("REST_PATH", ""))
					var layout_path: String = rig.call("_layout_path", facing) if rest_path.is_empty() else ""
					var path: String = rest_fallback_path(layout_path, facing, rest_path)
					if not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
						texture = Assets.load_texture_source_first(path)
	elif StaticFacing.handles(str(unit.get("type", ""))):
		texture = board.call("_texture_for_unit", unit)
	return {"mask_texture": texture, "mask_flip": mirrored, "mask_pose": "%s:%s:%s" % [facing, str(mirrored), pose_set]}

static func rest_fallback_path(layout_path: String, facing: String, rest_path: String) -> String:
	if rest_path.is_empty(): return layout_path.get_base_dir().path_join(facing + "/rest.png")
	return rest_path.replace("/front/", "/rear/") if facing == "rear" else rest_path

static func pose_set_signature(board: Control) -> Array:
	var signature: Array = []
	for unit: Dictionary in board.call("_visible_units"):
		var renderer: Node = board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer): signature.append([unit.get("key", ""), renderer.get("facing"), renderer.get("mirrored"), renderer.get("clip")])
	return signature

static func drawing(board: Control, entry: Dictionary) -> Dictionary:
	var data: Dictionary = entry["data"]
	var tile: Vector2i = entry["tile"]
	var texture: Texture2D
	var rect: Rect2
	match str(entry["kind"]):
		"unit":
			texture = board.call("_texture_for_unit", data)
			rect = board.call("_unit_texture_draw_rect", data, board.call("_unit_center", data))
			var shake: float = board.call("_unit_impact_shake_strength", data)
			if shake > 0.0: rect.position.x += sin(preload("res://scripts/presentation_clock.gd").ticks_msec() * 0.09) * 3.0 * shake
		"trap":
			texture = board.call("_trap_idle_texture", data)
			rect = board.call("_trap_visual_draw_rect", data)
		"loot":
			texture = board.call("_loot_texture", data)
			if texture != null:
				rect = board.call("_loot_rect_for_tile", tile, texture, data)
				if board.call("_is_floating_loot", data):
					rect.position += board.call("_equipment_pickup_bob_offset", board.call("_equipment_pickup_pulse", tile, data))
		"terrain":
			var art_kind: String = board.call("_terrain_art_kind", str(data.get("kind", "")))
			texture = (board.get("_terrain_textures") as Dictionary).get(art_kind)
			if texture != null: rect = board.call("_terrain_rect_for_tile", tile, texture, art_kind)
	if texture == null or rect.get_area() <= 0.0: return {}
	return {"texture": texture, "rect": rect}


static func opening_door_mask(board: Control, grid: Array, source: Dictionary) -> Dictionary:
	if source.get("prop_kind") != "door": return {}
	var tile: Vector2i = source["tile"]
	var opening: Texture2D = board._door_opening_texture_for_tile(grid, tile)
	if opening == null: return {}
	return {"mask_texture": opening, "rect": board._door_opening_draw_rect(opening, source["mask_texture"],
		source["rect"], board._door_uses_flipped_orientation(grid, tile))}

static func static_content_geometry(board: Control, source: Dictionary, alpha: RefCounted) -> Dictionary:
	var grid: Array = board.combat_state.get("grid", [])
	var door: Dictionary = opening_door_mask(board, grid, source)
	if not door.is_empty():
		return source.merged({"rect": door["rect"], "mask": alpha.mask_for(door)}, true)
	var terrain: Dictionary = source.get("data", {})
	var kind: String = terrain.get("kind", "")
	if kind not in ["crag_outcrop", "dragon_spire"]: return source
	var tile: Vector2i = source["tile"]
	var width: float = board._tile_width()
	var rise: float = board._procedural_terrain_rise(terrain) if board.has_method("_procedural_terrain_rise") else 1.0
	var shape: Dictionary = procedural_mask(board, {"kind": kind, "tile": tile, "width": width, "rise": rise})
	if shape.is_empty(): return source
	var rect: Rect2 = shape["bounds"]
	rect.position += board._tile_center(tile)
	return source.merged({"rect": rect, "mask": alpha.mask_from_image(shape["image"], str([kind, tile, width, rise]))}, true)

# The live terrain renderer paints these two bodies as opaque stone facets,
# rather than using the placeholder sprite in the resting coverage sources.
static func procedural_mask(board: Control, asset: Dictionary) -> Dictionary:
	var faces: Array[PackedVector2Array]
	var record := func(command: Array) -> void:
		if command[0] == "polygon": faces.append(command[1])
	var tile: Vector2i = asset["tile"]
	var seed: int = tile.x * 101 + tile.y * 307
	if asset["kind"] == "dragon_spire":
		DragonProps.draw_spire(board, Vector2.ZERO, asset["width"], seed, asset["rise"], 1.0, record)
	else:
		SurfacePaint.draw_outcrop(board, Vector2.ZERO, asset["width"], seed, asset["rise"], 1.0, record)
	if faces.is_empty(): return {}
	var bounds := Rect2(faces[0][0], Vector2.ZERO)
	for face: PackedVector2Array in faces:
		for point: Vector2 in face: bounds = bounds.expand(point)
	var origin: Vector2 = bounds.position.floor()
	var size := Vector2i(bounds.end.ceil() - origin)
	if size.x <= 0 or size.y <= 0: return {}
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	# Scan each facet along pixel centers. Paint only its covered spans.
	for face: PackedVector2Array in faces:
		var min_y: int = maxi(0, ceili(minf(face[0].y, minf(face[1].y, face[2].y)) - origin.y - 0.5))
		var max_y: int = mini(size.y, ceili(maxf(face[0].y, maxf(face[1].y, face[2].y)) - origin.y - 0.5))
		for y: int in range(min_y, max_y):
			var scan_y: float = origin.y + float(y) + 0.5
			var left: float = INF
			var right: float = -INF
			for edge: int in range(face.size()):
				var a: Vector2 = face[edge]
				var b: Vector2 = face[(edge + 1) % face.size()]
				if (a.y > scan_y) == (b.y > scan_y): continue
				var x: float = lerpf(a.x, b.x, (scan_y - a.y) / (b.y - a.y))
				left = minf(left, x)
				right = maxf(right, x)
			if left >= right: continue
			var start: int = clampi(ceili(left - origin.x - 0.5), 0, size.x)
			var end: int = clampi(ceili(right - origin.x - 0.5), start, size.x)
			if end > start: image.fill_rect(Rect2i(start, y, end - start, 1), Color.WHITE)
	return {"image": image, "bounds": Rect2(origin, size)}
