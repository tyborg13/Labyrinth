extends "res://scripts/board_layer_slices.gd"

## Hover identity is presentation state. Retained command owners animate their
## CanvasItem alpha; neither the tween nor a held hover invalidates board paint.
const DIM_ALPHA: float = 0.30
const TRANSITION_SECONDS: float = 0.12
const HoverActor = preload("res://scripts/board_hover_actor.gd")

static func resolve(scene: Node, state: Dictionary, tile: Vector2i, rest: Dictionary, allow_reverse: bool = true) -> Array[String]:
	var keys: Array[String]
	# A display forecast may schedule an enemy; only the committed actor owns
	# the live interaction phase while the player is still choosing a target.
	if scene._animation_lock or not scene._combat_engine.is_player_turn(scene._combat_state): return keys
	var direct: String = HoverActor.key_at_tile(scene, state, tile, scene._turn_order_hovered_enemy_key)
	if not direct.is_empty():
		keys.append(direct)
		return keys
	if not allow_reverse or tile.x < 0: return keys
	for unit: Dictionary in state.get("allies", []):
		if unit.get("pos") == tile and int(unit.get("hp", 0)) > 0: return keys
	if state.get("player", {}).get("pos") == tile: return keys
	for threat: Dictionary in rest.get("threats", []):
		if (threat.get("tiles", []) as Array).has(tile) and not keys.has(str(threat["key"])): keys.append(str(threat["key"]))
	for key: String in marked_keys(scene, state, tile):
		if not keys.has(key): keys.append(key)
	keys.sort()
	return keys

static func decorate(scene: Node, state: Dictionary, presentation: Dictionary, tile: Vector2i) -> void:
	var rest: Dictionary = scene._stage_hover_refresh.rest_badges(scene, scene._enemy_intent_preview_state(state), "")
	var keys: Array[String] = resolve(scene, state, tile, rest, not scene._targeted_card_aiming_active())
	presentation["threats_at_rest"] = rest
	presentation["isolated_enemy_actor_keys"] = keys
	presentation["hover_owner_tile"] = scene._hovered_board_tile
	presentation["threat_isolation_hero_preview"] = scene._selected_card_index >= 0 or scene._player_movement_selected
	if not keys.is_empty(): presentation["expanded_enemy_actor_keys"] = keys
	update_rail(scene, keys)

static func alpha_for(keys: Array, selected: Array) -> float:
	if keys.is_empty() or selected.is_empty(): return 1.0
	for key: String in keys:
		if selected.has(key): return 1.0
	return DIM_ALPHA

static func tile_keys(board: Control, tile: Vector2i) -> Array[String]:
	var keys: Array[String]
	for threat: Dictionary in board.presentation.get("threats_at_rest", {}).get("threats", []):
		if (threat.get("tiles", []) as Array).has(tile): keys.append(str(threat["key"]))
	return keys

static func update_rail(scene: Node, keys: Array) -> void:
	if scene._turn_order_bar == null: return
	for slot: Control in scene._turn_order_bar.get_children():
		var actor: String = str(slot.get_meta("turn_order_actor_key", ""))
		if not actor.begins_with("enemy:"): continue
		var parts: Dictionary = slot.get_meta("perf03_retained_parts", {})
		var edge: Control = parts.get("edge")
		if edge == null: continue
		# Both inspection and threat isolation feed the one retained animator.
		slot.set_meta("threat_isolation_hovered", keys.has(actor.trim_prefix("enemy:")))
		preload("res://scripts/board_rail_highlight.gd").apply(slot, scene.board_view.plate_visibility)

static func intent_enemy_at_point(board: Control, point: Vector2) -> Dictionary:
	var units: Array[Dictionary] = board._visible_units()
	for badge: Dictionary in preload("res://scripts/intent_badges.gd").layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])):
		if not (badge.get("rect", Rect2()) as Rect2).has_point(point): continue
		for unit: Dictionary in units:
			if str(unit.get("key", "")) == str(badge["key"]): return unit
	return {}

static func enemy_at_point(board: Control, point: Vector2) -> Dictionary:
	var intent: Dictionary = intent_enemy_at_point(board, point)
	if not intent.is_empty(): return intent
	# Hit testing must not reverse the board's shared retained roster.
	var units: Array[Dictionary]
	units.assign(board._visible_units())
	units.reverse()
	for unit: Dictionary in units:
		if str(unit.get("role", "")) != "enemy": continue
		if board._unit_draw_rect(unit).has_point(point): return unit
	return {}

