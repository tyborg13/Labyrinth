extends Control
class_name SectionMapPanel

const Specials = preload("res://scripts/special_encounter_library.gd")
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
const Palette = preload("res://scripts/ui_palette.gd")

signal room_selected(coord: Vector2i)
signal scout_requested(coord: Vector2i)
signal door_requested(coord: Vector2i)
signal event_requested(choice: String)
signal interaction_changed
signal close_requested

const BACKGROUND_MODULATE := Color(0.56, 0.54, 0.59)

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
var _close: Button
var _legacy: Control
var _layout: VBoxContainer
var _field: Control
var _boss_legend_icon: Control
var _legend: Control
var _legend_types: Array[String]
const LEGEND_ORDER: Array = ["combat", "special_warband", "special_umbral_snare", "special_ember_hoarder", "special_last_light", "guardian", "event", "scavenger", "graftwright", "treasure", "campfire", "boss", "unknown"]
const LEGEND_MAX_GAP: float = 40.0
const LEGEND_MIN_GAP: float = 12.0
var scout_targeting: bool = false
var _scout_hint: Label
var _preview: PanelContainer
var _preview_text: String = ""
var _reduced_motion: bool = false
var activation_coord: Vector2i = Graph.INVALID
var _activation_kind: String = ""
var _activation_generation: int = 0
var _activation_tween: Tween
const ACTIVATION_SECONDS: float = 0.28
const REDUCED_ACTIVATION_SECONDS: float = 0.14
# Revision 7 sections scroll sideways (map-03, owner-approved mockup 2026-10-21):
# rooms keep their size, columns get 240 px, and the painting drifts at 0.3x.
const SCROLL_COLUMN: float = 240.0
const SCROLL_START_X: float = 112.0
const SCROLL_FIRST_STEP_X: float = 320.0
const SCROLL_BOSS_GAP: float = 190.0
const SCROLL_END_MARGIN: float = 128.0
const SCROLL_TOP: float = 72.0
const SCROLL_BOTTOM: float = 96.0
const SCROLL_STAGGER: float = 22.0
const SCROLL_JITTER: Vector2 = Vector2(10, 6)
const SCROLL_NODE_GAP: float = 10.0
const SCROLL_FOCUS_FRACTION: float = 0.38
const SCROLL_KEEP_VISIBLE_MARGIN: float = 150.0
const SCROLL_PARALLAX: float = 0.3
const SCROLL_WHEEL_STEP: float = 170.0
const SCROLL_PAN_GESTURE_STEP: float = 26.0
const SCROLL_STICK_SPEED: float = 1150.0
const SCROLL_STICK_DEADZONE: float = 0.22
const SCROLL_DRAG_THRESHOLD: float = 6.0
const SCROLL_SETTLE_SECONDS: float = 0.32
const SCROLL_EDGE_FADE: float = 104.0
const SCROLL_TRACK_WIDTH: float = 420.0
const SCROLL_TRACK_HEIGHT: float = 6.0
const SCROLL_TRACK_INSET: float = 22.0
const LANTERN_WALK_SECONDS: float = 0.62
var _world: Control
var _token: Control
var _scroll_overlay: Control
var _scroll: float = 0.0
var _scroll_max: float = 0.0
var _scroll_world_width: float = 0.0
var _scroll_tween: Tween
var _scroll_anchor: String = ""
var _drag_pressed: bool = false
var _drag_active: bool = false
var _drag_released: bool = false
var _drag_origin: float = 0.0
var _drag_scroll: float = 0.0
var _fog_openings := PackedVector4Array()

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
	_background.modulate = BACKGROUND_MODULATE
	_full_field(_background)
	_fog = ColorRect.new()
	_fog.name = "DynamicFog"
	var material := ShaderMaterial.new()
	material.shader = Fog
	_fog.material = material
	_full_field(_fog)
	# Known topology remains legible over fog. Only revealed/outlined endpoints
	# enter the canvas, so this never draws a route to an undiscovered room.
	# The world holds the trails and rooms. It fills the field, and in a
	# scrolling section it is wider and slides left as the map scrolls.
	_world = Control.new()
	_world.name = "MapWorld"
	_full_field(_world)
	_canvas = Canvas.new()
	_canvas.name = "Connections"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_canvas)
	_nodes = Control.new()
	_nodes.name = "RoomNodes"
	_nodes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_nodes)
	_token = Control.new()
	_token.name = "LanternWalk"
	_token.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_token.draw.connect(func() -> void: _canvas.call("draw_lantern_token", _token))
	_world.add_child(_token)
	_scroll_overlay = Control.new()
	_scroll_overlay.name = "ScrollCues"
	_full_field(_scroll_overlay)
	_scroll_overlay.draw.connect(_draw_scroll_cues)
	_field.gui_input.connect(_on_field_input)
	var footer: PanelContainer = _panel()
	_layout.add_child(footer)
	var legend_row := HBoxContainer.new()
	legend_row.add_theme_constant_override("separation", 24)
	footer.add_child(legend_row)
	_legend = _build_legend()
	var legend: Control = _legend
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

