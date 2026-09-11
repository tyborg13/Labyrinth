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
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Fog = preload("res://shaders/section_map_fog.gdshader")

signal room_selected(coord: Vector2i)
signal scout_requested(coord: Vector2i)
signal door_requested(coord: Vector2i)
signal event_requested(choice: String)
signal interaction_changed
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
var _scout: Button
var _continue: Button
var _close: Button
var _legacy: Control
var _layout: VBoxContainer
var _field: Control
var _boss_legend_icon: Control
var scout_targeting: bool = false
var _scout_hint: Label
var _preview: PanelContainer
var _preview_text: String = ""
var _event_panel: PanelContainer
var _event_embers: Button
var _event_survey: Button
var _reduced_motion: bool = false
var activation_coord: Vector2i = Graph.INVALID
var _activation_kind: String = ""
var _activation_generation: int = 0
var _activation_tween: Tween
const ACTIVATION_SECONDS: float = 0.28
const REDUCED_ACTIVATION_SECONDS: float = 0.14

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
	_continue = _button("Next section", _request_onward, UiSkin.VARIANT_SELECTED)
	_continue.name = "NextSectionButton"
	_skin.apply_button_native_size(_continue, 56, 224, false, UiSkin.VARIANT_SELECTED)
	_continue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_continue)
	_continue.hide()
	_close = _button("X", _request_close, UiSkin.VARIANT_ICON)
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
	_fog = ColorRect.new()
	_fog.name = "DynamicFog"
	var material := ShaderMaterial.new()
	material.shader = Fog
	_fog.material = material
	_full_field(_fog)
	# Known topology remains legible over fog. Only revealed/outlined endpoints
	# enter the canvas, so this never draws a route to an undiscovered room.
	_canvas = Canvas.new()
	_canvas.name = "Connections"
	_full_field(_canvas)
	_nodes = Control.new()
	_nodes.name = "RoomNodes"
	_full_field(_nodes)
	var footer: PanelContainer = _panel()
	_layout.add_child(footer)
	var legend_row := HBoxContainer.new()
	legend_row.add_theme_constant_override("separation", 24)
	footer.add_child(legend_row)
	var legend := _build_legend()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend_row.add_child(legend)
	_scout_hint = _label("Choose an unknown room", Typography.ROLE_BODY)
	_scout_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend_row.add_child(_scout_hint)
	_scout = _button("Scout", _toggle_scout)
	_scout.name = "ScoutButton"
	_skin.apply_button_native_size(_scout, 56, 224, false, UiSkin.VARIANT_STANDARD)
	_scout.icon = MapSkin.icon_texture("scout")
	_scout.expand_icon = true
	_scout.add_theme_constant_override("icon_max_width", 28)
	_scout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend_row.add_child(_scout)
	_build_event()
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

