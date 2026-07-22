extends HBoxContainer
class_name SkillTreeView

const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

signal skill_focused(skill_id: String)
signal pending_changed(skill_ids: Array)
signal level_up_choice_changed(skill_id: String)
signal respec_draft_changed(skill_ids: Array)
signal confirm_requested(skill_ids: Array)
signal cancel_requested()

const MODE_VIEW: String = "view"
const MODE_LEVEL_UP: String = "level_up"
const MODE_RESPEC: String = "respec"

const STATE_OWNED: String = "owned"
const STATE_AVAILABLE: String = "available"
const STATE_LOCKED: String = "locked"
const STATE_PENDING: String = "pending"
const STATE_EXCLUDED: String = "excluded"
const STATE_SELECTED: String = "selected"

const GRAPH_SIZE: Vector2 = Vector2(730.0, 350.0)
const DETAIL_WIDTH: float = 300.0
const ROOT_SIZE: Vector2 = Vector2(56.0, 56.0)
const BRANCH_SIZE: Vector2 = Vector2(52.0, 52.0)
const JUNCTION_SIZE: Vector2 = Vector2(56.0, 56.0)
const KEYSTONE_SIZE: Vector2 = Vector2(64.0, 64.0)
const LINK_NODE_CLEARANCE: float = 3.0

const BRANCH_COLORS: Dictionary = {
	"tactics": Color("d7a85d"),
	"resolve": Color("d17a72"),
	"traverse": Color("79b9a5"),
	"foresight": Color("b994d0"),
	"keystone": Color("e5cf9b"),
}

class SkillLinkLayer:
	extends Control

	var links: Array[Dictionary]

	func set_links(value: Array[Dictionary]) -> void:
		links.clear()
		for link: Dictionary in value:
			links.append(link.duplicate(true))
		queue_redraw()

	func _draw() -> void:
		var ordered_links: Array[Dictionary]
		for link: Dictionary in links:
			if not bool(link.get("highlighted", false)):
				ordered_links.append(link)
		for link: Dictionary in links:
			if bool(link.get("highlighted", false)):
				ordered_links.append(link)
		for link: Dictionary in ordered_links:
			var points: PackedVector2Array = link.get("points", PackedVector2Array())
			if points.size() < 2:
				continue
			var color: Color = link.get("color", Color("4a434d"))
			var width: float = float(link.get("width", 3.0))
			var under_color := Color(0.025, 0.02, 0.027, 0.95)
			if bool(link.get("highlighted", false)):
				var glow := color
				glow.a = 0.20
				draw_polyline(points, glow, width + 8.0, true)
			draw_polyline(points, under_color, width + 3.0, true)
			draw_polyline(points, color, width, true)
			for point_index: int in range(1, points.size() - 1):
				draw_circle(points[point_index], width * 0.5, color, true, -1.0, true)
			draw_circle(points[0], width * 0.9 + 1.0, under_color, true, -1.0, true)
			draw_circle(points[0], width * 0.65, color, true, -1.0, true)
			draw_circle(points[points.size() - 1], width * 0.9 + 1.0, under_color, true, -1.0, true)
			draw_circle(points[points.size() - 1], width * 0.65, color, true, -1.0, true)