# The section transition matches the live cover-fit rectangle, including the
# current header/footer and outer-frame layout, rather than duplicating it.
func transition_backdrop() -> TextureRect:
	return _background

func _build_legend() -> Control:
	var legend := Control.new()
	legend.name = "MapLegend"
	legend.custom_minimum_size.y = 48
	legend.resized.connect(_layout_legend)
	return legend

func _refresh_legend() -> void:
	var present: Dictionary = {}
	if int(run_state.get("section_map_layout_revision", 0)) >= 6:
		for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
			if int(node.get("section_index", -1)) != viewed_section: continue
			var type: String = str(node.get("type", ""))
			if type == "special": type = "special_" + str(node.get("special_type", ""))
			if type == "mystery": type = "unknown"
			present[type] = true
	else:
		for type: String in LEGEND_ORDER:
			if not type.begins_with("special_"): present[type] = true
	var types: Array[String]
	for type: String in LEGEND_ORDER:
		if present.has(type): types.append(type)
	if types != _legend_types:
		for child: Node in _legend.get_children():
			_legend.remove_child(child)
			child.queue_free()
		_legend_types = types
		for type: String in types: _add_legend_item(type)
	if is_instance_valid(_boss_legend_icon):
		_boss_legend_icon.set_meta("room_icon_id", "boss_" + str(Graph.section(run_state, viewed_section).get("boss_id", "tharokh")))
		_boss_legend_icon.queue_redraw()
	_layout_legend.call_deferred()

func _add_legend_item(type: String) -> void:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	_legend.add_child(item)
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

# Keep a single row until the exact measured native labels cannot fit with
# 12px gaps. Splitting balances the two centred rows without shrinking text.
func _layout_legend() -> void:
	if not is_instance_valid(_legend) or _legend.get_child_count() == 0: return
	var widths: Array[float]
	var total: float = 0.0
	for item: Control in _legend.get_children():
		widths.append(item.get_combined_minimum_size().x)
		total += widths.back()
	var split: int = widths.size()
	if total + LEGEND_MIN_GAP * (widths.size() - 1) > _legend.size.x:
		var best: float = INF
		for candidate: int in range(1, widths.size()):
			var left: float = LEGEND_MIN_GAP * (candidate - 1)
			var right: float = LEGEND_MIN_GAP * (widths.size() - candidate - 1)
			for index: int in range(widths.size()):
				if index < candidate: left += widths[index]
				else: right += widths[index]
			if maxf(left, right) < best:
				best = maxf(left, right)
				split = candidate
	var rows: int = 1 if split == widths.size() else 2
	_legend.custom_minimum_size.y = 48.0 * rows
	for row: int in range(rows):
		var first: int = 0 if row == 0 else split
		var end: int = split if row == 0 else widths.size()
		var sum: float = 0.0
		for index: int in range(first, end): sum += widths[index]
		var gaps: int = end - first - 1
		var gap: float = clampf((_legend.size.x - sum) / maxi(1, gaps), LEGEND_MIN_GAP, LEGEND_MAX_GAP)
		var x: float = (_legend.size.x - sum - gap * gaps) * 0.5
		for index: int in range(first, end):
			var item: Control = _legend.get_child(index)
			item.position = Vector2(x, row * 48.0)
			item.size = Vector2(widths[index], 48)
			x += widths[index] + gap

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
	run_state = {"rooms": source.get("rooms", {}), "map_sections": source.get("map_sections", []), "current_room": source.get("current_room", Vector2i.ZERO), "mode": source.get("mode", "room"), "section_map_version": source.get("section_map_version", 0), "seed": source.get("seed", 0), "section_map_layout_revision": source.get("section_map_layout_revision", Graph.section(source, 0).get("lane_count", 0)), "reach_exit": str(objective.get("type", "")) == "reach_exit"}
	if previous_current != run_state.get("current_room", Graph.INVALID):
		viewed_section = Graph.active_section(run_state)
		reset_interaction()
		if _canvas != null:
			_canvas.set("travel_progress", 0.0)
			_token.queue_redraw()
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
	_refresh_legend()
	var visited: int = 0
	for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == viewed_section and bool(node.get("visited", false)) and str(node.get("type", "")) != "start":
			visited += 1
	_progress.text = "SECTION %s / VI  ·  %d / %d ROOMS EXPLORED%s" % [_roman(viewed_section), visited, int(info.get("room_count", 11)), "  ·  HISTORY" if viewed_section < Graph.active_section(run_state) else ""]
	# Tabs are a fixed six-control surface. Refresh their current state instead
	# of discarding native controls and their complete theme notifications.
	if _tabs.get_child_count() == 0:
		for index: int in range(6):
			var tab := TooltipButton.new()
			tab.text = _roman(index)
			tab.pressed.connect(select_section.bind(index))
			tab.focus_entered.connect(interaction_changed.emit)
			tab.name = "Section%d" % (index + 1)
			tab.custom_minimum_size = Vector2(62, 62)
			tab.toggle_mode = true
			MapSkin.section_tab(tab)
			_tabs.add_child(tab)
	for index: int in range(6):
		var tab: Button = _tabs.get_child(index) as Button
		tab.button_pressed = index == viewed_section
		tab.disabled = index > Graph.active_section(run_state)
		tab.tooltip_text = str(Graph.section(run_state, index).get("title", "")) if not tab.disabled else "Unreached section"
		tab.focus_neighbor_bottom = NodePath("")
	_background.texture = Assets.load_texture("res://assets/art/backgrounds/sections/%s.png" % str(info.get("boss_id", "tharokh")))
	_layout_nodes()
	_refresh_actions()
	if selected_coord != Graph.INVALID and node_buttons.has(selected_coord):
		_show_preview(selected_coord)

