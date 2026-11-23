extends RefCounted

## Retain the existing painters on per-actor canvases. Canvas modulation tweens
## change renderer state only: no board paint invalidation on animation frames.
const Layers = preload("res://scripts/board_layer_slices.gd")
const Context = preload("res://scripts/targeted_tile_context.gd")
const HudRetention = preload("res://scripts/board_hud_retention.gd")
const SPRITE_RGB: float = 0.62
const HUD_ALPHA: float = 0.5
const TRANSITION_SECONDS: float = 0.12
# Director feedback 1: quadratic ease-out accepted.
const EASE_OUT_CURVE: int = Tween.TRANS_QUAD
const LATE_HUD_BINDINGS: Array = [
	"_hover_tile", "_controller_focus_tile", "_idle_elapsed", "_hud_health_rects_cache", "_hud_layout_entries_cache",
]
var active: bool = false
var affected_tiles: Dictionary = {}
var choosing: bool = false
var focus_tile := Vector2i(-1, -1)
var canvases: Dictionary = {}
var changes: int = 0
var _signature: Array = []
var _outline_targets: Dictionary = {}
var _outline_tweens: Dictionary = {}
var _hud_sources_to_reorder: Dictionary = {}
var _hud_route_order: Array[Control]
var _record_hud_route_order: bool = false
# occ-02 focus reveal: body opacity per actor, on each body canvas's modulate
# (self_modulate keeps the aim dim; HUD canvases never take it).
var body_alphas: Dictionary = {}

static func for_board(board: Control) -> RefCounted:
	var owner: Control = board.get("_render_instrumentation_owner") as Control
	return (owner if is_instance_valid(owner) else board).get("_aim_focus")

func submit(scene: Node, preview: Dictionary) -> void:
	var next_choosing: bool = Context.choosing(scene)
	if next_choosing and not choosing: _close_terrain_popup(scene.board_view)
	choosing = next_choosing
	var next_active: bool = choosing and not scene._player_movement_selected and not scene._surface_aim.active() and (scene._selected_card_index >= 0 or scene._drag_targeting_active) and not bool(preview.get("complete", true))
	var signature: Array = [next_active, scene._combat_preview_revision, scene._selected_card_index, scene._drag_card_index, scene._pending_action_index, scene._aoe_aim_orientation, scene._pending_orientation_target_tile, preview.get("target_tiles", [])]
	if signature == _signature: return
	_signature = signature.duplicate(true)
	var tiles: Dictionary = {}
	if next_active:
		var action: Dictionary = preview.get("action", {})
		_add_action_tiles(scene, preview.get("state", {}), action, preview.get("target_tiles", []), tiles)
		if str(action.get("type", "")) == "confirm":
			# Automatic/self-centred actions have already entered the staged preview,
			# but remain uncommitted until confirmation. Query their original reach.
			for staged: Dictionary in preview.get("actions", []):
				var targets: Array = scene._combat_engine.valid_targets_for_player_action(scene._combat_state, staged)
				_add_action_tiles(scene, scene._combat_state, staged, targets, tiles)
		if str(action.get("type", "")) in ["move", "blink"]:
			scene._prepare_preview_shortcuts_for_current_action(preview)
			for tile: Vector2i in scene._preview_shortcuts_cache.get("tiles", []): tiles[tile] = true
	active = next_active
	affected_tiles = tiles
	changes += 1
	_update_canvases()

func _add_action_tiles(scene: Node, state: Dictionary, action: Dictionary, targets: Array, tiles: Dictionary) -> void:
	for target: Vector2i in targets:
		if str(action.get("type", "")) in ["aoe", "meteor_marks"]:
			for tile: Vector2i in scene._aoe_tiles_for_action(state, action, target): tiles[tile] = true
		else: tiles[target] = true

func finish() -> void:
	if not active and not choosing: return
	active = false
	choosing = false
	affected_tiles = {}
	_signature = []
	changes += 1
	_update_canvases()

