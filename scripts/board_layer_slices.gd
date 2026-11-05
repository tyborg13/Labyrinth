extends RefCounted

## Ordered retained slices, split only at original command boundaries. Clock
## invalidations visit animated slices; input invalidations rebuild the plan and
## repaint both kinds. Each child uses the original board methods and material,
## with identity local coordinates, so no texture baking or resampling occurs.
## Ambient and foreground have no independently static visible primitives: their
## buffers/transforms/motes move together. Keep each as one animated slice. HUD
## chip paint below mirrors Badges._draw_chip with only its halo omitted; use
## that renderer's constants and keep both command sequences aligned.
const Badges = preload("res://scripts/intent_badges.gd")
const Threats = preload("res://scripts/threat_tiles.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const STATE_FIELDS: Array = [
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
	"_umbra_return_start_by_tile", "_foreground_obstruction_entries_cache", "_foreground_obstruction_geometry_inputs", "_hud_health_rects_cache",
	"_hud_layout_entries_cache", "_rest_threat_tile_alphas"
]

var canvases: Array[Control]
var _animated: Array[bool]
var _initialized: bool = false

static func supports(kind: String) -> bool:
	return kind in ["ambient", "overlays", "foreground", "hud"]

func invalidate(layer: Control, clock_only: bool) -> void:
	if not clock_only or not _initialized:
		_rebuild(layer)
	for index: int in range(canvases.size()):
		if not clock_only or _animated[index]:
			var canvas: Control = canvases[index]
			canvas.set("_idle_elapsed", layer.get("_idle_elapsed"))
			canvas.queue_redraw()

func _rebuild(layer: Control) -> void:
	# These two plans contain one argument-free animated callback. Input changes
	# reach their existing canvases through retained-state bindings; rebuilding
	# their operation/group arrays cannot change the plan or its paint order.
	var kind: String = str(layer.get("_render_layer_kind"))
	var has_state: bool = not (layer.get("combat_state") as Dictionary).is_empty()
	if _initialized and kind in ["ambient", "foreground"] and has_state == (not canvases.is_empty()):
		for canvas: Control in canvases:
			canvas.size = layer.size
			canvas.material = layer.material
			if not bool(canvas.get("_board_layout_cache_valid")):
				layer.call("_copy_resolved_board_layout_to", canvas)
		layer.queue_redraw()
		return
	var operations: Array = []
	layer.set("_slice_building", true)
	layer.set("_slice_operations", operations)
	if not (layer.get("combat_state") as Dictionary).is_empty():
		match str(layer.get("_render_layer_kind")):
			"ambient": operations.append(["_draw_ambient_render_layer", [], true])
			"foreground": operations.append(["_draw_foreground_render_layer", [], true])
			"overlays": layer.call("_draw_overlay_render_layer")
			"hud": _hud_operations(layer)
	layer.set("_slice_building", false)
	var groups: Array = []
	var animated: Array[bool]
	for operation: Array in operations:
		var on_clock: bool = bool(operation[2])
		if groups.is_empty() or animated.back() != on_clock:
			groups.append([])
			animated.append(on_clock)
		(groups.back() as Array).append(operation.slice(0, 2))
	# The original layer keeps the first static segment. Its public node identity,
	# direct queue_redraw path, draw counters and primary tooltip regions survive.
	var parent_ops: Array = []
	if not groups.is_empty() and not animated[0]:
		parent_ops = groups.pop_front()
		animated.pop_front()
	layer.set("_render_slice_ops", parent_ops)
	# Retain node identities on ordinary changes; discard only unused tail slots.
	if canvases.size() != groups.size():
		var owner: Control = layer.get("_render_instrumentation_owner") as Control
		if is_instance_valid(owner): owner.call("_invalidate_retained_render_layers")
	while canvases.size() > groups.size():
		var stale: Control = canvases.pop_back()
		layer.remove_child(stale)
		stale.queue_free()
	for index: int in range(groups.size()):
		var canvas: Control
		var created: bool = index >= canvases.size()
		if index < canvases.size():
			canvas = canvases[index]
		else:
			canvas = layer.get_script().new() as Control
			canvas.name = "RetainedSlice%d" % index
			canvas.set("_is_dynamic_render_layer", true)
			canvas.set("_is_layer_slice_canvas", true)
			canvas.set("_render_layer_kind", layer.get("_render_layer_kind"))
			canvas.set("_render_instrumentation_owner", layer.get("_render_instrumentation_owner"))
			canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.focus_mode = Control.FOCUS_NONE
			# Set before entering the tree: _ready must never construct a board.
			canvas.set("_render_slice_ops", groups[index])
			# Observers bind to the original HUD node, including first-paint proof.
			canvas.connect("intent_callout_drawn", func(layout: Dictionary) -> void: layer.emit_signal("intent_callout_drawn", layout))
			layer.add_child(canvas)
			canvases.append(canvas)
		canvas.size = layer.size
		canvas.material = layer.material
		canvas.set("_render_slice_ops", groups[index])
		if created:
			# Existing slices already receive changed fields through the owner's
			# normal retained-state/asset binding path. Copy all bindings only once.
			for field: String in STATE_FIELDS:
				canvas.set(field, layer.get(field))
			var owner: Control = layer.get("_render_instrumentation_owner") as Control
			for field: String in owner.get("_retained_asset_bindings"):
				canvas.set(field, layer.get(field))
			for field: String in ["health_ghost_tracker", "status_pop_tracker", "_art_treatment", "_art_treatment_enabled"]:
				canvas.set(field, layer.get(field))
		for field: String in ["_hover_tile", "_controller_focus_tile", "_idle_elapsed", "_hud_health_rects_cache", "_hud_layout_entries_cache"]:
			canvas.set(field, layer.get(field))
		if created or not bool(canvas.get("_board_layout_cache_valid")):
			layer.call("_copy_resolved_board_layout_to", canvas)
	_animated = animated
	_initialized = true
	layer.set("_slice_operations", [])
	# Empty parent canvases need one clearing submission after a previous plan.
	layer.queue_redraw()