class SkillNodeFace:
	extends Control

	var tier: String = "branch"
	var state: String = "locked"
	var relationship: String = "none"
	var selected: bool = false
	var branch_color: Color = Color("b99a6b")
	var icon_texture: Texture2D

	func configure(
		next_tier: String,
		next_state: String,
		next_relationship: String,
		next_selected: bool,
		next_branch_color: Color,
		next_icon: Texture2D
	) -> void:
		tier = next_tier
		state = next_state
		relationship = next_relationship
		selected = next_selected
		branch_color = next_branch_color
		icon_texture = next_icon
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 4.0
		var state_color: Color = _face_state_color(state)
		var fill: Color = _face_fill_color(state)
		var outline_width: float = 3.0 if state != "locked" else 2.0
		if selected or relationship != "none":
			var halo_color := Color("fff4d8")
			if relationship == "prerequisite":
				halo_color = Color("ffd47a")
			elif relationship == "dependent":
				halo_color = Color("8ce1d5")
			draw_arc(center, radius + 4.5, 0.0, TAU, 40, Color(0.02, 0.015, 0.02, 0.94), 6.0, true)
			draw_arc(center, radius + 4.5, 0.0, TAU, 40, halo_color, 2.5, true)
		_draw_node_shadow(center, radius)
		match tier:
			"root":
				draw_circle(center, radius, fill, true, -1.0, true)
				draw_arc(center, radius, 0.0, TAU, 40, state_color, outline_width, true)
			"junction":
				var diamond := _diamond_points(center, radius)
				draw_colored_polygon(diamond, fill)
				draw_polyline(_closed_points(diamond), state_color, outline_width, true)
			"keystone":
				var hexagon := _hexagon_points(center, radius)
				draw_colored_polygon(hexagon, fill)
				draw_polyline(_closed_points(hexagon), state_color, outline_width + 1.0, true)
				draw_polyline(_closed_points(_hexagon_points(center, radius - 5.5)), branch_color.darkened(0.08), 1.5, true)
			_:
				var style := StyleBoxFlat.new()
				style.bg_color = fill
				style.border_color = state_color
				style.set_border_width_all(int(outline_width))
				style.set_corner_radius_all(10)
				draw_style_box(style, Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)))
		var icon_size: float = 25.0 if tier != "keystone" else 29.0
		if icon_texture != null:
			var icon_tint := Color.WHITE if state != "locked" else Color("77737b")
			draw_texture_rect(icon_texture, Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, icon_tint)
		draw_circle(center + Vector2(-radius * 0.62, radius * 0.70), 3.5, Color(0.02, 0.015, 0.02, 0.98), true, -1.0, true)
		draw_circle(center + Vector2(-radius * 0.62, radius * 0.70), 2.4, branch_color, true, -1.0, true)
		_draw_state_marker(center + Vector2(radius * 0.68, radius * 0.70), state_color)

	func _draw_node_shadow(center: Vector2, radius: float) -> void:
		draw_circle(center + Vector2(0.0, 3.0), radius + 1.5, Color(0.0, 0.0, 0.0, 0.55), true, -1.0, true)

	func _draw_state_marker(center: Vector2, marker_color: Color) -> void:
		draw_circle(center, 7.2, Color(0.025, 0.02, 0.03, 0.98), true, -1.0, true)
		draw_arc(center, 7.0, 0.0, TAU, 20, marker_color, 1.8, true)
		match state:
			"owned":
				draw_polyline(PackedVector2Array([center + Vector2(-3.4, 0.0), center + Vector2(-0.7, 2.8), center + Vector2(4.0, -3.0)]), marker_color, 2.0, true)
			"available":
				draw_line(center + Vector2(-3.5, 0.0), center + Vector2(3.5, 0.0), marker_color, 1.8, true)
				draw_line(center + Vector2(0.0, -3.5), center + Vector2(0.0, 3.5), marker_color, 1.8, true)
			"pending":
				draw_circle(center, 3.2, marker_color, true, -1.0, true)
			"excluded":
				draw_line(center + Vector2(-3.7, 3.7), center + Vector2(3.7, -3.7), marker_color, 2.0, true)
			_:
				draw_rect(Rect2(center + Vector2(-3.0, -0.5), Vector2(6.0, 4.5)), marker_color, false, 1.5, true)
				draw_arc(center + Vector2(0.0, -0.5), 3.0, PI, TAU, 12, marker_color, 1.5, true)

	func _diamond_points(center: Vector2, radius: float) -> PackedVector2Array:
		return PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		])

	func _hexagon_points(center: Vector2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for point_index: int in range(6):
			var angle: float = -PI * 0.5 + float(point_index) * TAU / 6.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		return points

	func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
		var closed := PackedVector2Array(points)
		if not points.is_empty():
			closed.append(points[0])
		return closed

	func _face_state_color(value: String) -> Color:
		match value:
			"owned":
				return Color("e6b85f")
			"available":
				return Color("7dd7ca")
			"pending":
				return Color("70b9f2")
			"excluded":
				return Color("dc7186")
			_:
				return Color("68636d")

	func _face_fill_color(value: String) -> Color:
		match value:
			"owned":
				return Color("65461f")
			"available":
				return Color("173a35")
			"pending":
				return Color("174665")
			"excluded":
				return Color("3c1b25")
			_:
				return Color("17151a")

var _ui_skin := UiSkin.new()
var _mode: String = MODE_VIEW
var _owned_ids: Array[String]
var _pending_ids: Array[String]
var _required_count: int = 0
var _resource_count: int = 0
var _editing_enabled: bool = true
var _show_footer: bool = true
var _focused_id: String = ""

var _graph_canvas: Control
var _graph_scroll: ScrollContainer
var _link_layer: SkillLinkLayer
var _summary_label: Label
var _node_buttons: Dictionary = {}
var _node_faces: Dictionary = {}
var _node_centers: Dictionary = {}
var _legend: HBoxContainer
var _detail_status: Label
var _detail_title: Label
var _detail_description: Label
var _detail_activation: Label
var _detail_requirements: Label
var _detail_unlocks: Label
var _detail_reason: Label
var _detail_action: Button
var _footer: HBoxContainer
var _cancel_button: Button
var _confirm_button: Button

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UiTypography.PANEL_GAP)
	_build_view()
	_refresh_view()

func configure(context: Dictionary) -> void:
	_mode = _normalized_mode(str(context.get("mode", MODE_VIEW)))
	_owned_ids = SkillTreeLibrary.normalized_ids(context.get("owned_ids", []))
	_required_count = maxi(0, int(context.get(
		"required_count",
		_owned_ids.size() + 1 if _mode == MODE_LEVEL_UP else _owned_ids.size()
	)))
	_resource_count = maxi(0, int(context.get("resource_count", 0)))
	_editing_enabled = bool(context.get("editing_enabled", true))
	_show_footer = bool(context.get("show_footer", _mode != MODE_VIEW))
	_pending_ids = _normalized_pending_ids(context)
	var requested_focus: String = str(context.get("focused_id", _focused_id))
	_focused_id = requested_focus if SkillTreeLibrary.has_definition(requested_focus) else _default_focus_id()
	if is_node_ready():
		_refresh_view()

func set_mode(mode: String) -> void:
	var next_mode: String = _normalized_mode(mode)
	var context: Dictionary = {
		"mode": next_mode,
		"owned_ids": _owned_ids,
		"required_count": _required_count,
		"resource_count": _resource_count,
		"editing_enabled": _editing_enabled,
		"show_footer": _show_footer,
		"focused_id": _focused_id,
	}
	if next_mode == _mode:
		context["pending_ids"] = _pending_ids
	configure(context)

func mode() -> String:
	return _mode

func owned_skill_ids() -> Array[String]:
	return _string_array(_owned_ids)

func pending_skill_ids() -> Array[String]:
	return _string_array(_pending_ids)

func proposed_skill_ids() -> Array[String]:
	if _mode == MODE_RESPEC:
		return _string_array(_pending_ids)
	if _mode == MODE_LEVEL_UP:
		var result: Array[String] = _string_array(_owned_ids)
		for skill_id: String in _pending_ids:
			if not result.has(skill_id):
				result.append(skill_id)
		return result
	return _string_array(_owned_ids)

func focus_skill(skill_id: String) -> void:
	if not SkillTreeLibrary.has_definition(skill_id):
		return
	_focused_id = skill_id
	_refresh_nodes()
	_refresh_links()
	_refresh_detail()
	skill_focused.emit(skill_id)
	call_deferred("_ensure_focused_visible")

func focused_skill_id() -> String:
	return _focused_id

func activate_focused_skill() -> void:
	_on_detail_action_pressed()

func request_confirm() -> void:
	_on_confirm_pressed()

func request_cancel() -> void:
	cancel_requested.emit()