func _build_legend() -> HBoxContainer:
	var legend := HBoxContainer.new()
	legend.name = "MapLegend"
	legend.add_theme_constant_override("separation", 18)
	for type: String in ["combat", "event", "scavenger", "treasure", "campfire", "boss", "unknown"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(item)
		var icon := Control.new()
		icon.name = "Legend_" + type
		icon.custom_minimum_size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_meta("room_icon_id", type)
		icon.draw.connect(func() -> void:
			var center: Vector2 = icon.size * 0.5
			if str(icon.get_meta("room_icon_id")) == "unknown":
				for segment: int in range(8):
					var angle: float = TAU * float(segment) / 8.0
					icon.draw_arc(center, 18, angle, angle + 0.47, 8, Color("aaa2af"), 1.8, true)
			else:
				MapSkin.draw_medallion(icon, center, 24, MapSkin.icon_texture(str(icon.get_meta("room_icon_id"))))
		)
		if type == "boss": _boss_legend_icon = icon
		item.add_child(icon)
		var label: Label = _label(_type_label(type), Typography.ROLE_CAPTION)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(label)
	return legend

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
	button.focus_entered.connect(interaction_changed.emit)
	button.focus_exited.connect(interaction_changed.emit)
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
	_cancel_activation()
	var previous_current: Vector2i = run_state.get("current_room", Graph.INVALID)
	_signature = next_signature
	run_state = {"rooms": source.get("rooms", {}), "map_sections": source.get("map_sections", []), "current_room": source.get("current_room", Vector2i.ZERO), "mode": source.get("mode", "room"), "section_map_version": source.get("section_map_version", 0), "seed": source.get("seed", 0), "reach_exit": str(objective.get("type", "")) == "reach_exit"}
	if previous_current != run_state.get("current_room", Graph.INVALID):
		viewed_section = Graph.active_section(run_state)
		reset_interaction()
	if _built:
		_refresh()

func _refresh() -> void:
	if not _built or run_state.is_empty():
		return
	_reduced_motion = Settings.reduced_motion_enabled(Settings.load_settings())
	var modern: bool = Graph.enabled(run_state)
	_layout.visible = modern
	_legacy.visible = not modern
	if not modern:
		_legacy.call("set_run_state", run_state)
		return
	viewed_section = clampi(viewed_section, 0, Graph.active_section(run_state))
	var info: Dictionary = Graph.section(run_state, viewed_section)
	_title.text = str(info.get("title", "Map"))
	_boss_legend_icon.set_meta("room_icon_id", "boss_" + str(info.get("boss_id", "tharokh")))
	_boss_legend_icon.queue_redraw()
	var visited: int = 0
	for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == viewed_section and bool(node.get("visited", false)) and str(node.get("type", "")) != "start":
			visited += 1
	_progress.text = "SECTION %s / VI  ·  %d / %d ROOMS EXPLORED%s" % [_roman(viewed_section), visited, int(info.get("room_count", 11)), "  ·  HISTORY" if viewed_section < Graph.active_section(run_state) else ""]
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for index: int in range(6):
		var tab := TooltipButton.new()
		tab.text = _roman(index)
		tab.pressed.connect(select_section.bind(index))
		tab.focus_entered.connect(interaction_changed.emit)
		tab.name = "Section%d" % (index + 1)
		tab.custom_minimum_size = Vector2(62, 62)
		tab.toggle_mode = true
		tab.button_pressed = index == viewed_section
		MapSkin.section_tab(tab)
		tab.disabled = index > Graph.active_section(run_state)
		tab.tooltip_text = str(Graph.section(run_state, index).get("title", "")) if not tab.disabled else "Unreached section"
		_tabs.add_child(tab)
	_background.texture = Assets.load_texture("res://assets/art/backgrounds/sections/%s.png" % str(info.get("boss_id", "tharokh")))
	_layout_nodes()
	_refresh_actions()
	if selected_coord != Graph.INVALID and node_buttons.has(selected_coord):
		_show_preview(selected_coord)

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
	var restore_tab_focus: bool = false
	for tab: Control in _tabs.get_children():
		restore_tab_focus = restore_tab_focus or tab.has_focus()
	viewed_section = index
	reset_interaction()
	_refresh()
	# Refresh rebuilds the reached-section tabs. Restore the native focus owner
	# so keyboard/controller users can keep navigating after switching history.
	if restore_tab_focus:
		(_tabs.get_child(index) as Control).grab_focus()

func select_room(coord: Vector2i) -> void:
	# Inspection is optional and never a prerequisite for activating a room.
	_show_preview(coord)

func can_activate_room(coord: Vector2i) -> bool:
	if viewed_section != Graph.active_section(run_state): return false
	var mode: String = str(run_state.get("mode", ""))
	if scout_targeting:
		return mode in ["room", "combat", "pre_battle"] and not Graph.scout_targets(run_state, coord).is_empty()
	return available_destinations().has(coord) and (mode == "room" or (mode == "combat" and bool(run_state.get("reach_exit", false))))

func activate_room(coord: Vector2i) -> void:
	# One gesture owns the entire acknowledgement and commit. Rapid clicks or
	# key repeats cannot schedule a second destination while it is in flight.
	if activation_coord != Graph.INVALID: return
	if not can_activate_room(coord):
		_show_preview(coord)
		return
	_hide_preview()
	activation_coord = coord
	_activation_kind = "scout" if scout_targeting else ("door" if str(run_state.get("mode", "")) == "combat" else "room")
	_activation_generation += 1
	var generation: int = _activation_generation
	var source_signature: int = _signature
	var button: Control = node_buttons.get(coord)
	var seconds: float = REDUCED_ACTIVATION_SECONDS if _reduced_motion else ACTIVATION_SECONDS
	if button != null:
		button.call("set_activation_progress", 0.001)
		_activation_tween = button.create_tween()
		_activation_tween.tween_method(Callable(button, "set_activation_progress"), 0.001, 1.0, seconds)
	_canvas.set("selected", coord)
	_canvas.queue_redraw()
	var feedback: Node = get_node_or_null("/root/CursorFeedback")
	if feedback != null: feedback.call("play_action_confirmation")
	interaction_changed.emit()
	# A timer completes even if a resize, close, section change or state refresh
	# kills the tween. Generation and snapshot checks discard those stale calls.
	await get_tree().create_timer(seconds).timeout
	if generation != _activation_generation or source_signature != _signature or not is_visible_in_tree(): return
	var action: String = _activation_kind
	_cancel_activation()
	if not can_activate_room(coord): return
	if action == "scout":
		scout_targeting = false
		scout_requested.emit(coord)
		_refresh_actions()
	elif action == "door":
		door_requested.emit(coord)
	else:
		room_selected.emit(coord)

func _cancel_activation() -> void:
	_activation_generation += 1
	if _activation_tween != null:
		_activation_tween.kill()
		_activation_tween = null
	var button: Control = node_buttons.get(activation_coord)
	if is_instance_valid(button): button.call("set_activation_progress", 0.0)
	activation_coord = Graph.INVALID
	_activation_kind = ""

func cancel_action() -> bool:
	if activation_coord != Graph.INVALID:
		_cancel_activation()
		_hide_preview()
		return true
	if not scout_targeting: return false
	scout_targeting = false
	_hide_preview()
	_refresh_actions()
	_scout.grab_focus()
	return true

func reset_interaction() -> void:
	_cancel_activation()
	scout_targeting = false
	_hide_preview()

func _request_close() -> void:
	if not cancel_action(): close_requested.emit()

func _layout_nodes() -> void:
	if not _built or not Graph.enabled(run_state) or _field.size.x < 100:
		return
	_cancel_activation()
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
	var available: Array[Vector2i] = available_destinations()
	var future: Dictionary = Graph.descendants(run_state, run_state.get("current_room", Graph.INVALID))
	var positions: Dictionary = {}
	var openings := PackedVector4Array()
	for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) != viewed_section or not (bool(node.get("revealed", false)) or bool(node.get("map_outline", false)) or _has_recovery(node)):
			continue
		var coord: Vector2i = node.get("coord", Graph.INVALID)
		var x: float = 80 + (_field.size.x - 204) * float(node.get("map_step", 0)) / float(count)
		var y: float = 116 + (_field.size.y - 232) * (float(node.get("map_lane", 1)) / 2.0)
		var point := Vector2(x, y)
		positions[coord] = point
		var button: Button = NodeButton.new()
		button.name = "Room_%s" % Graph.key(coord).replace("-", "n").replace(",", "_")
		var extent: float = 106.0 if str(node.get("type", "")) == "boss" else 61.0
		button.position = point - Vector2.ONE * extent
		button.size = Vector2.ONE * extent * 2.0
		var state: String = _node_route_state(node, available, future)
		button.call("configure", node, _room_label(node), state, _reduced_motion)
		button.set("scout_target", scout_targeting and can_activate_room(coord))
		button.set("actionable", can_activate_room(coord))
		button.call("refresh_state")
		button.pressed.connect(activate_room.bind(coord))
		button.focus_entered.connect(_show_preview.bind(coord))
		button.focus_exited.connect(_hide_preview_for.bind(coord))
		button.mouse_entered.connect(_show_preview.bind(coord))
		button.mouse_exited.connect(_hide_preview_for.bind(coord))
		_nodes.add_child(button)
		node_buttons[coord] = button
		var known: bool = bool(node.get("revealed", false)) or _has_recovery(node)
		openings.append(Vector4(x / _field.size.x, y / _field.size.y, 0.081 if known else 0.045, 0.21 if known else 0.11))
	_refresh_route_radii()
	_wire_choice_focus()
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

