extends Button
class_name CardWidget

signal activated
signal drag_started

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const DRAG_THRESHOLD: float = 10.0
const HOVER_LIFT: float = -12.0
const SELECTED_LIFT: float = -5.0
const HOVER_SCALE: float = 1.04
const SELECTED_SCALE: float = 1.01
const DAMAGE_NEUTRAL_COLOR: String = "#503d2c"
const DAMAGE_BONUS_COLOR: String = "#4f8a43"
const DAMAGE_PENALTY_COLOR: String = "#a34a42"
const COMPACT_CARD_WIDTH: float = 144.0

class AoePatternView:
	extends Control

	const TILE_WIDTH: float = 12.0
	const TILE_HEIGHT: float = 8.0
	const TILE_PADDING: float = 4.0

	var pattern_offsets: Array[Vector2i] = []
	var show_origin: bool = false

	func setup(raw_pattern: Variant, next_show_origin: bool, next_tooltip: String) -> void:
		pattern_offsets = _parse_offsets(raw_pattern)
		show_origin = next_show_origin
		tooltip_text = next_tooltip
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = _desired_size()
		queue_redraw()

	func _draw() -> void:
		var draw_offsets: Array[Vector2i] = _draw_offsets()
		if draw_offsets.is_empty():
			return
		var bounds: Rect2 = _bounds_for_offsets(draw_offsets)
		var shift: Vector2 = size * 0.5 - bounds.get_center()
		var hit_lookup: Dictionary = {}
		for offset: Vector2i in pattern_offsets:
			hit_lookup[offset] = true
		for offset: Vector2i in draw_offsets:
			var is_origin: bool = show_origin and offset == Vector2i.ZERO and not hit_lookup.has(offset)
			var fill: Color = Color("e9dcc6") if is_origin else Color("d95f4a")
			var border: Color = Color("5a493b") if is_origin else Color("7b2f25")
			_draw_tile(_iso_center(offset) + shift, fill, border)

	func _desired_size() -> Vector2:
		var draw_offsets: Array[Vector2i] = _draw_offsets()
		if draw_offsets.is_empty():
			return Vector2(34.0, 24.0)
		var bounds: Rect2 = _bounds_for_offsets(draw_offsets)
		return Vector2(maxf(34.0, bounds.size.x + TILE_PADDING * 2.0), maxf(24.0, bounds.size.y + TILE_PADDING * 2.0))

	func _draw_offsets() -> Array[Vector2i]:
		var lookup: Dictionary = {}
		for offset: Vector2i in pattern_offsets:
			lookup[offset] = true
		if show_origin:
			lookup[Vector2i.ZERO] = true
		var offsets: Array[Vector2i] = []
		for offset_var: Variant in lookup.keys():
			if typeof(offset_var) == TYPE_VECTOR2I:
				offsets.append(offset_var)
		offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		)
		return offsets

	func _bounds_for_offsets(offsets: Array[Vector2i]) -> Rect2:
		var first: bool = true
		var rect := Rect2()
		for offset: Vector2i in offsets:
			var center: Vector2 = _iso_center(offset)
			var tile_rect := Rect2(center - Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5), Vector2(TILE_WIDTH, TILE_HEIGHT))
			if first:
				rect = tile_rect
				first = false
			else:
				rect = rect.merge(tile_rect)
		return rect

	func _iso_center(offset: Vector2i) -> Vector2:
		return Vector2(float(offset.x - offset.y) * TILE_WIDTH * 0.5, float(offset.x + offset.y) * TILE_HEIGHT * 0.5)

	func _draw_tile(center: Vector2, fill: Color, border: Color) -> void:
		var points := PackedVector2Array([
			center + Vector2(0.0, -TILE_HEIGHT * 0.5),
			center + Vector2(TILE_WIDTH * 0.5, 0.0),
			center + Vector2(0.0, TILE_HEIGHT * 0.5),
			center + Vector2(-TILE_WIDTH * 0.5, 0.0),
			center + Vector2(0.0, -TILE_HEIGHT * 0.5)
		])
		draw_colored_polygon(points, fill)
		draw_polyline(points, border, 1.0, true)

	func _parse_offsets(raw_pattern: Variant) -> Array[Vector2i]:
		var parsed: Array[Vector2i] = []
		if typeof(raw_pattern) != TYPE_ARRAY:
			parsed.append(Vector2i.ZERO)
			return parsed
		for offset_var: Variant in raw_pattern:
			match typeof(offset_var):
				TYPE_VECTOR2I:
					parsed.append(offset_var)
				TYPE_ARRAY:
					var pair: Array = offset_var
					if pair.size() >= 2:
						parsed.append(Vector2i(int(pair[0]), int(pair[1])))
				TYPE_DICTIONARY:
					var offset_dict: Dictionary = offset_var
					parsed.append(Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0))))
		if parsed.is_empty():
			parsed.append(Vector2i.ZERO)
		return parsed