static func _hud_operations(board: Control) -> void:
	var units: Array[Dictionary] = board.call("_visible_units")
	board.call("_slice_op", "_draw_slice_hud_base", [units])
	var font: Font = board.get_theme_default_font()
	if font != null:
		for unit: Dictionary in units:
			var preview: Dictionary = board.call("_unit_damage_preview", unit)
			if not board.call("_damage_preview_shows_lost_hp", preview): continue
			var health: Rect2 = board.get("_hud_health_rects_cache").get(str(unit.get("key", "")), Rect2())
			if health.size.x <= 0.0 or health.size.y <= 0.0: continue
			var rect: Rect2 = board.call("_health_bar_content_rect", unit, health)
			board.call("_slice_op", "_draw_health_damage_preview", [unit, rect, preview], not bool(board.presentation.get("reduced_motion", false)))
			board.call("_slice_op", "_draw_health_bar_text", [unit, rect, preview, font])
	board.call("_slice_op", "_draw_slice_hud_chips", [])
	var measured: Array[Dictionary] = Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", []))
	board.call("_slice_op", "_draw_slice_intent_orders", [measured])
	for on_top: bool in [false, true]:
		for badge: Dictionary in measured:
			if bool(badge["above_everything"]) != on_top: continue
			if bool(badge.get("danger", false)):
				board.call("_slice_op", "_draw_slice_intent_halo", [badge], not bool(board.presentation.get("reduced_motion", false)))
			board.call("_slice_op", "_draw_slice_intent_chip", [badge])
	board.call("_slice_op", "_draw_slice_callouts", [])

static func threat_operations(board: Control, tile: Vector2i, polygon: PackedVector2Array, sources: Dictionary) -> void:
	var lob: Dictionary = sources["lob_marks"] if sources.has("lob_marks") else board.LobView.marks(board)
	var threats: Dictionary = board.get("_rest_threat_tile_alphas")
	var hero: Vector2i = board.presentation.get("threats_at_rest", {}).get("hero_tile", Vector2i(-1, -1))
	if lob.has(tile):
		threats = {tile: float(threats.get(tile, 1.0))}
		hero = tile if bool(lob[tile]["center"]) else Vector2i(-1, -1)
	if not threats.has(tile) or not board.call("_board_tile_is_visible_to_player", tile): return
	var alpha: float = float(threats[tile])
	var center: Vector2 = board.call("_tile_center", tile)
	var inset: float = Threats.OUTLINE_WIDTH * 0.5
	var width: float = float(board.call("_tile_width"))
	var height: float = float(board.call("_tile_height"))
	var edge_distance: float = (width * height * 0.5) / sqrt(width * width + height * height)
	var inner := PackedVector2Array()
	for point: Vector2 in polygon:
		inner.append(center + (point - center) * maxf(0.0, 1.0 - inset / edge_distance))
	if tile == hero:
		board.call("_slice_op", "_draw_slice_threat_fill", [inner, alpha], not bool(board.presentation.get("reduced_motion", false)))
	else:
		board.call("_slice_op", "draw_colored_polygon", [inner, Color(Palette.DANGER, Threats.FILL_ALPHA * alpha)])
	inner = inner.duplicate()
	inner.append(inner[0])
	board.call("_slice_op", "draw_polyline", [inner, Color(Palette.DANGER, Threats.OUTLINE_ALPHA * alpha), Threats.OUTLINE_WIDTH, true])
	for tag: Dictionary in sources["zone_tags"] if sources.has("zone_tags") else Threats.zone_tags(board.presentation.get("threats_at_rest", {}).get("threats", [])):
		if tag["tile"] == tile: board.call("_slice_op", "_draw_slice_threat_tag", [tag, center])