func full_strength(board: Control, unit: Dictionary) -> bool:
	if not active or str(unit.get("role", "")) == "player" or bool(unit.get("death_animation", false)) or board.call("_unit_is_preview_echo", unit): return true
	for tile: Vector2i in board.call("_unit_footprint_tiles", unit):
		if affected_tiles.has(tile): return true
	return false

func set_body_alpha(key: String, alpha: float) -> void:
	if alpha >= 1.0: body_alphas.erase(key)
	else: body_alphas[key] = alpha
	for record: Dictionary in canvases.values():
		if bool(record.hud) or str(record.unit.get("key", "")) != key or not is_instance_valid(record.canvas): continue
		(record.canvas as Control).modulate.a = alpha

func set_focus(tile: Vector2i) -> void:
	if focus_tile == tile: return
	focus_tile = tile
	_update_canvases()

func _update_canvases() -> void:
	for id: String in canvases.keys():
		var record: Dictionary = canvases[id]
		if not is_instance_valid(record.canvas):
			canvases.erase(id)
			continue
		_present(record)

func begin_draw(source: Control) -> void:
	if source.has_meta("rd03_canvas") or not source._board_redraw_baseline(): return
	for child: Node in source.get_children():
		if child.has_meta("rd03_canvas"): (child as Control).hide()

func finish_draw(source: Control) -> void:
	if source.has_meta("rd03_canvas") or source._board_redraw_baseline(): return
	if not source._confirm_draw_baseline() and not source.has_meta("rd03_has_children"): return
	# A draw that still routes this child can retain its visibility and cached
	# commands. Retire children whose actor disappeared from this source's paint.
	for child: Node in source.get_children():
		if child.has_meta("rd03_canvas"):
			if child.has_meta("rd03_routed"): child.remove_meta("rd03_routed")
			else: (child as Control).hide()

func release_room_canvases(keep_unit_sprites: bool = false, keep_hud: bool = false) -> void:
	# The source layers may be reused in the next room, but their child
	# canvases contain this room's actor snapshots and paint commands.
	_hud_sources_to_reorder.clear()
	for id: String in canvases.keys():
		var record: Dictionary = canvases[id]
		if not is_instance_valid(record.canvas):
			canvases.erase(id)
			continue
		var canvas: Control = record.canvas
		var source: Control = canvas.get_parent() as Control
		var layer: String = source.get("_render_layer_kind") if source != null else ""
		var retain_hud: bool = keep_hud and bool(record.hud) and layer == "hud" and HudRetention.enabled(source)
		if retain_hud or (
			keep_unit_sprites and not bool(record.hud) and canvas.is_visible_in_tree() and layer == "unit_body_outline"
		):
			# Returning from a coordinate-less forecast keeps the same painter
			# sources. Start bright, as a fresh canvas would. The submission
			# rebinds each routed HUD piece and retires any piece it no longer uses.
			var tween: Tween = canvas.get_meta("rd03_tween") if canvas.has_meta("rd03_tween") else null
			if tween != null and tween.is_valid(): tween.kill()
			canvas.set_meta("rd03_target", Color.WHITE)
			canvas.self_modulate = Color.WHITE
			if retain_hud:
				_hud_sources_to_reorder[source.get_instance_id()] = true
				# Fresh HUD canvases have no tooltip hits before their first draw.
				# Discard the aim registrations and repaint to publish the new ones.
				if not canvas._tooltip_regions.is_empty() or not canvas._tile_tooltip_regions.is_empty():
					canvas._tooltip_regions.clear()
					canvas._tile_tooltip_regions.clear()
					record.erase("paint_inputs")
				for child: Node in canvas.get_children():
					if child is Control and str(child.name).begins_with("IntentTab_"):
						# A fresh aim-exit painter recreates its tab on the next
						# draw. Keep the painter and retire only that animated child.
						canvas.remove_child(child)
						child.queue_free()
						record.erase("paint_inputs")
			continue
		canvas.hide()
		canvas.queue_free()
		canvases.erase(id)

