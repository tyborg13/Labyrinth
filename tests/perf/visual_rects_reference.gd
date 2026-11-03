extends "res://tests/perf/profiled_combat_board.gd"

# Pre-perf03 oracle; retain the complete original ordered rectangles.
func _queue_presentation_change_redraws(changed_keys: Dictionary, damage_preview_changed: bool = false,
	moving_actor_keys: Dictionary = {}, previous_unit_render_tiles: Dictionary = {}, previous_unit_obstruction_entries: Dictionary = {},
	previous_elemental_scene_tiles: Array = [], next_elemental_scene_tiles: Array = [], previous_focus_actor_keys: Array = [], next_focus_actor_keys: Array = [],
	previous_terrain_destruction_units: Array = [], next_terrain_destruction_units: Array = [], previous_scene_props: Array = [], next_scene_props: Array = [], previous_path_presentation: Dictionary = {}, previous_damage_preview: Dictionary = {}) -> void:
	super._queue_presentation_change_redraws(changed_keys, damage_preview_changed, moving_actor_keys, previous_unit_render_tiles, previous_unit_obstruction_entries,
		previous_elemental_scene_tiles, next_elemental_scene_tiles, previous_focus_actor_keys, next_focus_actor_keys,
		previous_terrain_destruction_units, next_terrain_destruction_units, previous_scene_props, next_scene_props, previous_path_presentation, previous_damage_preview)
	if changed_keys.has("en05_dive_telegraphs"): _queue_dynamic_redraw()
	for key: String in ["path_color", "path_tiles", "displacement_paths", "enemy_threat_previews", "illusion_echo_previews"]:
		if changed_keys.has(key):
			for tile: Vector2i in _scene_render_layers_by_tile: _queue_scene_render_layer_for_tile(tile)
			break

func rendered_visual_rects(include_unit_hud: bool = true, include_units: bool = true) -> Array[Rect2]:
	# This is deliberately based on the exact draw rectangles used by the static
	# board and DynamicRenderLayer, rather than only tile diamonds. Keeping the
	# rectangles separate lets HUD collision checks distinguish a genuinely
	# occupied corner from the empty corner of their combined bounding box.
	_ensure_board_layout_cache()
	var rects: Array[Rect2]
	var grid: Array = combat_state.get("grid", [])
	for tile: Vector2i in _board_layout_cache_tiles:
		var polygon: PackedVector2Array = _tile_polygon(tile)
		if not polygon.is_empty():
			var tile_bounds := Rect2(polygon[0], Vector2.ZERO)
			for point: Vector2 in polygon:
				tile_bounds = tile_bounds.expand(point)
			rects.append(tile_bounds)
		if tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= (grid[tile.y] as Array).size():
			continue
		var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
		if tile_id == "wall" and not _is_outer_boundary_tile(grid, tile):
			tile_id = "pillar"
		if tile_id == "pillar":
			var pillar: Texture2D = _prop_textures.get("pillar", null)
			if pillar != null:
				var pillar_rect: Rect2 = _prop_draw_rect(pillar, _prop_rect_for_tile(tile))
				rects.append(pillar_rect)
				var left_torch: Texture2D = _pillar_torch_texture("left")
				var right_torch: Texture2D = _pillar_torch_texture("right")
				if left_torch != null:
					rects.append(_pillar_torch_rect(pillar_rect, left_torch, -1.0))
				if right_torch != null:
					rects.append(_pillar_torch_rect(pillar_rect, right_torch, 1.0))
		elif tile_id == "wall":
			for segment: Dictionary in _boundary_prop_segments(tile_id, grid, tile):
				rects.append(segment.get("draw_rect", Rect2()) as Rect2)
		elif tile_id == "door":
			var door: Texture2D = _door_texture_for_tile(grid, tile)
			if door != null:
				var door_rect: Rect2 = _prop_draw_rect(door, _door_rect_for_tile(tile, grid))
				var opening: Texture2D = _door_opening_texture_for_tile(grid, tile)
				rects.append(_door_opening_draw_rect(opening, door, door_rect, _door_uses_flipped_orientation(grid, tile)) if opening != null else door_rect)
				if opening == null and not str(exit_icon_ids.get(tile, "")).is_empty():
					rects.append(_door_icon_visual_rect(door, door_rect))
	for unit: Dictionary in _visible_units():
		if not include_units and str(unit.get("role", "")) != "npc":
			continue
		rects.append(_unit_draw_rect(unit))
		if include_unit_hud:
			rects.append(_unit_health_bar_rect(unit, _unit_center(unit)))
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		var prop_texture: Texture2D = _texture_for_scene_prop(prop)
		if prop_texture != null:
			rects.append(_scene_prop_rect(prop_texture, prop))
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if not _board_tile_is_visible_to_player(terrain.get("pos", Vector2i(-1, -1))):
			continue
		if not BoardSurfaceRules.terrain_is_live(terrain):
			continue
		var terrain_texture: Texture2D = _terrain_textures.get(str(terrain.get("kind", "")), null)
		if terrain_texture != null:
			rects.append(_terrain_rect_for_tile(terrain.get("pos", Vector2i(-1, -1)), terrain_texture, str(terrain.get("kind", ""))))
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if not _board_tile_is_visible_to_player(loot.get("pos", Vector2i(-1, -1))):
			continue
		if bool(loot.get("claimed", false)):
			continue
		var loot_texture: Texture2D = _loot_texture(loot)
		if loot_texture != null:
			rects.append(_loot_rect_for_tile(loot.get("pos", Vector2i(-1, -1)), loot_texture, loot))
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if _board_tile_is_visible_to_player(trap.get("pos", Vector2i(-1, -1))):
			rects.append(_trap_visual_draw_rect(trap))
	return rects

