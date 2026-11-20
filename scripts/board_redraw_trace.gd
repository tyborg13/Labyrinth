extends RefCounted

## Probe-only receipts. Fingerprint work runs after the exclusive draw timer.
## Unsupported paints are reported as unknown, never counted as redundant.
const ENVIRONMENT: String = "LABYRINTH_BOARD_REDRAW_TRACE"

var resolve_inputs: bool
var baseline: bool
var confirm_baseline: bool
var targeting_baseline: bool
var active: bool = false
var reasons: Array = []
var _pending: Dictionary = {}
var _rows: Array[Dictionary]
var _previous: Dictionary = {}
var _sites: Dictionary = {}

func _init(mode: String) -> void:
	resolve_inputs = mode == "inputs"
	baseline = OS.get_environment("LABYRINTH_BOARD_REDRAW_BASELINE") == "1"
	confirm_baseline = OS.get_environment("LABYRINTH_PERF148_BASELINE") == "1"
	targeting_baseline = OS.get_environment("LABYRINTH_PERF157_BASELINE") == "1"

func begin() -> void:
	_rows.clear()
	_pending.clear()
	_sites.clear()
	active = true

func finish() -> Array[Dictionary]:
	active = false
	return _rows.duplicate()

func note(layer: Control, extra: String = "", site: String = "") -> void:
	if not active: return
	var pending: Dictionary = _pending.get_or_add(layer.get_instance_id(), {})
	for reason: String in reasons: pending[reason] = true
	if not extra.is_empty(): pending[extra] = true
	if not site.is_empty(): (_sites.get_or_add(layer.get_instance_id(), {}) as Dictionary)[site] = true

func inherit_reason(source: Control, canvas: Control, clock_only: bool, extra: String = "") -> void:
	if not active: return
	note(canvas, "clock" if clock_only else extra)
	var pending: Dictionary = _pending[canvas.get_instance_id()]
	pending.merge(_pending.get(source.get_instance_id(), {}))
	if _sites.has(source.get_instance_id()):
		(_sites.get_or_add(canvas.get_instance_id(), {}) as Dictionary).merge(_sites[source.get_instance_id()])

func draw_finished(layer: Control, usec: int, operations: Dictionary = {}) -> void:
	if not active: return
	var id: int = layer.get_instance_id()
	var fingerprint: Variant = _resolved_inputs(layer) if resolve_inputs else null
	var previous: Variant = _previous.get(id)
	if resolve_inputs: _previous[id] = fingerprint
	var reason: Array = (_pending.get(id, {}) as Dictionary).keys()
	_pending.erase(id)
	var sites: Array = (_sites.get(id, {}) as Dictionary).keys()
	_sites.erase(id)
	var tile: Vector2i = layer._render_layer_tile
	var source: Control = layer.get_parent() as Control
	var kind: String = layer._render_layer_kind
	if kind.is_empty() and layer.has_meta("rd03_canvas") and source != null:
		kind = source._render_layer_kind
		tile = source._render_layer_tile
	_rows.append({
		"frame": Engine.get_process_frames(),
		"kind": kind if not kind.is_empty() else ("static_cache" if layer._is_static_render_cache_layer else "board"),
		"slice": str(layer.name) if layer._is_layer_slice_canvas else "",
		"path": str(layer.get_path()),
		"tile": [tile.x, tile.y],
		"depth_pass": layer._render_layer_scene_effect_pass,
		"reasons": reason if not reason.is_empty() else ["direct queue_redraw or CanvasItem lifecycle"],
		"sites": sites,
		"operations": operations,
		"usec": usec,
		"input_hash": fingerprint,
		"redundant": fingerprint == previous if fingerprint != null and previous != null else null,
	})

func queue_site() -> String:
	if not active or not resolve_inputs: return ""
	for frame: Dictionary in get_stack():
		var method: String = frame["function"]
		if method in ["queue_site", "_request_render_layer_redraw", "_queue_render_layer_redraw", "_queue_scene_render_layer_for_tile", "_queue_scene_effect_render_layers_for_tile", "_queue_scene_paint_redraw"]: continue
		return "%s:%d %s" % [str(frame["source"]).trim_prefix("res://"), frame["line"], method]
	return ""

