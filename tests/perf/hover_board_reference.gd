extends "res://tests/perf/profiled_combat_board.gd"

# Frozen cd8cd0e64 optimization algorithms, with the sb-01/sb-02 HUD
# dependency and final-clearance contract applied below. The old oracle omitted
# plates/pills/crests and could accept callouts through the new bounded groups.
# This oracle never calls
# the candidate warmup or submission path; retained layers stay enabled.

func _enemy_intent_contour_layout(unit: Dictionary, center: Vector2, rows: Array, intent_name: String, occupied_rects: Array, font: Font) -> Dictionary:
	if font == null or (rows.is_empty() and intent_name.is_empty()):
		return {"bounds": Rect2(), "line_rects": [], "side": "", "offset": Vector2.ZERO}
	var actor_rect: Rect2 = _enemy_hud_actor_clear_rect(unit, center)
	var external_obstacles: Array[Rect2]
	for obstacle_var: Variant in occupied_rects:
		if typeof(obstacle_var) != TYPE_RECT2:
			continue
		var obstacle: Rect2 = obstacle_var as Rect2
		if obstacle.position.is_equal_approx(actor_rect.position) and obstacle.size.is_equal_approx(actor_rect.size):
			continue
		external_obstacles.append(obstacle)
	var line_rects: Array[Rect2] = _enemy_intent_contour_line_rects(actor_rect, rows, intent_name, font, "right")
	var bounds: Rect2 = _rects_bounds(line_rects)
	var viewport_bounds: Rect2 = _enemy_hud_viewport_bounds()
	var x_offset: float = (
		clampf(bounds.position.x, viewport_bounds.position.x, maxf(viewport_bounds.position.x, viewport_bounds.end.x - bounds.size.x))
		- bounds.position.x
	)
	var min_y_offset: float = viewport_bounds.position.y - bounds.position.y
	var max_y_offset: float = viewport_bounds.end.y - bounds.end.y
	var base_y_offset: float = clampf(0.0, min_y_offset, max_y_offset)
	var y_offsets: Array[float]
	for y_step_var: Variant in ENEMY_HUD_OFFSET_Y_STEPS:
		var y_offset: float = clampf(base_y_offset + float(y_step_var), min_y_offset, max_y_offset)
		if not y_offsets.has(y_offset):
			y_offsets.append(y_offset)
	var contour_step: float = bounds.size.y + 8.0
	for y_offset: float in [
		clampf(base_y_offset - contour_step, min_y_offset, max_y_offset),
		clampf(base_y_offset + contour_step, min_y_offset, max_y_offset)
	]:
		if not y_offsets.has(y_offset):
			y_offsets.append(y_offset)
	# Include exact clear positions around fixed overlays, including the boss bar.
	# Small actors near the top can need more clearance than a regular nudge.
	for obstacle: Rect2 in external_obstacles:
		if obstacle.end.x < bounds.position.x + x_offset or obstacle.position.x > bounds.end.x + x_offset:
			continue
		for offset: float in [obstacle.end.y + 8.0 - bounds.position.y, obstacle.position.y - 8.0 - bounds.end.y]:
			var candidate: float = clampf(offset, min_y_offset, max_y_offset)
			if not y_offsets.has(candidate):
				y_offsets.append(candidate)
	var x_offsets: Array[float]
	x_offsets.assign([x_offset])
	# Boss-room overlays reserve the header and hand. If their remaining vertical
	# band cannot fit all intents, allow a modest sideways shift too.
	if not (presentation.get("hud_obstacle_global_rects", []) as Array).is_empty():
		for shift: float in [-120.0, 120.0, -240.0, 240.0, -360.0, 360.0]:
			var candidate: float = clampf(bounds.position.x + shift, viewport_bounds.position.x, maxf(viewport_bounds.position.x, viewport_bounds.end.x - bounds.size.x)) - bounds.position.x
			if not x_offsets.has(candidate): x_offsets.append(candidate)
	var best: Dictionary = {}
	for candidate_x: float in x_offsets:
		for y_offset: float in y_offsets:
			var offset := Vector2(candidate_x, y_offset)
			var shifted_rects: Array[Rect2] = _offset_rects(line_rects, offset)
			var score: float = _enemy_hud_layout_score(shifted_rects, external_obstacles, viewport_bounds, offset)
			if best.is_empty() or score < float(best.get("score", INF)):
				best = {"score": score, "side": "right", "line_rects": shifted_rects, "bounds": _rects_bounds(shifted_rects), "offset": offset}
	if best.is_empty():
		return {"bounds": Rect2(), "line_rects": [], "side": "", "offset": Vector2.ZERO}
	return preload("res://scripts/board_intent_clearance.gd").finish(self, unit, line_rects, external_obstacles, viewport_bounds, best)


func _sync_dynamic_render_state(layout_changed: bool = false, visual_framing_changed: bool = false, changed_fields: Array = [], geometry_changed: bool = true) -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		_sync_strike_trail(presentation.get("effect", {}), float(presentation.get("effect_progress", 1.0)))
		return
	# Resolve the fixed room envelope once on the parent before invalidating
	# retained layers so every layer uses the same origin and scale.
	if (layout_changed or visual_framing_changed) and not combat_state.is_empty():
		_ensure_board_layout_cache()
	_refresh_snare_chips()
	var fields: Array = changed_fields
	if fields.is_empty():
		fields = [
			"combat_state", "move_tiles", "attack_tiles", "selected_tile", "status_label",
			"status_detail", "exit_tiles", "exit_icon_ids", "presentation", "_hover_tile", "_controller_focus_tile",
			"_navigation_zoom", "_navigation_pan", "_navigation_uses_default_zoom", "_navigation_content_signature",
			"_floor_variant_by_tile", "_moss_tiles_by_surface", "_board_layout_signature", "_board_visual_framing_signature",
			"_board_layout_cache_visual_top_offset",
			"_floor_variant_signature", "_moss_signature", "_damage_preview_cache",
			"_visible_units_cache", "_units_by_draw_tile_cache", "_scene_props_by_tile", "_terrain_by_tile", "_loot_by_tile",
			"_traps_by_tile", "_campfire_scene_props_cache", "_grid_tile_ids_cache",
			"_ability_tiles_cache", "_move_tiles_lookup_cache", "_attack_tiles_lookup_cache",
			"_focus_tiles_lookup_cache", "_objective_exit_tiles_lookup_cache",
			"_projected_attack_tiles_lookup_cache", "_summon_tiles_lookup_cache", "_projected_destination_tiles_lookup_cache",
			"_ability_tiles_lookup_cache",
			"_ambient_element_id_cache", "_equipment_pickup_beacon_cache",
			"_preview_unit_pulse_cache", "_submission_cache_valid", "_idle_elapsed",
			"_umbra_return_start_by_tile", "_foreground_obstruction_entries_cache", "_hud_health_rects_cache",
			"_hud_layout_entries_cache", "_rest_threat_tile_alphas"
		]
	for layer: Control in _retained_render_layers():
		if layout_changed and geometry_changed:
			layer.call("_invalidate_board_layout_cache")
		elif layout_changed:
			# Geometry remains valid; room-dependent particle/obstruction data does not.
			layer.call("_invalidate_layout_render_semantics")
		elif visual_framing_changed:
			layer.call("_invalidate_board_layout_cache", false, true)
		for field_var: Variant in fields:
			var field: String = str(field_var)
			layer.set(field, get(field))

	_effects_render_layer.call("_sync_strike_trail", presentation.get("effect", {}), float(presentation.get("effect_progress", 1.0)))