func available_destinations() -> Array[Vector2i]:
	var result: Array[Vector2i]
	var current: Dictionary = Graph.room(run_state, run_state.get("current_room", Vector2i.ZERO))
	for link: Dictionary in current.get("connections", []):
		var coord: Vector2i = link.get("coord", Graph.INVALID)
		var node: Dictionary = Graph.room(run_state, coord)
		if bool(node.get("revealed", false)) and not bool(node.get("sealed", false)):
			result.append(coord)
	return result

func select_section(index: int) -> void:
	if index < 0 or index > Graph.active_section(run_state):
		return
	# Like set_run_state, history selection may arrive before _ready builds the
	# controls. Retain it for _ready's refresh without touching unbuilt tabs.
	if not _built:
		viewed_section = index
		reset_interaction()
		return
	var restore_tab_focus: bool = false
	for tab: Control in _tabs.get_children():
		restore_tab_focus = restore_tab_focus or tab.has_focus()
	viewed_section = index
	reset_interaction()
	_refresh()
	# Keep native focus on the chosen reached section for keyboard/controller
	# navigation after switching history.
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
	var current: Vector2i = run_state.get("current_room", Graph.INVALID)
	# On a scrolling map the lantern walks the trail to the chosen room first.
	var walking: bool = _activation_kind == "room" and bool(_canvas.get("ink")) and not _reduced_motion and node_buttons.has(current) and button != null
	if walking: seconds = LANTERN_WALK_SECONDS
	if button != null:
		button.call("set_activation_progress", 0.001)
		_activation_tween = button.create_tween()
		_activation_tween.tween_method(Callable(button, "set_activation_progress"), 0.001, 1.0, seconds)
	if walking:
		(node_buttons[current] as Control).set("lantern_marker", false)
		(node_buttons[current] as Control).queue_redraw()
		_canvas.set("travel_from", current)
		_canvas.set("travel_to", coord)
		_activation_tween.parallel().tween_method(_set_travel_progress, 0.001, 1.0, seconds)
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
	# The timer can fire before the tween's last step; the walk has arrived.
	if walking: _set_travel_progress(1.0)
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

func _set_travel_progress(progress: float) -> void:
	_canvas.set("travel_progress", progress)
	_token.queue_redraw()