func room_description(coord: Vector2i) -> String:
	var node: Dictionary = Graph.room(run_state, coord)
	var detail: String = "Not yet visited"
	if coord == run_state.get("current_room", Graph.INVALID):
		detail = "Current room"
	elif bool(node.get("visited", false)):
		detail = "Already visited"
	elif not Graph.descendants(run_state, run_state.get("current_room", Graph.INVALID)).has(coord):
		detail = "No longer reachable"
	elif not bool(node.get("revealed", false)):
		detail = "Scout to reveal" if scout_targeting and can_activate_room(coord) else "Undiscovered"
	if _has_recovery(node):
		detail += " · %d lost Embers" % int(node.get("recovery_amount", 0))
	return _room_label(node) + "\n" + detail

func _show_preview(coord: Vector2i) -> void:
	if activation_coord != Graph.INVALID or not node_buttons.has(coord) or _event_panel.visible: return
	_hide_preview()
	selected_coord = coord
	_preview_text = room_description(coord)
	_preview = Tooltip.make_text(_preview_text)
	_preview.name = "RoomPreview"
	# Shared inset ornaments draw one layer behind their parent. Keep both
	# the tooltip body and its text above the map background and nodes.
	_preview.z_index = 2
	_field.add_child(_preview)
	_preview.reset_size()
	_position_preview.call_deferred(coord)
	_canvas.set("selected", coord)
	_canvas.queue_redraw()
	interaction_changed.emit()