func _queue_hover_redraws() -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		queue_redraw()
		return
	# Hover only changes tile overlays and enemy intent/HUD layout. Ambient,
	# occupied-tile art, foreground atmosphere, and effects retain their draw
	# commands while pointer motion remains fully event-driven.
	_rebuild_hud_health_rects_cache()
	if _hud_render_layer != null and is_instance_valid(_hud_render_layer):
		_hud_render_layer.set("_hud_layout_entries_cache", _hud_layout_entries_cache)
		_hud_render_layer.set("_hud_health_rects_cache", _hud_health_rects_cache)
	if _effects_render_layer != null and is_instance_valid(_effects_render_layer):
		_effects_render_layer.set("_hud_health_rects_cache", _hud_health_rects_cache)
	_queue_render_layer_redraw(_overlay_render_layer)
	_queue_render_layer_redraw(_hud_render_layer)


func _draw_overlay_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var section_started_usec: int = Time.get_ticks_usec()
	for tile: Vector2i in tiles:
		_draw_tile_overlays(tile)
	# Wind is drawn once over the floor, not per tile (director, warband-markers).
	WindView.draw_field(self)
	_draw_action_ground_markings()
	_draw_large_enemy_attack_highlight_extensions(_visible_units())
	_record_render_section_time("tile_overlays", section_started_usec)
	_record_dynamic_draw_time(started_usec)


func _draw_tile_overlays(tile: Vector2i) -> void:
	var detailed: bool = is_instance_valid(_render_instrumentation_owner) and bool(_render_instrumentation_owner.get("_submission_performance_instrumentation_enabled"))
	var started: int = Time.get_ticks_usec() if detailed else 0
	var polygon: PackedVector2Array = _tile_polygon(tile)
	WarbandView.draw_banner_tile(self, tile, polygon, LEADER_MARKER_GOLD)
	if detailed: _record_render_section_time("overlay_banner", started); started = Time.get_ticks_usec()
	var rest: Dictionary = presentation.get("threats_at_rest", {}) as Dictionary
	ThreatTiles.draw_tile(self, tile, polygon, _rest_threat_tile_alphas, rest.get("hero_tile", Vector2i(-1, -1)), bool(presentation.get("reduced_motion", false)))
	if detailed: _record_render_section_time("overlay_rest", started); started = Time.get_ticks_usec()
	var draw_aoe_footprint: bool = _focus_tiles_lookup_cache.has(tile) and _player_aoe_preview_active()
	if _snare_sealing_threshold(tile): draw_colored_polygon(polygon, Color(UiPaletteTokens.UMBRA, 0.30))
	# A Warband's Command glow centres on its captain and the crest names it.
	if tile == presentation.get("objective_leader_tile", Vector2i(-1, -1)) and not WarbandRules.active(combat_state):
		_draw_objective_leader_beacon(tile)
	if _objective_exit_tiles_lookup_cache.has(tile):
		_draw_objective_exit_target(tile)
	if exit_tiles.has(tile):
		draw_colored_polygon(polygon, EXIT_HIGHLIGHT)
		if bool(presentation.get("pulse_exit_tiles", false)):
			_draw_exit_tile_pulse(tile)
	if _confirmation_target_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, EXIT_HIGHLIGHT)
		_draw_exit_tile_pulse(tile)
	if _focus_tiles_lookup_cache.has(tile) and not draw_aoe_footprint:
		draw_colored_polygon(polygon, presentation.get("focus_color", FOCUS_HIGHLIGHT))
	if _move_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, MOVE_HIGHLIGHT)
		_draw_tile_ring(tile, Color(0.60, 0.91, 0.94, 0.58), 2.0, 0.86)
	if _ability_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, ABILITY_HIGHLIGHT)
		_draw_tile_ring(tile, Color(0.55, 0.92, 0.48, 0.62), 2.0, 0.86)
	if _attack_tiles_lookup_cache.has(tile) and not _projected_attack_tiles_lookup_cache.has(tile):
		_draw_attack_tile_highlight(tile)
	if _projected_attack_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, Color(0.98, 0.30, 0.20, 0.18))
		_draw_tile_ring(tile, Color(1.0, 0.42, 0.25, 0.94), 3.6, 0.78)
	if _summon_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, Color(0.24, 0.80, 0.30, 0.23))
		_draw_tile_ring(tile, Color(0.52, 0.96, 0.48, 0.95), 3.6, 0.78)
		var summon_icon: Texture2D = ActionIcons.icon_texture("summon_minions")
		if summon_icon != null:
			var icon_side: float = _tile_width() * 0.23
			draw_texture_rect(summon_icon, Rect2(_tile_center(tile)-Vector2.ONE*icon_side*0.5, Vector2.ONE*icon_side), false, Color(0.76, 1.0, 0.72))
	if _projected_destination_tiles_lookup_cache.has(tile):
		_draw_tile_ring(tile, Color(0.95, 0.78, 0.43, 0.98), 4.0, 0.92)
	if detailed: _record_render_section_time("overlay_targets", started); started = Time.get_ticks_usec()
	_draw_meteor_mark(tile)
	if detailed: _record_render_section_time("overlay_meteor", started); started = Time.get_ticks_usec()
	IcefallView.draw_tile(self, tile)
	if detailed: _record_render_section_time("overlay_icefall", started); started = Time.get_ticks_usec()
	LobView.draw_tile(self, tile)
	if detailed: _record_render_section_time("overlay_lob", started); started = Time.get_ticks_usec()
	if detailed: _record_render_section_time("overlay_wind", started)
	if draw_aoe_footprint:
		# Keep every legal center visible, then layer the concrete consequence on
		# top so it remains the unmistakable primary targeting signal.
		_draw_aoe_footprint_highlight(tile)
	if tile == selected_tile:
		draw_colored_polygon(polygon, SELECT_HIGHLIGHT)
	if tile == _hover_tile and _controller_focus_tile.x < 0:
		draw_colored_polygon(polygon, HOVER_HIGHLIGHT)
	if tile == _controller_focus_tile:
		if exit_tiles.has(tile):
			_draw_controller_door_focus(tile)
		else:
			draw_colored_polygon(polygon, Color(0.98, 0.79, 0.37, 0.16))
			_draw_tile_ring(tile, Color(1.0, 0.80, 0.36, 0.98), 3.2, 0.90)

# Player Meteorfall marks persist through enemy turns and land at the start of
# the player's next turn. They reuse the Meteorfall (cinder_marks) identity on
# an ember-ringed tile, with the incoming damage in the tooltip.

