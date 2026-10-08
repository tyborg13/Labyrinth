# Original HEAD 1eeead41087e11e64609f266e33508d0357efe25 rebuild paths.
extends "res://scripts/section_map_panel.gd"
const OriginalNode = preload("res://tests/fixtures/section_map_node_reference.gd")

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
		var button: Button = OriginalNode.new()
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