func sync_hud_source(source: Control) -> void:
	# The original slices still own the same ordered operations. Bind their
	# routed children before requesting draw so an unchanged parent has no
	# CanvasItem work. A lifecycle draw only submits its own direct paint.
	var direct: Array = []
	_record_hud_route_order = _hud_sources_to_reorder.erase(source.get_instance_id())
	source._hud_paint_environment = HudRetention.environment(source)
	for operation: Array in source._render_slice_ops:
		if not route_operation(source, operation[0], operation[1], direct):
			direct.append(operation)
	if _record_hud_route_order:
		_record_hud_route_order = false
		# Fresh canvases would append in this operation order. Restore the same
		# sibling order when projected health, badges or focus changed the plan.
		var start: int = source.get_child_count() - _hud_route_order.size()
		for index: int in range(_hud_route_order.size() - 1, -1, -1):
			var canvas: Control = _hud_route_order[index]
			if canvas.get_index() != start + index:
				source.move_child(canvas, start + index)
		_hud_route_order.clear()
	finish_draw(source)
	source._hud_direct_ops = direct
	_sync_direct_hud(source)

func _sync_direct_hud(source: Control) -> void:
	var inputs: Variant = HudRetention.direct_inputs(source, source._hud_direct_ops)
	if source._hud_direct_inputs != null and inputs == source._hud_direct_inputs: return
	source._hud_direct_inputs = inputs.duplicate(true) if inputs != null else null
	source.queue_redraw()

func update_plate_opacity(hud: Control) -> void:
	# Keep fade alpha in the original primitives. Canvas modulation would
	# cull very faint paint and also dim the separately tinted connector.
	var trace: RefCounted = hud.get("_board_redraw_trace")
	var live_forecast: bool = HudRetention.has_live_preview_clock(hud)
	for record: Dictionary in canvases.values():
		if not bool(record.hud) or not is_instance_valid(record.canvas): continue
		var canvas: Control = record.canvas
		if not canvas.visible: continue # Retired, as opposed to a hidden ancestor.
		var ops: Array = canvas._render_slice_ops
		if ops.is_empty(): continue
		var method: String = ops[0][0]
		if HudRetention.health_method(method):
			var alpha: float = hud._plate_opacity(record.unit)
			if not live_forecast and alpha == record.get("plate_opacity"): continue
			record["plate_opacity"] = alpha
		if HudRetention.health_method(method) or (live_forecast and method == "_draw_unit_hud_details"):
			var source: Control = canvas.get_parent() as Control
			var inputs: Variant = _paint_inputs(source, method, ops[0][1], record.unit)
			if inputs != null and inputs == record.get("paint_inputs"): continue
			record["paint_inputs"] = inputs.duplicate(true) if inputs != null else null
		elif method != "_draw_slice_intent_halo" or bool(canvas.presentation.get("reduced_motion", false)):
			continue
		if trace != null and trace.active: trace.note(canvas, "plate clock", trace.queue_site())
		canvas.queue_redraw()
	_sync_direct_hud(hud)
	for source: Control in hud.get("_layer_slices").canvases:
		if not source._hud_direct_ops.is_empty(): _sync_direct_hud(source)

func _paint_inputs(source: Control, method: String, args: Array, unit: Dictionary) -> Variant:
	var paint: Variant = HudRetention.piece_inputs(source, method, args, unit)
	return [source._hud_paint_environment, paint] if paint != null else null