func _draw_meteor_mark(tile: Vector2i) -> void:
	BurrowView.draw_mark(self, tile)
	DeathBurstView.draw_preview(self, tile)
	# Floor wash and ring only; the icon and damage are drawn above units by
	# `_draw_meteor_mark_badges`.
	var marked: bool = false
	for mark_var: Variant in combat_state.get("meteor_marks", []):
		if typeof(mark_var) == TYPE_DICTIONARY and ((mark_var as Dictionary).get("tiles", []) as Array).has(tile):
			marked = true
			break
	if not marked:
		return
	draw_colored_polygon(_tile_polygon(tile), Color(0.95, 0.38, 0.16, 0.20))
	_draw_tile_ring(tile, Color(1.0, 0.55, 0.22, 0.95), 3.2, 0.80)


func _visible_units() -> Array[Dictionary]:
	if _submission_cache_valid:
		return _visible_units_cache
	return _build_visible_units()


func _rebuild_submission_caches(presentation_changes: Dictionary = {}, combat_changed_hint: bool = true, moving_actor_keys: Dictionary = {}) -> bool:
	# set_combat_state already computes the exact top-level presentation diff.
	# Use that routing information directly instead of rebuilding and recursively
	# comparing five overlapping source dictionaries on every animation sample.
	# Interpolated world positions do not change the visible-unit list: draw and
	# HUD helpers read those positions from presentation at use time.
	var first_submission: bool = not _submission_cache_initialized
	var combat_changed: bool = first_submission or combat_changed_hint
	var scene_changed: bool = first_submission or presentation_changes.has("scene_props")
	var units_changed: bool = combat_changed or first_submission
	# Wind landing ghosts also depend on the visible tiles and, while wind blows,
	# on previewed paths.
	for unit_key: String in ["preview_units", "death_animation_units", "visible_enemy_ids", "umbra_visible_tiles"]:
		if presentation_changes.has(unit_key):
			units_changed = true
			break
	if _wind_ghost_inputs_changed(presentation_changes): units_changed = true
	var unit_geometry_changed: bool = units_changed
	for geometry_key: String in ["unit_world_positions", "unit_footprint_world_positions", "unit_draw_tiles"]:
		if presentation_changes.has(geometry_key):
			unit_geometry_changed = true
			break
	var visibility_changed: bool = (
		presentation_changes.has("umbra_visible_tiles")
		or presentation_changes.has("umbra_stage")
	)
	var damage_changed: bool = (
		first_submission
		or presentation_changes.has("damage_preview")
		or presentation_changes.has("effect")
	)
	var ability_changed: bool = first_submission or presentation_changes.has("ability_tiles")
	_submission_cache_combat_changed = combat_changed
	if not combat_changed and not scene_changed and not unit_geometry_changed and not visibility_changed and not damage_changed and not ability_changed:
		_submission_cache_valid = true
		_submission_cache_combat_changed = false
		return false
	# Keep the one authoritative combat snapshot used to detect non-conforming
	# in-place state mutation. Presentation is owned as immutable copy-on-write
	# data by RunScene, so the already-computed change set is its source of truth.
	if combat_changed:
		_submission_cache_source_snapshot["combat"] = _combat_submission_cache_source(combat_state).duplicate(true)
	_submission_cache_initialized = true
	if damage_changed:
		_damage_preview_cache = _build_damage_preview_map(presentation)
	if scene_changed:
		_scene_props_by_tile = _index_dictionary_entries_by_tile(presentation.get("scene_props", []), "tile")
		_campfire_scene_props_cache = []
		for prop_var: Variant in presentation.get("scene_props", []):
			if typeof(prop_var) != TYPE_DICTIONARY:
				continue
			var prop: Dictionary = prop_var
			if str(prop.get("kind", "")) == "campfire_bonfire":
				_campfire_scene_props_cache.append(prop)
	if combat_changed:
		_terrain_by_tile = _index_dictionary_entries_by_tile(combat_state.get("terrain", []), "pos")
		_loot_by_tile = _index_dictionary_entries_by_tile(combat_state.get("loot", []), "pos")
		_traps_by_tile = _index_dictionary_entries_by_tile(combat_state.get("traps", []), "pos")
		_grid_tile_ids_cache = {}
		for row_var: Variant in combat_state.get("grid", []):
			if typeof(row_var) != TYPE_ARRAY:
				continue
			for cell_var: Variant in row_var as Array:
				_grid_tile_ids_cache[str(cell_var)] = true
		_ambient_element_id_cache = str(combat_state.get("room_element", ElementData.NONE))
		_equipment_pickup_beacon_cache = false
		for loot_var: Variant in combat_state.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var
			if not bool(loot.get("claimed", false)) and _is_floating_loot(loot):
				_equipment_pickup_beacon_cache = true
				break
	if ability_changed:
		_ability_tiles_cache = _vector2i_array(presentation.get("ability_tiles", []))
		_ability_tiles_lookup_cache = _vector2i_lookup(_ability_tiles_cache)
	if combat_changed or units_changed:
		_visible_units_cache = _build_visible_units()
		_preview_unit_pulse_cache = false
		for unit: Dictionary in _visible_units_cache:
			if _unit_is_preview_echo(unit):
				_preview_unit_pulse_cache = true
				break
	if units_changed or presentation_changes.has("unit_draw_tiles"):
		# Keep the already-authored unit order inside each tile. Animated draw-tile
		# overrides change depth ownership without rebuilding the visible list.
		_units_by_draw_tile_cache = {}
		for unit: Dictionary in _visible_units_cache:
			var draw_tile: Vector2i = _effective_unit_tile(unit)
			var tile_units: Array = _units_by_draw_tile_cache.get(draw_tile, []) as Array
			tile_units.append(unit)
			_units_by_draw_tile_cache[draw_tile] = tile_units
	# Scene props participate in foreground obstruction even though they do not
	# affect the visible-unit list. Keep that derived cache aligned when a room
	# prop changes without paying to rebuild it for damage-only hovers.
	if combat_changed or units_changed or scene_changed or visibility_changed:
		if is_inside_tree():
			_foreground_obstruction_entries_cache = _foreground_obstruction_entries(_visible_units_cache)
		else:
			_foreground_obstruction_entries_cache.clear()
	elif unit_geometry_changed and not _refresh_moving_foreground_obstruction_entries(moving_actor_keys):
		_foreground_obstruction_entries_cache = _foreground_obstruction_entries(_visible_units_cache)
	if combat_changed or scene_changed or visibility_changed:
		_foreground_obstruction_candidates_cache_valid = false
	_submission_cache_valid = true
	return true