func _cancel_activation() -> void:
	_activation_generation += 1
	if _activation_tween != null:
		_activation_tween.kill()
		_activation_tween = null
	# A finished walk keeps the lantern at its destination until the run moves
	# there; an interrupted one puts it back.
	if _canvas != null and float(_canvas.get("travel_progress")) > 0.0 and float(_canvas.get("travel_progress")) < 1.0:
		_set_travel_progress(0.0)
		var walker: Control = node_buttons.get(_canvas.get("travel_from"))
		if is_instance_valid(walker):
			walker.set("lantern_marker", true)
			walker.queue_redraw()
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
	var remaining: Dictionary = node_buttons.duplicate()
	var retained: Dictionary = {}
	var info: Dictionary = Graph.section(run_state, viewed_section)
	var available: Array[Vector2i] = available_destinations()
	var future: Dictionary = Graph.descendants(run_state, run_state.get("current_room", Graph.INVALID))
	var positions: Dictionary = {}
	var openings := PackedVector4Array()
	var scrolling: bool = bool(info.get("scroll", false)) and Graph.modern(run_state)
	var world_positions: Dictionary = section_positions(run_state.get("rooms", {}), info, _field.size) if scrolling else {}
	_configure_world(scrolling, info)
	for node: Dictionary in (run_state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) != viewed_section or not (bool(node.get("revealed", false)) or bool(node.get("map_outline", false)) or _has_recovery(node)):
			continue
		var coord: Vector2i = node.get("coord", Graph.INVALID)
		var point: Vector2 = world_positions.get(coord, Vector2.ZERO) if scrolling else _node_position(node, info, _field.size, Graph.modern(run_state))
		positions[coord] = point
		var button: Button = remaining.get(coord) as Button
		var created: bool = button == null
		if created:
			button = NodeButton.new()
			button.name = "Room_%s" % Graph.key(coord).replace("-", "n").replace(",", "_")
		remaining.erase(coord)
		var extent: float = 106.0 if str(node.get("type", "")) == "boss" else 61.0
		button.position = point - Vector2.ONE * extent
		button.size = Vector2.ONE * extent * 2.0
		var state: String = _node_route_state(node, available, future)
		button.call("configure", node, _room_label(node), state, _reduced_motion)
		button.set("modern_layout", Graph.modern(run_state))
		button.set("round_hit", scrolling)
		button.set("lantern_marker", scrolling)
		button.set("scout_target", scout_targeting and can_activate_room(coord))
		button.set("actionable", can_activate_room(coord))
		button.call("refresh_state")
		if created:
			button.pressed.connect(_on_room_pressed.bind(coord))
			button.gui_input.connect(_on_room_input.bind(button))
			button.focus_entered.connect(_show_preview.bind(coord))
			button.focus_entered.connect(_keep_room_visible.bind(coord))
			button.focus_exited.connect(_hide_preview_for.bind(coord))
			button.mouse_entered.connect(_show_preview.bind(coord))
			button.mouse_exited.connect(_hide_preview_for.bind(coord))
			_nodes.add_child(button)
		if button.get_index() != retained.size(): _nodes.move_child(button, retained.size())
		retained[coord] = button
		var known: bool = bool(node.get("revealed", false)) or _has_recovery(node)
		openings.append(Vector4(point.x, point.y, 0.081 if known else 0.045, 0.21 if known else 0.11))
	# Keep only the displayed section's known nodes; section switches and lost
	# outlines remove stale controls, so retention remains bounded by this view.
	for stale: Control in remaining.values():
		_nodes.remove_child(stale)
		stale.queue_free()
	node_buttons = retained
	_refresh_route_radii()
	_wire_choice_focus()
	if focused_coord != Graph.INVALID and node_buttons.has(focused_coord):
		(node_buttons[focused_coord] as Control).grab_focus()
		_show_preview(focused_coord)
	_fog_openings = openings
	_fog.visible = not Graph.full_visibility(run_state, viewed_section)
	var unknown_legend: Control = find_child("Legend_unknown", true, false)
	if unknown_legend != null:
		(unknown_legend.get_parent().get_child(1) as Label).text = "Unknown room" if Graph.modern(run_state) else "Unknown"
	_canvas.set("ink", scrolling)
	_canvas.set("state", run_state)
	_canvas.set("positions", positions)
	_canvas.set("section_index", viewed_section)
	_canvas.set("selected", selected_coord)
	_canvas.queue_redraw()
	if scrolling:
		var anchor: String = "%d|%s" % [viewed_section, Graph.key(run_state.get("current_room", Graph.INVALID))]
		if anchor != _scroll_anchor:
			_scroll_anchor = anchor
			_set_scroll(_focus_scroll(world_positions, info), false)
		else:
			_set_scroll(_scroll, false)
	else:
		_scroll_anchor = ""
		_set_scroll(0.0, false)
	# Retained hovered nodes do not re-emit mouse_entered on a resize. Keep the
	# existing optional preview beside its node after deferred layout settles.
	if selected_coord != Graph.INVALID and node_buttons.has(selected_coord) and is_instance_valid(_preview):
		_position_preview.call_deferred(selected_coord)