func route(source: Control, method: String, args: Array, unit: Dictionary, hud: bool) -> bool:
	if source.has_meta("rd03_canvas") or unit.is_empty() or bool(unit.get("death_animation", false)): return false
	var key: String = str(unit.get("key", ""))
	if key.is_empty(): return false
	var id: String = "%d:%s:%s" % [source.get_instance_id(), method, key]
	var record: Dictionary = canvases.get(id, {})
	var canvas: Control = record.get("canvas") as Control
	var retained_hud: bool = hud and HudRetention.enabled(source)
	if not is_instance_valid(canvas):
		canvas = source.get_script().new() as Control
		canvas.set_meta("rd03_canvas", true)
		var root_owner: Control = source.get("_render_instrumentation_owner") as Control
		canvas.set("_is_dynamic_render_layer", true)
		canvas.set("_is_layer_slice_canvas", true)
		canvas.set("_render_instrumentation_owner", root_owner if is_instance_valid(root_owner) else source)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.focus_mode = Control.FOCUS_NONE
		source.add_child(canvas)
		source.set_meta("rd03_has_children", true)
		record = {"canvas": canvas, "unit": unit, "hud": hud}
		canvases[id] = record
	# Keep the ordinal canvas and its aim/outline ownership. The production
	# ordinal painter is empty, so after initialization it can retain its paint.
	var retain: bool = (
		method == "_draw_slice_intent_orders"
		and source.get_script().resource_path == "res://scripts/combat_board_view.gd"
		and not source._board_redraw_baseline() and not canvas.get("_render_slice_ops").is_empty()
	)
	if retained_hud:
		var inputs: Variant = _paint_inputs(source, method, args, unit)
		retain = inputs != null and inputs == record.get("paint_inputs") and canvas.is_visible_in_tree()
		if not retain: record["paint_inputs"] = inputs.duplicate(true) if inputs != null else null
		if HudRetention.health_method(method): record["plate_opacity"] = source._plate_opacity(unit)
	_bind_canvas(source, canvas, false)
	canvas._render_slice_ops = [[method, args]]
	record.unit = unit
	_present(record)
	if not hud: canvas.modulate.a = float(body_alphas.get(key, 1.0))
	_queue_canvas(source, canvas, method, retain)
	return true

const HERO_HUD_Z: int = 3
const TOP_CANVAS_Z: int = HERO_HUD_Z + 1

func route_top(source: Control, method: String, args: Array) -> bool:
	if source.has_meta("rd03_canvas"): return false
	var id: String = "%d:%s:__top" % [source.get_instance_id(), method]
	var canvas: Control = (canvases.get(id, {}) as Dictionary).get("canvas") as Control
	if not is_instance_valid(canvas):
		canvas = source.get_script().new() as Control
		canvas.set_meta("rd03_canvas", true)
		canvas.set_meta("rd03_top_canvas", true)
		canvas.set("_is_dynamic_render_layer", true)
		canvas.set("_is_layer_slice_canvas", true)
		var root_owner: Control = source.get("_render_instrumentation_owner") as Control
		canvas.set("_render_instrumentation_owner", root_owner if is_instance_valid(root_owner) else source)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.focus_mode = Control.FOCUS_NONE
		canvas.z_index = TOP_CANVAS_Z
		canvas.connect("intent_callout_drawn", func(layout: Dictionary) -> void: source.emit_signal("intent_callout_drawn", layout))
		source.add_child(canvas)
		source.set_meta("rd03_has_children", true)
		canvases[id] = {"canvas": canvas, "unit": {}, "hud": true, "top": true}
	var empty: bool = (source.presentation.get("intent_callouts", []) as Array).is_empty()
	var retain: bool = not source._confirm_draw_baseline() and empty and bool(canvas.get_meta("perf148_empty_callout", false)) and canvas.is_visible_in_tree()
	canvas.set_meta("perf148_empty_callout", empty)
	if not retain: _bind_canvas(source, canvas, true)
	canvas.set("_render_slice_ops", [[method, args]])
	_queue_canvas(source, canvas, method, retain)
	return true

