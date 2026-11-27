extends RefCounted
## Tooltip and rail strings come from live Controls. The board HUD draws
## directly to CanvasItems, so its literals come from the live painter inputs.

const RailHealth = preload("res://scripts/turn_order_health_numeral.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const BurstText = preload("res://scripts/enemy_mechanics/burst_trait_text.gd")


static func read(scene: Node, board: Control, viewport: SubViewport, tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var bounds: Rect2 = viewport.get_visible_rect()
	var result: Dictionary = {"controls": {}, "tooltips": [], "intents": {}, "plates": {},
		"rail": {}, "board": {}}
	_control_text(scene, bounds, result["controls"], "")
	for popup: Window in viewport.get_embedded_subwindows():
		if not popup.visible or popup.theme_type_variation != &"TooltipPanel": continue
		var popup_bounds := Rect2(Vector2(popup.position), Vector2(popup.size))
		if not popup_bounds.intersects(bounds): continue
		var panels: Array = _popup_panels(popup, Rect2(Vector2.ZERO, Vector2(popup.size)))
		if panels.is_empty(): continue
		result["tooltips"].append({"owner": str(popup.get_parent().get_path()), "panels": panels})
	var popup_tile: Vector2i = tile
	if not (result["tooltips"] as Array).is_empty() and viewport.gui_get_hovered_control() == board:
		popup_tile = _floor_tooltip_tile(board, tile)
	result["tooltip_tile"] = popup_tile
	var rail: Control = scene.get("_turn_order_bar")
	if is_instance_valid(rail):
		for slot: Control in rail.get_children():
			var edge: Control = slot.get_node_or_null("TurnOrderSlashEdge")
			if edge == null or not edge.is_visible_in_tree() or edge.get("color") != Palette.GOLD_BRIGHT: continue
			var key: String = str(slot.get_meta("rd05_actor_key", slot.get_meta("turn_order_actor_key", "")))
			var labels: Dictionary = {}
			_control_text(slot, bounds, labels, "")
			var health: Control = slot.get_node_or_null("TurnOrderHealthNumeral")
			var hp: String = str(health.get("text")) if is_instance_valid(health) and health.is_visible_in_tree() else ""
			result["rail"][str(slot.name)] = {"actor": key, "text": labels.values(), "health": hp}
	_board_hud(board, bounds, result)
	var lob: Dictionary = Lob.marks(board).get(popup_tile, {}).get("enemy", {})
	var icefall: Dictionary = Icefall.marks(board).get(popup_tile, {})
	result["lob_tooltip_owner"] = "enemy_%d" % int(lob["id"]) if not lob.is_empty() else ""
	result["icefall_tooltip_owner"] = "enemy_%d" % int(icefall["id"]) if not icefall.is_empty() else ""
	var reveal: Node = board.get("_occlusion_reveal")
	var fades: Array[Dictionary]
	for fade: Dictionary in (reveal.get("targets") as Dictionary).values():
		if fade["on"] and float(fade["progress"]) > 0.0:
			fades.append({"id": fade["id"], "tile": fade["tile"], "progress": fade["progress"]})
	var shown: Dictionary = board.get("presentation")
	var silhouettes: Node = board.get("_occlusion_silhouettes")
	result["board"] = {
		"hover_fill_tile": board.get("_hover_tile"),
		"actor_focus": shown.get("focus_actor_keys", []),
		"inspected_actors": (board.get("plate_visibility").inspected_keys as Dictionary).keys(),
		"isolated_enemies": shown.get("isolated_enemy_actor_keys", []),
		"occluder_fades": fades,
		"xray": _rim_keys(silhouettes),
		"threat_previews": shown.get("enemy_threat_previews", []),
		"threat_outline_tile": board.get("_threat_lift_tile"),
	}
	return result


static func _floor_tooltip_tile(board: Control, tile: Vector2i) -> Vector2i:
	var point: Vector2 = board.get_local_mouse_position()
	if not str(board.get("plate_visibility").tooltip_at(point)).is_empty(): return tile
	if board.call("_pointer_on_unit", point): return tile
	var state: Dictionary = board.get("combat_state")
	# _get_tooltip checks bobbing loot before its retained hit regions.
	for loot: Dictionary in state.get("loot", []):
		var origin: Vector2i = loot.get("pos", Vector2i(-1, -1))
		if bool(loot.get("claimed", false)) or not board.call("_board_tile_is_visible_to_player", origin): continue
		var texture: Texture2D = board.call("_loot_texture", loot)
		if texture != null and (board.call("_loot_rect_for_tile", origin, texture, loot) as Rect2).grow(18.0).has_point(point):
			return origin
	var sources: Array = (board.call("_retained_render_layers") as Array).duplicate(false)
	for entry: Dictionary in board.get("_aim_focus").canvases.values():
		if is_instance_valid(entry.canvas) and entry.canvas.visible and entry.hud: sources.append(entry.canvas)
	sources.reverse()
	sources.append(board)
	for source: Control in sources:
		var regions: Array = source.get("_tooltip_regions")
		var tiles: Dictionary = source.get("_tile_tooltip_regions")
		for index: int in range(regions.size() - 1, -1, -1):
			if (regions[index].get("rect", Rect2()) as Rect2).has_point(point):
				return tiles.get(index, {}).get("tile", tile)
	return tile


static func _rim_keys(silhouettes: Node) -> Array:
	var result: Array = []
	for key: String in silhouettes.entries:
		var entry: Dictionary = silhouettes.entries[key]
		if (entry["sprite"] as Sprite2D).is_visible_in_tree() and float(entry["alpha"]) > 0.0:
			result.append(key)
	return result


static func _control_text(node: Node, bounds: Rect2, result: Dictionary, prefix: String) -> void:
	if node is Window: return
	if node is CanvasItem and (not node.is_visible_in_tree() or node.modulate.a <= 0.0): return
	if node is Control and node.self_modulate.a > 0.0 and (node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)).intersects(bounds):
		var value: String = ""
		if node is RichTextLabel: value = node.get_parsed_text()
		elif node is Label or node is Button or node.get_script() == RailHealth: value = node.get("text")
		elif node is LineEdit or node is TextEdit: value = node.text
		if not value.is_empty(): result[prefix] = value
	for child: Node in node.get_children(true):
		_control_text(child, bounds, result, prefix.path_join(str(child.name)))


static func _popup_panels(node: Node, bounds: Rect2) -> Array:
	var result: Array = []
	for child: Node in node.get_children(true):
		if child is CanvasItem and not child.is_visible_in_tree(): continue
		if child.has_meta("tile_tooltip_entry"):
			var labels: Dictionary = {}
			_control_text(child, bounds, labels, str(child.name))
			if not labels.is_empty():
				var entry: Dictionary = child.get_meta("tile_tooltip_entry")
				result.append({"title": entry.get("title", ""), "icon": entry.get("icon", ""),
					"builder_key": entry.get("builder_key", ""), "text": labels.values()})
		else:
			result.append_array(_popup_panels(child, bounds))
	if node is Window and result.is_empty():
		var labels: Dictionary = {}
		for child: Node in node.get_children(true): _control_text(child, bounds, labels, str(child.name))
		if not labels.is_empty(): result.append({"title": "", "icon": "", "builder_key": "", "text": labels.values()})
	return result


static func _board_hud(board: Control, bounds: Rect2, result: Dictionary) -> void:
	var visibility: RefCounted = board.get("plate_visibility")
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var units: Dictionary = {}
	for unit: Dictionary in board.call("_hud_layout_units"):
		units[str(unit.get("key", ""))] = unit
	# HUD layout entries are the same ones submitted by the retained HUD painter.
	for entry: Dictionary in board.get("_hud_layout_entries_cache"):
		var key: String = str(entry["actor_key"])
		var unit: Dictionary = units.get(key, {})
		if unit.is_empty() or not (board.call("_umbra_actor_clip_for_unit", unit) as Dictionary).is_empty(): continue
		var layout: Dictionary = entry.get("layout", {})
		var intent: Dictionary = _intent(layout, bounds, transform)
		if not intent.is_empty(): result["intents"][key] = intent
		var frame: Rect2 = entry.get("health_rect", Rect2())
		if not frame.has_area() or not (transform * frame).intersects(bounds) or float(board.call("_plate_opacity", unit)) <= 0.0: continue
		var display_hp: int = board.call("_health_bar_fill_hp", unit, board.call("_unit_damage_preview", unit))
		var statuses: Dictionary = {}
		for status: Dictionary in visibility.status_entries(unit):
			var rect: Rect2 = status.get("rect", Rect2())
			if rect.has_area() and (transform * rect).intersects(bounds):
				statuses[str(status["icon"])] = str(status["label"])
		result["plates"][key] = {"health": "%d/%d" % [display_hp, int(unit.get("max_hp", 1))],
			"statuses": statuses}


static func _intent(layout: Dictionary, bounds: Rect2, transform: Transform2D) -> Dictionary:
	var rows: Array = layout.get("rows", [])
	var line_rects: Array = layout.get("line_rects", [])
	if line_rects.is_empty(): return {}
	var title: String = str(layout.get("intent_name", ""))
	var prefix: int = BurstText.title_index(rows) if not rows.is_empty() and not (rows[0] as Array).is_empty() and str(rows[0][0].get("icon", "")) == "burst" and str(rows[0][0].get("value", "")).begins_with("Burst ") else 0
	var lines: Array = []
	var index: int = 0
	for row_index: int in range(rows.size() + 1):
		if not title.is_empty() and row_index == prefix and index < line_rects.size():
			if (transform * (line_rects[index] as Rect2)).intersects(bounds): lines.append({"title": title})
			index += 1
		if row_index >= rows.size() or index >= line_rects.size(): break
		if (transform * (line_rects[index] as Rect2)).intersects(bounds):
			var tokens: Array = []
			for token: Dictionary in rows[row_index]:
				tokens.append({"text": "" if token.get("kind") == "aoe_pattern" else Icons.token_value_text(token),
					"icon": token.get("icon", ""), "pattern": token.get("kind") == "aoe_pattern",
					"modifier": "+" if Icons.token_is_modified(token) else ""})
			lines.append({"tokens": tokens})
		index += 1
	return {"lines": lines} if not lines.is_empty() else {}