static func _node_jitter(coord: Vector2i) -> Vector2:
	var coord_hash: int = hash(coord)
	return Vector2(coord_hash % 33 - 16, (coord_hash >> 8) % 25 - 12)

# Revision 5 reserves the approved final 175px for the boss, leaving its centre
# fixed. Earlier revisions retain their original column spacing and jitter.
const NODE_BUTTON_EXTENT: float = 61.0
const NODE_BUTTON_GAP: float = 8.0
const BOSS_COLUMN_SEPARATION: float = 175.0

static func _node_position(node: Dictionary, info: Dictionary, field_size: Vector2, modern_layout: bool) -> Vector2:
	var count: int = int(info.get("room_count", 11))
	var lanes: int = int(info.get("lane_count", 3))
	var lane_divisor: float = float(lanes - 1)
	var x_step: float = (field_size.x - 204) / float(count)
	var y_step: float = (field_size.y - 232) / lane_divisor
	var point := Vector2(80 + (field_size.x - 204) * float(node.get("map_step", 0)) / float(count), 116 + (field_size.y - 232) * float(node.get("map_lane", 1)) / lane_divisor)
	var step: int = int(node.get("map_step", 0))
	if lanes == 5 and step < count:
		var boss_x: float = 80 + (field_size.x - 204)
		x_step = (boss_x - BOSS_COLUMN_SEPARATION - 80) / float(count - 1)
		point.x = 80 + x_step * float(step)
	if modern_layout and str(node.get("type", "")) not in ["start", "boss"]:
		var jitter: Vector2 = _node_jitter(node.get("coord", Graph.INVALID))
		if lanes == 5:
			var x_limit: float = maxf(0.0, (x_step - NODE_BUTTON_EXTENT * 2.0 - NODE_BUTTON_GAP) * 0.5)
			var y_limit: float = maxf(0.0, (y_step - NODE_BUTTON_EXTENT * 2.0 - NODE_BUTTON_GAP) * 0.5)
			jitter.x = clampf(jitter.x, -x_limit, x_limit)
			if step == count - 1: jitter.x = minf(jitter.x, 0.0)
			jitter.y = clampf(jitter.y, -y_limit, y_limit)
		point += jitter
	return point

# --- Revision 7 scrolling ---------------------------------------------------

# World positions for a scrolling section. Odd lanes sit a little right and even
# lanes a little left, so neighbouring lanes stagger instead of stacking, and
# two rooms in a column never touch even at their largest (an actionable
# Guardian beside an enlarged choice).
static func section_positions(rooms: Dictionary, info: Dictionary, field_size: Vector2) -> Dictionary:
	var index: int = int(info.get("index", 0))
	var count: int = int(info.get("room_count", 11))
	var lanes: int = int(info.get("lane_count", 7))
	var span: float = maxf(1.0, field_size.y - SCROLL_TOP - SCROLL_BOTTOM)
	var columns: Dictionary = {}
	var result: Dictionary = {}
	var radii: Dictionary = {}
	for node: Dictionary in rooms.values():
		if int(node.get("section_index", -1)) != index: continue
		var coord: Vector2i = node.get("coord", Graph.INVALID)
		var type: String = str(node.get("type", ""))
		var lane: float = float(node.get("map_lane", float(lanes - 1) * 0.5))
		var step: int = int(node.get("map_step", 0))
		var point := Vector2(_scroll_column_x(step, count, type), SCROLL_TOP + span * lane / float(maxi(1, lanes - 1)))
		radii[coord] = NodeButton.max_visual_radius(node)
		if type not in ["start", "boss"]:
			var jitter: Vector2 = _node_jitter(coord)
			var stagger: float = SCROLL_STAGGER if roundi(lane) % 2 == 1 else -SCROLL_STAGGER
			point += Vector2(stagger + clampf(jitter.x, -SCROLL_JITTER.x, SCROLL_JITTER.x), clampf(jitter.y, -SCROLL_JITTER.y, SCROLL_JITTER.y))
			if not columns.has(step): columns[step] = []
			columns[step].append(coord)
		result[coord] = point
	for step: int in columns:
		var cells: Array = columns[step]
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (result[a] as Vector2).y < (result[b] as Vector2).y)
		for offset: int in range(1, cells.size()):
			var upper: Vector2i = cells[offset - 1]
			var lower: Vector2i = cells[offset]
			var need: float = float(radii[upper]) + float(radii[lower]) + SCROLL_NODE_GAP
			var delta: Vector2 = (result[lower] as Vector2) - (result[upper] as Vector2)
			if delta.length() >= need or absf(delta.y) >= need: continue
			var spread: float = (sqrt(need * need - delta.y * delta.y) - absf(delta.x)) * 0.5
			var side: float = 1.0 if delta.x >= 0.0 else -1.0
			result[upper] = (result[upper] as Vector2) - Vector2(side * spread, 0.0)
			result[lower] = (result[lower] as Vector2) + Vector2(side * spread, 0.0)
	return result

