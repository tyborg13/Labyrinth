extends HBoxContainer
class_name SkillTreeView

const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
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

const NODE_SIZE: Vector2 = Vector2(154.0, 44.0)
const COLUMN_PITCH: float = 168.0
const ROW_PITCH: float = 55.0
const GRAPH_LEFT: float = 64.0
const GRAPH_TOP: float = 25.0
const GRAPH_SIZE: Vector2 = Vector2(730.0, 344.0)
const DETAIL_WIDTH: float = 300.0
const LINK_ARROW_LENGTH: float = 8.0
const LINK_ARROW_HALF_WIDTH: float = 4.5

const TIER_LABELS = [
	"ROOT",
	"PATH I",
	"PATH II",
	"JOIN I",
	"JOIN II",
	"KEY",
]

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
		for link: Dictionary in links:
			var points: PackedVector2Array = link.get("points", PackedVector2Array())
			if points.size() < 2:
				continue
			var color: Color = link.get("color", Color("4a434d"))
			var width: float = float(link.get("width", 2.0))
			draw_polyline(points, color, width, true)
			var tip: Vector2 = points[points.size() - 1]
			var previous: Vector2 = points[points.size() - 2]
			var direction: Vector2 = (tip - previous).normalized()
			if direction.is_zero_approx():
				continue
			var perpendicular := Vector2(-direction.y, direction.x)
			var arrow := PackedVector2Array([
				tip,
				tip - direction * LINK_ARROW_LENGTH + perpendicular * LINK_ARROW_HALF_WIDTH,
				tip - direction * LINK_ARROW_LENGTH - perpendicular * LINK_ARROW_HALF_WIDTH,
			])
			draw_colored_polygon(arrow, color)

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
var _link_layer: SkillLinkLayer
var _summary_label: Label
var _node_buttons: Dictionary = {}
var _node_name_labels: Dictionary = {}
var _node_state_labels: Dictionary = {}
var _node_branch_strips: Dictionary = {}
var _node_focus_rings: Dictionary = {}
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

	var scroll := ScrollContainer.new()
	scroll.name = "SkillTreeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)

	_graph_canvas = Control.new()
	_graph_canvas.name = "SkillTreeCanvas"
	_graph_canvas.custom_minimum_size = GRAPH_SIZE
	_graph_canvas.size = GRAPH_SIZE
	_graph_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_graph_canvas)

	_link_layer = SkillLinkLayer.new()
	_link_layer.name = "SkillTreeLinkLayer"
	_link_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_canvas.add_child(_link_layer)

	_build_branch_labels()
	_build_tier_labels()
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