static func enemy_at_tile(board: Control, tile: Vector2i) -> Dictionary:
	for unit: Dictionary in board._visible_units():
		if str(unit.get("role", "")) == "enemy" and board._unit_footprint_tiles(unit).has(tile): return unit
	return {}

static func supports(kind: String, shown: Dictionary = {}) -> bool:
	return kind in ["ambient", "overlays", "foreground", "hud"] or (shown.has("isolated_enemy_actor_keys") and kind in ["scene_tile", "effects", "effect_telegraphs"])

func _apply_alpha(canvas: Control, keys: Array, selected: Array) -> void:
	canvas.set_meta("threat_actor_keys", keys.duplicate())
	# Reused slice slots can change from enemy paint to hero/floor paint.
	# Unowned paint must never inherit a retiring enemy’s in-flight fade.
	if keys.is_empty():
		var retiring: Tween = canvas.get_meta("rd04_tween") if canvas.has_meta("rd04_tween") else null
		if retiring != null and retiring.is_valid(): retiring.kill()
		canvas.modulate.a = 1.0
		canvas.set_meta("rd04_alpha", 1.0)
		return
	var target: float = alpha_for(keys, selected)
	if is_equal_approx(float(canvas.get_meta("rd04_alpha", 1.0)), target): return
	canvas.set_meta("rd04_alpha", target)
	var previous: Tween = canvas.get_meta("rd04_tween") if canvas.has_meta("rd04_tween") else null
	if previous != null and previous.is_valid(): previous.kill()
	var tween: Tween = canvas.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(canvas, "modulate:a", target, TRANSITION_SECONDS)
	canvas.set_meta("rd04_tween", tween)

func _rebuild(layer: Control) -> void:
	if not layer.presentation.has("isolated_enemy_actor_keys"):
		super._rebuild(layer)
		return
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
			"scene_tile": layer.call("_build_threat_scene_operations")
			"effects": layer.call("_build_threat_effect_operations")
			"effect_telegraphs": layer.call("_build_threat_telegraph_operations")
	layer.set("_slice_building", false)
	var groups: Array = []
	var animated: Array[bool]
	var owners: Array = []
	for operation: Array in operations:
		var on_clock: bool = bool(operation[2])
		var keys: Array = operation[3] if operation.size() > 3 else []
		if groups.is_empty() or animated.back() != on_clock or owners.back() != keys:
			groups.append([])
			animated.append(on_clock)
			owners.append(keys)
		(groups.back() as Array).append(operation.slice(0, 2))
	# The original layer keeps the first static segment. Its public node identity,
	# direct queue_redraw path, draw counters and primary tooltip regions survive.
	var parent_ops: Array = []
	if kind != "scene_tile" and not groups.is_empty() and not animated[0] and owners[0].is_empty():
		parent_ops = groups.pop_front()
		animated.pop_front()
		owners.pop_front()
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
		_apply_alpha(canvas, owners[index], layer.presentation.get("isolated_enemy_actor_keys", []))
		# The team-outline unit canvases retain their original child indices.
		# Paint this tile's floor, paths and props before the original parent and
		# its bodies, while preserving painter order between different tiles.
		canvas.show_behind_parent = kind == "scene_tile"
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
			for field: String in ["plate_visibility", "_status_plate_layout", "health_ghost_tracker", "status_pop_tracker", "_art_treatment", "_art_treatment_enabled"]:
				canvas.set(field, layer.get(field))
		for field: String in ["_render_layer_tile", "_render_layer_scene_effect_pass", "_hover_tile", "_controller_focus_tile", "_idle_elapsed", "_hud_health_rects_cache", "_hud_layout_entries_cache"]:
			canvas.set(field, layer.get(field))
		if created or not bool(canvas.get("_board_layout_cache_valid")):
			layer.call("_copy_resolved_board_layout_to", canvas)
	_animated = animated
	_initialized = true
	layer.set("_slice_operations", [])
	# Empty parent canvases need one clearing submission after a previous plan.
	layer.queue_redraw()