func _hud_layout_source(hud_units: Array[Dictionary]) -> Dictionary:
	# Framing and safe-rect changes can move the board without changing its
	# Control size. Resolve first: layout can also update the default zoom/pan.
	_ensure_board_layout_cache()
	_status_plate_layout.fixed_order_rects = IntentBadges.fixed_order_rects(self, hud_units)
	return {
		"visible_units": hud_units,
		"cutout_registrations": _cutout_floor_registrations(),
		# HUD geometry changes only when pointer hover expands a different enemy's
		# intent. Every empty tile is layout-equivalent, and every tile in a large
		# enemy footprint is equivalent too. Keying by the raw tile forced the dense
		# collision solver to build a distinct layout for every Blink destination.
		"hover_actor_key": _hud_hover_actor_key(hud_units),
		"size": size,
		"board_origin": _board_layout_cache_origin,
		"tile_width": _board_layout_cache_tile_width,
		"navigation_zoom": _navigation_zoom,
		"navigation_pan": _navigation_pan,
		"expanded_enemy_actor_keys": presentation.get("expanded_enemy_actor_keys", []),
		"expand_enemy_intents": presentation.get("expand_enemy_intents", false),
		"show_all_enemy_intents": presentation.get("show_all_enemy_intents", false),
		"hud_obstacle_global_rects": presentation.get("hud_obstacle_global_rects", []),
		"unit_draw_tiles": presentation.get("unit_draw_tiles", {}),
		"unit_world_positions": presentation.get("unit_world_positions", {}),
		"group_reserved_ui": _status_plate_layout.Groups.screen_reservations(self),
		"status_preview": presentation.get("surface_status_preview", {}),
		"defense_preview": _damage_preview_map(),
		"truesight_activations": presentation.get("umbra_truesight_activations", 0),
		"truesight_conditional": presentation.get("umbra_truesight_conditional", false),
		"order_badges": (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []),
		"boss_health_frame": presentation.get("boss_health_frame_global_rect", Rect2())
	}


func _pillar_torch_ember_mote_point(source_point: Vector2, seed: int, cycle: float, time_seconds: float, side_sign: float, _hashes: PackedFloat64Array = PackedFloat64Array()) -> Vector2:
	var tile_width: float = _tile_width()
	var base_lateral: float = lerpf(-0.18, 0.18, _ambient_hash01(seed + 23)) * tile_width * lerpf(1.0, 0.64, cycle)
	var sway: float = sin(time_seconds * lerpf(1.2, 2.6, _ambient_hash01(seed + 29)) + _ambient_hash01(seed + 31) * TAU) * tile_width * lerpf(0.006, 0.038, cycle)
	var side_drift: float = side_sign * tile_width * lerpf(0.006, 0.030, _ambient_hash01(seed + 33)) * pow(cycle, 1.10)
	var rise: float = pow(cycle, 0.76) * tile_width * COLUMN_TORCH_EMBER_PLUME_HEIGHT_SCALE * lerpf(0.82, 1.18, _ambient_hash01(seed + 35))
	return source_point + Vector2(base_lateral + sway + side_drift, _tile_height() * 0.018 - rise)