@onready var vbox: VBoxContainer = $Margin/VBox
@onready var title_label: Label = $Margin/VBox/TopRow/Title
@onready var cost_badge: Label = $Margin/VBox/TopRow/CostBadge
@onready var element_icon: TextureRect = $Margin/VBox/TopRow/ElementIcon
@onready var art_frame: PanelContainer = $Margin/VBox/ArtFrame
@onready var art_rect: TextureRect = $Margin/VBox/ArtFrame/Art
@onready var desc_label: RichTextLabel = $Margin/VBox/Description
@onready var footer_label: Label = $Margin/VBox/Footer

var card_id: String = ""
var _selected: bool = false
var _dimmed: bool = false
var _usable: bool = true
var _previewed: bool = false
var _interactive: bool = true
var _printed_playable: bool = true
var _card_override: Dictionary = {}
var _summary_bbcode: String = ""
var _summary_rows: Array = []
var _modifier_tooltip_lines: PackedStringArray = []
var _left_pressed: bool = false
var _drag_emitted: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _local_hovered: bool = false
var _pose_tween: Tween
var _summary_icon_box: VBoxContainer
var _cost_badge_icon: TextureRect

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	text = ""
	title_label.add_theme_color_override("font_color", Color("39271b"))
	title_label.add_theme_color_override("font_outline_color", Color("f8f1dd"))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("default_color", Color("503d2c"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.scroll_following = false
	footer_label.visible = false
	footer_label.add_theme_color_override("font_color", Color("6d5841"))
	footer_label.add_theme_color_override("font_outline_color", Color("f5ecdb"))
	footer_label.add_theme_constant_override("outline_size", 1)
	cost_badge.add_theme_color_override("font_color", Color("fff4dc"))
	cost_badge.add_theme_color_override("font_outline_color", Color("2f2018"))
	cost_badge.add_theme_constant_override("outline_size", 2)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_summary_icon_box()
	_ensure_cost_badge_icon()
	mouse_entered.connect(_on_local_mouse_entered)
	mouse_exited.connect(_on_local_mouse_exited)
	_update_layout_metrics()
	_apply_configuration()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_layout_metrics()
		pivot_offset = size * 0.5
		if not card_id.is_empty():
			_apply_configuration()

func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_pressed = true
			_drag_emitted = false
			_press_position = event.position
			accept_event()
			return
		if _left_pressed:
			_left_pressed = false
			accept_event()
			if not _drag_emitted:
				activated.emit()
			_drag_emitted = false
	elif event is InputEventMouseMotion and _left_pressed and not _drag_emitted:
		if event.position.distance_to(_press_position) >= DRAG_THRESHOLD:
			_drag_emitted = true
			drag_started.emit()
			accept_event()

func _get_tooltip(_at_position: Vector2) -> String:
	var icon_tooltip: String = _tooltip_for_icon_at(get_global_mouse_position())
	if not icon_tooltip.is_empty():
		return icon_tooltip
	return "modifiers" if not _modifier_tooltip_lines.is_empty() else ""

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text == "modifiers":
		if _modifier_tooltip_lines.is_empty():
			return null
		return UiTooltipPanel.make_lines("MODIFIERS", _modifier_tooltip_lines)
	if for_text.strip_edges().is_empty():
		return null
	return UiTooltipPanel.make_text(for_text)

func _tooltip_for_icon_at(global_point: Vector2) -> String:
	for root_node: Variant in [_summary_icon_box, cost_badge]:
		var tooltip: String = _tooltip_for_control_at(root_node as Node, global_point)
		if not tooltip.is_empty():
			return tooltip
	return ""

func _tooltip_for_control_at(node: Node, global_point: Vector2) -> String:
	if node == null or not (node is Control):
		return ""
	var control: Control = node
	if not control.visible or not control.get_global_rect().has_point(global_point):
		return ""
	for child: Node in control.get_children():
		var child_tooltip: String = _tooltip_for_control_at(child, global_point)
		if not child_tooltip.is_empty():
			return child_tooltip
	return str(control.tooltip_text)

func configure(
	next_card_id: String,
	selected: bool = false,
	dimmed: bool = false,
	usable: bool = true,
	previewed: bool = false,
	interactive: bool = true,
	printed_playable: bool = true,
	card_override: Dictionary = {}
) -> void:
	card_id = next_card_id
	_selected = selected
	_dimmed = dimmed
	_usable = usable
	_previewed = previewed
	_interactive = interactive
	_printed_playable = printed_playable
	_card_override = card_override.duplicate(true)
	if is_node_ready():
		_apply_configuration()

func set_display_overrides(summary_bbcode: String = "", modifier_lines: Array = [], summary_rows: Array = []) -> void:
	_summary_bbcode = summary_bbcode
	_summary_rows = summary_rows.duplicate(true)
	_modifier_tooltip_lines = PackedStringArray()
	for line_var: Variant in modifier_lines:
		_modifier_tooltip_lines.append(str(line_var))
	tooltip_text = "modifiers" if not _modifier_tooltip_lines.is_empty() else ""
	if is_node_ready():
		_apply_configuration()

func _apply_configuration() -> void:
	if not is_node_ready():
		return
	var card: Dictionary = _display_card_def()
	var element_id: String = GameData.card_element_from_def(card)
	var element: Dictionary = ElementData.def(element_id)
	title_label.text = str(card.get("name", card_id))
	_refresh_summary_display(card)
	footer_label.text = ""
	footer_label.visible = false
	art_rect.texture = AssetLoader.load_texture(str(card.get("art_path", "")))
	element_icon.visible = ElementData.is_elemental(element_id)
	element_icon.texture = AssetLoader.load_texture(str(element.get("icon_path", ""))) if element_icon.visible else null
	element_icon.modulate = Color(str(element.get("accent", "#8a6b4a")))
	var accent: Color = ElementData.accent(element_id) if ElementData.is_elemental(element_id) else Color(str(card.get("accent", "#8a6b4a")))
	var background: Color = ElementData.card_background(element_id, _selected)
	if not ElementData.is_elemental(element_id):
		background = Color("ddd0bb") if _selected else Color("efe4cf")
	if _previewed and not _selected:
		background = background.lightened(0.03)
	if _dimmed:
		background = background.darkened(0.12)
	_apply_base_style(background, accent, _usable, _previewed, _printed_playable, ElementData.card_art_background(element_id))
	var badge_text: String = ""
	var badge_icon: String = ""
	if bool(card.get("burn", false)):
		badge_icon = "burn"
	elif int(card.get("health_cost", 0)) > 0:
		badge_icon = "health"
		badge_text = "  -%d" % int(card.get("health_cost", 0))
	cost_badge.visible = not badge_text.is_empty() or not badge_icon.is_empty()
	cost_badge.text = badge_text
	cost_badge.tooltip_text = ActionIcons.tooltip(badge_icon) if not badge_icon.is_empty() else ""
	_configure_cost_badge_icon(badge_icon, not badge_text.is_empty())
	cost_badge.add_theme_stylebox_override("normal", _badge_style(accent))
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _interactive else Control.CURSOR_ARROW
	var alpha: float = 1.0
	if not _usable:
		alpha = 0.56
	elif _dimmed:
		alpha = 0.72
	elif not _printed_playable:
		alpha = 0.90
	modulate = Color(1.0, 1.0, 1.0, alpha)
	_update_pose(true)

func _update_layout_metrics() -> void:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var compact: bool = width <= COMPACT_CARD_WIDTH
	var title_size: int = 10 if compact else 12
	var detail_size: int = 10 if compact else 11
	UiTypography.set_label_size(title_label, title_size)
	UiTypography.set_label_size(cost_badge, detail_size)
	UiTypography.set_rich_text_size(desc_label, detail_size)
	UiTypography.set_label_size(footer_label, detail_size)
	var art_height: float = clampf(width * 0.56, 78.0, 102.0)
	art_frame.custom_minimum_size = Vector2(0.0, art_height)
	desc_label.custom_minimum_size = Vector2(0.0, 54.0 if compact else 64.0)
	footer_label.custom_minimum_size = Vector2.ZERO
	if _summary_icon_box != null:
		_summary_icon_box.custom_minimum_size = desc_label.custom_minimum_size
	pivot_offset = size * 0.5

func _apply_base_style(background: Color, border: Color, usable: bool, previewed: bool, printed_playable: bool, art_background: Color) -> void:
	var edge_color: Color = border
	if not usable:
		edge_color = border.darkened(0.46)
	elif not printed_playable:
		edge_color = border.lerp(Color("bfa690"), 0.42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = edge_color
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_right = 12
	normal.corner_radius_bottom_left = 12
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	normal.shadow_size = 12 if _local_hovered else 10 if previewed or _selected else 8
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = edge_color.lightened(0.18)
	hover.shadow_size = 12
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = background.darkened(0.05)
	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = background.darkened(0.08)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = art_background
	art_style.border_color = edge_color.darkened(0.14)
	art_style.border_width_left = 2
	art_style.border_width_top = 2
	art_style.border_width_right = 2
	art_style.border_width_bottom = 2
	art_style.corner_radius_top_left = 10
	art_style.corner_radius_top_right = 10
	art_style.corner_radius_bottom_right = 10
	art_style.corner_radius_bottom_left = 10
	art_style.content_margin_left = 4.0
	art_style.content_margin_top = 4.0
	art_style.content_margin_right = 4.0
	art_style.content_margin_bottom = 4.0
	art_frame.add_theme_stylebox_override("panel", art_style)

func _badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.08)
	style.border_color = accent.lightened(0.14)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.content_margin_left = 7.0
	style.content_margin_top = 4.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 4.0
	return style

func _ensure_summary_icon_box() -> void:
	if _summary_icon_box != null:
		return
	_summary_icon_box = VBoxContainer.new()
	_summary_icon_box.name = "IconSummary"
	_summary_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_icon_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_summary_icon_box)
	vbox.move_child(_summary_icon_box, desc_label.get_index() + 1)

func _ensure_cost_badge_icon() -> void:
	if _cost_badge_icon != null:
		return
	_cost_badge_icon = TextureRect.new()
	_cost_badge_icon.name = "KeywordIcon"
	_cost_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge_icon.expand_mode = 1
	_cost_badge_icon.stretch_mode = 5
	cost_badge.add_child(_cost_badge_icon)

func _refresh_summary_display(card: Dictionary) -> void:
	var rows: Array = _summary_rows.duplicate(true)
	if rows.is_empty() and _summary_bbcode.is_empty():
		rows = ActionIcons.rows_for_actions(card.get("actions", []))
	if rows.is_empty():
		desc_label.visible = true
		desc_label.text = _summary_bbcode if not _summary_bbcode.is_empty() else str(card.get("description", ""))
		if _summary_icon_box != null:
			_summary_icon_box.visible = false
			_clear_children(_summary_icon_box)
		return
	desc_label.visible = false
	desc_label.text = ""
	_summary_icon_box.visible = true
	_render_summary_icon_rows(rows)

func _render_summary_icon_rows(rows: Array) -> void:
	if _summary_icon_box == null:
		return
	_clear_children(_summary_icon_box)
	var icon_size: float = _summary_icon_size()
	var label_size: int = 10 if icon_size <= 15.0 else 12
	var row_gap: int = 3 if icon_size <= 15.0 else 4
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", row_gap)
		for token_var: Variant in (row_var as Array):
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			_add_token_to_summary_row(row, token_var as Dictionary, icon_size, label_size)
		if row.get_child_count() > 0:
			_summary_icon_box.add_child(row)

func _add_token_to_summary_row(row: HBoxContainer, token: Dictionary, icon_size: float, label_size: int) -> void:
	var tooltip: String = ActionIcons.token_tooltip(token)
	if str(token.get("kind", "")) == "aoe_pattern":
		var pattern_view := AoePatternView.new()
		pattern_view.setup(token.get("pattern", []), bool(token.get("show_origin", false)), tooltip)
		row.add_child(pattern_view)
		return
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.texture = ActionIcons.icon_texture(str(token.get("icon", "")))
	icon.expand_mode = 1
	icon.stretch_mode = 5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = tooltip
	row.add_child(icon)
	var value_text: String = ActionIcons.token_value_text(token)
	if value_text.is_empty():
		return
	var label := Label.new()
	label.text = value_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.tooltip_text = tooltip
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, label_size)
	label.add_theme_color_override("font_color", _token_value_color(token))
	label.add_theme_color_override("font_outline_color", Color("f8f1dd"))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)