static func objective_operations(board: Control, tile: Vector2i, polygon: PackedVector2Array) -> void:
	if not board.call("_snare_sealing_threshold", tile): board.call("_slice_op", "draw_colored_polygon", [polygon, Color(0.15, 0.70, 0.72, 0.30)])
	board.call("_slice_op", "_draw_objective_exit_ring", [tile], true)
	board.call("_slice_op", "_draw_objective_exit_icon", [tile])

static func draw_intent_chip(board: Control, badge: Dictionary, triangle_batch: RefCounted) -> void:
	var font: Font = Typography.ui_font()
	var center: Vector2 = badge["center"]
	var alpha: float = float(badge.get("alpha", 1.0))
	var ring: Color = Badges.ring_color(badge)
	var end: float = Badges.plate_end(badge, font)

	if end > 0.0:
		var plate := Rect2(center + Vector2(Badges.PLATE_START, -Badges.PLATE_HEIGHT * 0.5), Vector2(end - Badges.PLATE_START, Badges.PLATE_HEIGHT))
		board.draw_rect(plate, Color(Badges.PLATE_FILL, 0.92 * alpha))
		board.draw_line(plate.position, Vector2(plate.end.x, plate.position.y), Color(ring, 230.0 / 255.0 * alpha), 1.0, true)
		board.draw_line(Vector2(plate.position.x, plate.end.y), plate.end, Color(ring, 230.0 / 255.0 * alpha), 1.0, true)
		var finial: Vector2 = center + Vector2(end + 1.0, 0.0)
		board.draw_colored_polygon(PackedVector2Array([finial + Vector2(0, -5), finial + Vector2(5, 0), finial + Vector2(0, 5), finial + Vector2(-5, 0)]), Color(ring, alpha))
		var x: float = Badges._draw_number(board, font, str(badge["number"]), center.x + Badges.NUMBER_START, center.y + 1.0, Badges.PRIMARY_FONT_SIZE, alpha)
		if not str(badge.get("secondary_icon", "")).is_empty():
			x += Badges.SECONDARY_GAP
			Badges._draw_icon(board, str(badge["secondary_icon"]), Rect2(Vector2(x, center.y - Badges.SECONDARY_ICON_SIZE * 0.5), Vector2.ONE * Badges.SECONDARY_ICON_SIZE), alpha)
			Badges._draw_number(board, font, str(badge.get("secondary_number", "")), x + Badges.SECONDARY_ICON_SIZE, center.y + 1.0, Badges.SECONDARY_FONT_SIZE, alpha)
	if triangle_batch != null:
		triangle_batch.circle(center, Badges.MEDALLION_DIAMETER * 0.5, Color(Badges.MEDALLION_FILL, alpha), true)
		triangle_batch.flush(board)
	else:
		board.draw_circle(center, Badges.MEDALLION_DIAMETER * 0.5, Color(Badges.MEDALLION_FILL, alpha), true, -1.0, true)
	board.draw_arc(center, Badges.MEDALLION_DIAMETER * 0.5 - 1.0, 0.0, TAU, Badges.CIRCLE_SEGMENTS, Color(ring, alpha), 2.0, true)
	board.draw_arc(center, Badges.MEDALLION_DIAMETER * 0.5 - 4.0, 0.0, TAU, Badges.CIRCLE_SEGMENTS, Color(ring.r * 0.5, ring.g * 0.5, ring.b * 0.5, alpha), 1.0, true)
	var icon_rect := Rect2(center - Vector2.ONE * Badges.PRIMARY_ICON_SIZE * 0.5, Vector2.ONE * Badges.PRIMARY_ICON_SIZE)
	Badges._draw_icon(board, str(badge["icon"]), icon_rect, alpha)
	if bool(badge.get("cancelled", false)):
		board.draw_line(Vector2(icon_rect.position.x, icon_rect.end.y), Vector2(icon_rect.end.x, icon_rect.position.y), Color(Palette.TEXT_2, alpha), 2.0, true)

