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

const NODE_SIZE: Vector2 = Vector2(164.0, 48.0)
const COLUMN_PITCH: float = 184.0
const ROW_PITCH: float = 52.0
const GRAPH_LEFT: float = 4.0
const GRAPH_TOP: float = 38.0
const GRAPH_SIZE: Vector2 = Vector2(728.0, 350.0)
const DETAIL_WIDTH: float = 300.0
const LINK_SAMPLES: int = 18

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
			var from_point: Vector2 = link.get("from", Vector2.ZERO)
			var to_point: Vector2 = link.get("to", Vector2.ZERO)
			var color: Color = link.get("color", Color("4a434d"))
			var width: float = float(link.get("width", 2.0))
			var midpoint_y: float = lerpf(from_point.y, to_point.y, 0.5)
			var first_control := Vector2(from_point.x, midpoint_y)
			var second_control := Vector2(to_point.x, midpoint_y)
			var points := PackedVector2Array()
			for sample_index: int in range(LINK_SAMPLES + 1):
				var t: float = float(sample_index) / float(LINK_SAMPLES)
				var inverse: float = 1.0 - t
				points.append(
					from_point * inverse * inverse * inverse
					+ first_control * 3.0 * inverse * inverse * t
					+ second_control * 3.0 * inverse * t * t
					+ to_point * t * t * t
				)
			draw_polyline(points, color, width, true)

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
var _detail_status: Label
var _detail_title: Label
var _detail_description: Label
var _detail_activation: Label
var _detail_requirements: Label
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
			return STATE_OWNED if _owned_ids.has(skill_id) else STATE_PENDING
		if _owned_ids.has(skill_id):
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
	_build_skill_nodes()
	return panel

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

