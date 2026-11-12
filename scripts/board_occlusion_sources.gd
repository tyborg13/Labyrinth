extends RefCounted

# Production rest-pose alpha sources in the same painter order as the board.
# Live rim drawing remains separate: idle/walk phase never rebuilds rest masks.
const Assets = preload("res://scripts/asset_loader.gd")
const StaticFacing = preload("res://scripts/static_enemy_facing.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")

static func collect(board: Control) -> Array[Dictionary]:
	var entries: Array[Dictionary]
	var units: Array = board.call("_visible_units")
	var state: Dictionary = board.get("combat_state")
	var shown: Dictionary = board.get("presentation")
	var grid: Array = state.get("grid", [])
	for trap: Dictionary in state.get("traps", []):
		_add_object(board, entries, "trap", trap, true)
	for loot: Dictionary in state.get("loot", []):
		if board.call("_loot_renders_below_path", loot): _add_object(board, entries, "loot", loot, true)
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		# Rendered tiles can briefly describe a previous board while a new state lands.
		if tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= (grid[tile.y] as Array).size(): continue
		if board.call("_board_tile_is_visible_to_player", tile):
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
	if kind == "loot" and (str(data.get("kind", "")) not in ["equipment", "item"] or bool(data.get("claimed", false)) or float(board.call("_missed_equipment_disintegration_progress", data)) >= 0.0): return
	if kind == "terrain" and not Surface.terrain_is_live(data): return
	var entry: Dictionary = {"key": "%s:%s:%s" % [kind, str(data.get("id", "")), str(tile)],
		"tile": tile, "kind": kind, "data": data, "ground": ground, "eligible": true}
	var draw: Dictionary = drawing(board, entry)
	if draw.is_empty(): return
	entry["rect"] = draw["rect"]
	entry["mask_texture"] = draw["texture"]
	entry["mask_pose"] = "rest"
	if kind == "trap": entry["mask_texture"] = (board.get("_trap_textures") as Dictionary).get(str(data.get("element", "")), draw["texture"])
	if kind == "loot": entry["rect"] = board.call("_loot_rect_for_tile", tile, draw["texture"], data)
	# Only the tactical terrain in the brief receives rims; other terrain can
	# still occlude units. These are the production crate/box/barrel ids.
	if kind == "terrain": entry["eligible"] = str(data.get("kind", "")) in ["wooden_box", "wooden_crate", "powder_keg", "barrel"]
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
					var path: String = str(constants.get("REST_PATH", ""))
					if path.is_empty(): path = str(rig.call("_layout_path", facing)).get_base_dir().path_join(facing + "/rest.png")
					elif facing == "rear": path = path.replace("/front/", "/rear/")
					if not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
						texture = Assets.load_texture_source_first(path)
	elif StaticFacing.handles(str(unit.get("type", ""))):
		texture = board.call("_texture_for_unit", unit)
	return {"mask_texture": texture, "mask_flip": mirrored, "mask_pose": "%s:%s:%s" % [facing, str(mirrored), pose_set]}

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