func status_for_skill(skill_id: String) -> String:
	if not SkillTreeLibrary.has_definition(skill_id):
		return STATE_LOCKED
	if _mode == MODE_RESPEC:
		if _pending_ids.has(skill_id):
			return STATE_PENDING
		if _is_excluded(skill_id, _pending_ids):
			return STATE_EXCLUDED
		return STATE_AVAILABLE if SkillTreeLibrary.is_available(skill_id, _pending_ids) else STATE_LOCKED
	if _owned_ids.has(skill_id):
		return STATE_OWNED
	if _mode == MODE_LEVEL_UP and _pending_ids.has(skill_id):
		return STATE_PENDING
	if _is_excluded(skill_id, _owned_ids):
		return STATE_EXCLUDED
	return STATE_AVAILABLE if SkillTreeLibrary.is_available(skill_id, _owned_ids) else STATE_LOCKED

func visual_state_for_skill(skill_id: String) -> String:
	return STATE_SELECTED if skill_id == _focused_id else status_for_skill(skill_id)

func node_for_skill(skill_id: String) -> Button:
	return _node_buttons.get(skill_id, null) as Button

func node_count() -> int:
	return _node_buttons.size()

func connection_count() -> int:
	return _link_layer.links.size() if _link_layer != null else 0

func highlighted_connection_count() -> int:
	if _link_layer == null:
		return 0
	var result: int = 0
	for link: Dictionary in _link_layer.links:
		if bool(link.get("highlighted", false)):
			result += 1
	return result

func highlighted_connection_pairs() -> Array[String]:
	var result: Array[String]
	if _link_layer == null:
		return result
	for link: Dictionary in _link_layer.links:
		if bool(link.get("highlighted", false)):
			result.append("%s>%s" % [str(link.get("from_id", "")), str(link.get("to_id", ""))])
	result.sort()
	return result

func legend_state_count() -> int:
	return _legend.get_child_count() / 2 if _legend != null else 0

func points_remaining() -> int:
	return maxi(0, _required_count - _pending_ids.size()) if _mode == MODE_RESPEC else 0

func confirm_is_enabled() -> bool:
	return _confirm_button != null and not _confirm_button.disabled

func detail_action_is_enabled() -> bool:
	return _detail_action != null and _detail_action.visible and not _detail_action.disabled

func detail_title_text() -> String:
	return _detail_title.text if _detail_title != null else ""

func graph_canvas_size() -> Vector2:
	return _graph_canvas.custom_minimum_size if _graph_canvas != null else Vector2.ZERO

func node_center_for_skill(skill_id: String) -> Vector2:
	return _node_center(skill_id)

func node_visual_rect(skill_id: String) -> Rect2:
	return _node_visual_rect(skill_id)

func node_role_for_skill(skill_id: String) -> String:
	return SkillTreeLibrary.tier(skill_id)

func connection_points(source_id: String, target_id: String) -> PackedVector2Array:
	if _link_layer == null:
		return PackedVector2Array()
	for link: Dictionary in _link_layer.links:
		if str(link.get("from_id", "")) == source_id and str(link.get("to_id", "")) == target_id:
			return link.get("points", PackedVector2Array()) as PackedVector2Array
	return PackedVector2Array()

func connection_intersection_count(clearance: float = 2.0) -> int:
	return connection_intersection_pairs(clearance).size()

func connection_intersection_pairs(clearance: float = 2.0) -> Array[String]:
	var result: Array[String]
	if _link_layer == null:
		return result
	for link: Dictionary in _link_layer.links:
		var source_id: String = str(link.get("from_id", ""))
		var target_id: String = str(link.get("to_id", ""))
		var points: PackedVector2Array = link.get("points", PackedVector2Array()) as PackedVector2Array
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if skill_id in [source_id, target_id]:
				continue
			var obstacle: Rect2 = _node_visual_rect(skill_id).grow(clearance)
			for point_index: int in range(points.size() - 1):
				if _axis_segment_intersects_rect(points[point_index], points[point_index + 1], obstacle):
					result.append("%s>%s@%s" % [source_id, target_id, skill_id])
					break
	return result

func minimum_connection_width() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = INF
	for link: Dictionary in _link_layer.links:
		result = minf(result, float(link.get("width", 0.0)))
	return result

func minimum_connection_alpha() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = 1.0
	for link: Dictionary in _link_layer.links:
		var color: Color = link.get("color", Color.TRANSPARENT)
		result = minf(result, color.a)
	return result

func minimum_understroke_margin() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = INF
	for link: Dictionary in _link_layer.links:
		result = minf(result, float(link.get("under_width", 0.0)) - float(link.get("width", 0.0)))
	return result

func _build_view() -> void:
	if not _node_buttons.is_empty():
		return
	add_child(_build_graph_panel())
	add_child(_build_detail_panel())

func _build_graph_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "SkillTreeGraphPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("756245")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	column.add_child(header)
	var title := Label.new()
	title.text = "SKILL TREE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(title, UiTypography.ROLE_SECTION)
	title.add_theme_color_override("font_color", Color("f2e6d1"))
	header.add_child(title)
	_summary_label = Label.new()
	UiTypography.apply_label_role(_summary_label, UiTypography.ROLE_CAPTION)
	_summary_label.add_theme_color_override("font_color", Color("d6bc87"))
	header.add_child(_summary_label)

	_legend = HBoxContainer.new()
	_legend.name = "SkillStateLegend"
	_legend.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	column.add_child(_legend)
	_build_state_legend()

	_graph_scroll = ScrollContainer.new()
	_graph_scroll.name = "SkillTreeScroll"
	_graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(_graph_scroll)

	_graph_canvas = Control.new()
	_graph_canvas.name = "SkillTreeCanvas"
	_graph_canvas.custom_minimum_size = GRAPH_SIZE
	_graph_canvas.size = GRAPH_SIZE
	_graph_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_graph_scroll.add_child(_graph_canvas)

	_link_layer = SkillLinkLayer.new()
	_link_layer.name = "SkillTreeLinkLayer"
	_link_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_canvas.add_child(_link_layer)

	_build_skill_nodes()
	return panel