func _build_skill_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button := Button.new()
		button.name = "SkillNode_%s" % skill_id
		button.position = _node_position(skill_id)
		button.size = NODE_SIZE
		button.custom_minimum_size = NODE_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.clip_contents = true
		button.pressed.connect(_on_node_pressed.bind(skill_id))
		_graph_canvas.add_child(button)
		_node_buttons[skill_id] = button

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 7.0
		content.offset_top = 4.0
		content.offset_right = -7.0
		content.offset_bottom = -3.0
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)

		var name_label := Label.new()
		name_label.text = SkillTreeLibrary.display_name(skill_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.apply_label_role(name_label, UiTypography.ROLE_CAPTION)
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
	_refresh_summary()
	_refresh_nodes()
	_refresh_links()
	_refresh_detail()
	_refresh_footer()

func _refresh_summary() -> void:
	if _summary_label == null:
		return
	match _mode:
		MODE_LEVEL_UP:
			_summary_label.text = "CHOOSE 1  ·  LEARNED %d" % _owned_ids.size()
		MODE_RESPEC:
			_summary_label.text = "DRAFT %d/%d  ·  MOLTSHARDS %d" % [_pending_ids.size(), _required_count, _resource_count]
		_:
			_summary_label.text = "LEARNED %d" % _owned_ids.size()

func _refresh_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button: Button = node_for_skill(skill_id)
		if button == null:
			continue
		var base_state: String = status_for_skill(skill_id)
		var selected: bool = skill_id == _focused_id
		button.set_meta("skill_id", skill_id)
		button.set_meta("skill_state", base_state)
		button.set_meta("skill_visual_state", STATE_SELECTED if selected else base_state)
		button.set_meta("selected", selected)
		button.add_theme_stylebox_override("normal", _node_style(skill_id, base_state, selected, false))
		button.add_theme_stylebox_override("hover", _node_style(skill_id, base_state, true, false))
		button.add_theme_stylebox_override("pressed", _node_style(skill_id, base_state, true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.tooltip_text = _node_tooltip(skill_id, base_state)
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
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var target_rect := Rect2(_node_position(skill_id), NODE_SIZE)
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			var source_rect := Rect2(_node_position(prerequisite_id), NODE_SIZE)
			var target_state: String = status_for_skill(skill_id)
			links.append({
				"from": Vector2(source_rect.get_center().x, source_rect.end.y),
				"to": Vector2(target_rect.get_center().x, target_rect.position.y),
				"color": _state_color(target_state).darkened(0.18),
				"width": 3.0 if target_state in [STATE_OWNED, STATE_PENDING] else 2.0,
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
			_detail_action.text = "Remove" if dependents.is_empty() else "Remove dependents first"
			_detail_action.disabled = not _editing_enabled or not dependents.is_empty()
		elif state in [STATE_AVAILABLE, STATE_PENDING]:
			_detail_action.text = "Add" if not _owned_ids.has(_focused_id) else "Restore"
			_detail_action.disabled = not _editing_enabled or not SkillTreeLibrary.is_available(_focused_id, _pending_ids)
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
		_confirm_button.tooltip_text = "Consume 1 Moltshard and apply this skill tree."
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
		elif SkillTreeLibrary.is_available(_focused_id, _pending_ids):
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
		return _string_array(_owned_ids)
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
	if state == STATE_PENDING and _mode == MODE_RESPEC:
		return "REMOVE" if _owned_ids.has(skill_id) and not _pending_ids.has(skill_id) else "ADD"
	match state:
		STATE_OWNED:
			return "LEARNED"
		STATE_AVAILABLE:
			return "AVAILABLE"
		STATE_PENDING:
			return "CHOSEN"
		STATE_EXCLUDED:
			return "EXCLUSIVE"
		_:
			return "LOCKED"

func _detail_status_text(skill_id: String, state: String) -> String:
	var tier: String = str(SkillTreeLibrary.definition(skill_id).get("tier", "skill")).to_upper()
	return "%s  ·  %s" % [tier, _node_state_text(skill_id, state)]

func _detail_reason_text(skill_id: String, state: String) -> String:
	if state == STATE_PENDING:
		if _mode == MODE_RESPEC and _owned_ids.has(skill_id) and not _pending_ids.has(skill_id):
			return "This skill will be removed when the draft is confirmed."
		return "This skill is part of the pending choice."
	if state == STATE_OWNED:
		return "Learned and active."
	if state == STATE_AVAILABLE:
		return "All requirements are met."
	return SkillTreeLibrary.locked_reason(skill_id, _selection_for_availability())

func _requirements_text(skill_id: String) -> String:
	var parts: Array[String]
	var names: Array[String]
	for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
		names.append(SkillTreeLibrary.display_name(prerequisite_id))
	if names.is_empty():
		parts.append("No prerequisite")
	else:
		parts.append("Requires %s" % ", ".join(names))
	var minimum_owned: int = SkillTreeLibrary.minimum_owned(skill_id)
	if minimum_owned > 0:
		parts.append("%d learned skills" % minimum_owned)
	if not SkillTreeLibrary.exclusive_group(skill_id).is_empty():
		parts.append("One keystone only")
	return "  ·  ".join(parts)

func _selection_for_availability() -> Array[String]:
	return _string_array(_pending_ids if _mode == MODE_RESPEC else _owned_ids)

func _branch_color(branch_id: String) -> Color:
	return BRANCH_COLORS.get(branch_id, Color("b99a6b"))

func _state_color(state: String) -> Color:
	match state:
		STATE_OWNED:
			return Color("d7a85d")
		STATE_AVAILABLE:
			return Color("b994d0")
		STATE_PENDING:
			return Color("8ec5ff")
		STATE_EXCLUDED:
			return Color("b76878")
		_:
			return Color("615968")

func _node_text_color(state: String) -> Color:
	return Color("f7ead0") if state != STATE_LOCKED else Color("9c939f")

func _node_style(skill_id: String, state: String, selected: bool, pressed: bool) -> StyleBoxFlat:
	var accent: Color = _state_color(state)
	var branch_id: String = str(SkillTreeLibrary.definition(skill_id).get("branch", ""))
	if state == STATE_LOCKED:
		accent = _branch_color(branch_id).darkened(0.48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17131a")
	match state:
		STATE_OWNED:
			style.bg_color = Color("302518")
		STATE_AVAILABLE:
			style.bg_color = Color("24182d")
		STATE_PENDING:
			style.bg_color = Color("172939")
		STATE_EXCLUDED:
			style.bg_color = Color("28171d")
	if pressed:
		style.bg_color = style.bg_color.lightened(0.10)
	style.border_color = Color("f2e8d7") if selected else accent
	style.set_border_width_all(3 if selected or SkillTreeLibrary.is_keystone(skill_id) else 2)
	style.set_corner_radius_all(10 if SkillTreeLibrary.is_keystone(skill_id) else 6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 7 if selected else 4
	style.content_margin_left = 5.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	return style

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
