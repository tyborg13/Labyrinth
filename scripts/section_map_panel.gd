extends Control
class_name SectionMapPanel

const Graph = preload("res://scripts/section_map_graph.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const NodeButton = preload("res://scripts/section_map_node.gd")
const Canvas = preload("res://scripts/section_map_canvas.gd")
const LegacyMap = preload("res://scripts/labyrinth_map_view.gd")
const Fog = preload("res://shaders/section_map_fog.gdshader")

signal room_selected(coord: Vector2i)
signal scout_requested(coord: Vector2i)
signal door_requested(coord: Vector2i)
signal event_requested(choice: String)
signal close_requested

var run_state: Dictionary = {}
var viewed_section: int = 0
var selected_coord: Vector2i = Graph.INVALID
var node_buttons: Dictionary = {}
var _skin := UiSkin.new()
var _signature: int = 0
var _built: bool = false
var _background: TextureRect
var _canvas: Control
var _fog: ColorRect
var _nodes: Control
var _header: HBoxContainer
var _title: Label
var _progress: Label
var _tabs: HBoxContainer
var _detail: Label
var _consequence: Label
var _scout: Button
var _enter: Button
var _close: Button
var _legacy: Control
var _layout: VBoxContainer
var _field: Control
var _selection_status: Label

func _ready() -> void:
	_build()
	resized.connect(_layout_nodes)
	_refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout = VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 0)
	add_child(_layout)
	var header_panel: PanelContainer = _panel()
	_layout.add_child(header_panel)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 24)
	header_panel.add_child(_header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title_stack)
	_title = _label("", Typography.ROLE_HERO)
	_title.name = "SectionTitle"
	title_stack.add_child(_title)
	_progress = _label("", Typography.ROLE_BODY)
	title_stack.add_child(_progress)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_tabs)
	_close = _button("X", func() -> void: close_requested.emit(), UiSkin.VARIANT_ICON)
	_close.name = "CloseButton"
	_close.custom_minimum_size = Vector2(48, 48)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.tooltip_text = "Close map"
	_header.add_child(_close)
	_field = Control.new()
	_field.name = "MapField"
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.custom_minimum_size = Vector2(640, 430)
	_field.clip_contents = true
	_layout.add_child(_field)
	_field.resized.connect(_layout_nodes)
	_background = TextureRect.new()
	_background.name = "SectionBackground"
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.modulate = Color(0.56, 0.54, 0.59)
	_full_field(_background)
	_canvas = Canvas.new()
	_canvas.name = "Connections"
	_full_field(_canvas)
	_fog = ColorRect.new()
	_fog.name = "DynamicFog"
	var material := ShaderMaterial.new()
	material.shader = Fog
	_fog.material = material
	_full_field(_fog)
	_nodes = Control.new()
	_nodes.name = "RoomNodes"
	_full_field(_nodes)
	var footer: PanelContainer = _panel()
	_layout.add_child(footer)
	var footer_stack := VBoxContainer.new()
	footer_stack.add_theme_constant_override("separation", 0)
	footer.add_child(footer_stack)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	footer_stack.add_child(actions)
	var detail_stack := VBoxContainer.new()
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.custom_minimum_size.x = 470
	actions.add_child(detail_stack)
	_selection_status = _label("", Typography.ROLE_CAPTION)
	_selection_status.add_theme_color_override("font_color", Color("bca77d"))
	detail_stack.add_child(_selection_status)
	_detail = _label("", Typography.ROLE_TITLE)
	detail_stack.add_child(_detail)
	_consequence = _label("", Typography.ROLE_BODY_LARGE)
	_consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consequence.custom_minimum_size.y = 60
	detail_stack.add_child(_consequence)
	_scout = _button("Scout", _request_scout)
	_scout.name = "ScoutButton"
	_skin.apply_button_native_size(_scout, 56, 224, false, UiSkin.VARIANT_STANDARD)
	_scout.icon = MapSkin.icon_texture("scout")
	_scout.expand_icon = true
	_scout.add_theme_constant_override("icon_max_width", 28)
	_scout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(_scout)
	_enter = _button("Enter room", _request_entry, UiSkin.VARIANT_SELECTED)
	_enter.name = "EnterRoomButton"
	_skin.apply_button_native_size(_enter, 60, 264, false, UiSkin.VARIANT_SELECTED)
	_enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(_enter)
	_legacy = LegacyMap.new()
	_legacy.name = "LegacyMap"
	_legacy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_legacy.connect("room_selected", func(coord: Vector2i) -> void: room_selected.emit(coord))
	add_child(_legacy)
	_legacy.hide()
	var legacy_close: Button = _button("Close", func() -> void: close_requested.emit())
	legacy_close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legacy_close.position = Vector2(-110, 12)
	legacy_close.custom_minimum_size = Vector2(96, 48)
	_legacy.add_child(legacy_close)

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MapSkin.panel_style())
	return panel