static func _scroll_column_x(step: int, count: int, type: String) -> float:
	if type == "start": return SCROLL_START_X
	if type == "boss": return SCROLL_FIRST_STEP_X + float(count - 2) * SCROLL_COLUMN + SCROLL_BOSS_GAP
	return SCROLL_FIRST_STEP_X + float(step - 1) * SCROLL_COLUMN

static func scroll_world_width(info: Dictionary, field_size: Vector2) -> float:
	var boss_x: float = _scroll_column_x(0, int(info.get("room_count", 11)), "boss")
	return maxf(field_size.x, boss_x + NodeButton.max_visual_radius({"type": "boss"}) + SCROLL_END_MARGIN)

func _configure_world(scrolling: bool, info: Dictionary) -> void:
	if scrolling:
		_scroll_world_width = scroll_world_width(info, _field.size)
		_scroll_max = maxf(0.0, _scroll_world_width - _field.size.x)
		_world.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_world.size = Vector2(_scroll_world_width, _field.size.y)
		# The painting is wider than the field by its parallax share of the scroll.
		_background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_background.size = Vector2(_field.size.x + _scroll_max * SCROLL_PARALLAX, _field.size.y)
	else:
		_scroll_world_width = _field.size.x
		_scroll_max = 0.0
		_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# The current room sits a little left of centre so its choices show ahead.
func _focus_scroll(world_positions: Dictionary, _info: Dictionary) -> float:
	var current: Vector2i = run_state.get("current_room", Graph.INVALID)
	var x: float = (world_positions[current] as Vector2).x if world_positions.has(current) else SCROLL_START_X
	return x - _field.size.x * SCROLL_FOCUS_FRACTION

func scroll_offset() -> float:
	return _scroll

func scroll_limit() -> float:
	return _scroll_max

func scroll_to(value: float, animate: bool = false) -> void:
	_set_scroll(value, animate)

func _set_scroll(value: float, animate: bool) -> void:
	var target: float = clampf(value, 0.0, _scroll_max)
	if _scroll_tween != null:
		_scroll_tween.kill()
		_scroll_tween = null
	if animate and not _reduced_motion and is_inside_tree() and absf(target - _scroll) > 1.0:
		_scroll_tween = create_tween()
		_scroll_tween.tween_method(_apply_scroll, _scroll, target, SCROLL_SETTLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_apply_scroll(target)

func _apply_scroll(value: float) -> void:
	_scroll = clampf(value, 0.0, _scroll_max)
	if _world == null: return
	_world.position = Vector2(-_scroll, 0.0)
	if _scroll_max > 0.0: _background.position = Vector2(-_scroll * SCROLL_PARALLAX, 0.0)
	_update_fog()
	_scroll_overlay.queue_redraw()
	if selected_coord != Graph.INVALID and is_instance_valid(_preview): _position_preview(selected_coord)

func _update_fog() -> void:
	# The shader holds 32 openings; rooms on screen take precedence.
	var visible_openings := PackedVector4Array()
	var hidden_openings := PackedVector4Array()
	for opening: Vector4 in _fog_openings:
		var screen := Vector4((opening.x - _scroll) / _field.size.x, opening.y / _field.size.y, opening.z, opening.w)
		if screen.x > -0.1 and screen.x < 1.1: visible_openings.append(screen)
		else: hidden_openings.append(screen)
	visible_openings.append_array(hidden_openings)
	var opening_count: int = mini(32, visible_openings.size())
	visible_openings.resize(32)
	var material := _fog.material as ShaderMaterial
	material.set_shader_parameter("openings", visible_openings)
	material.set_shader_parameter("opening_count", opening_count)
	material.set_shader_parameter("motion", 0.0)

func _on_field_input(event: InputEvent) -> void:
	if _scroll_input(event): _field.accept_event()

# Room buttons stop the pointer, so they forward it: the wheel and drags scroll
# the map from anywhere, and a press that became a drag never commits travel.
func _on_room_input(event: InputEvent, button: Control) -> void:
	if _scroll_input(event): button.accept_event()

func _on_room_pressed(coord: Vector2i) -> void:
	if _drag_released: return
	activate_room(coord)

# Keys and pads reach the panel before the focused room, so an activation in
# the same frame as a drag's release is never mistaken for that release.
func _input(event: InputEvent) -> void:
	if _drag_released and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction): _drag_released = false