func _build_state_legend() -> void:
	if _legend == null:
		return
	for state: String in [STATE_OWNED, STATE_AVAILABLE, STATE_LOCKED, STATE_PENDING, STATE_EXCLUDED]:
		var swatch := ColorRect.new()
		swatch.name = "SkillLegendSwatch_%s" % state
		swatch.custom_minimum_size = Vector2(9.0, 9.0)
		swatch.color = _state_color(state)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_legend.add_child(swatch)
		var label := Label.new()
		label.name = "SkillLegendLabel_%s" % state
		label.text = _legend_state_text(state)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.set_label_size(label, 8)
		label.add_theme_color_override("font_color", Color("cfc4b2") if state != STATE_LOCKED else Color("8f8991"))
		_legend.add_child(label)

func _build_skill_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var node_size: Vector2 = _node_size(skill_id)
		var node_center: Vector2 = _node_center(skill_id)
		_node_centers[skill_id] = node_center
		var button := Button.new()
		button.name = "SkillNode_%s" % skill_id
		button.position = node_center - node_size * 0.5
		button.size = node_size
		button.custom_minimum_size = node_size
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.clip_contents = false
		button.pressed.connect(_on_node_pressed.bind(skill_id))
		button.focus_entered.connect(_on_node_focus_entered.bind(skill_id))
		button.mouse_entered.connect(_on_node_hovered.bind(skill_id))
		for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		_graph_canvas.add_child(button)
		_node_buttons[skill_id] = button
		var face := SkillNodeFace.new()
		face.name = "SkillNodeFace"
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_child(face)
		_node_faces[skill_id] = face
	_configure_focus_neighbors()

func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "SkillDetailPanel"
	panel.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("8c6f49")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_COMPACT))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING_COMPACT))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_COMPACT))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_COMPACT))
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	margin.add_child(column)

	_detail_status = Label.new()
	UiTypography.apply_label_role(_detail_status, UiTypography.ROLE_CAPTION)
	column.add_child(_detail_status)

	_detail_title = Label.new()
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_title, UiTypography.ROLE_SECTION)
	_detail_title.add_theme_color_override("font_color", Color("f5ead4"))
	column.add_child(_detail_title)

	_detail_description = Label.new()
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_description, UiTypography.ROLE_BODY)
	_detail_description.add_theme_color_override("font_color", Color("ddcfb7"))
	column.add_child(_detail_description)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	column.add_child(divider)

	_detail_activation = Label.new()
	UiTypography.apply_label_role(_detail_activation, UiTypography.ROLE_CAPTION)
	_detail_activation.add_theme_color_override("font_color", Color("c9b998"))
	column.add_child(_detail_activation)

	_detail_requirements = Label.new()
	_detail_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_requirements, UiTypography.ROLE_CAPTION)
	_detail_requirements.add_theme_color_override("font_color", Color("c9b998"))
	column.add_child(_detail_requirements)

	_detail_unlocks = Label.new()
	_detail_unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_unlocks, UiTypography.ROLE_CAPTION)
	_detail_unlocks.add_theme_color_override("font_color", Color("a8c9c1"))
	column.add_child(_detail_unlocks)

	_detail_reason = Label.new()
	_detail_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_reason, UiTypography.ROLE_BODY)
	column.add_child(_detail_reason)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_detail_action = Button.new()
	_detail_action.name = "SkillDetailAction"
	_detail_action.custom_minimum_size = Vector2(0.0, 44.0)
	_detail_action.pressed.connect(_on_detail_action_pressed)
	column.add_child(_detail_action)

	_footer = HBoxContainer.new()
	_footer.name = "SkillTreeFooter"
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	column.add_child(_footer)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(104.0, 42.0)
	_cancel_button.pressed.connect(request_cancel)
	_footer.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(142.0, 42.0)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_footer.add_child(_confirm_button)
	return panel

func _refresh_view() -> void:
	if _graph_canvas == null:
		return
	_refresh_legend()
	_refresh_summary()
	_refresh_nodes()
	_refresh_links()
	_refresh_detail()
	_refresh_footer()

func _refresh_legend() -> void:
	if _legend == null:
		return
	for state: String in [STATE_OWNED, STATE_AVAILABLE, STATE_LOCKED, STATE_PENDING, STATE_EXCLUDED]:
		var label: Label = _legend.get_node_or_null("SkillLegendLabel_%s" % state) as Label
		if label != null:
			label.text = _legend_state_text(state)

func _refresh_summary() -> void:
	if _summary_label == null:
		return
	match _mode:
		MODE_LEVEL_UP:
			_summary_label.text = "CHOOSE 1  ·  LEARNED %d" % _owned_ids.size()
		MODE_RESPEC:
			_summary_label.text = "ALLOCATED %d/%d  ·  %d LEFT  ·  MOLTSHARDS %d" % [
				_pending_ids.size(),
				_required_count,
				points_remaining(),
				_resource_count,
			]
		_:
			_summary_label.text = "LEARNED %d" % _owned_ids.size()

func _refresh_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button: Button = node_for_skill(skill_id)
		if button == null:
			continue
		var base_state: String = status_for_skill(skill_id)
		var selected: bool = skill_id == _focused_id
		var relationship: String = _relationship_to_focus(skill_id)
		button.set_meta("skill_id", skill_id)
		button.set_meta("skill_state", base_state)
		button.set_meta("skill_visual_state", STATE_SELECTED if selected else base_state)
		button.set_meta("selected", selected)
		button.set_meta("focus_relationship", relationship)
		button.set_meta("node_role", SkillTreeLibrary.tier(skill_id))
		button.set_meta("icon_key", SkillTreeLibrary.icon_key(skill_id))
		button.tooltip_text = _node_tooltip(skill_id, base_state)
		var face: SkillNodeFace = _node_faces.get(skill_id, null) as SkillNodeFace
		if face != null:
			face.configure(
				SkillTreeLibrary.tier(skill_id),
				base_state,
				relationship,
				selected,
				_branch_color(str(SkillTreeLibrary.definition(skill_id).get("branch", ""))),
				ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id))
			)

