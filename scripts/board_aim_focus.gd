extends RefCounted

## Retain the existing painters on per-actor canvases. Canvas modulation tweens
## change renderer state only: no board paint invalidation on animation frames.
const Layers = preload("res://scripts/board_layer_slices.gd")
const Context = preload("res://scripts/targeted_tile_context.gd")
const SPRITE_RGB: float = 0.62
const HUD_ALPHA: float = 0.5
const TRANSITION_SECONDS: float = 0.12
# Director feedback 1: quadratic ease-out accepted.
const EASE_OUT_CURVE: int = Tween.TRANS_QUAD
var active: bool = false
var affected_tiles: Dictionary = {}
var choosing: bool = false
var focus_tile := Vector2i(-1, -1)
var canvases: Dictionary = {}
var changes: int = 0
var _signature: Array = []
var _outline_targets: Dictionary = {}
var _outline_tweens: Dictionary = {}
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
	if source.has_meta("rd03_canvas"): return
	for child: Node in source.get_children():
		if child.has_meta("rd03_canvas"): (child as Control).hide()

func route(source: Control, method: String, args: Array, unit: Dictionary, hud: bool) -> bool:
	if source.has_meta("rd03_canvas") or unit.is_empty() or bool(unit.get("death_animation", false)): return false
	var key: String = str(unit.get("key", ""))
	if key.is_empty(): return false
	var id: String = "%d:%s:%s" % [source.get_instance_id(), method, key]
	var record: Dictionary = canvases.get(id, {})
	var canvas: Control = record.get("canvas") as Control
	if not is_instance_valid(canvas):
		canvas = source.get_script().new() as Control
		canvas.set_meta("rd03_canvas", true)
		canvas.set("_is_dynamic_render_layer", true)
		canvas.set("_is_layer_slice_canvas", true)
		var root_owner: Control = source.get("_render_instrumentation_owner") as Control
		canvas.set("_render_instrumentation_owner", root_owner if is_instance_valid(root_owner) else source)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.focus_mode = Control.FOCUS_NONE
		source.add_child(canvas)
		record = {"canvas": canvas, "unit": unit, "hud": hud}
		canvases[id] = record
	canvas.size = source.size
	canvas.material = source.material
	for field: String in Layers.STATE_FIELDS: canvas.set(field, source.get(field))
	var owner: Control = source.get("_render_instrumentation_owner") as Control
	if not is_instance_valid(owner): owner = source
	for field: String in owner.get("_retained_asset_bindings"): canvas.set(field, source.get(field))
	for field: String in ["plate_visibility", "_status_plate_layout", "health_ghost_tracker", "status_pop_tracker", "_art_treatment", "_art_treatment_enabled"]: canvas.set(field, source.get(field))
	source.call("_copy_resolved_board_layout_to", canvas)
	canvas.set("_render_slice_ops", [[method, args]])
	record.unit = unit
	_present(record)
	if not hud: canvas.modulate.a = float(body_alphas.get(key, 1.0))
	canvas.show()
	canvas.queue_redraw()
	return true

const TOP_CANVAS_Z: int = 3

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
		canvases[id] = {"canvas": canvas, "unit": {}, "hud": true, "top": true}
	canvas.size = source.size
	canvas.material = source.material
	for field: String in Layers.STATE_FIELDS: canvas.set(field, source.get(field))
	var owner: Control = source.get("_render_instrumentation_owner") as Control
	if not is_instance_valid(owner): owner = source
	for field: String in owner.get("_retained_asset_bindings"): canvas.set(field, source.get(field))
	source.call("_copy_resolved_board_layout_to", canvas)
	canvas.set("_render_slice_ops", [[method, args]])
	canvas.show()
	canvas.queue_redraw()
	return true

func _present(record: Dictionary) -> void:
	# The callout canvas never dims and keeps its topmost z.
	if bool(record.get("top", false)): return
	var canvas: Control = record.canvas
	var strong: bool = full_strength(canvas, record.unit)
	# Body and HUD records share one outline transition per actor on the board.
	var owner: Control = canvas.get("_render_instrumentation_owner")
	var key: String = str(record.unit.get("key", ""))
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
		canvas.z_index = 2 if canvas.call("_unit_footprint_tiles", record.unit).has(focus_tile) else 1

func route_operation(source: Control, method: String, args: Array) -> bool:
	if source.has_meta("rd03_canvas"): return false
	# Intent callouts are the topmost board HUD. Per-unit HUD canvases are
	# children of this layer, so the callouts get their own child above them.
	if method == "_draw_slice_callouts": return route_top(source, method, args)
	if method == "_draw_unit_hud_details":
		for unit: Dictionary in args[0]:
			var one: Array[Dictionary] = preload("res://scripts/typed_arrays.gd").dictionaries([unit])
			if not route(source, method, [one], unit, true): source.call(method, one)
		return true
	if method in ["_draw_health_bar_entry", "_draw_health_damage_preview", "_draw_health_bar_text"]:
		if method == "_draw_health_bar_entry":
			if bool(args[0].get("terrain", false)): return false
			return route(source, method, args, args[0].unit, true)
		return route(source, method, args, args[0], true)
	if method == "_draw_slice_intent_orders":
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