func _summary_icon_size() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	return 15.0 if width <= COMPACT_CARD_WIDTH else 18.0

func _token_value_color(token: Dictionary) -> Color:
	match str(token.get("tone", "neutral")):
		"bonus":
			return Color(DAMAGE_BONUS_COLOR)
		"penalty":
			return Color(DAMAGE_PENALTY_COLOR)
		_:
			return Color(DAMAGE_NEUTRAL_COLOR)

func _display_card_def() -> Dictionary:
	return _card_override.duplicate(true) if not _card_override.is_empty() else GameData.card_def(card_id)

func _configure_cost_badge_icon(icon_key: String, has_text: bool) -> void:
	if _cost_badge_icon == null:
		return
	_cost_badge_icon.visible = not icon_key.is_empty()
	if icon_key.is_empty():
		_cost_badge_icon.texture = null
		_cost_badge_icon.tooltip_text = ""
		return
	_cost_badge_icon.texture = ActionIcons.icon_texture(icon_key)
	_cost_badge_icon.tooltip_text = ActionIcons.tooltip(icon_key)
	_cost_badge_icon.anchor_left = 0.0
	_cost_badge_icon.anchor_top = 0.0
	_cost_badge_icon.anchor_bottom = 1.0
	if has_text:
		_cost_badge_icon.anchor_right = 0.0
		_cost_badge_icon.offset_left = 5.0
		_cost_badge_icon.offset_top = 4.0
		_cost_badge_icon.offset_right = 19.0
		_cost_badge_icon.offset_bottom = -4.0
	else:
		_cost_badge_icon.anchor_right = 1.0
		_cost_badge_icon.offset_left = 5.0
		_cost_badge_icon.offset_top = 4.0
		_cost_badge_icon.offset_right = -5.0
		_cost_badge_icon.offset_bottom = -4.0

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _on_local_mouse_entered() -> void:
	_local_hovered = true
	_update_pose()

func _on_local_mouse_exited() -> void:
	_local_hovered = false
	_update_pose()

func _update_pose(immediate: bool = false) -> void:
	if not is_node_ready():
		return
	var lift: float = 0.0
	var target_scale: Vector2 = Vector2.ONE
	if _local_hovered and _interactive and not _dimmed:
		lift = HOVER_LIFT
		target_scale = Vector2.ONE * HOVER_SCALE
	elif _selected or _previewed:
		lift = SELECTED_LIFT
		target_scale = Vector2.ONE * SELECTED_SCALE
	z_index = 20 if lift < 0.0 else 0
	if _pose_tween != null:
		_pose_tween.kill()
	if top_level:
		scale = target_scale
		return
	if immediate or not is_inside_tree():
		position = Vector2(position.x, lift)
		scale = target_scale
		return
	_pose_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "position:y", lift, 0.12)
	_pose_tween.parallel().tween_property(self, "scale", target_scale, 0.12)