func _build_branch_labels() -> void:
	for column_index: int in range(4):
		var root_id: String = ""
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if SkillTreeLibrary.position(skill_id) == Vector2i(column_index, 0):
				root_id = skill_id
				break
		var branch_id: String = str(SkillTreeLibrary.definition(root_id).get("branch", ""))
		var label := Label.new()
		label.name = "SkillBranch_%s" % branch_id
		label.text = branch_id.to_upper()
		label.position = Vector2(GRAPH_LEFT + float(column_index) * COLUMN_PITCH, 8.0)
		label.size = Vector2(NODE_SIZE.x, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.apply_label_role(label, UiTypography.ROLE_CAPTION)
		label.add_theme_color_override("font_color", _branch_color(branch_id).lightened(0.18))
		_graph_canvas.add_child(label)

func _build_tier_labels() -> void:
	for tier_index: int in range(TIER_LABELS.size()):
		var label := Label.new()
		label.name = "SkillTier_%d" % tier_index
		label.text = str(TIER_LABELS[tier_index])
		label.position = Vector2(0.0, GRAPH_TOP + float(tier_index) * ROW_PITCH + 13.0)
		label.size = Vector2(GRAPH_LEFT - 7.0, 18.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.set_label_size(label, 8)
		label.add_theme_color_override("font_color", Color("7f7780") if tier_index < 5 else Color("b89f72"))
		_graph_canvas.add_child(label)

func _build_skill_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button := Button.new()
		button.name = "SkillNode_%s" % skill_id
		button.position = _node_position(skill_id)
		button.size = NODE_SIZE
		button.custom_minimum_size = NODE_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.clip_contents = false
		button.pressed.connect(_on_node_pressed.bind(skill_id))
		_graph_canvas.add_child(button)
		_node_buttons[skill_id] = button

		var branch_strip := ColorRect.new()
		branch_strip.name = "BranchAccent"
		branch_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		branch_strip.offset_bottom = 4.0
		branch_strip.color = _branch_color(str(SkillTreeLibrary.definition(skill_id).get("branch", "")))
		branch_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(branch_strip)
		_node_branch_strips[skill_id] = branch_strip

		var focus_ring := Panel.new()
		focus_ring.name = "FocusRing"
		focus_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		focus_ring.offset_left = -3.0
		focus_ring.offset_top = -3.0
		focus_ring.offset_right = 3.0
		focus_ring.offset_bottom = 3.0
		focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_ring.add_theme_stylebox_override("panel", _focus_ring_style())
		focus_ring.visible = false
		focus_ring.z_index = 4
		button.add_child(focus_ring)
		_node_focus_rings[skill_id] = focus_ring

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 7.0
		content.offset_top = 5.0
		content.offset_right = -7.0
		content.offset_bottom = -3.0
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)

		var name_label := Label.new()
		name_label.text = SkillTreeLibrary.display_name(skill_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.set_label_size(name_label, 10)
		content.add_child(name_label)
		_node_name_labels[skill_id] = name_label

		var state_label := Label.new()
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.set_label_size(state_label, 9)
		content.add_child(state_label)
		_node_state_labels[skill_id] = state_label

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
		button.add_theme_stylebox_override("normal", _node_style(skill_id, base_state, selected, false))
		button.add_theme_stylebox_override("hover", _node_style(skill_id, base_state, true, false))
		button.add_theme_stylebox_override("pressed", _node_style(skill_id, base_state, true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.tooltip_text = _node_tooltip(skill_id, base_state)
		var focus_ring: Panel = _node_focus_rings.get(skill_id, null) as Panel
		if focus_ring != null:
			focus_ring.visible = selected or relationship in ["prerequisite", "dependent"]
			focus_ring.add_theme_stylebox_override("panel", _focus_ring_style(relationship if not selected else "focused"))
		var name_label: Label = _node_name_labels.get(skill_id, null) as Label
		var state_label: Label = _node_state_labels.get(skill_id, null) as Label
		if name_label != null:
			name_label.add_theme_color_override("font_color", _node_text_color(base_state))
		if state_label != null:
			state_label.text = _node_state_text(skill_id, base_state)
			state_label.add_theme_color_override("font_color", _state_color(base_state).lightened(0.12))

func _refresh_links() -> void:
	if _link_layer == null:
		return
	var links: Array[Dictionary]
	var ancestor_ids: Array[String] = _ancestor_ids(_focused_id)
	var route_index: int = 0
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			var target_state: String = status_for_skill(skill_id)
			var relationship: String = "unrelated"
			if skill_id == _focused_id:
				relationship = "prerequisite"
			elif prerequisite_id == _focused_id:
				relationship = "dependent"
			elif ancestor_ids.has(prerequisite_id) and ancestor_ids.has(skill_id):
				relationship = "ancestor"
			var visual: Dictionary = _link_visual(target_state, relationship)
			links.append({
				"from_id": prerequisite_id,
				"to_id": skill_id,
				"relationship": relationship,
				"highlighted": relationship in ["prerequisite", "dependent"],
				"points": _link_points(prerequisite_id, skill_id, route_index),
				"color": visual.get("color", Color("413b43")),
				"width": float(visual.get("width", 1.4)),
			})
			route_index += 1
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

func _node_position(skill_id: String) -> Vector2:
	var data_position: Vector2i = SkillTreeLibrary.position(skill_id)
	return Vector2(
		GRAPH_LEFT + float(data_position.x) * COLUMN_PITCH,
		GRAPH_TOP + float(data_position.y) * ROW_PITCH
	)

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

func _node_text_color(state: String) -> Color:
	return Color("fff3d8") if state != STATE_LOCKED else Color("8e8990")

func _node_style(skill_id: String, state: String, selected: bool, pressed: bool) -> StyleBoxFlat:
	var accent: Color = _state_color(state)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("161419")
	match state:
		STATE_OWNED:
			style.bg_color = Color("62441f")
		STATE_AVAILABLE:
			style.bg_color = Color("15302d")
		STATE_PENDING:
			style.bg_color = Color("17405c")
		STATE_EXCLUDED:
			style.bg_color = Color("3a1c25")
		STATE_LOCKED:
			style.bg_color = Color("121115")
	if pressed:
		style.bg_color = style.bg_color.lightened(0.10)
	style.border_color = accent
	style.set_border_width_all(3 if state in [STATE_OWNED, STATE_AVAILABLE, STATE_PENDING, STATE_EXCLUDED] else 1)
	style.set_corner_radius_all(10 if SkillTreeLibrary.is_keystone(skill_id) else 6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 7 if selected else 3
	style.content_margin_left = 5.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	return style

func _focus_ring_style(relationship: String = "focused") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	match relationship:
		"prerequisite":
			style.border_color = Color("ffd47a")
		"dependent":
			style.border_color = Color("8ce1d5")
		_:
			style.border_color = Color("fff8e8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	return style

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

func _link_visual(target_state: String, relationship: String) -> Dictionary:
	match relationship:
		"prerequisite":
			return {"color": Color("ffd47a"), "width": 4.5}
		"dependent":
			return {"color": Color("8ce1d5"), "width": 4.0}
		"ancestor":
			return {"color": Color("bfa36d"), "width": 2.8}
	var base: Color = _state_color(target_state)
	base.a = 0.24 if not _focused_id.is_empty() else 0.14
	return {"color": base, "width": 1.4}

func _link_points(source_id: String, target_id: String, route_index: int) -> PackedVector2Array:
	var source_rect := Rect2(_node_position(source_id), NODE_SIZE)
	var target_rect := Rect2(_node_position(target_id), NODE_SIZE)
	var source_position: Vector2i = SkillTreeLibrary.position(source_id)
	var target_position: Vector2i = SkillTreeLibrary.position(target_id)
	var row_distance: int = absi(target_position.y - source_position.y)
	if source_position.x == target_position.x and row_distance == 1:
		return PackedVector2Array([
			Vector2(source_rect.get_center().x, source_rect.end.y),
			Vector2(target_rect.get_center().x, target_rect.position.y),
		])
	if source_position.x == target_position.x:
		var route_right: bool = source_position.x < 3
		var source_edge_x: float = source_rect.end.x if route_right else source_rect.position.x
		var target_edge_x: float = target_rect.end.x if route_right else target_rect.position.x
		var lane_x: float = source_edge_x + (7.0 if route_right else -7.0)
		return PackedVector2Array([
			Vector2(source_edge_x, source_rect.get_center().y),
			Vector2(lane_x, source_rect.get_center().y),
			Vector2(lane_x, target_rect.get_center().y),
			Vector2(target_edge_x, target_rect.get_center().y),
		])
	var target_is_right: bool = target_rect.get_center().x > source_rect.get_center().x
	var direction: float = 1.0 if target_is_right else -1.0
	var source_edge := Vector2(
		source_rect.end.x if target_is_right else source_rect.position.x,
		source_rect.get_center().y
	)
	var lane_x: float = source_edge.x + direction * 7.0
	var route_slot: int = route_index % 3
	var track_y: float = target_rect.position.y - 5.0 - float(route_slot) * 2.0
	return PackedVector2Array([
		source_edge,
		Vector2(lane_x, source_edge.y),
		Vector2(lane_x, track_y),
		Vector2(target_rect.get_center().x, track_y),
		Vector2(target_rect.get_center().x, target_rect.position.y),
	])

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