func _scroll_input(event: InputEvent) -> bool:
	if _scroll_max <= 0.0: return false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var factor: float = button.factor if button.factor > 0.0 else 1.0
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			_set_scroll(_scroll + SCROLL_WHEEL_STEP * factor, true)
			return true
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			_set_scroll(_scroll - SCROLL_WHEEL_STEP * factor, true)
			return true
		if button.button_index == MOUSE_BUTTON_LEFT:
			# The release that ends a drag reaches the room button after this
			# handler; the flag swallows only that one press.
			if not button.pressed and _drag_active:
				_drag_released = true
				set_deferred("_drag_released", false)
			_drag_pressed = button.pressed
			_drag_active = false
			_drag_origin = button.global_position.x
			_drag_scroll = _scroll
	elif event is InputEventMouseMotion and _drag_pressed:
		var moved: float = (event as InputEventMouseMotion).global_position.x - _drag_origin
		_drag_active = _drag_active or absf(moved) >= SCROLL_DRAG_THRESHOLD
		if _drag_active:
			_set_scroll(_drag_scroll - moved, false)
			return true
	elif event is InputEventPanGesture:
		_set_scroll(_scroll + (event as InputEventPanGesture).delta.x * SCROLL_PAN_GESTURE_STEP, false)
		return true
	return false

func _process(delta: float) -> void:
	# The right stick pans freely; the left stick and arrows move focus, and the
	# map follows the focused room.
	if _scroll_max <= 0.0 or not is_visible_in_tree(): return
	var axis: float = 0.0
	for device: int in Input.get_connected_joypads():
		var value: float = Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
		if absf(value) > absf(axis): axis = value
	if absf(axis) < SCROLL_STICK_DEADZONE: return
	var strength: float = (absf(axis) - SCROLL_STICK_DEADZONE) / (1.0 - SCROLL_STICK_DEADZONE)
	_set_scroll(_scroll + signf(axis) * strength * SCROLL_STICK_SPEED * delta, false)

func _keep_room_visible(coord: Vector2i) -> void:
	if _scroll_max <= 0.0 or not node_buttons.has(coord): return
	var button: Control = node_buttons[coord]
	var x: float = button.position.x + button.size.x * 0.5
	if x < _scroll + SCROLL_KEEP_VISIBLE_MARGIN:
		_set_scroll(x - SCROLL_KEEP_VISIBLE_MARGIN, true)
	elif x > _scroll + _field.size.x - SCROLL_KEEP_VISIBLE_MARGIN:
		_set_scroll(x - _field.size.x + SCROLL_KEEP_VISIBLE_MARGIN, true)

# Edge fades show there is more map that way; a slim track shows where you are.
func _draw_scroll_cues() -> void:
	if _scroll_max <= 0.0: return
	var area: Vector2 = _field.size
	var dark := Color(Palette.INK_0, 0.74)
	var clear := Color(Palette.INK_0, 0.0)
	if _scroll > 0.5:
		_scroll_overlay.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(SCROLL_EDGE_FADE, 0), Vector2(SCROLL_EDGE_FADE, area.y), Vector2(0, area.y)]), PackedColorArray([dark, clear, clear, dark]))
	if _scroll < _scroll_max - 0.5:
		_scroll_overlay.draw_polygon(PackedVector2Array([Vector2(area.x - SCROLL_EDGE_FADE, 0), Vector2(area.x, 0), Vector2(area.x, area.y), Vector2(area.x - SCROLL_EDGE_FADE, area.y)]), PackedColorArray([clear, dark, dark, clear]))
	var track := Rect2(Vector2((area.x - SCROLL_TRACK_WIDTH) * 0.5, area.y - SCROLL_TRACK_INSET - SCROLL_TRACK_HEIGHT), Vector2(SCROLL_TRACK_WIDTH, SCROLL_TRACK_HEIGHT))
	_draw_pill(track.grow(1.5), Color(Palette.LINE, 0.9))
	_draw_pill(track, Color(Palette.INK_0, 0.86))
	var thumb_width: float = maxf(40.0, SCROLL_TRACK_WIDTH * area.x / _scroll_world_width)
	var thumb := Rect2(Vector2(track.position.x + (SCROLL_TRACK_WIDTH - thumb_width) * (_scroll / _scroll_max), track.position.y), Vector2(thumb_width, SCROLL_TRACK_HEIGHT))
	_draw_pill(thumb, Palette.GOLD)

