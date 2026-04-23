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
const CARD_FRAME_PATH: String = "res://assets/art/ui/card_frame.png"
const CARD_FRAME_MARGIN: float = 34.0
const COMPACT_CARD_WIDTH: float = 190.0
const CARD_VERTICAL_CHROME: float = 82.0

class AoePatternView:
	extends Control

	const TILE_WIDTH: float = 16.0
	const TILE_HEIGHT: float = 10.0
	const TILE_PADDING: float = 5.0

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
@onready var details_panel: PanelContainer = $Margin/VBox/DetailsPanel
@onready var details_vbox: VBoxContainer = $Margin/VBox/DetailsPanel/DetailsMargin/DetailsVBox
@onready var desc_label: RichTextLabel = $Margin/VBox/DetailsPanel/DetailsMargin/DetailsVBox/Description
@onready var footer_label: Label = $Margin/VBox/DetailsPanel/DetailsMargin/DetailsVBox/Footer

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
var _rarity_notch: PanelContainer

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	text = ""
	title_label.add_theme_color_override("font_color", Color("39271b"))
	title_label.add_theme_color_override("font_outline_color", Color("f8f1dd"))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_ensure_rarity_notch()
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
	_configure_rarity_notch(str(card.get("rarity", "common")))
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
	var title_size: int = 14 if compact else 16
	var detail_size: int = 13 if compact else 15
	var badge_size: int = 12 if compact else 14
	UiTypography.set_label_size(title_label, title_size)
	UiTypography.set_label_size(cost_badge, badge_size)
	UiTypography.set_rich_text_size(desc_label, detail_size)
	UiTypography.set_label_size(footer_label, detail_size)
	var height: float = size.y if size.y > 0.0 else custom_minimum_size.y
	var art_height: float = clampf(width * 0.38, 62.0, 96.0)
	var details_height: float = clampf(width * 0.62, 100.0, 148.0)
	var available_body_height: float = maxf(146.0, height - CARD_VERTICAL_CHROME)
	var body_overflow: float = art_height + details_height - available_body_height
	if body_overflow > 0.0:
		var art_reduction: float = minf(body_overflow, art_height - 62.0)
		art_height -= art_reduction
		body_overflow -= art_reduction
		if body_overflow > 0.0:
			details_height = maxf(96.0, details_height - body_overflow)
	art_frame.custom_minimum_size = Vector2(0.0, art_height)
	details_panel.custom_minimum_size = Vector2(0.0, details_height)
	desc_label.custom_minimum_size = Vector2(0.0, details_height)
	footer_label.custom_minimum_size = Vector2.ZERO
	if _summary_icon_box != null:
		_summary_icon_box.custom_minimum_size = Vector2(0.0, details_height)
	pivot_offset = size * 0.5

func _apply_base_style(_background: Color, _border: Color, _usable: bool, _previewed: bool, _printed_playable: bool, _art_background: Color) -> void:
	var normal: StyleBoxTexture = _card_frame_style(0.0)
	var hover: StyleBoxTexture = _card_frame_style(2.0)
	var pressed: StyleBoxTexture = _card_frame_style(0.0)
	var disabled_style: StyleBoxTexture = _card_frame_style(0.0)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)
	art_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	details_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _card_frame_style(expand: float = 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = AssetLoader.load_texture(CARD_FRAME_PATH)
	style.texture_margin_left = CARD_FRAME_MARGIN
	style.texture_margin_top = CARD_FRAME_MARGIN
	style.texture_margin_right = CARD_FRAME_MARGIN
	style.texture_margin_bottom = CARD_FRAME_MARGIN
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.expand_margin_left = expand
	style.expand_margin_top = expand
	style.expand_margin_right = expand
	style.expand_margin_bottom = expand
	return style

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
	_summary_icon_box.add_theme_constant_override("separation", 5)
	details_vbox.add_child(_summary_icon_box)
	details_vbox.move_child(_summary_icon_box, desc_label.get_index() + 1)

func _ensure_cost_badge_icon() -> void:
	if _cost_badge_icon != null:
		return
	_cost_badge_icon = TextureRect.new()
	_cost_badge_icon.name = "KeywordIcon"
	_cost_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge_icon.expand_mode = 1
	_cost_badge_icon.stretch_mode = 5
	cost_badge.add_child(_cost_badge_icon)

func _ensure_rarity_notch() -> void:
	if _rarity_notch != null:
		return
	_rarity_notch = PanelContainer.new()
	_rarity_notch.name = "RarityNotch"
	_rarity_notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_notch.anchor_left = 0.5
	_rarity_notch.anchor_right = 0.5
	_rarity_notch.anchor_top = 1.0
	_rarity_notch.anchor_bottom = 1.0
	_rarity_notch.offset_left = -17.0
	_rarity_notch.offset_right = 17.0
	_rarity_notch.offset_top = -9.0
	_rarity_notch.offset_bottom = -3.0
	_rarity_notch.z_index = 4
	add_child(_rarity_notch)

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
	var label_size: int = 13 if icon_size <= 22.0 else 15
	var row_gap: int = 5 if icon_size <= 22.0 else 6
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		for segment: Array in _summary_token_segments(row_var as Array):
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", row_gap)
			for token_var: Variant in segment:
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
	return 22.0 if width <= COMPACT_CARD_WIDTH else 26.0

func _summary_token_segments(tokens: Array) -> Array:
	var clean_tokens: Array = []
	var contains_pattern: bool = false
	var valued_tokens: int = 0
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		clean_tokens.append(token)
		if str(token.get("kind", "")) == "aoe_pattern":
			contains_pattern = true
		if token.has("value"):
			valued_tokens += 1
	if clean_tokens.size() <= 3 and not contains_pattern:
		if clean_tokens.size() < 3 or valued_tokens < 3:
			return [clean_tokens]
	var max_tokens_per_segment: int = 2 if contains_pattern or valued_tokens >= 3 else 3
	var segments: Array = []
	var current: Array = []
	for token_var: Variant in clean_tokens:
		current.append(token_var)
		if current.size() >= max_tokens_per_segment:
			segments.append(current)
			current = []
	if not current.is_empty():
		segments.append(current)
	return segments

func _configure_rarity_notch(rarity: String) -> void:
	if _rarity_notch == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = _rarity_color(rarity)
	style.border_color = Color("3e2f22")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	_rarity_notch.add_theme_stylebox_override("panel", style)
	_rarity_notch.tooltip_text = rarity.capitalize()

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"starter":
			return Color("8f7654")
		"common":
			return Color("c7b37c")
		"uncommon":
			return Color("6b9c68")
		"rare":
			return Color("9f6fc4")
		_:
			return Color("a58f68")

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
		_cost_badge_icon.offset_top = 3.0
		_cost_badge_icon.offset_right = 24.0
		_cost_badge_icon.offset_bottom = -3.0
	else:
		_cost_badge_icon.anchor_right = 1.0
		_cost_badge_icon.offset_left = 5.0
		_cost_badge_icon.offset_top = 3.0
		_cost_badge_icon.offset_right = -5.0
		_cost_badge_icon.offset_bottom = -3.0

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