func _position_preview(coord: Vector2i) -> void:
	if _preview == null or selected_coord != coord or not node_buttons.has(coord): return
	var button: Control = node_buttons[coord]
	var center: Vector2 = button.position + button.size * 0.5
	var radius: float = float(button.call("visual_radius")) + 18.0
	var y: float = center.y + radius if center.y < _field.size.y * 0.55 else center.y - radius - _preview.size.y
	_preview.position = Vector2(clampf(center.x - _preview.size.x * 0.5, 12, _field.size.x - _preview.size.x - 12), clampf(y, 12, _field.size.y - _preview.size.y - 12))

func _hide_preview_for(coord: Vector2i) -> void:
	if selected_coord == coord: _hide_preview()

func _hide_preview() -> void:
	selected_coord = Graph.INVALID
	_preview_text = ""
	if is_instance_valid(_preview):
		_preview.hide()
		_preview.queue_free()
	_preview = null
	if _canvas != null:
		_canvas.set("selected", Graph.INVALID)
		_canvas.queue_redraw()
	interaction_changed.emit()

func _refresh_actions() -> void:
	var return_room_focus: bool = _event_panel.visible and (_event_embers.has_focus() or _event_survey.has_focus())
	var active: bool = viewed_section == Graph.active_section(run_state)
	var mode: String = str(run_state.get("mode", ""))
	var uses: int = int(Graph.section(run_state, viewed_section).get("scouts", 0))
	var has_targets: bool = not Graph.scout_options(run_state).is_empty()
	_scout.disabled = not active or uses <= 0 or not has_targets or mode not in ["room", "combat", "pre_battle"]
	if _scout.disabled: scout_targeting = false
	_scout.text = "Cancel Scout" if scout_targeting else "Scout · %d / 2" % uses
	_scout.tooltip_text = "Reveal an unknown room."
	if uses <= 0: _scout.tooltip_text = "No Scouts remaining."
	elif not active: _scout.tooltip_text = "Completed section."
	elif not has_targets: _scout.tooltip_text = "No unknown rooms in sight."
	elif mode not in ["room", "combat", "pre_battle"]: _scout.tooltip_text = "Resolve the current room first."
	_scout_hint.visible = scout_targeting
	_continue.visible = _next_section_destination() != Graph.INVALID
	_continue.disabled = not _continue.visible
	_event_panel.visible = active and mode == "event"
	_event_survey.disabled = not event_has_discoveries()
	_event_survey.tooltip_text = "All routes within four rooms are already revealed." if _event_survey.disabled else "Reveal every route up to four rooms ahead."
	for coord: Vector2i in node_buttons:
		var button: Button = node_buttons[coord]
		button.set("scout_target", scout_targeting and can_activate_room(coord))
		button.set("actionable", can_activate_room(coord))
		button.focus_mode = Control.FOCUS_NONE if _event_panel.visible else Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if _event_panel.visible else Control.MOUSE_FILTER_STOP
		button.call("refresh_state")
	_refresh_route_radii()
	_wire_choice_focus()
	if return_room_focus and not _event_panel.visible:
		focus_controller_on_current()
	interaction_changed.emit()

func _refresh_route_radii() -> void:
	var radii: Dictionary = {}
	for coord: Vector2i in node_buttons:
		radii[coord] = float((node_buttons[coord] as Control).call("visual_radius")) + 6.0
	_canvas.set("radii", radii)
	_canvas.queue_redraw()

func _choice_destinations() -> Array[Vector2i]:
	return Graph.scout_options(run_state) if scout_targeting else available_destinations()

func _wire_choice_focus() -> void:
	# Vertical navigation follows the current decision before visiting other
	# depths. The ends lead to tabs/Scout so this does not trap native focus.
	for button: Control in node_buttons.values():
		button.focus_neighbor_top = NodePath("")
		button.focus_neighbor_bottom = NodePath("")
		button.focus_neighbor_left = NodePath("")
	if _event_panel.visible or viewed_section != Graph.active_section(run_state): return
	var choices: Array[Vector2i]
	for coord: Vector2i in _choice_destinations():
		if node_buttons.has(coord) and (not scout_targeting or can_activate_room(coord)):
			choices.append(coord)
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (node_buttons[a] as Control).position.y < (node_buttons[b] as Control).position.y)
	for index: int in range(choices.size()):
		var button: Control = node_buttons[choices[index]]
		var above: Control = node_buttons[choices[index - 1]] if index > 0 else _tabs.get_child(viewed_section)
		var below: Control = node_buttons[choices[index + 1]] if index + 1 < choices.size() else _scout
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		var current: Control = node_buttons.get(run_state.get("current_room", Graph.INVALID))
		if current != null and not scout_targeting: button.focus_neighbor_left = button.get_path_to(current)
	if not choices.is_empty():
		_scout.focus_neighbor_top = _scout.get_path_to(node_buttons[choices.back()])
		var tab: Control = _tabs.get_child(viewed_section)
		tab.focus_neighbor_bottom = tab.get_path_to(node_buttons[choices.front()])