func _resolved_inputs(layer: Control) -> Variant:
	var ops: Array = layer._render_slice_ops
	var kind: String = layer._render_layer_kind
	if ops.is_empty():
		if layer._is_dynamic_render_layer and (layer.LayerSlices.supports(kind, layer.presentation) or layer.LayerRedraws.is_empty(layer, layer)):
			return hash([])
		if not layer._is_dynamic_render_layer and not layer._is_static_render_cache_layer and layer._static_render_cache_enabled and is_instance_valid(layer._static_render_cache_texture) and layer._static_render_cache_texture.visible:
			return hash([])
		return null
	var inputs: Array = []
	for operation: Array in ops:
		var method: String = operation[0]
		var args: Array = operation[1]
		match method:
			"draw_colored_polygon", "draw_polyline", "draw_polygon", "draw_texture_rect", "draw_texture_rect_region", "draw_line":
				inputs.append(operation)
			"_draw_isolated_props":
				if not _empty_props(layer, args[0]): return null
			"_draw_board_surface":
				if not _empty_surface(layer, args[0]): return null
			"_draw_noctyrax_refuge_tile":
				if not (layer.combat_state.get("guardian_braziers", []) as Array).is_empty(): return null
			"_draw_slice_wind":
				if layer.WindView.has_forecast(layer): return null
			"_draw_slice_intent_orders":
				pass
			"_draw_health_bar_entry":
				var entry: Dictionary = args[0]
				if bool(entry["terrain"]) or layer._plate_opacity(entry["unit"]) > 0.0: return null
			"_draw_slice_hud_chips":
				if not (layer.presentation.get("friendly_damage_chips", []) as Array).is_empty() or not (layer.presentation.get("en05_reflect_preview", {}) as Dictionary).is_empty(): return null
			"_draw_slice_callouts":
				if not (layer.presentation.get("intent_callouts", []) as Array).is_empty(): return null
			"_draw_noctyrax_brazier_markers":
				if not (layer.combat_state.get("guardian_braziers", []) as Array).is_empty(): return null
			"_draw_isolated_path":
				var entry: Array = args[0]
				var path: Array[Vector2i] = entry[0]
				var centers := PackedVector2Array()
				for index: int in range(path.size()):
					if index > 0 and bool(entry[2]) and preload("res://scripts/surface_variety_relic_rules.gd").is_light_link(layer.combat_state, path[index - 1], path[index]): return null
					centers.append(layer._tile_center(path[index]))
				inputs.append([operation, centers, layer._tile_polygon(args[1]), layer._tile_width(), layer._tile_height()])
			"_draw_elemental_scene_depth_pass":
				if not layer.LayerRedraws.is_empty(layer, layer): return null
			_:
				return null
	return hash(inputs)

static func _empty_props(layer: Control, tile: Vector2i) -> bool:
	var grid: Array = layer.combat_state.get("grid", [])
	if not layer._tile_in_grid(grid, tile): return true
	if not layer._submission_cache_valid: return false
	if str(grid[tile.y][tile.x]) in ["wall", "pillar", "door"]: return false
	return (
		not layer._scene_props_by_tile.has(tile) and not layer._terrain_by_tile.has(tile)
		and not layer._loot_by_tile.has(tile)
		and (layer.presentation.get("terrain_destruction_units", []) as Array).is_empty()
	)

static func _empty_surface(layer: Control, tile: Vector2i) -> bool:
	return (
		not (layer.combat_state.get("surfaces", {}) as Dictionary).has(layer._tile_paint_inputs.surface_key(tile))
		and not (layer.presentation.get("throw_surface_frames", layer.presentation.get("combat_feel_surface_frames", {})) as Dictionary).has(tile)
		and (layer.presentation.get("surface_feedback_events", []) as Array).is_empty()
		and (layer.presentation.get("surface_preview_events", []) as Array).is_empty()
		and (layer.presentation.get("surface_preview_arcs", []) as Array).is_empty()
		and layer.presentation.get("effect", {}).get("kind", "") != "chain"
		and layer._surface_rubble_layer == null and layer._surface_rubble_floor_layer == null
		and layer._surface_ice_layer == null and layer._surface_fire_layer == null and layer._surface_electric_layer == null
		and layer._surface_base_drawing == null and layer._surface_feedback_pixel_layer == null
	)