func _refresh_links() -> void:
	if _link_layer == null:
		return
	var links: Array[Dictionary]
	var ancestor_ids: Array[String] = _ancestor_ids(_focused_id)
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			var relationship: String = "unrelated"
			if skill_id == _focused_id:
				relationship = "prerequisite"
			elif prerequisite_id == _focused_id:
				relationship = "dependent"
			elif ancestor_ids.has(prerequisite_id) and ancestor_ids.has(skill_id):
				relationship = "ancestor"
			var visual: Dictionary = _link_visual(_link_state(prerequisite_id, skill_id), relationship)
			links.append({
				"from_id": prerequisite_id,
				"to_id": skill_id,
				"relationship": relationship,
				"highlighted": relationship in ["prerequisite", "dependent"],
				"points": _link_points(prerequisite_id, skill_id),
				"color": visual.get("color", Color("413b43")),
				"width": float(visual.get("width", 3.0)),
				"under_width": float(visual.get("width", 3.0)) + 3.0,
			})
	_link_layer.set_links(links)

func _refresh_detail() -> void:
	if _detail_title == null:
		return
	if not SkillTreeLibrary.has_definition(_focused_id):
		_detail_status.text = "SELECT A SKILL"
		_detail_title.text = "Skill Tree"
		_detail_description.text = "Choose a node to inspect its effect and requirements."
		_detail_activation.text = ""
		_detail_requirements.text = ""
		_detail_unlocks.text = ""
		_detail_reason.text = ""
		_detail_action.visible = false
		return
	var state: String = status_for_skill(_focused_id)
	_detail_status.text = _detail_status_text(_focused_id, state)
	_detail_status.add_theme_color_override("font_color", _state_color(state).lightened(0.12))
	_detail_title.text = SkillTreeLibrary.display_name(_focused_id)
	_detail_description.text = SkillTreeLibrary.description(_focused_id)
	_detail_activation.text = "ACTIVATION  ·  %s" % SkillTreeLibrary.activation_kind(_focused_id).to_upper()
	_detail_requirements.text = _requirements_text(_focused_id)
	_detail_unlocks.text = _unlocks_text(_focused_id)
	_detail_reason.text = _detail_reason_text(_focused_id, state)
	_detail_reason.add_theme_color_override("font_color", _state_color(state).lightened(0.16))
	_refresh_detail_action(state)

func _refresh_detail_action(state: String) -> void:
	_detail_action.visible = _mode != MODE_VIEW
	_detail_action.disabled = true
	if _mode == MODE_LEVEL_UP:
		if _pending_ids.has(_focused_id):
			_detail_action.text = "Clear Choice"
			_detail_action.disabled = not _editing_enabled
		elif state == STATE_AVAILABLE:
			_detail_action.text = "Choose"
			_detail_action.disabled = not _editing_enabled
		else:
			_detail_action.text = "Unavailable"
	elif _mode == MODE_RESPEC:
		if _pending_ids.has(_focused_id):
			var dependents: Array[String] = SkillTreeLibrary.dependent_ids(_focused_id, _pending_ids)
			_detail_action.text = "Refund Point" if dependents.is_empty() else "Remove dependents first"
			_detail_action.disabled = not _editing_enabled or not dependents.is_empty()
		elif state == STATE_AVAILABLE:
			_detail_action.text = "Spend Point" if points_remaining() > 0 else "No Points Left"
			_detail_action.disabled = (
				not _editing_enabled
				or points_remaining() <= 0
				or not SkillTreeLibrary.is_available(_focused_id, _pending_ids)
			)
		else:
			_detail_action.text = "Unavailable"
	var action_variant: String = UiSkin.VARIANT_SELECTED if not _detail_action.disabled else UiSkin.VARIANT_STANDARD
	_ui_skin.apply_button_stylebox_overrides(_detail_action, action_variant)
	_ui_skin.apply_button_text_overrides(_detail_action)
	UiTypography.apply_button_role(_detail_action, UiTypography.ROLE_BODY)