func _draw_pill(rect: Rect2, color: Color) -> void:
	var radius: float = rect.size.y * 0.5
	_scroll_overlay.draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(maxf(0.0, rect.size.x - rect.size.y), rect.size.y)), color)
	_scroll_overlay.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	_scroll_overlay.draw_circle(rect.end - Vector2(radius, radius), radius, color)

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
	if bool(node.get("revealed", false)) and str(node.get("type", "")) == "graftwright":
		detail = "Inherit an equipment card · " + detail
	if str(node.get("type","")) == "guardian" and bool(node.get("revealed",false)):
		var guardian: Dictionary = preload("res://scripts/guardian_library.gd").for_guardian(str(node.get("guardian_id","")))
		return "%s · Guardian combat\n%s" % [guardian.get("name","Guardian"),detail]
	if str(node.get("type", "")) == "special" and bool(node.get("revealed", false)):
		return Specials.display_name(node) + "\n" + Specials.tooltip_line(node) + "\n" + detail
	return _room_label(node) + "\n" + detail

func _show_preview(coord: Vector2i) -> void:
	if activation_coord != Graph.INVALID or not node_buttons.has(coord): return
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
	var center: Vector2 = button.position + button.size * 0.5 + _world.position
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
	for coord: Vector2i in node_buttons:
		var button: Button = node_buttons[coord]
		button.set("scout_target", scout_targeting and can_activate_room(coord))
		button.set("actionable", can_activate_room(coord))
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.call("refresh_state")
	_refresh_route_radii()
	_wire_choice_focus()
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
	if viewed_section != Graph.active_section(run_state): return
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
	if focused == _close: return "Close"
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

func _has_recovery(node: Dictionary) -> bool:
	return bool(node.get("recovery_marker", false)) and int(node.get("recovery_amount", 0)) > 0

func event_has_discoveries() -> bool:
	for coord: Vector2i in Graph.descendants(run_state, run_state.get("current_room", Vector2i.ZERO), 4):
		if not bool(Graph.room(run_state, coord).get("revealed", false)):
			return true
	return false

func _room_label(node: Dictionary) -> String:
	if str(node.get("type", "")) == "mystery":
		return "Unknown room · " + _type_label(Graph.display_type(node)) if bool(node.get("scouted", false)) else "Unknown room"
	if not bool(node.get("revealed", false)):
		return "Unknown"
	if str(node.get("type", "")) == "special": return Specials.display_name(node)
	if str(node.get("type", "")) == "guardian":
		return str(preload("res://scripts/guardian_library.gd").for_guardian(str(node.get("guardian_id", ""))).get("name","Guardian"))
	if str(node.get("type", "")) == "boss":
		return str(node.get("boss_id", "Boss")).capitalize()
	return _type_label(str(node.get("type", "")))

func _type_label(type: String) -> String:
	if type.begins_with("special_"): return str(Specials.definition(type.trim_prefix("special_")).get("name", "ERROR_MISSING_SPECIAL_NAME"))
	return {"combat": "Standard combat", "guardian": "Guardian combat", "event": "Event", "scavenger": "Scavenger", "graftwright": "Graftwright", "treasure": "Relic", "campfire": "Ember Hearth", "boss": "Boss", "start": "Threshold", "unknown": "Unknown"}.get(type, "Room")

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
	else:
		var choices: Array[Vector2i] = _choice_destinations()
		# At a section threshold the approved first focus is the lowest lane.
		# Other rooms retain their established connection ordering.
		if not scout_targeting and str(Graph.room(run_state, run_state.get("current_room", Graph.INVALID)).get("type", "")) == "start":
			choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return float(Graph.room(run_state, a).get("map_lane", 0)) < float(Graph.room(run_state, b).get("map_lane", 0)))
		for coord: Vector2i in choices:
			if node_buttons.has(coord) and (not scout_targeting or can_activate_room(coord)):
				(node_buttons[coord] as Control).grab_focus()
				return
		_close.grab_focus()

func begin_travel_animation(from: Vector2i, to: Vector2i) -> bool:
	if not Graph.enabled(run_state):
		return bool(_legacy.call("begin_travel_animation", from, to))
	return false
