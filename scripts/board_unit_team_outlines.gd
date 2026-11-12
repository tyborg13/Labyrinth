extends RefCounted

# A retained body canvas plus a shader rim per unit, in original painter order.
# Every normal body still uses CombatBoardView's original drawing methods/material.
const Kindle = preload("res://scripts/enemy_mechanics/kindle_view.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const ShaderSource = preload("res://scripts/board_occlusion_silhouettes.gdshader")
const ALPHA: float = 0.80
const WIDTH: float = 2.0
const KIND: String = "unit_body_outline"
var board: Control
var manager: Node2D
var bodies: Dictionary = {}
var entries: Dictionary = {}
var _bindings: Dictionary = {}
var updates: int = 0

func attach(owner_board: Control, overlay: Node2D) -> void:
	board = owner_board
	manager = overlay

static func color_for(unit: Dictionary) -> Color:
	return Color(Palette.DANGER if str(unit.get("role", "")) == "enemy" else Palette.ALLY, ALPHA)

static func visible_to_player(owner_board: Control, unit: Dictionary) -> bool:
	var shown: Dictionary = owner_board.get("presentation")
	if str(unit.get("role", "")) == "enemy" and shown.has("visible_enemy_ids") and not (shown["visible_enemy_ids"] as Array).has(int(unit.get("id", -1))): return false
	return bool(owner_board.call("_board_tile_is_visible_to_player", unit.get("pos", Vector2i(-1, -1)))) and owner_board.call("_umbra_actor_clip_for_unit", unit).is_empty()

static func eligible(owner_board: Control, unit: Dictionary) -> bool:
	if int(unit.get("hp", 0)) <= 0 or bool(unit.get("death_animation", false)): return false
	if str(unit.get("role", "")) == "npc" or owner_board.call("_unit_is_preview_echo", unit): return false
	if bool(unit.get("burrowed", false)): return false
	if not owner_board.call("_board_tile_is_visible_to_player", unit.get("pos", Vector2i(-1, -1))): return false
	return visible_to_player(owner_board, unit)

# Residual alpha under the identical x-ray kernel. Standard alpha-over then
# produces max(team rim, x-ray) at every edge sample, never a stacked bright line.
static func residual_alpha(base: float, xray: float, mask: float = 1.0) -> float:
	return maxf(0.0, (base - xray) * mask) / maxf(0.00001, 1.0 - xray * mask)

func sync() -> void:
	var next_bindings: Dictionary = (board.get("_retained_asset_bindings") as Dictionary).duplicate(false)
	next_bindings.merge(board.get("_retained_state_bindings"), true)
	next_bindings["combat_state"] = board.get("combat_state")
	next_bindings["presentation"] = board.get("presentation")
	next_bindings["_art_treatment"] = board.get("_art_treatment")
	next_bindings["_art_treatment_enabled"] = board.get("_art_treatment_enabled")
	var changed: Dictionary = {}
	for field: String in next_bindings:
		if not _bindings.has(field) or not is_same(_bindings[field], next_bindings[field]): changed[field] = next_bindings[field]
	_bindings = next_bindings
	var retained: Dictionary = {}
	var slot: Dictionary = {}
	for unit: Dictionary in board.call("_visible_units"):
		var key: String = str(unit.get("key", ""))
		var tile: Vector2i = board.call("_effective_unit_tile", unit)
		var layer: Control = (board.get("_scene_render_layers_by_tile") as Dictionary).get(tile)
		if layer == null: continue
		var canvas: Control = bodies.get(key)
		var fresh: bool = not is_instance_valid(canvas)
		if fresh:
			canvas = board.get_script().new()
			canvas.name = "UnitBody_" + key
			canvas.set("_is_dynamic_render_layer", true)
			canvas.set("_render_layer_kind", KIND)
			canvas.set("_render_instrumentation_owner", board)
			canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.focus_mode = Control.FOCUS_NONE
			canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			layer.add_child(canvas)
			bodies[key] = canvas
		elif canvas.get_parent() != layer:
			canvas.reparent(layer, false)
		var desired_index: int = int(slot.get(tile, 0))
		if canvas.get_index() != desired_index: layer.move_child(canvas, desired_index)
		slot[tile] = desired_index + 1
		for field: String in (_bindings if fresh else changed): canvas.set(field, _bindings[field])
		canvas.material = layer.material
		canvas.set("_render_layer_tile", tile)
		canvas.set("_unit_outline_actor", unit)
		# Copy the authoritative geometry without evicting shared shadow meshes.
		board.call("_copy_resolved_board_layout_to", canvas)
		retained[key] = true
		var alive: bool = eligible(board, unit)
		var continuing_death: bool = bool(unit.get("death_animation", false)) and entries.has(key) and visible_to_player(board, unit)
		if str((board.get("presentation") as Dictionary).get("board_framing_mode", "combat")) != "combat": alive = false; continuing_death = false
		if alive or continuing_death:
			if not entries.has(key):
				var rim := Sprite2D.new()
				rim.name = "TeamOutline"
				var ink := ShaderMaterial.new()
				ink.shader = ShaderSource
				rim.material = ink
				canvas.add_child(rim)
				entries[key] = {"sprite": rim, "unit": unit, "tile": tile}
			entries[key]["unit"] = unit
			entries[key]["tile"] = tile
			_update(key)
		elif entries.has(key):
			(entries[key]["sprite"] as Sprite2D).visible = false
			(entries[key]["sprite"] as Sprite2D).queue_free()
			entries.erase(key)
		canvas.visible = bool(manager.get("tool_enabled"))
		if fresh: canvas.queue_redraw()
	for key: String in bodies.keys():
		if retained.has(key): continue
		if is_instance_valid(bodies[key]):
			(bodies[key] as Control).visible = false
			(bodies[key] as Node).queue_free()
		bodies.erase(key)
		entries.erase(key)

func set_enabled(enabled: bool) -> void:
	for key: String in bodies:
		(bodies[key] as Control).visible = enabled
		if enabled: (bodies[key] as Control).queue_redraw()
	for tile: Vector2i in (board.get("_scene_render_layers_by_tile") as Dictionary):
		Kindle.clear_glows((board.get("_scene_render_layers_by_tile") as Dictionary)[tile])
		board.call("_queue_scene_render_layer_for_tile", tile)

func refresh_tile(tile: Vector2i) -> void:
	if not bool(manager.get("tool_enabled")): return
	for key: String in bodies:
		var canvas: Control = bodies[key]
		if canvas.get("_render_layer_tile") != tile: continue
		canvas.set("_idle_elapsed", board.get("_idle_elapsed"))
		canvas.set("_hover_tile", board.get("_hover_tile"))
		canvas.set("_controller_focus_tile", board.get("_controller_focus_tile"))
		canvas.queue_redraw()
		if entries.has(key): _update(key)

func refresh_alpha(key: String) -> void:
	if not entries.has(key): return
	var entry: Dictionary = entries[key]
	var unit: Dictionary = entry["unit"]
	var multiplier: float = manager.call("unit_alpha_multiplier", key)
	var death_alpha: float = float(board.call("_health_bar_owner_alpha", unit)) if bool(unit.get("death_animation", false)) else 1.0
	var color: Color = color_for(unit)
	color.a *= multiplier * death_alpha
	var xray_alpha: float = manager.call("xray_opacity", key)
	var signature: Array = [color, xray_alpha, bool(manager.get("tool_enabled"))]
	if signature == entry.get("alpha_signature", []): return
	entry["alpha_signature"] = signature
	var rim: Sprite2D = entry["sprite"]
	var ink: ShaderMaterial = rim.material
	ink.set_shader_parameter("rim_color", color)
	ink.set_shader_parameter("over_alpha", xray_alpha)
	rim.visible = bool(manager.get("tool_enabled")) and color.a > xray_alpha
	entry["base_alpha"] = color.a
	entry["xray_alpha"] = xray_alpha

func _update(key: String) -> void:
	var entry: Dictionary = entries[key]
	var unit: Dictionary = entry["unit"]
	var draw: Dictionary = Sources.drawing(board, {"kind": "unit", "data": unit, "tile": entry["tile"]})
	if draw.is_empty(): return
	var texture: Texture2D = draw["texture"]
	var rect: Rect2 = draw["rect"]
	var signature: Array = [texture, rect, board.get("_navigation_zoom")]
	if signature != entry.get("signature", []):
		var rim: Sprite2D = entry["sprite"]
		rim.texture = texture
		rim.position = rect.get_center()
		rim.scale = rect.size / Vector2(texture.get_size())
		manager.call("configure_rim", rim.material, texture, rect)
		entry["signature"] = signature
		updates += 1
	refresh_alpha(key)
