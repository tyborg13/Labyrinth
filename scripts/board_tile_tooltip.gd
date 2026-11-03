extends RefCounted

## One snapshot feeds the native mouse popup and controller detail builder.
## Like CardFocusTooltipStack, each entry owns a shared UiTooltipPanel in a VBox.
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Surface = preload("res://scripts/board_surface_presentation.gd")
const Rules = preload("res://scripts/board_surface_rules.gd")
const PREFIX: String = "tile-effects:"
const PANEL_GAP: int = 6

static func entries(view: Control, tile: Vector2i) -> Array[Dictionary]:
	return view.get("_tile_tooltip_cache").entries_for_tile(view, tile)

static func build_entries(view: Control, tile: Vector2i, marks: Dictionary, lights: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = Surface.tooltip_entries(view.combat_state, tile)
	var state: Dictionary = view.combat_state
	for trap: Dictionary in state.get("traps", []):
		if trap.get("pos") == tile: result.append(from_text(view._trap_tooltip_text(trap)))
	# Preserve the controller's existing terrain-before-loot traversal. Surface
	# effects and traps now precede both, per the tile stack contract.
	for terrain: Dictionary in state.get("terrain", []):
		if terrain.get("pos") == tile and Rules.terrain_is_live(terrain):
			result.append(from_text(view._terrain_tooltip_text(terrain)))
	for loot: Dictionary in state.get("loot", []):
		if loot.get("pos") != tile or bool(loot.get("claimed", false)): continue
		var text: String = view._loot_tooltip_text(loot)
		if text.is_empty(): continue
		var entry: Dictionary = from_text(text)
		if text.begins_with("equipment:") or text.begins_with("item:"):
			entry["builder_key"] = text
		result.append(entry)
	result.append_array(marks.get(tile, []))
	result.append_array(lights.get(tile, []))
	return result

# Build each map once per submitted state revision, rather than forecasting
# every enemy for each hovered tile (or each navigation candidate).
static func mark_entries(view: Control) -> Dictionary:
	var result: Dictionary = {}
	var state: Dictionary = view.combat_state
	var player_tile: Vector2i = state.get("player", {}).get("pos", Vector2i(-1, -1))
	var meteors: Dictionary = {}
	for mark: Dictionary in state.get("meteor_marks", []):
		var seen_tiles: Dictionary = {}
		for tile: Vector2i in mark.get("tiles", []):
			if seen_tiles.has(tile): continue
			seen_tiles[tile] = true
			var combined: Dictionary = meteors.get(tile, {"damage": 0, "surface": ""})
			combined["damage"] = int(combined["damage"]) + int(mark.get("damage", 0))
			combined["surface"] = str(mark.get("surface", combined["surface"]))
			meteors[tile] = combined
	for tile: Vector2i in meteors:
		var mark: Dictionary = meteors[tile]
		var surface: String = str(mark["surface"])
		_append_for_tile(result, tile, from_text("Meteorfall\nAt the start of your next turn this tile takes %d damage%s.%s" % [int(mark["damage"]), " and becomes %s" % surface.capitalize() if not surface.is_empty() else "", _standing_line(tile, player_tile)], "cinder_marks"))
	for tile: Vector2i in preload("res://scripts/enemy_mechanics/icefall_view.gd").marks(view):
		_append_for_tile(result, tile, from_text(Icons.tooltip("icefall") + "\n5 damage.%s" % _standing_line(tile, player_tile), "icefall"))
	var lob: Dictionary = preload("res://scripts/enemy_mechanics/lob_view.gd").marks(view)
	var lob_texts: Dictionary = {}
	for tile: Vector2i in lob:
		var enemy: Dictionary = lob[tile]["enemy"]
		var id: int = int(enemy.get("id", -1))
		if not lob_texts.has(id): lob_texts[id] = preload("res://scripts/enemy_mechanics/lob_view.gd").mark_tooltip(state, enemy)
		_append_for_tile(result, tile, from_text(lob_texts[id], "lob"))
	for mark: Dictionary in preload("res://scripts/enemy_mechanics/burrow_view.gd").marks(state):
		var tile: Vector2i = mark["tile"]
		_append_for_tile(result, tile, from_text(Icons.tooltip("erupt") + "\n%d damage.%s" % [int(mark["damage"]), _standing_line(tile, player_tile)], "erupt"))
	return result

static func _standing_line(tile: Vector2i, player_tile: Vector2i) -> String:
	return "\nYou are standing on it." if tile == player_tile else ""

static func _append_for_tile(target: Dictionary, tile: Vector2i, entry: Dictionary) -> void:
	if not target.has(tile):
		var values: Array[Dictionary]
		target[tile] = values
	(target[tile] as Array).append(entry)

static func light_entries(view: Control) -> Dictionary:
	# Retain exact live copy/counters from the existing retained registrations.
	# This scan occurs once when the revision is first inspected, and once after
	# a changed submission has rendered if a held inspector used the old regions.
	var result: Dictionary = {}
	var sources: Array = view._retained_render_layers()
	sources.reverse()
	sources.append(view)
	var seen: Dictionary = {}
	for source: Control in sources:
		for region: Dictionary in (source.get("_tile_tooltip_regions") as Dictionary).values():
			var key: String = str(region.get("tile_detail_key", ""))
			if key.is_empty(): continue
			var tile: Vector2i = region["tile"]
			var tile_seen: Dictionary = seen.get(tile, {})
			if tile_seen.has(key): continue
			tile_seen[key] = true
			seen[tile] = tile_seen
			_append_for_tile(result, tile, from_text(str(region["tooltip"])))
	return result

static func from_text(text: String, icon: String = "") -> Dictionary:
	var newline: int = text.find("\n")
	return {"icon": icon, "title": text if newline < 0 else text.left(newline), "description": "" if newline < 0 else text.substr(newline + 1)}

static func encode(values: Array[Dictionary]) -> String:
	return "" if values.is_empty() else PREFIX + JSON.stringify(values)

static func decode(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if not text.begins_with(PREFIX): return result
	var parsed: Variant = JSON.parse_string(text.trim_prefix(PREFIX))
	if parsed is Array:
		for value: Variant in parsed:
			if value is Dictionary: result.append(value)
	return result

static func plain_text(values: Array[Dictionary]) -> String:
	var text := PackedStringArray()
	for entry: Dictionary in values:
		text.append(str(entry["title"]) + ("\n" + str(entry["description"]) if not str(entry["description"]).is_empty() else ""))
	return "\n\n".join(text)

static func make_stack(values: Array[Dictionary], builder: Callable) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.name = "BoardTileTooltipStack"
	stack.set_meta("tile_tooltip_stack", true)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", PANEL_GAP)
	for entry: Dictionary in values:
		var panel: Control
		if entry.has("builder_key"):
			panel = builder.call(str(entry["builder_key"])) as Control
		else:
			var icon: String = str(entry.get("icon", ""))
			var texture: Texture2D = Icons.icon_texture(icon) if not icon.is_empty() else null
			var lines := PackedStringArray([str(entry["description"])]) if not str(entry["description"]).is_empty() else PackedStringArray()
			panel = Panels.make_icon_lines(texture, str(entry["title"]), lines) if texture != null else Panels.make_lines(str(entry["title"]), lines)
		if panel == null: continue
		panel.set_meta("tile_tooltip_entry", entry.duplicate(true))
		stack.add_child(panel)
	return stack

static func refresh_held_popup(view: Control) -> void:
	if not view._tooltips_enabled: return
	for child: Node in view.get_children():
		if not child is Window or not child.visible or child.is_queued_for_deletion(): continue
		if child.theme_type_variation != &"TooltipPanel": continue
		if not child.get_flag(Window.FLAG_MOUSE_PASSTHROUGH): continue
		for content: Node in child.get_children():
			if not content.has_meta("tile_tooltip_stack"): continue
			var viewport: Viewport = view.get_viewport()
			if viewport.gui_get_hovered_control() != view: return
			var replacement: Control = view._make_custom_tooltip(view._get_tooltip(view._last_pointer_position)) as Control
			if replacement == null:
				child.hide()
				child.queue_free()
			else:
				# Keep Godot's tooltip Window/hover ownership and its position. Its
				# custom root is replaceable; the new ornament remeasures the stack.
				child.remove_child(content)
				content.queue_free()
				child.remove_meta("tooltip_wrapper_sanitized")
				child.add_child(replacement)
			return