func _bind_canvas(source: Control, canvas: Control, top: bool) -> void:
	canvas.size = source.size
	canvas.material = source.material
	var owner: Control = source.get("_render_instrumentation_owner") as Control
	if not is_instance_valid(owner): owner = source
	var baseline: bool = source._board_redraw_baseline()
	if source._render_layer_kind == "hud" and owner != source and not source._confirm_draw_baseline():
		_bind_hud_state(source, canvas, owner)
	else:
		for field: String in Layers.STATE_FIELDS: canvas.set(field, source.get(field))
	var assets: Dictionary = owner.get("_retained_asset_bindings")
	if baseline or not is_same(canvas.get_meta("rd03_asset_bindings", {}), assets):
		for field: String in assets: canvas.set(field, source.get(field))
		canvas.set_meta("rd03_asset_bindings", assets)
	if not top:
		for field: String in ["plate_visibility", "_status_plate_layout", "health_ghost_tracker", "status_pop_tracker", "_art_treatment", "_art_treatment_enabled"]: canvas.set(field, source.get(field))
	# The passive hover changes the HUD's paint inputs at the existing board
	# projection. The source replaces its tile centers on real layout changes.
	if (
		not owner._submitting_focus_delta or not canvas._board_layout_cache_valid
		or canvas._board_layout_cache_size != canvas.size
		or not is_same(canvas._board_layout_cache_tile_centers, source._board_layout_cache_tile_centers)
	):
		source.call("_copy_resolved_board_layout_to", canvas)

func _bind_hud_state(source: Control, canvas: Control, owner: Control) -> void:
	var revision: int = owner._hud_binding_revision
	var previous: int = int(canvas.get_meta("perf148_state_binding_revision", -1))
	# Each routed canvas stays with its one source. The owner's sync publishes
	# replaced bindings, while the HUD's clock and deferred hover can also
	# update a handful of fields before the next full submission.
	if previous < 0 or revision - previous > 1:
		for field: String in Layers.STATE_FIELDS: canvas.set(field, source.get(field))
	elif previous != revision:
		for field: StringName in owner._hud_changed_bindings:
			if Layers.STATE_FIELDS.has(str(field)): canvas.set(field, source.get(field))
	for field: String in LATE_HUD_BINDINGS: canvas.set(field, source.get(field))
	canvas.set_meta("perf148_state_binding_revision", revision)

func _queue_canvas(source: Control, canvas: Control, method: String, retain: bool = false) -> void:
	if not source._board_redraw_baseline(): canvas.set_meta("rd03_routed", true)
	if _record_hud_route_order and not _hud_route_order.has(canvas): _hud_route_order.append(canvas)
	if retain:
		canvas.show()
		return
	var trace: RefCounted = source.get("_board_redraw_trace")
	if trace != null: trace.inherit_reason(source, canvas, false, "aim painter: " + method)
	canvas.show()
	canvas.queue_redraw()