func _draw_pillar_torch_ember_motes_for_side(tile: Vector2i, pillar_rect: Rect2, side_key: String, side_sign: float, tint_alpha: float, time_seconds: float) -> void:
	if tint_alpha <= 0.0:
		return
	var torch_texture: Texture2D = _pillar_torch_texture(side_key)
	if torch_texture == null:
		return
	var torch_rect: Rect2 = _pillar_torch_rect(pillar_rect, torch_texture, side_sign)
	var source_point: Vector2 = _pillar_torch_flame_point(torch_rect, side_sign)
	for index: int in range(COLUMN_TORCH_EMBER_MOTE_COUNT):
		var seed: int = _pillar_torch_ember_seed(tile, side_key, index)
		var speed: float = lerpf(0.34, 0.56, _ambient_hash01(seed + 13))
		var cycle: float = wrapf(_ambient_hash01(seed + 17) + time_seconds * speed, 0.0, 1.0)
		var alpha: float = pow(clampf(sin(cycle * PI), 0.0, 1.0), 0.86) * COLUMN_TORCH_EMBER_MOTE_ALPHA * tint_alpha
		alpha *= lerpf(0.56, 1.0, _ambient_hash01(seed + 19))
		if alpha <= 0.045:
			continue
		var point: Vector2 = _pillar_torch_ember_mote_point(source_point, seed, cycle, time_seconds, side_sign)
		var previous_cycle: float = maxf(0.0, cycle - _ambient_motion_blur_cycle_delta("fire") * 0.62)
		var previous_point: Vector2 = _pillar_torch_ember_mote_point(source_point, seed, previous_cycle, time_seconds - 0.09, side_sign)
		var velocity: Vector2 = point - previous_point
		var draw_width: float = _tile_width() * lerpf(COLUMN_TORCH_EMBER_MIN_WIDTH_SCALE, COLUMN_TORCH_EMBER_MAX_WIDTH_SCALE, _ambient_hash01(seed + 37))
		var variant_index: int = posmod(index + int(_ambient_hash01(seed + 39) * float(AMBIENT_PARTICLE_ATLAS_COLUMNS)), AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = _ambient_particle_texture("fire", variant_index)
		var soft_texture: Texture2D = _ambient_fire_soft_texture(variant_index)
		var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", variant_index)
		if texture == null and soft_texture == null:
			draw_circle(point, maxf(0.7, draw_width * 0.28), Color(1.0, 0.70, 0.30, minf(alpha * 0.62, 0.48)))
			continue
		if texture == null:
			texture = soft_texture
		var texture_size: Vector2 = texture.get_size()
		var draw_size := Vector2(draw_width, draw_width)
		if texture_size.x > 0.0:
			draw_size.y = draw_width * texture_size.y / texture_size.x
		var rotation: float = lerpf(-0.22, 0.22, _ambient_hash01(seed + 43)) + sin(time_seconds * 0.86 + _ambient_hash01(seed + 47) * TAU) * 0.07
		var mote_alpha: float = alpha * lerpf(0.48, 0.74, _ambient_hash01(seed + 41))
		_draw_ambient_fire_particle(texture, soft_texture, glow_texture, point, velocity, draw_size, rotation, mote_alpha, seed, time_seconds)
		draw_circle(point, maxf(0.65, draw_width * 0.16), Color(1.0, 0.86, 0.42, minf(mote_alpha * 0.52, 0.46)))


func set_combat_state(next_state: Dictionary, next_move_tiles: Array = [], next_attack_tiles: Array = [], next_selected_tile: Vector2i = Vector2i(-1, -1), next_status_label: String = "", next_status_detail: String = "", next_exit_tiles: Dictionary = {}, next_exit_icon_ids: Dictionary = {}, next_presentation: Dictionary = {}, trust_same_reference_state: bool = false) -> void:
	# Keep current mechanic adapters while preserving the frozen submission algorithm.
	var submitted_paths: Dictionary = next_presentation.duplicate(false)
	next_presentation = CapacitorView.presentation_for(next_state, next_presentation)
	next_presentation = BrambleView.presentation_for(next_state, next_presentation)
	next_presentation = SnarePressureView.presentation_for(next_state, next_presentation)
	next_presentation = BattlefieldRuleView.presentation_for(next_state, next_presentation)
	next_presentation = preload("res://scripts/enemy_path_presentation.gd").without_enemy_paths(next_presentation, submitted_paths)
	next_presentation = StaticEnemyFacing.presentation_for(self, next_state, next_presentation, presentation)
	_rest_threat_tile_alphas = ThreatTiles.tile_alphas((next_presentation.get("threats_at_rest", {}) as Dictionary).get("threats", []))
	var submission_phase_started: int = Time.get_ticks_usec() if _submission_performance_instrumentation_enabled else 0
	# The owning RunScene submits immutable copy-on-write snapshots. Pointer-only
	# presentation changes therefore retain the exact combat dictionary reference;
	# compare only the board-consumed snapshot when a non-conforming caller mutates
	# that dictionary in place. This keeps the safety net exact without walking
	# unrelated late-run state on the normal immutable-snapshot path.
	var state_reference_changed: bool = not is_same(next_state, combat_state)
	var state_changed: bool = state_reference_changed and next_state != combat_state
	var same_reference_state_mutation: bool = false
	# The live combat dictionary may already contain an in-place mutation by the
	# time it is resubmitted. Use the last deep cache snapshot as the authoritative
	# previous render source so selective invalidation still sees that mutation.
	var previous_combat_render_source: Dictionary = {}
	var next_combat_render_source: Dictionary = {}
	var combat_render_changes: Dictionary = {}
	# Generic callers keep conservative in-place mutation detection. RunScene opts
	# out only for a stable sequence of animation samples after the state boundary
	# has been validated, avoiding recursive combat-state comparisons on each
	# subsequent rendered frame without hiding in-place enemy-step commits.
	if state_reference_changed or (_submission_cache_initialized and not trust_same_reference_state):
		previous_combat_render_source = (
			_submission_cache_source_snapshot.get("combat", {}) as Dictionary
			if _submission_cache_initialized
			else _combat_submission_cache_source(combat_state)
		)
		next_combat_render_source = _combat_submission_cache_source(next_state)
		combat_render_changes = _changed_presentation_keys(previous_combat_render_source, next_combat_render_source)
		if not state_reference_changed and _submission_cache_initialized:
			state_changed = not combat_render_changes.is_empty()
			same_reference_state_mutation = state_changed
	var move_tiles_changed: bool = next_move_tiles != move_tiles
	var attack_tiles_changed: bool = next_attack_tiles != attack_tiles
	var selected_tile_changed: bool = next_selected_tile != selected_tile
	var status_changed: bool = next_status_label != status_label or next_status_detail != status_detail
	var exit_tiles_changed: bool = next_exit_tiles != exit_tiles
	var exit_icon_ids_changed: bool = next_exit_icon_ids != exit_icon_ids
	var previous_exit_tiles: Dictionary = exit_tiles
	var interaction_changed: bool = (
		move_tiles_changed
		or attack_tiles_changed
		or selected_tile_changed
		or status_changed
		or exit_tiles_changed
		or exit_icon_ids_changed
	)
	# Layout/framing semantics must remain valid before _ready() creates retained
	# layers (unit tests and callers can submit state while the view is detached).
	# Live views already pay this exact diff cost for selective redraw routing.
	var presentation_changes: Dictionary = _changed_presentation_keys(presentation, next_presentation)
	var biome_changed: bool = _biome_id != str(next_presentation.get("biome_id", Biomes.default_biome()))
	var surface_redraw_tiles: Array[Vector2i] = BoardSurfaceRenderDependencies.changed_tiles(presentation, next_presentation, presentation_changes)
	var previous_damage_preview: Dictionary = {}
	var moving_actor_keys: Dictionary = {}
	var previous_unit_render_tiles: Dictionary = {}
	var previous_unit_obstruction_entries: Dictionary = {}
	var previous_elemental_scene_tiles: Array[Vector2i] = _elemental_scene_depth_tiles_for_presentation(presentation)
	var previous_focus_actor_keys: Array = presentation.get("focus_actor_keys", []) as Array
	var previous_terrain_destruction_units: Array = presentation.get("terrain_destruction_units", []) as Array
	var previous_scene_props: Array = presentation.get("scene_props", []) as Array
	var previous_units_by_key: Dictionary = {}
	var track_visible_unit_changes: bool = false
	if _dynamic_render_layer != null and is_instance_valid(_dynamic_render_layer):
		previous_damage_preview = _damage_preview_map().duplicate(true)
		moving_actor_keys = _changed_unit_presentation_actor_keys(presentation, next_presentation)
		# The retained visible-unit cache still represents the last submitted
		# frame even when a non-conforming caller mutated the combat dictionary in
		# place. Capture it before rebuilding the cache so the exact old/new actor
		# tiles can use the same selective invalidation route as copy-on-write state.
		track_visible_unit_changes = (
			combat_render_changes.has("player")
			or combat_render_changes.has("illusions")
			or combat_render_changes.has("enemies")
			or combat_render_changes.has("npcs")
			or presentation_changes.has("preview_units")
			or presentation_changes.has("death_animation_units")
			or presentation_changes.has("visible_enemy_ids")
			or presentation_changes.has("surface_status_preview")
		)
		if track_visible_unit_changes:
			previous_units_by_key = _units_by_key(_visible_units())
			previous_unit_render_tiles = _unit_render_tiles_by_key(_visible_units())
			previous_unit_obstruction_entries = _unit_obstruction_entries_by_key(_visible_units())
		elif not moving_actor_keys.is_empty():
			previous_unit_render_tiles = _unit_render_tiles_for_actor_keys(_visible_units(), moving_actor_keys)
			previous_unit_obstruction_entries = _unit_obstruction_entries_for_actor_keys(_visible_units(), moving_actor_keys)
	submission_phase_started = _record_submission_performance_phase("diff", submission_phase_started)
	var layout_inputs_changed: bool = state_changed or exit_tiles_changed or _board_layout_signature.is_empty()
	for layout_key: String in [
		"active_door_tiles",
		"locked_door_tiles",
		"board_backdrop_visible",
		"board_framing_mode",
		"board_safe_global_rect",
		"board_fit_rect", "board_encounter_types",
		"controller_combat_navigation",
	]:
		if presentation_changes.has(layout_key):
			layout_inputs_changed = true
			break
	var framing_inputs_changed: bool = state_changed or _board_visual_framing_signature.is_empty()
	for framing_key: String in ["death_animation_units", "visible_enemy_ids", "scene_props"]:
		if presentation_changes.has(framing_key):
			framing_inputs_changed = true
			break
	var next_room_grid_signature: String = _room_grid_signature(next_state) if state_changed or layout_inputs_changed or _navigation_content_signature.is_empty() else _floor_variant_signature
	var next_navigation_content_signature: String = _navigation_content_signature
	if state_changed or layout_inputs_changed or _navigation_content_signature.is_empty():
		next_navigation_content_signature = "%s|%s|%s" % [
			next_room_grid_signature,
			str(next_state.get("room_coord", Vector2i(-1, -1))),
			str(next_presentation.get("board_encounter_types", []))
		]
	var next_layout_signature: String = (
		_layout_signature_for_state(next_state, next_exit_tiles, next_presentation, next_room_grid_signature)
		if layout_inputs_changed
		else _board_layout_signature
	)
	var next_visual_framing_signature: String = (
		_visual_framing_signature_for_state(next_state, next_presentation)
		if framing_inputs_changed
		else _board_visual_framing_signature
	)
	var next_floor_signature: String = next_room_grid_signature if state_changed or _floor_variant_signature.is_empty() else _floor_variant_signature
	var next_moss_signature: String = _moss_signature_for_state(next_state) if state_changed or _moss_signature.is_empty() else _moss_signature
	var layout_changed: bool = next_layout_signature != _board_layout_signature
	var previous_geometry: Dictionary = _resolved_board_geometry_inputs() if layout_changed else {}
	var geometry_changed: bool = layout_changed
	var visual_framing_changed: bool = false
	var floor_changed: bool = next_floor_signature != _floor_variant_signature
	var moss_changed: bool = next_moss_signature != _moss_signature
	var static_presentation_changed: bool = biome_changed or presentation_changes.has("board_backdrop_visible") or presentation_changes.has("scene_props") or combat_render_changes.has("room_element")
	submission_phase_started = _record_submission_performance_phase("signatures", submission_phase_started)
	var previous_path_presentation: Dictionary = presentation
	var previous_transition_state: Dictionary = previous_combat_render_source if same_reference_state_mutation else combat_state
	_update_umbra_return_transition(previous_transition_state, presentation, next_state, next_presentation, layout_changed)
	_submission_cache_valid = false
	# Combat and presentation dictionaries are copy-on-write snapshots owned by
	# the caller. CombatBoardView only reads them and stores derived render data,
	# avoiding a full recursive clone on every animation/hover submission.
	combat_state = next_state
	if not _submission_cache_initialized or combat_render_changes.has("surfaces"):
		_animated_surface_tiles.clear()
		for surface_tile: Vector2i in BoardSurfaceRules.tiles(next_state):
			# Rubble's authored material is static. Elemental layers keep the
			# exact existing continuous cadence, including Fire's conduction.
			if not BoardSurfaceRules.element_at(next_state, surface_tile).is_empty():
				_animated_surface_tiles.append(surface_tile)
	move_tiles = _vector2i_array(next_move_tiles)
	attack_tiles = _vector2i_array(next_attack_tiles)
	selected_tile = next_selected_tile
	status_label = next_status_label
	status_detail = next_status_detail
	exit_tiles = next_exit_tiles
	exit_icon_ids = next_exit_icon_ids
	presentation = next_presentation
	if biome_changed:
		_biome_id = str(presentation.get("biome_id", Biomes.default_biome()))
		_biome_light_color = Biomes.light_color(_biome_id)
		if not _tile_textures.is_empty(): _load_base_floor_assets()
		if not _prop_textures.is_empty(): _load_biome_prop_assets()
		if not _pillar_torch_idle_frames.is_empty(): _load_pillar_idle_assets()
	health_ghost_tracker.observe_state(combat_state if _next_health_ghost_state.is_empty() else _next_health_ghost_state, presentation)
	_next_health_ghost_state = {}
	_update_impact_camera_shake()
	var previous_registrations: Dictionary = _cutout_floor_registrations()
	# A pose-only submission affects its addressed family. Other persistent
	# canvases continue their own idle processing; walking the complete roster
	# for every family needlessly resubmitted unrelated actors each frame.
	# Snapshot caches can be populated before _ready(), while actor pools cannot
	# create their child canvases until this board enters the scene tree.
	var refresh_cutout_roster: bool = not _cutout_roster_initialized or not _submission_cache_initialized
	for key: String in ["player", "enemies", "illusions", "npcs"]:
		refresh_cutout_roster = refresh_cutout_roster or combat_render_changes.has(key)
	for key: String in ["preview_units", "death_animation_units", "visible_enemy_ids", "reduced_motion"]:
		refresh_cutout_roster = refresh_cutout_roster or presentation_changes.has(key)
	var roster_phase_started: int = Time.get_ticks_usec() if _submission_performance_instrumentation_enabled else 0
	if refresh_cutout_roster or presentation_changes.has("equipped_equipment"):
		ProtagonistGearBoard.sync(self)
	if refresh_cutout_roster or presentation_changes.has("illusion_motion") or presentation_changes.has("equipped_equipment"):
		_sync_illusion_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_illusion", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("warden_motion"):
		_sync_warden_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_warden", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("crawler_motion"):
		_sync_crawler_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_crawler", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("acolyte_motion"):
		_sync_acolyte_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_acolyte", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("guardian_motion"):
		_sync_guardian_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_guardian", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("bile_bloomer_motion"):
		_sync_bile_bloomer_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_bile_bloomer", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("gust_shrike_motion"):
		GustShrikePresentation.sync(self)
	roster_phase_started = _record_submission_performance_phase("roster_gaoler", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("cinder_droplet_motion"):
		_sync_cinder_droplet_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_cinder_droplet", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("cinder_ooze_motion"):
		CinderOozePresentation.sync(self)
	if refresh_cutout_roster or presentation_changes.has("grave_surgeon_motion"):
		_sync_grave_surgeon_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_grave_surgeon", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("harrier_motion"):
		_sync_harrier_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_harrier", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("iskaldra_motion"):
		_sync_iskaldra_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_iskaldra", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("lightning_wisp_motion"):
		_sync_lightning_wisp_renderers()
	for rr07_type: String in _rr07_renderers:
		if refresh_cutout_roster or presentation_changes.has(rr07_type + "_motion"):
			MaquettePresentation.sync(self, rr07_type, _rr07_renderers[rr07_type])
	roster_phase_started = _record_submission_performance_phase("roster_lightning_wisp", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("noctyrax_motion"):
		_sync_noctyrax_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_noctyrax", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("tharokh_motion"):
		_sync_tharokh_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_tharokh", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("vaeloryx_motion"):
		_sync_vaeloryx_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_vaeloryx", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("veilbound_acolyte_motion"):
		_sync_veilbound_acolyte_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_veilbound_acolyte", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("vyraketh_motion"):
		_sync_vyraketh_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_vyraketh", roster_phase_started)
	if refresh_cutout_roster or presentation_changes.has("zekarion_motion"):
		_sync_zekarion_renderers()
	roster_phase_started = _record_submission_performance_phase("roster_zekarion", roster_phase_started)
	if is_instance_valid(_protagonist_renderer) and (refresh_cutout_roster or presentation_changes.has("protagonist_motion")):
		_protagonist_renderer.call("present", presentation.get("protagonist_motion", {}),
			bool(presentation.get("reduced_motion", false)), not (combat_state.get("player", {}) as Dictionary).is_empty())
	# A detached update leaves existing pools stale too; resubmit them after
	# reattachment even if the next presentation/state is identical.
	_cutout_roster_initialized = is_inside_tree() and not _is_dynamic_render_layer and not _is_static_render_cache_layer
	var registration_changes: Dictionary = {}
	var current_registrations: Dictionary = _cutout_floor_registrations()
	for actor_key: String in current_registrations:
		if previous_registrations.get(actor_key) != current_registrations[actor_key]:
			registration_changes[actor_key] = true
			moving_actor_keys[actor_key] = true
	var next_elemental_scene_tiles: Array[Vector2i] = _elemental_scene_depth_tiles_for_presentation(presentation)
	if move_tiles_changed:
		_move_tiles_lookup_cache = _vector2i_lookup(move_tiles)
	if attack_tiles_changed:
		_attack_tiles_lookup_cache = _vector2i_lookup(attack_tiles)
	var overlay_presentation_cache_changed: bool = not _submission_cache_initialized
	for overlay_key: String in ["focus_tiles", "confirmation_target_tiles", "objective_exit_target_tiles", "projected_attack_tiles", "projected_destination", "enemy_threat_previews"]:
		if presentation_changes.has(overlay_key):
			overlay_presentation_cache_changed = true
			break
	if overlay_presentation_cache_changed:
		_focus_tiles_lookup_cache = _vector2i_lookup(presentation.get("focus_tiles", []))
		_confirmation_target_tiles_lookup_cache = _vector2i_lookup(presentation.get("confirmation_target_tiles", []))
		_objective_exit_tiles_lookup_cache = _vector2i_lookup(presentation.get("objective_exit_target_tiles", []))
		_projected_attack_tiles_lookup_cache = _vector2i_lookup(presentation.get("projected_attack_tiles", []))
		_summon_tiles_lookup_cache.clear()
		_projected_destination_tiles_lookup_cache.clear()
		var projected_destination: Vector2i = presentation.get("projected_destination", Vector2i(-999, -999))
		if projected_destination.x > -999:
			_projected_destination_tiles_lookup_cache[projected_destination] = true
		for threat_var: Variant in presentation.get("enemy_threat_previews", []):
			if typeof(threat_var) != TYPE_DICTIONARY:
				continue
			var threat: Dictionary = threat_var
			for summon_tile: Vector2i in _vector2i_array(threat.get("summon", [])):
				_summon_tiles_lookup_cache[summon_tile] = true
			for attack_tile: Vector2i in _vector2i_array(threat.get("projected_attack", [])):
				_projected_attack_tiles_lookup_cache[attack_tile] = true
			var destination: Vector2i = threat.get("projected_destination", Vector2i(-999, -999))
			if destination.x > -999 and _threat_has_projected_movement(threat):
				_projected_destination_tiles_lookup_cache[destination] = true
			# Where the intent's Push or Pull would land the hero.
			var player_force: Dictionary = threat.get("projected_player_force", {}) as Dictionary
			if (player_force.get("path", []) as Array).size() >= 2:
				_projected_destination_tiles_lookup_cache[player_force.get("destination", Vector2i(-999, -999))] = true
	if not _navigation_content_signature.is_empty() and next_navigation_content_signature != _navigation_content_signature:
		_navigation_pan = Vector2.ZERO
		_enemy_hud_side_by_actor.clear()
		_clear_hud_layout_signature_cache()
	_navigation_content_signature = next_navigation_content_signature
	if state_changed or presentation_changes.has("death_animation_units") or not _submission_cache_initialized:
		_ensure_unit_assets_for_submission(combat_state, presentation)
	submission_phase_started = _record_submission_performance_phase("assign_and_assets", submission_phase_started)
	if layout_changed:
		_board_layout_signature = next_layout_signature
		# Recompute through the original framing path before deciding whether
		# the existing foot-relative shadow geometry can remain prepared.
		_invalidate_board_layout_cache(true, false, not previous_geometry.is_empty())

	_board_visual_framing_signature = next_visual_framing_signature
	if floor_changed:
		_floor_variant_signature = next_floor_signature
		_floor_variant_by_tile = _build_floor_variant_lookup(combat_state.get("grid", []))
	if moss_changed:
		_moss_signature = next_moss_signature
		_moss_tiles_by_surface = _build_moss_tile_lookup(combat_state.get("moss", {}))
	var submission_sources_changed: bool = state_changed or not _submission_cache_initialized
	for cache_key: String in [
		"scene_props", "preview_units", "death_animation_units", "unit_draw_tiles",
		"unit_world_positions", "unit_footprint_world_positions", "visible_enemy_ids", "umbra_visible_tiles",
		"umbra_light_sources", "umbra_stage", "damage_preview", "effect", "ability_tiles",
		"enemy_intent_compasses", "en01_erupt", "en01_erupt_dust", "en01_burst", "en01_burst_progress"
	]:
		if presentation_changes.has(cache_key):
			submission_sources_changed = true
			break
	# Wind landing ghosts skip paths the presentation already previews; without
	# wind there are no ghosts, so card previews keep their cached unit list.
	if _wind_ghost_inputs_changed(presentation_changes):
		submission_sources_changed = true
	if submission_sources_changed:
		_rebuild_submission_caches(presentation_changes, state_changed, moving_actor_keys)
	else:
		_submission_cache_valid = true
		_submission_cache_combat_changed = false
	submission_phase_started = _record_submission_performance_phase("derived_caches", submission_phase_started)
	if track_visible_unit_changes:
		var current_units_by_key: Dictionary = _units_by_key(_visible_units())
		for actor_key_var: Variant in previous_units_by_key:
			if not current_units_by_key.has(actor_key_var) or previous_units_by_key.get(actor_key_var) != current_units_by_key.get(actor_key_var):
				moving_actor_keys[str(actor_key_var)] = true
		for actor_key_var: Variant in current_units_by_key:
			if not previous_units_by_key.has(actor_key_var) or current_units_by_key.get(actor_key_var) != previous_units_by_key.get(actor_key_var):
				moving_actor_keys[str(actor_key_var)] = true
	var hud_layout_inputs_changed: bool = state_changed or layout_changed or visual_framing_changed or _hud_layout_entries_cache.is_empty()
	for hud_key: String in [
		"expanded_enemy_actor_keys", "expand_enemy_intents", "show_all_enemy_intents",
		"unit_draw_tiles", "unit_world_positions", "preview_units", "death_animation_units",
		"visible_enemy_ids", "surface_status_preview", "hud_obstacle_global_rects",
		"damage_preview", "effect", "umbra_truesight_activations", "umbra_truesight_conditional", "threats_at_rest", "boss_health_frame_global_rect"
	]:
		if presentation_changes.has(hud_key):
			hud_layout_inputs_changed = true
			break
	if hud_layout_inputs_changed:
		var structural_hud_change: bool = (
			state_changed
			or layout_changed
			or visual_framing_changed
			or presentation_changes.has("expanded_enemy_actor_keys")
			or presentation_changes.has("expand_enemy_intents")
			or presentation_changes.has("show_all_enemy_intents")
			or presentation_changes.has("preview_units")
			or presentation_changes.has("death_animation_units")
			or presentation_changes.has("visible_enemy_ids")
		)
		if structural_hud_change or not _refresh_moving_hud_geometry(moving_actor_keys):
			_rebuild_hud_health_rects_cache()
	submission_phase_started = _record_submission_performance_phase("hud_layout", submission_phase_started)
	if layout_changed:
		_ensure_board_layout_cache()
		geometry_changed = previous_geometry.is_empty() or previous_geometry != _resolved_board_geometry_inputs()
		if geometry_changed:
			_unit_shadow_draw_geometry_cache.clear()
			_unit_shadow_draw_mesh_cache.clear()
	if _dynamic_render_layer != null and is_instance_valid(_dynamic_render_layer) and (layout_changed or _scene_render_layers.is_empty()):
		_sync_scene_render_layers()
		_sync_dynamic_render_assets()
	var retained_sync_fields: Array = []
	if biome_changed:
		_sync_dynamic_render_assets()
		# New/reframed tile layers need the full state. A biome-only list would
		# override that full sync and leave their combat_state empty indefinitely.
		if not layout_changed and not visual_framing_changed:
			retained_sync_fields.append_array(["_biome_id", "_biome_light_color"])
	if not layout_changed and not visual_framing_changed:
		if state_changed:
			retained_sync_fields.append_array([
				"combat_state", "_terrain_by_tile", "_loot_by_tile", "_traps_by_tile",
				"_grid_tile_ids_cache", "_ambient_element_id_cache", "_equipment_pickup_beacon_cache",
				"_visible_units_cache", "_units_by_draw_tile_cache", "_preview_unit_pulse_cache", "_foreground_obstruction_entries_cache",
				"_hud_health_rects_cache", "_hud_layout_entries_cache", "_submission_cache_valid",
				"_umbra_return_start_by_tile"
			])
		if move_tiles_changed:
			retained_sync_fields.append_array(["move_tiles", "_move_tiles_lookup_cache"])
		if attack_tiles_changed:
			retained_sync_fields.append_array(["attack_tiles", "_attack_tiles_lookup_cache"])
		if selected_tile_changed:
			retained_sync_fields.append("selected_tile")
		if status_changed:
			retained_sync_fields.append_array(["status_label", "status_detail"])
		if exit_tiles_changed:
			retained_sync_fields.append("exit_tiles")
		if exit_icon_ids_changed:
			retained_sync_fields.append("exit_icon_ids")
		if not presentation_changes.is_empty():
			retained_sync_fields.append_array(["presentation", "_rest_threat_tile_alphas"])
			retained_sync_fields.append_array(["_hud_health_rects_cache", "_hud_layout_entries_cache"])
		if presentation_changes.has("damage_preview") or presentation_changes.has("effect"):
			retained_sync_fields.append("_damage_preview_cache")
		if presentation_changes.has("ability_tiles"):
			retained_sync_fields.append_array(["_ability_tiles_cache", "_ability_tiles_lookup_cache"])
		if overlay_presentation_cache_changed:
			retained_sync_fields.append_array([
				"_focus_tiles_lookup_cache", "_confirmation_target_tiles_lookup_cache", "_objective_exit_tiles_lookup_cache",
				"_projected_attack_tiles_lookup_cache", "_summon_tiles_lookup_cache", "_projected_destination_tiles_lookup_cache"
			])
		for unit_key: String in ["preview_units", "death_animation_units", "unit_draw_tiles", "unit_world_positions", "unit_footprint_world_positions", "visible_enemy_ids", "umbra_visible_tiles", "umbra_light_sources", "umbra_stage"]:
			if not presentation_changes.has(unit_key):
				continue
			retained_sync_fields.append_array([
				"_visible_units_cache", "_units_by_draw_tile_cache", "_preview_unit_pulse_cache", "_foreground_obstruction_entries_cache",
				"_submission_cache_valid"
			])
			break
		# Wind landing ghosts follow previewed paths into the retained layers too.
		if _wind_ghost_inputs_changed(presentation_changes):
			retained_sync_fields.append_array(["_visible_units_cache", "_units_by_draw_tile_cache", "_preview_unit_pulse_cache", "_foreground_obstruction_entries_cache", "_submission_cache_valid"])
		if presentation_changes.has("scene_props"):
			retained_sync_fields.append_array([
				"_scene_props_by_tile", "_campfire_scene_props_cache", "_foreground_obstruction_entries_cache",
				"_submission_cache_valid"
			])
		if floor_changed:
			retained_sync_fields.append_array(["_floor_variant_by_tile", "_floor_variant_signature"])
		if moss_changed:
			retained_sync_fields.append_array(["_moss_tiles_by_surface", "_moss_signature"])
		var unique_sync_fields: Array = []
		for field_var: Variant in retained_sync_fields:
			if not unique_sync_fields.has(field_var):
				unique_sync_fields.append(field_var)
		retained_sync_fields = unique_sync_fields
	if layout_changed or visual_framing_changed or not retained_sync_fields.is_empty():
		_sync_dynamic_render_state(layout_changed, visual_framing_changed, retained_sync_fields, geometry_changed)
	submission_phase_started = _record_submission_performance_phase("retained_sync", submission_phase_started)
	_update_cursor_shape()
	if layout_changed or visual_framing_changed or floor_changed or moss_changed or static_presentation_changed or _dynamic_render_layer == null:
		_sync_static_render_cache()
		queue_redraw()
	if biome_changed or layout_changed or visual_framing_changed or floor_changed or moss_changed:
		_explicit_effects_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_explicit_impact_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_queue_dynamic_redraw()
	else:
		if _submission_cache_combat_changed:
			_queue_combat_state_change_redraws(
				combat_render_changes,
				previous_combat_render_source,
				next_combat_render_source,
				moving_actor_keys,
				previous_unit_render_tiles,
				previous_unit_obstruction_entries
			)
		if interaction_changed:
			_queue_interaction_change_redraws(
				move_tiles_changed,
				attack_tiles_changed,
				selected_tile_changed,
				status_changed,
				exit_tiles_changed,
				exit_icon_ids_changed,
				previous_exit_tiles
			)
		_queue_presentation_change_redraws(
			presentation_changes,
			previous_damage_preview != _damage_preview_cache,
			moving_actor_keys,
			previous_unit_render_tiles,
			previous_unit_obstruction_entries,
			previous_elemental_scene_tiles,
			next_elemental_scene_tiles,
			previous_focus_actor_keys,
			next_presentation.get("focus_actor_keys", []) as Array,
			previous_terrain_destruction_units,
			next_presentation.get("terrain_destruction_units", []) as Array,
			previous_scene_props,
			next_presentation.get("scene_props", []) as Array,
			previous_path_presentation
		)
		for surface_tile: Vector2i in surface_redraw_tiles:
			_queue_scene_render_layer_for_tile(surface_tile)
	if not registration_changes.is_empty():
		# A persistent viewport can turn without changing its actor dictionary.
		# The retained draw command must select that view's floor registration too.
		_refresh_moving_foreground_obstruction_entries(registration_changes)
		_rebuild_hud_health_rects_cache()
		_sync_dynamic_render_state(false, false, ["_foreground_obstruction_entries_cache", "_hud_health_rects_cache", "_hud_layout_entries_cache"])
		_queue_render_layer_redraw(_hud_render_layer)
		_queue_moving_actor_redraws(registration_changes, previous_unit_render_tiles, previous_unit_obstruction_entries)
	_sync_enemy_shadow_dissolve_effects()
	_record_submission_performance_phase("redraw_routing", submission_phase_started)

	# An untimed oracle always resolves the current source and publishes all HUD
	# bindings, independent of candidate warmup and selective submission routing.
	_hud_health_rects_source_snapshot = {}
	_hud_layout_cache_by_signature.clear()
	_hud_layout_cache_order.clear()
	_rebuild_hud_health_rects_cache()
	if is_instance_valid(_hud_render_layer):
		_hud_render_layer.set("_hud_layout_entries_cache", _hud_layout_entries_cache)
		_hud_render_layer.set("_hud_health_rects_cache", _hud_health_rects_cache)
	if is_instance_valid(_effects_render_layer):
		_effects_render_layer.set("_hud_health_rects_cache", _hud_health_rects_cache)
	_queue_render_layer_redraw(_hud_render_layer)