func _refresh_footer() -> void:
	if _footer == null:
		return
	_footer.visible = _show_footer and _mode != MODE_VIEW
	if not _footer.visible:
		return
	_ui_skin.apply_button_stylebox_overrides(_cancel_button, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(_cancel_button)
	UiTypography.apply_button_role(_cancel_button, UiTypography.ROLE_BODY)
	_confirm_button.text = "Confirm"
	_confirm_button.tooltip_text = ""
	if _mode == MODE_RESPEC:
		_confirm_button.text = "Spend 1"
		_confirm_button.tooltip_text = "Consume 1 Moltshard and replace the active build."
	_confirm_button.disabled = not _can_confirm()
	_ui_skin.apply_button_stylebox_overrides(
		_confirm_button,
		UiSkin.VARIANT_SELECTED if not _confirm_button.disabled else UiSkin.VARIANT_STANDARD
	)
	_ui_skin.apply_button_text_overrides(_confirm_button)
	UiTypography.apply_button_role(_confirm_button, UiTypography.ROLE_BODY)

func _on_node_pressed(skill_id: String) -> void:
	focus_skill(skill_id)

func _on_node_focus_entered(skill_id: String) -> void:
	if skill_id != _focused_id:
		focus_skill(skill_id)

func _on_node_hovered(skill_id: String) -> void:
	if skill_id != _focused_id:
		focus_skill(skill_id)

func _ensure_focused_visible() -> void:
	if _graph_scroll == null:
		return
	var button: Button = node_for_skill(_focused_id)
	if button != null:
		_graph_scroll.ensure_control_visible(button)

func _configure_focus_neighbors() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button: Button = node_for_skill(skill_id)
		if button == null:
			continue
		for direction: String in ["left", "right", "up", "down"]:
			var neighbor_id: String = _nearest_node_in_direction(skill_id, direction)
			var neighbor: Button = node_for_skill(neighbor_id)
			if neighbor == null:
				continue
			var neighbor_path: NodePath = button.get_path_to(neighbor)
			button.set_meta("nav_%s" % direction, neighbor_id)
			match direction:
				"left":
					button.focus_neighbor_left = neighbor_path
				"right":
					button.focus_neighbor_right = neighbor_path
				"up":
					button.focus_neighbor_top = neighbor_path
				"down":
					button.focus_neighbor_bottom = neighbor_path

func _nearest_node_in_direction(skill_id: String, direction: String) -> String:
	var origin: Vector2 = _node_center(skill_id)
	var best_id: String = ""
	var best_score: float = INF
	for candidate_id: String in SkillTreeLibrary.ordered_ids():
		if candidate_id == skill_id:
			continue
		var delta: Vector2 = _node_center(candidate_id) - origin
		var primary: float = 0.0
		var secondary: float = 0.0
		match direction:
			"left":
				if delta.x >= -0.5:
					continue
				primary = -delta.x
				secondary = absf(delta.y)
			"right":
				if delta.x <= 0.5:
					continue
				primary = delta.x
				secondary = absf(delta.y)
			"up":
				if delta.y >= -0.5:
					continue
				primary = -delta.y
				secondary = absf(delta.x)
			_:
				if delta.y <= 0.5:
					continue
				primary = delta.y
				secondary = absf(delta.x)
		var score: float = primary + secondary * (2.0 if direction in ["left", "right"] else 1.4)
		if score < best_score:
			best_score = score
			best_id = candidate_id
	return best_id

func _on_detail_action_pressed() -> void:
	if not _editing_enabled or not SkillTreeLibrary.has_definition(_focused_id):
		return
	if _mode == MODE_LEVEL_UP:
		if _pending_ids.has(_focused_id):
			_pending_ids.clear()
		elif SkillTreeLibrary.is_available(_focused_id, _owned_ids):
			_pending_ids = _string_array([_focused_id])
		else:
			return
		level_up_choice_changed.emit(_pending_ids[0] if not _pending_ids.is_empty() else "")
		pending_changed.emit(_pending_ids.duplicate())
	elif _mode == MODE_RESPEC:
		if _pending_ids.has(_focused_id):
			if not SkillTreeLibrary.dependent_ids(_focused_id, _pending_ids).is_empty():
				return
			_pending_ids.erase(_focused_id)
		elif points_remaining() > 0 and SkillTreeLibrary.is_available(_focused_id, _pending_ids):
			_pending_ids.append(_focused_id)
		else:
			return
		respec_draft_changed.emit(_pending_ids.duplicate())
		pending_changed.emit(_pending_ids.duplicate())
	_refresh_view()

func _on_confirm_pressed() -> void:
	if not _can_confirm():
		return
	confirm_requested.emit(proposed_skill_ids())

func _can_confirm() -> bool:
	if not _editing_enabled:
		return false
	if _mode == MODE_LEVEL_UP:
		return (
			_pending_ids.size() == 1
			and SkillTreeLibrary.is_available(_pending_ids[0], _owned_ids)
			and SkillTreeLibrary.selection_is_valid(proposed_skill_ids(), _required_count)
		)
	if _mode != MODE_RESPEC or _resource_count <= 0:
		return false
	if not SkillTreeLibrary.selection_is_valid(_pending_ids, _required_count):
		return false
	var owned_sorted: Array[String] = _string_array(_owned_ids)
	var pending_sorted: Array[String] = _string_array(_pending_ids)
	owned_sorted.sort()
	pending_sorted.sort()
	return owned_sorted != pending_sorted

func _normalized_pending_ids(context: Dictionary) -> Array[String]:
	if _mode == MODE_RESPEC:
		if context.has("pending_ids"):
			return SkillTreeLibrary.normalized_ids(context.get("pending_ids", []))
		return _string_array([])
	if _mode == MODE_LEVEL_UP:
		var candidates: Array[String] = SkillTreeLibrary.normalized_ids(context.get("pending_ids", []))
		var result: Array[String]
		for skill_id: String in candidates:
			if not _owned_ids.has(skill_id):
				result.append(skill_id)
				break
		return result
	return _string_array([])

func _default_focus_id() -> String:
	if not _pending_ids.is_empty():
		return _pending_ids[0]
	if _mode == MODE_RESPEC:
		var draft_available: Array[String] = SkillTreeLibrary.available_ids(_pending_ids)
		return draft_available[0] if not draft_available.is_empty() else ""
	if not _owned_ids.is_empty():
		return _owned_ids[0]
	var available: Array[String] = SkillTreeLibrary.available_ids([])
	return available[0] if not available.is_empty() else ""

func _normalized_mode(value: String) -> String:
	return value if value in [MODE_VIEW, MODE_LEVEL_UP, MODE_RESPEC] else MODE_VIEW

func _is_excluded(skill_id: String, selection: Array[String]) -> bool:
	var group_id: String = SkillTreeLibrary.exclusive_group(skill_id)
	if group_id.is_empty():
		return false
	for selected_id: String in selection:
		if selected_id != skill_id and SkillTreeLibrary.exclusive_group(selected_id) == group_id:
			return true
	return false

func _node_center(skill_id: String) -> Vector2:
	if _node_centers.has(skill_id):
		return _node_centers.get(skill_id, Vector2.ZERO) as Vector2
	return Vector2(SkillTreeLibrary.layout_position(skill_id))

func _node_size(skill_id: String) -> Vector2:
	match SkillTreeLibrary.tier(skill_id):
		"root":
			return ROOT_SIZE
		"junction":
			return JUNCTION_SIZE
		"keystone":
			return KEYSTONE_SIZE
		_:
			return BRANCH_SIZE

func _node_visual_rect(skill_id: String) -> Rect2:
	var visual_size: Vector2 = _node_size(skill_id) - Vector2(8.0, 8.0)
	return Rect2(_node_center(skill_id) - visual_size * 0.5, visual_size)

func _node_tooltip(skill_id: String, state: String) -> String:
	return "%s\n%s\n%s" % [
		SkillTreeLibrary.display_name(skill_id),
		SkillTreeLibrary.description(skill_id),
		_detail_reason_text(skill_id, state),
	]

func _node_state_text(skill_id: String, state: String) -> String:
	match state:
		STATE_OWNED:
			return "[ LEARNED ]"
		STATE_AVAILABLE:
			return "+  AVAILABLE"
		STATE_PENDING:
			return "[ DRAFTED ]" if _mode == MODE_RESPEC else "[ CHOSEN ]"
		STATE_EXCLUDED:
			return "X  EXCLUSIVE"
		_:
			return "-  LOCKED"

func _legend_state_text(state: String) -> String:
	match state:
		STATE_OWNED:
			return "LEARNED"
		STATE_AVAILABLE:
			return "AVAILABLE"
		STATE_PENDING:
			return "DRAFTED" if _mode == MODE_RESPEC else "CHOSEN"
		STATE_EXCLUDED:
			return "EXCLUSIVE"
		_:
			return "LOCKED"

func _detail_status_text(skill_id: String, state: String) -> String:
	var tier: String = str(SkillTreeLibrary.definition(skill_id).get("tier", "skill")).to_upper()
	return "%s  ·  %s" % [tier, _node_state_text(skill_id, state)]

func _detail_reason_text(skill_id: String, state: String) -> String:
	if state == STATE_PENDING:
		return "Allocated in the replacement build.\nYour current build stays active until you spend a Moltshard." if _mode == MODE_RESPEC else "This skill is the pending choice."
	if state == STATE_OWNED:
		return "Learned and active."
	if state == STATE_AVAILABLE:
		if _mode == MODE_RESPEC and points_remaining() <= 0:
			return "All points are allocated. Refund a leaf skill to choose this."
		if _mode == MODE_RESPEC:
			return "All requirements are met.\nYour current build stays active until you spend a Moltshard."
		return "All requirements are met."
	return SkillTreeLibrary.locked_reason(skill_id, _selection_for_availability())

func _requirements_text(skill_id: String) -> String:
	var parts: Array[String]
	parts.append("REQUIRES")
	var selection: Array[String] = _selection_for_availability()
	for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
		parts.append("%s  %s" % [
			"READY" if selection.has(prerequisite_id) else "NEED",
			SkillTreeLibrary.display_name(prerequisite_id),
		])
	if SkillTreeLibrary.prerequisites(skill_id).is_empty():
		parts.append("ROOT SKILL")
	var minimum_owned: int = SkillTreeLibrary.minimum_owned(skill_id)
	if minimum_owned > 0:
		parts.append("%s  %d total skills" % ["READY" if selection.size() >= minimum_owned else "NEED", minimum_owned])
	if not SkillTreeLibrary.exclusive_group(skill_id).is_empty():
		parts.append("LIMIT  One keystone per build")
	return "\n".join(parts)

func _unlocks_text(skill_id: String) -> String:
	var dependents: Array[String] = _direct_dependent_ids(skill_id)
	if dependents.is_empty():
		return "UNLOCKS\nNo direct unlocks"
	var names: Array[String]
	for dependent_id: String in dependents:
		names.append(SkillTreeLibrary.display_name(dependent_id))
	return "UNLOCKS\n%s" % "  ·  ".join(names)

func _selection_for_availability() -> Array[String]:
	return _string_array(_pending_ids if _mode == MODE_RESPEC else _owned_ids)

func _branch_color(branch_id: String) -> Color:
	return BRANCH_COLORS.get(branch_id, Color("b99a6b"))

func _state_color(state: String) -> Color:
	match state:
		STATE_OWNED:
			return Color("e6b85f")
		STATE_AVAILABLE:
			return Color("7dd7ca")
		STATE_PENDING:
			return Color("70b9f2")
		STATE_EXCLUDED:
			return Color("dc7186")
		_:
			return Color("57535b")

func _relationship_to_focus(skill_id: String) -> String:
	if _focused_id.is_empty() or skill_id == _focused_id:
		return "none"
	if SkillTreeLibrary.prerequisites(_focused_id).has(skill_id):
		return "prerequisite"
	if _direct_dependent_ids(_focused_id).has(skill_id):
		return "dependent"
	return "none"

func _direct_dependent_ids(skill_id: String) -> Array[String]:
	var result: Array[String]
	if skill_id.is_empty():
		return result
	for candidate_id: String in SkillTreeLibrary.ordered_ids():
		if SkillTreeLibrary.prerequisites(candidate_id).has(skill_id):
			result.append(candidate_id)
	return result

func _ancestor_ids(skill_id: String) -> Array[String]:
	var result: Array[String]
	if skill_id.is_empty():
		return result
	var pending: Array[String] = SkillTreeLibrary.prerequisites(skill_id)
	while not pending.is_empty():
		var candidate_id: String = pending.pop_front()
		if result.has(candidate_id):
			continue
		result.append(candidate_id)
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(candidate_id):
			if not result.has(prerequisite_id):
				pending.append(prerequisite_id)
	return result

func _link_state(source_id: String, target_id: String) -> String:
	var source_state: String = status_for_skill(source_id)
	var target_state: String = status_for_skill(target_id)
	if STATE_PENDING in [source_state, target_state]:
		return STATE_PENDING
	if source_state == STATE_OWNED and target_state == STATE_OWNED:
		return STATE_OWNED
	if target_state == STATE_AVAILABLE:
		return STATE_AVAILABLE
	if STATE_EXCLUDED in [source_state, target_state]:
		return STATE_EXCLUDED
	return STATE_LOCKED

func _link_visual(link_state: String, relationship: String) -> Dictionary:
	match relationship:
		"prerequisite":
			return {"color": Color("ffd47a"), "width": 5.0}
		"dependent":
			return {"color": Color("8ce1d5"), "width": 5.0}
		"ancestor":
			var ancestor_color := Color("bfa36d")
			ancestor_color.a = 0.90
			return {"color": ancestor_color, "width": 3.8}
	match link_state:
		STATE_OWNED:
			return {"color": Color("d6a84f"), "width": 4.0}
		STATE_AVAILABLE:
			return {"color": Color("69c5b8"), "width": 3.6}
		STATE_PENDING:
			return {"color": Color("66afe7"), "width": 4.2}
		STATE_EXCLUDED:
			return {"color": Color("b96073"), "width": 3.2}
		_:
			return {"color": Color("746d79"), "width": 3.0}

func _link_points(source_id: String, target_id: String) -> PackedVector2Array:
	var source_port: Vector2 = _output_port(source_id, target_id)
	var target_port: Vector2 = _input_port(target_id, source_id)
	var source_stub := Vector2(
		source_port.x,
		_row_visual_edge(source_id, true) + LINK_NODE_CLEARANCE + 1.0
	)
	var target_stub := Vector2(
		target_port.x,
		_row_visual_edge(target_id, false) - LINK_NODE_CLEARANCE - 1.0
	)
	if source_stub.y > target_stub.y:
		var midpoint_y: float = (source_port.y + target_port.y) * 0.5
		source_stub.y = midpoint_y
		target_stub.y = midpoint_y
	var channel_x: float = _best_route_channel_x(source_id, target_id, source_stub, target_stub)
	return _simplified_points(PackedVector2Array([
		source_port,
		source_stub,
		Vector2(channel_x, source_stub.y),
		Vector2(channel_x, target_stub.y),
		target_stub,
		target_port,
	]))

func _row_visual_edge(skill_id: String, bottom: bool) -> float:
	var row_y: float = _node_center(skill_id).y
	var edge: float = _node_visual_rect(skill_id).end.y if bottom else _node_visual_rect(skill_id).position.y
	for candidate_id: String in SkillTreeLibrary.ordered_ids():
		if not is_equal_approx(_node_center(candidate_id).y, row_y):
			continue
		var candidate_rect: Rect2 = _node_visual_rect(candidate_id)
		edge = maxf(edge, candidate_rect.end.y) if bottom else minf(edge, candidate_rect.position.y)
	return edge

func _input_port(target_id: String, source_id: String) -> Vector2:
	var prerequisites: Array[String] = SkillTreeLibrary.prerequisites(target_id)
	prerequisites.sort_custom(func(left: String, right: String) -> bool:
		return _node_center(left).x < _node_center(right).x
	)
	var index: int = prerequisites.find(source_id)
	var offset_x: float = _distributed_port_offset(index, prerequisites.size(), 8.0)
	return _node_boundary_port(target_id, offset_x, false)

func _output_port(source_id: String, target_id: String) -> Vector2:
	var dependents: Array[String] = _direct_dependent_ids(source_id)
	dependents.sort_custom(func(left: String, right: String) -> bool:
		var left_center: Vector2 = _node_center(left)
		var right_center: Vector2 = _node_center(right)
		return left_center.x < right_center.x if not is_equal_approx(left_center.x, right_center.x) else left_center.y < right_center.y
	)
	var index: int = dependents.find(target_id)
	var offset_x: float = _distributed_port_offset(index, dependents.size(), 14.0)
	return _node_boundary_port(source_id, offset_x, true)

func _distributed_port_offset(index: int, count: int, maximum_offset: float) -> float:
	if count <= 1 or index < 0:
		return 0.0
	return lerpf(-maximum_offset, maximum_offset, float(index) / float(count - 1))

func _node_boundary_port(skill_id: String, offset_x: float, bottom: bool) -> Vector2:
	var center: Vector2 = _node_center(skill_id)
	var radius: float = minf(_node_size(skill_id).x, _node_size(skill_id).y) * 0.5 - 4.0
	var vertical_extent: float = radius
	match SkillTreeLibrary.tier(skill_id):
		"root":
			vertical_extent = sqrt(maxf(0.0, radius * radius - offset_x * offset_x))
		"junction":
			vertical_extent = maxf(0.0, radius - absf(offset_x))
		_:
			vertical_extent = radius
	return center + Vector2(offset_x, vertical_extent if bottom else -vertical_extent)

func _best_route_channel_x(
	source_id: String,
	target_id: String,
	source_stub: Vector2,
	target_stub: Vector2
) -> float:
	var preferred_x: float = (source_stub.x + target_stub.x) * 0.5
	var best_x: float = preferred_x
	var best_score: float = INF
	var candidate_x: float = 12.0
	while candidate_x <= GRAPH_SIZE.x - 12.0:
		if _vertical_route_is_clear(candidate_x, source_stub.y, target_stub.y, source_id, target_id):
			var score: float = absf(candidate_x - preferred_x) + 0.18 * (
				absf(candidate_x - source_stub.x) + absf(candidate_x - target_stub.x)
			)
			if score < best_score:
				best_score = score
				best_x = candidate_x
		candidate_x += 4.0
	return best_x

func _vertical_route_is_clear(
	x: float,
	start_y: float,
	end_y: float,
	source_id: String,
	target_id: String
) -> bool:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		if skill_id in [source_id, target_id]:
			continue
		var obstacle: Rect2 = _node_visual_rect(skill_id).grow(LINK_NODE_CLEARANCE)
		if _axis_segment_intersects_rect(Vector2(x, start_y), Vector2(x, end_y), obstacle):
			return false
	return true

func _simplified_points(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if not result.is_empty() and result[result.size() - 1].is_equal_approx(point):
			continue
		if result.size() >= 2:
			var previous_direction: Vector2 = result[result.size() - 1] - result[result.size() - 2]
			var next_direction: Vector2 = point - result[result.size() - 1]
			if is_zero_approx(previous_direction.cross(next_direction)):
				result[result.size() - 1] = point
				continue
		result.append(point)
	return result

func _axis_segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	if is_equal_approx(start.x, finish.x):
		return (
			start.x >= rect.position.x
			and start.x <= rect.end.x
			and maxf(minf(start.y, finish.y), rect.position.y) <= minf(maxf(start.y, finish.y), rect.end.y)
		)
	if is_equal_approx(start.y, finish.y):
		return (
			start.y >= rect.position.y
			and start.y <= rect.end.y
			and maxf(minf(start.x, finish.x), rect.position.x) <= minf(maxf(start.x, finish.x), rect.end.x)
		)
	return rect.intersects(Rect2(start, finish - start).abs())

func _panel_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.042, 0.052, 0.97)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String]
	if typeof(value) != TYPE_ARRAY:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