func controller_cancel_label() -> String:
	if activation_coord != Graph.INVALID: return "Cancel"
	return "Cancel Scout" if scout_targeting else "Close"

func controller_action_label() -> String:
	if activation_coord != Graph.INVALID:
		return {"room": "Entering", "door": "Showing exit", "scout": "Scouting"}.get(_activation_kind, "Confirm")
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == _scout: return "Cancel Scout" if scout_targeting else "Scout"
	if focused == _continue: return "Continue"
	if focused == _close: return "Close"
	if focused == _event_embers: return "Take Embers"
	if focused == _event_survey: return "Reveal routes"
	if focused != null and focused.get_parent() == _tabs: return "View section"
	for coord: Vector2i in node_buttons:
		if node_buttons[coord] != focused: continue
		if not can_activate_room(coord): return "Inspect"
		if scout_targeting: return "Scout"
		return "Show exit" if str(run_state.get("mode", "")) == "combat" else "Enter"
	return "Confirm"

func _toggle_scout() -> void:
	if _scout.disabled or activation_coord != Graph.INVALID: return
	if cancel_action(): return
	scout_targeting = true
	_hide_preview()
	_refresh_actions()
	focus_controller_on_current()

func _build_event() -> void:
	_event_panel = _panel()
	_event_panel.name = "CartographerEvent"
	_event_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_event_panel.position = Vector2(-340, -114)
	_event_panel.custom_minimum_size = Vector2(680, 228)
	_field.add_child(_event_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 20)
	_event_panel.add_child(stack)
	stack.add_child(_label("The Lost Cartographer", Typography.ROLE_TITLE))
	var description := _label("Take 25 Embers, or reveal every route up to four rooms ahead.", Typography.ROLE_BODY_LARGE)
	description.custom_minimum_size.x = 540
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 20)
	stack.add_child(choices)
	_event_embers = _button("Take 25 Embers", func() -> void: event_requested.emit("embers"), UiSkin.VARIANT_SELECTED)
	_event_survey = _button("Reveal routes", func() -> void: event_requested.emit("survey"))
	for button: Button in [_event_embers, _event_survey]:
		_skin.apply_button_native_size(button, 56, 264, false, UiSkin.VARIANT_STANDARD)
		choices.add_child(button)
	_event_panel.hide()

func _request_onward() -> void:
	if activation_coord != Graph.INVALID: return
	var onward: Vector2i = _next_section_destination()
	if onward != Graph.INVALID: room_selected.emit(onward)

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

func _room_label(node: Dictionary) -> String:
	if not bool(node.get("revealed", false)):
		return "Unknown"
	if str(node.get("type", "")) == "boss":
		return str(node.get("boss_id", "Boss")).capitalize()
	return _type_label(str(node.get("type", "")))

func _type_label(type: String) -> String:
	return {"combat": "Standard combat", "event": "Event", "scavenger": "Scavenger", "treasure": "Relic", "campfire": "Campfire", "boss": "Boss", "start": "Threshold", "unknown": "Unknown"}.get(type, "Room")

func _roman(index: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI"][clampi(index, 0, 5)]

func center_on_current(_reset_zoom: bool = true) -> void:
	if not Graph.enabled(run_state):
		if _legacy != null: _legacy.call("center_on_current", _reset_zoom)
		return
	viewed_section = Graph.active_section(run_state)
	reset_interaction()
	_refresh()

func focus_controller_on_current() -> void:
	if not Graph.enabled(run_state):
		_legacy.call("focus_controller_on_current")
	elif _event_panel.visible:
		_event_embers.grab_focus()
	elif _next_section_destination() != Graph.INVALID:
		_continue.grab_focus()
	else:
		var choices: Array[Vector2i] = _choice_destinations()
		for coord: Vector2i in choices:
			if node_buttons.has(coord) and (not scout_targeting or can_activate_room(coord)):
				(node_buttons[coord] as Control).grab_focus()
				return
		_close.grab_focus()

func begin_travel_animation(from: Vector2i, to: Vector2i) -> bool:
	if not Graph.enabled(run_state):
		return bool(_legacy.call("begin_travel_animation", from, to))
	return false