func _present(record: Dictionary) -> void:
	# The callout canvas never dims and keeps its topmost z.
	if bool(record.get("top", false)): return
	var canvas: Control = record.canvas
	var source: Control = canvas
	var unit: Dictionary = record.unit
	if record.hud and not source._confirm_draw_baseline() and str(unit.get("role", "")) in ["player", "enemy"]:
		var inputs: Array = [changes, focus_tile, unit.get("role"), unit.get("pos"), unit.get("footprint"), unit.get("death_animation", false)]
		if inputs == record.get("aim_presentation", []): return
		record["aim_presentation"] = inputs
	else:
		record.erase("aim_presentation")
	var strong: bool = full_strength(source, unit)
	# Body and HUD records share one outline transition per actor on the board.
	var owner: Control = source.get("_render_instrumentation_owner")
	var key: String = str(unit.get("key", ""))
	var outline_alpha: float = 1.0 if strong else HUD_ALPHA
	var outlines: Node2D = owner.get("_occlusion_silhouettes") if is_instance_valid(owner) else null
	if is_instance_valid(outlines) and _outline_targets.get(key, 1.0) != outline_alpha:
		_outline_targets[key] = outline_alpha
		var previous: Tween = _outline_tweens.get(key)
		if previous != null and previous.is_valid(): previous.kill()
		var from: float = outlines.supplied_alpha_multiplier(key)
		var motion: Tween = owner.create_tween().set_trans(EASE_OUT_CURVE).set_ease(Tween.EASE_OUT)
		motion.tween_method(func(value: float) -> void: owner.set_unit_outline_alpha_multiplier(key, value), from, outline_alpha, TRANSITION_SECONDS)
		_outline_tweens[key] = motion
	var tint: Color = Color.WHITE
	if not strong:
		if record.hud: tint.a = HUD_ALPHA
		else:
			tint.r = SPRITE_RGB
			tint.g = SPRITE_RGB
			tint.b = SPRITE_RGB
	if canvas.get_meta("rd03_target", Color.TRANSPARENT) != tint:
		canvas.set_meta("rd03_target", tint)
		var old: Tween = canvas.get_meta("rd03_tween") as Tween if canvas.has_meta("rd03_tween") else null
		if old != null and old.is_valid(): old.kill()
		var tween: Tween = canvas.create_tween().set_trans(EASE_OUT_CURVE).set_ease(Tween.EASE_OUT)
		tween.tween_property(canvas, "self_modulate", tint, TRANSITION_SECONDS)
		for child: Node in canvas.get_children():
			if child is Control and str(child.name).begins_with("IntentTab_"):
				tween.parallel().tween_property(child, "modulate", tint, TRANSITION_SECONDS)
		canvas.set_meta("rd03_tween", tween)
	if record.hud:
		# Crowded fallback still paints every enemy HUD beneath the hero HUD.
		if unit.get("role") == "player": canvas.z_index = HERO_HUD_Z
		else: canvas.z_index = 2 if source.call("_unit_footprint_tiles", unit).has(focus_tile) else 1

func route_operation(source: Control, method: String, args: Array, direct: Variant = null) -> bool:
	if source.has_meta("rd03_canvas"): return false
	# Intent callouts are the topmost board HUD. Per-unit HUD canvases are
	# children of this layer, so the callouts get their own child above them.
	if method == "_draw_slice_callouts": return route_top(source, method, args)
	if method == "_draw_unit_hud_details":
		for unit: Dictionary in args[0]:
			var one: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([unit])
			if route(source, method, [one], unit, true): continue
			if direct == null: source.call(method, one)
			else: direct.append([method, [one]])
		return true
	if method in ["_draw_health_bar_entry", "_draw_health_damage_preview", "_draw_health_bar_text"]:
		if method == "_draw_health_bar_entry":
			if bool(args[0].get("terrain", false)): return false
			return route(source, method, args, args[0].unit, true)
		return route(source, method, args, args[0], true)
	if method == "_draw_slice_intent_orders":
		# The production ordinal painter only reserves space in the plan. Its
		# observer overrides still run through the original routed canvas.
		if not source._confirm_draw_baseline() and source.get_script().resource_path == "res://scripts/combat_board_view.gd": return true
		for badge: Dictionary in args[0]:
			var routed: bool = false
			for unit: Dictionary in source.call("_visible_units"):
				if str(unit.get("key", "")) == str(badge.get("key", "")):
					var one_badge: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([badge])
					routed = route(source, method, [one_badge], unit, true)
					break
			if not routed: source.call(method, preload("res://scripts/typed_arrays.gd").dictionaries([badge]))
		return true
	if method in ["_draw_slice_intent_chip", "_draw_slice_intent_halo"]:
		for unit: Dictionary in source.call("_visible_units"):
			if str(unit.get("key", "")) == str(args[0].get("key", "")): return route(source, method, args, unit, true)
	return false

func _close_terrain_popup(board: Control) -> void:
	for child: Node in board.get_children():
		if not child is Window or child.get("theme_type_variation") != &"TooltipPanel": continue
		for content: Node in child.get_children():
			if content.has_meta("tile_tooltip_stack"):
				(child as Window).hide()
				child.queue_free()
				break