func _label(text: String, role: String) -> Label:
	var label := Label.new()
	label.text = text
	Typography.apply_label_role(label, role)
	label.add_theme_color_override("font_color", Color("e2d1ad"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable, variant: String = UiSkin.VARIANT_STANDARD) -> Button:
	var button := TooltipButton.new()
	button.text = text
	MapSkin.button(button, variant)
	button.pressed.connect(action)
	return button

func _full_field(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(control)

func set_run_state(source: Dictionary) -> void:
	var objective: Dictionary = (source.get("combat_state", {}) as Dictionary).get("objective", {}) as Dictionary
	var next_signature: int = hash([source.get("rooms", {}), source.get("map_sections", []), source.get("current_room"), source.get("mode"), objective.get("type", "")])
	if next_signature == _signature:
		return
	var previous_current: Vector2i = run_state.get("current_room", Graph.INVALID)
	_signature = next_signature
	run_state = {"rooms": source.get("rooms", {}), "map_sections": source.get("map_sections", []), "current_room": source.get("current_room", Vector2i.ZERO), "mode": source.get("mode", "room"), "section_map_version": source.get("section_map_version", 0), "seed": source.get("seed", 0), "reach_exit": str(objective.get("type", "")) == "reach_exit"}
	if previous_current != run_state.get("current_room", Graph.INVALID):
		viewed_section = Graph.active_section(run_state)
		selected_coord = Graph.INVALID
	if _built:
		_refresh()

func _refresh() -> void:
	if not _built or run_state.is_empty():
		return
	var modern: bool = Graph.enabled(run_state)
	_layout.visible = modern
	_legacy.visible = not modern
	if not modern:
		_legacy.call("set_run_state", run_state)
		return
	viewed_section = clampi(viewed_section, 0, Graph.active_section(run_state))
	var info: Dictionary = Graph.section(run_state, viewed_section)
	_title.text = str(info.get("title", "Map"))
	var visited: int = 0
	for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == viewed_section and bool(node.get("visited", false)) and str(node.get("type", "")) != "start":
			visited += 1
	_progress.text = "SECTION %s / VI  ·  %d / %d ROOMS EXPLORED%s" % [_roman(viewed_section), visited, int(info.get("room_count", 11)), "  ·  HISTORY" if viewed_section < Graph.active_section(run_state) else ""]
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for index: int in range(6):
		var tab: Button = _button(_roman(index), select_section.bind(index), UiSkin.VARIANT_ICON)
		tab.name = "Section%d" % (index + 1)
		tab.custom_minimum_size = Vector2(52, 48)
		tab.toggle_mode = true
		tab.button_pressed = index == viewed_section
		MapSkin.button(tab, UiSkin.VARIANT_SELECTED if index == viewed_section else UiSkin.VARIANT_ICON)
		tab.disabled = index > Graph.active_section(run_state)
		tab.tooltip_text = str(Graph.section(run_state, index).get("title", "")) if not tab.disabled else "Unreached section"
		_tabs.add_child(tab)
	_background.texture = Assets.load_texture("res://assets/art/backgrounds/sections/%s.png" % str(info.get("boss_id", "tharokh")))
	if selected_coord == Graph.INVALID or int(Graph.room(run_state, selected_coord).get("section_index", -1)) != viewed_section:
		var choices: Array[Vector2i] = available_destinations()
		selected_coord = choices[0] if viewed_section == Graph.active_section(run_state) and not choices.is_empty() else info.get("boss", Graph.INVALID)
	_layout_nodes()
	_refresh_detail()

func available_destinations() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current: Dictionary = Graph.room(run_state, run_state.get("current_room", Vector2i.ZERO))
	for link: Dictionary in current.get("connections", []):
		var coord: Vector2i = link.get("coord", Graph.INVALID)
		var node: Dictionary = Graph.room(run_state, coord)
		if bool(node.get("revealed", false)) and not bool(node.get("sealed", false)):
			result.append(coord)
	return result

func select_section(index: int) -> void:
	if index > Graph.active_section(run_state):
		return
	viewed_section = index
	selected_coord = Graph.INVALID
	_refresh()

func select_room(coord: Vector2i) -> void:
	if not node_buttons.has(coord):
		return
	selected_coord = coord
	for key: Vector2i in node_buttons:
		var button: Button = node_buttons[key]
		button.set("selected", key == selected_coord)
		button.call("refresh_state")
	_canvas.set("selected", coord)
	_canvas.queue_redraw()
	_refresh_detail()

func _layout_nodes() -> void:
	if not _built or not Graph.enabled(run_state) or _field.size.x < 100:
		return
	var focused_coord: Vector2i = Graph.INVALID
	for coord: Vector2i in node_buttons:
		if (node_buttons[coord] as Control).has_focus():
			focused_coord = coord
	for child: Node in _nodes.get_children():
		_nodes.remove_child(child)
		child.queue_free()
	node_buttons.clear()
	var info: Dictionary = Graph.section(run_state, viewed_section)
	var count: int = int(info.get("room_count", 11))
	for band: int in range(4):
		var low_step: int = count
		var high_step: int = 0
		for candidate: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
			if int(candidate.get("section_index", -1)) == viewed_section and int(candidate.get("depth", -1)) == viewed_section * 4 + band + 1:
				low_step = mini(low_step, int(candidate.get("map_step", count)))
				high_step = maxi(high_step, int(candidate.get("map_step", 0)))
		var band_label: Label = _label("DEPTH " + _roman(band), Typography.ROLE_BODY_LARGE)
		band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		band_label.position = Vector2(68 + (_field.size.x - 136) * float(low_step + high_step) / (2.0 * count) - 60, 18)
		band_label.size = Vector2(120, 28)
		_nodes.add_child(band_label)
	var available: Array[Vector2i] = available_destinations()
	var future: Dictionary = Graph.descendants(run_state, run_state.get("current_room", Graph.INVALID))
	var positions: Dictionary = {}
	var openings := PackedVector4Array()
	for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) != viewed_section or not (bool(node.get("revealed", false)) or bool(node.get("map_outline", false)) or _has_recovery(node)):
			continue
		var coord: Vector2i = node.get("coord", Graph.INVALID)
		var x: float = 68 + (_field.size.x - 136) * float(node.get("map_step", 0)) / float(count)
		var y: float = 152 + (_field.size.y - 282) * (float(node.get("map_lane", 1)) / 2.0)
		var point := Vector2(x, y)
		positions[coord] = point
		var button: Button = NodeButton.new()
		button.name = "Room_%s" % Graph.key(coord).replace("-", "n").replace(",", "_")
		button.position = point - Vector2(50, 48)
		button.size = Vector2(100, 160)
		var state: String = _node_route_state(node, available, future)
		var caption: String = _room_label(node).replace(" Fight", "\nFight")
		button.call("configure", node, caption, state)
		button.set("selected", selected_coord == coord)
		button.set("door_label", _door_name(coord).to_upper())
		button.call("refresh_state")
		button.pressed.connect(select_room.bind(coord))
		button.focus_entered.connect(select_room.bind(coord))
		_nodes.add_child(button)
		node_buttons[coord] = button
		if bool(node.get("revealed", false)) or _has_recovery(node):
			openings.append(Vector4(x / _field.size.x, y / _field.size.y, 0.081, 0.21))
	if focused_coord != Graph.INVALID and node_buttons.has(focused_coord):
		(node_buttons[focused_coord] as Control).grab_focus()
	var opening_count: int = mini(32, openings.size())
	while openings.size() < 32:
		openings.append(Vector4.ZERO)
	var material := _fog.material as ShaderMaterial
	material.set_shader_parameter("openings", openings)
	material.set_shader_parameter("opening_count", opening_count)
	material.set_shader_parameter("motion", 0.0)
	_canvas.set("state", run_state)
	_canvas.set("positions", positions)
	_canvas.set("section_index", viewed_section)
	_canvas.set("selected", selected_coord)
	_canvas.queue_redraw()

func _node_route_state(node: Dictionary, available: Array[Vector2i], future: Dictionary) -> String:
	var coord: Vector2i = node.get("coord", Graph.INVALID)
	if coord == run_state.get("current_room", Graph.INVALID): return "current"
	if bool(node.get("visited", false)): return "visited"
	if not future.has(coord): return "bypassed"
	if available.has(coord) and viewed_section == Graph.active_section(run_state): return "reachable"
	return "ahead"

func _refresh_detail() -> void:
	var node: Dictionary = Graph.room(run_state, selected_coord)
	var mode: String = str(run_state.get("mode", "room"))
	var active: bool = viewed_section == Graph.active_section(run_state)
	var available: bool = active and available_destinations().has(selected_coord)
	var known: bool = bool(node.get("revealed", false))
	_detail.text = _room_label(node)
	var future: Dictionary = Graph.descendants(run_state, run_state.get("current_room", Graph.INVALID))
	var route_state: String = _node_route_state(node, available_destinations(), future)
	_selection_status.text = {"current": "YOU ARE HERE", "visited": "VISITED ROOM", "bypassed": "ROUTE NOT TAKEN", "reachable": _door_name(selected_coord).to_upper() + " · SELECTED", "ahead": "AHEAD · " + ("KNOWN ROOM" if known else "UNEXPLORED")}.get(route_state, "")
	var next_names: Array[String] = []
	if known:
		for link: Dictionary in node.get("connections", []):
			var next: Dictionary = Graph.room(run_state, link.get("coord", Graph.INVALID))
			if bool(next.get("map_outline", false)) and int(next.get("section_index", -1)) == viewed_section:
				var label: String = _room_label(next)
				if not next_names.has(label):
					next_names.append(label)
	var detail: String = "Next: %s" % ", ".join(next_names) if not next_names.is_empty() else ""
	if available:
		var keeps: Array[String] = []
		var leaves: Array[String] = []
		var descendants: Dictionary = Graph.descendants(run_state, selected_coord)
		for candidate: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
			if int(candidate.get("section_index", -1)) != viewed_section or not future.has(candidate.get("coord", Graph.INVALID)):
				continue
			var landmark: bool = bool(candidate.get("map_landmark", false)) and not bool(candidate.get("visited", false))
			if landmark or _has_recovery(candidate):
				var names: Array[String] = keeps if descendants.has(candidate.get("coord", Graph.INVALID)) else leaves
				var name: String = "%d lost Embers" % int(candidate.get("recovery_amount", 0)) if _has_recovery(candidate) else _room_label(candidate)
				if not names.has(name): names.append(name)
		if not keeps.is_empty(): detail += "\nKeeps: %s" % ", ".join(keeps)
		if not leaves.is_empty(): detail += "  ·  Leaves: %s" % ", ".join(leaves)
	elif not active:
		detail = "Completed section · Discovered routes"
	elif bool(node.get("visited", false)):
		detail = "Current room" if selected_coord == run_state.get("current_room", Graph.INVALID) else "Already visited"
	else:
		detail = ("This route is no longer reachable." if route_state == "bypassed" else "Reach an earlier room on this route first.") + ("  ·  " + detail if not detail.is_empty() else "")
	if _has_recovery(node):
		detail += "\nRecover %d lost Embers here." % int(node.get("recovery_amount", 0))
	_consequence.text = detail
	var targets: Array[Vector2i] = Graph.scout_targets(run_state, selected_coord)
	_scout.text = "Scout · %d / 2" % int(Graph.section(run_state, viewed_section).get("scouts", 0))
	_scout.disabled = not available or targets.is_empty() or mode not in ["room", "combat", "pre_battle"]
	_scout.tooltip_text = "Reveal %d rooms along this branch, up to four steps ahead." % targets.size() if not targets.is_empty() else "This branch has no new rooms to reveal."
	if int(Graph.section(run_state, viewed_section).get("scouts", 0)) <= 0:
		_scout.tooltip_text = "Both Scouts have been used in this section."
	elif not available:
		_scout.tooltip_text = "Select an available door to scout its route." if active else "Scouting is unavailable in completed sections."
	_enter.disabled = not available or mode != "room"
	_enter.text = "Enter %s" % _type_label(str(node.get("type", "room"))) if available else {"current": "Current room", "visited": "Already visited", "bypassed": "Route not taken"}.get(route_state, "Further ahead")
	if mode == "combat":
		_enter.text = "Show door" if bool(run_state.get("reach_exit", false)) and available else "Combat in progress"
		_enter.disabled = not (bool(run_state.get("reach_exit", false)) and available)
		if bool(run_state.get("reach_exit", false)) and available:
			_consequence.text = detail + "\nReach this door to take this route."
	if active and mode == "event":
		_selection_status.text = "CURRENT EVENT"
		_detail.text = "The Lost Cartographer"
		_consequence.text = "Take 25 Embers or reveal every route up to four rooms ahead."
		_enter.text = "Take 25 Embers"
		_enter.disabled = false
		_scout.text = "Reveal routes"
		_scout.disabled = not event_has_discoveries()
	var onward: Vector2i = _next_section_destination()
	if onward != Graph.INVALID:
		_selection_status.text = "BOSS DEFEATED"
		_detail.text = "Section complete"
		_consequence.text = "Next: " + str(Graph.section(run_state, int(Graph.room(run_state, onward).get("section_index", 0))).get("title", ""))
		_enter.text = "Next section"
		_enter.disabled = false
		_scout.disabled = true
	if not active:
		_selection_status.text = "SECTION HISTORY"
		_enter.text = "Section complete"

func _has_recovery(node: Dictionary) -> bool:
	return bool(node.get("recovery_marker", false)) and int(node.get("recovery_amount", 0)) > 0

func _next_section_destination() -> Vector2i:
	if viewed_section != Graph.active_section(run_state) or str(run_state.get("mode", "")) != "room":
		return Graph.INVALID
	var current: Dictionary = Graph.room(run_state, run_state.get("current_room", Graph.INVALID))
	if str(current.get("type", "")) != "boss" or not bool(current.get("cleared", false)):
		return Graph.INVALID
	for coord: Vector2i in available_destinations():
		if int(Graph.room(run_state, coord).get("section_index", -1)) == viewed_section + 1:
			return coord
	return Graph.INVALID

func event_has_discoveries() -> bool:
	for coord: Vector2i in Graph.descendants(run_state, run_state.get("current_room", Vector2i.ZERO), 4):
		if not bool(Graph.room(run_state, coord).get("revealed", false)):
			return true
	return false

func _request_scout() -> void:
	if _scout.disabled:
		return
	if str(run_state.get("mode", "")) == "event":
		event_requested.emit("survey")
	else:
		scout_requested.emit(selected_coord)

func _request_entry() -> void:
	if _enter.disabled:
		return
	if str(run_state.get("mode", "")) == "event":
		event_requested.emit("embers")
	elif str(run_state.get("mode", "")) == "combat":
		door_requested.emit(selected_coord)
	else:
		var onward: Vector2i = _next_section_destination()
		room_selected.emit(onward if onward != Graph.INVALID else selected_coord)

func _door_name(coord: Vector2i) -> String:
	for link: Dictionary in Graph.room(run_state, run_state.get("current_room", Vector2i.ZERO)).get("connections", []):
		if link.get("coord", Graph.INVALID) == coord:
			var direction: Vector2i = link.get("door_dir", Vector2i.RIGHT)
			return {Vector2i.UP: "North door", Vector2i.RIGHT: "East door", Vector2i.DOWN: "South door", Vector2i.LEFT: "West door"}.get(direction, "Door")
	return "Door"

func _room_label(node: Dictionary) -> String:
	if not bool(node.get("revealed", false)):
		return "Unknown"
	if str(node.get("type", "")) == "boss":
		return str(node.get("boss_id", "Boss")).capitalize()
	if str(node.get("type", "")) == "combat":
		return "%s Fight" % str(node.get("element", "")).capitalize()
	return _type_label(str(node.get("type", "")))

func _type_label(type: String) -> String:
	return {"combat": "Fight", "event": "Event", "scavenger": "Scavenger", "treasure": "Relic", "campfire": "Campfire", "boss": "Boss", "start": "Threshold", "unknown": "Unknown"}.get(type, "Room")

func _roman(index: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI"][clampi(index, 0, 5)]

func center_on_current(_reset_zoom: bool = true) -> void:
	if not Graph.enabled(run_state):
		if _legacy != null: _legacy.call("center_on_current", _reset_zoom)
		return
	viewed_section = Graph.active_section(run_state)
	_refresh()

func focus_controller_on_current() -> void:
	if not Graph.enabled(run_state):
		_legacy.call("focus_controller_on_current")
	elif _next_section_destination() != Graph.INVALID:
		_enter.grab_focus()
	elif node_buttons.has(selected_coord):
		(node_buttons[selected_coord] as Control).grab_focus()
	else:
		_close.grab_focus()

func begin_travel_animation(from: Vector2i, to: Vector2i) -> bool:
	if not Graph.enabled(run_state):
		return bool(_legacy.call("begin_travel_animation", from, to))
	return false