static func mechanic_keys(board: Control, method: String, tile: Vector2i = Vector2i(-1, -1)) -> Array[String]:
	var keys: Array[String]
	for enemy: Dictionary in board.combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		if method == "_draw_slice_icefall" and not (enemy.get("icefall_tiles", []) as Array).has(tile): continue
		if method == "_draw_slice_meteor_mark":
			var found: bool = false
			for mark: Dictionary in board.BurrowView.marks(board.combat_state):
				if mark["tile"] == tile and int(mark["enemy_id"]) == int(enemy["id"]): found = true
			if not found: continue
		if method == "_draw_slice_wind" and int(enemy.get("id", -2)) != int(board.combat_state.get("wind", {}).get("source_id", -1)): continue
		keys.append("enemy_%d" % int(enemy.get("id", -1)))
	return keys

static func owner_keys(unit: Dictionary, board: Control = null) -> Array[String]:
	var keys: Array[String]
	var role: String = str(unit.get("role", ""))
	if board != null and role == board.WindView.GHOST_ROLE:
		var source_id: int = int(board.combat_state.get("wind", {}).get("source_id", -1))
		if source_id >= 0: keys.append("enemy_%d" % source_id)
	if role == "enemy_move_preview": keys.append("enemy_%d" % int(unit.get("id", -1)))
	if unit.has("threat_owner_key"): keys.append(str(unit["threat_owner_key"]))
	return keys

static func preview_tile_keys(board: Control, tile: Vector2i, field: String) -> Array[String]:
	var keys: Array[String]
	if bool(board.presentation.get("threat_isolation_hero_preview", false)): return keys
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		var covered: bool = (threat.get(field, []) as Array).has(tile) if field != "projected_destination" else threat.get(field) == tile or threat.get("projected_player_force", {}).get("destination") == tile
		if covered: keys.append(str(threat.get("enemy_key", "")))
	return keys

static func threat_operations(board: Control, tile: Vector2i, polygon: PackedVector2Array, sources: Dictionary) -> void:
	var owners: Array[String] = tile_keys(board, tile)
	var lob: Dictionary = sources.get("lob_marks", {})
	if lob.has(tile): owners.append("enemy_%d" % int(lob[tile]["enemy"]["id"]))
	board.set("_threat_slice_keys", owners)
	var local: Dictionary = sources.duplicate(false)
	local["zone_tags"] = []
	preload("res://scripts/board_layer_slices.gd").threat_operations(board, tile, polygon, local)
	for tag: Dictionary in sources.get("zone_tags", []):
		if tag["tile"] != tile: continue
		var tag_owner: Array[String]
		tag_owner.append(str(tag["key"]))
		board.set("_threat_slice_keys", tag_owner)
		board.call("_slice_op", "_draw_slice_threat_tag", [tag, board.call("_tile_center", tile)])
	var empty: Array[String]
	board.set("_threat_slice_keys", empty)

static func marked_keys(scene: Node, state: Dictionary, tile: Vector2i) -> Array[String]:
	var keys: Array[String]
	if tile.x < 0: return keys
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not scene._combat_engine.is_enemy_visible_to_player(state, enemy): continue
		var covered: bool = (enemy.get("icefall_tiles", []) as Array).has(tile) or (enemy.get("lob_tiles", []) as Array).has(tile)
		if not covered and (enemy.get("lob_tiles", []) as Array).is_empty():
			for action: Dictionary in enemy.get("intent", {}).get("actions", []):
				if str(action.get("type", "")) == "lob_mark":
					covered = (preload("res://scripts/enemy_mechanics/marked_strike.gd").aiming_forecast(scene._combat_engine, state, enemy).get("tiles", []) as Array).has(tile)
		if covered: keys.append("enemy_%d" % int(enemy["id"]))
	for mark: Dictionary in preload("res://scripts/enemy_mechanics/burrow_view.gd").marks(state):
		if mark["tile"] != tile: continue
		for enemy: Dictionary in state.get("enemies", []):
			var key: String = "enemy_%d" % int(enemy["id"])
			if int(enemy["id"]) == int(mark["enemy_id"]) and scene._combat_engine.is_enemy_visible_to_player(state, enemy) and not keys.has(key): keys.append(key)
	return keys

func retire(layer: Control) -> void:
	if not _initialized: return
	for canvas: Control in canvases:
		layer.remove_child(canvas)
		canvas.queue_free()
	canvases.clear()
	_animated.clear()
	_initialized = false
	layer.set("_render_slice_ops", [])
	var owner: Control = layer.get("_render_instrumentation_owner")
	if is_instance_valid(owner): owner.call("_invalidate_retained_render_layers")
