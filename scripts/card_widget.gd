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
const CONDITIONAL_TEXT_COLOR: String = "#fff7df"
const CONDITIONAL_OUTLINE_COLOR: String = "#24160f"
const CARD_FRAME_PATH: String = "res://assets/art/ui/card_frame.png"
const CARD_FRAME_STARTER_PATH: String = "res://assets/art/ui/card_frame_rarity_starter.png"
const CARD_FRAME_COMMON_PATH: String = "res://assets/art/ui/card_frame_rarity_common.png"
const CARD_FRAME_UNCOMMON_PATH: String = "res://assets/art/ui/card_frame_rarity_uncommon.png"
const CARD_FRAME_RARE_PATH: String = "res://assets/art/ui/card_frame_rarity_rare.png"
const CARD_FRAME_MARGIN: float = 34.0
const COMPACT_CARD_WIDTH: float = 190.0
const CARD_VERTICAL_CHROME: float = 82.0
const ART_MIN_HEIGHT: float = 76.0
const ART_MAX_HEIGHT: float = 118.0
const DETAILS_MIN_HEIGHT: float = 92.0
const DETAILS_MAX_HEIGHT: float = 142.0
const SUMMARY_VERTICAL_PADDING: float = 10.0
const TITLE_MIN_SIZE: int = 10
const TITLE_FIT_RELIEF: int = 2
const TITLE_MAX_RENDER_SIZE: int = 15
const TITLE_NAMEPLATE_WIDTH_RATIO: float = 0.500
const HAND_TITLE_WIDTH_MAX: float = 236.0
const ELEMENT_FRAME_BAND: int = 42
const ELEMENT_FRAME_VALUE_MAX: float = 0.58
const ELEMENT_FRAME_SATURATION_MAX: float = 0.42
const ELEMENT_FRAME_SATURATION_FLOOR: float = 0.46
const ELEMENT_FRAME_TINT_BLEND: float = 0.78
const FIRE_FRAME_SATURATION_FLOOR: float = 0.68
const FIRE_FRAME_TINT_BLEND: float = 0.88
const FIRE_FRAME_VALUE_LIFT: float = 1.035

static var _elemental_frame_cache: Dictionary = {}

class AoePatternView:
	extends Control

	const TILE_WIDTH: float = 16.0
	const TILE_HEIGHT: float = 10.0
	const TILE_PADDING: float = 5.0

	var pattern_offsets: Array[Vector2i] = []
	var show_origin: bool = false
	var tile_scale: float = 1.0

	func setup(raw_pattern: Variant, next_show_origin: bool, next_tooltip: String, next_tile_scale: float = 1.0) -> void:
		pattern_offsets = _parse_offsets(raw_pattern)
		show_origin = next_show_origin
		tile_scale = clampf(next_tile_scale, 0.42, 1.0)
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
			return Vector2(34.0, 24.0) * tile_scale
		var bounds: Rect2 = _bounds_for_offsets(draw_offsets)
		var padding: float = _tile_padding()
		return Vector2(maxf(34.0 * tile_scale, bounds.size.x + padding * 2.0), maxf(24.0 * tile_scale, bounds.size.y + padding * 2.0))

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
			var tile_rect := Rect2(center - Vector2(_tile_width() * 0.5, _tile_height() * 0.5), Vector2(_tile_width(), _tile_height()))
			if first:
				rect = tile_rect
				first = false
			else:
				rect = rect.merge(tile_rect)
		return rect

	func _iso_center(offset: Vector2i) -> Vector2:
		return Vector2(float(offset.x - offset.y) * _tile_width() * 0.5, float(offset.x + offset.y) * _tile_height() * 0.5)

	func _draw_tile(center: Vector2, fill: Color, border: Color) -> void:
		var tile_width: float = _tile_width()
		var tile_height: float = _tile_height()
		var points := PackedVector2Array([
			center + Vector2(0.0, -tile_height * 0.5),
			center + Vector2(tile_width * 0.5, 0.0),
			center + Vector2(0.0, tile_height * 0.5),
			center + Vector2(-tile_width * 0.5, 0.0),
			center + Vector2(0.0, -tile_height * 0.5)
		])
		draw_colored_polygon(points, fill)
		draw_polyline(points, border, 1.0, true)

	func _tile_width() -> float:
		return TILE_WIDTH * tile_scale

	func _tile_height() -> float:
		return TILE_HEIGHT * tile_scale

	func _tile_padding() -> float:
		return TILE_PADDING * tile_scale

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
@onready var art_frame: PanelContainer = $Margin/VBox/ArtBleed/ArtFrame
@onready var art_rect: TextureRect = $Margin/VBox/ArtBleed/ArtFrame/Art
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

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	text = ""
	art_frame.clip_contents = true
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_label.add_theme_color_override("font_color", Color("39271b"))
	title_label.add_theme_color_override("font_outline_color", Color("f8f1dd"))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	desc_label.add_theme_color_override("default_color", Color("503d2c"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.scroll_following = false
	footer_label.visible = false
	footer_label.add_theme_color_override("font_color", Color("6d5841"))
	footer_label.add_theme_color_override("font_outline_color", Color("f5ecdb"))
	footer_label.add_theme_constant_override("outline_size", 1)
	_ensure_summary_icon_box()
	mouse_entered.connect(_on_local_mouse_entered)
	mouse_exited.connect(_on_local_mouse_exited)
	_update_layout_metrics()
	_apply_configuration()
	_queue_title_refit()

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
	return _tooltip_for_control_at(_summary_icon_box, global_point)

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
	title_label.text = str(card.get("name", card_id))
	_fit_title_label(_base_title_size())
	_queue_title_refit()
	_refresh_summary_display(card)
	footer_label.text = ""
	footer_label.visible = false
	art_rect.texture = AssetLoader.load_texture(str(card.get("art_path", "")))
	var accent: Color = ElementData.accent(element_id) if ElementData.is_elemental(element_id) else Color(str(card.get("accent", "#8a6b4a")))
	var background: Color = ElementData.card_background(element_id, _selected)
	if not ElementData.is_elemental(element_id):
		background = Color("ddd0bb") if _selected else Color("efe4cf")
	if _previewed and not _selected:
		background = background.lightened(0.03)
	if _dimmed:
		background = background.darkened(0.12)
	_apply_base_style(background, accent, _usable, _previewed, _printed_playable, ElementData.card_art_background(element_id), str(card.get("rarity", "common")), element_id)
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
	var detail_size: int = 13 if compact else 15
	_fit_title_label(_base_title_size())
	UiTypography.set_rich_text_size(desc_label, detail_size)
	UiTypography.set_label_size(footer_label, detail_size)
	var height: float = size.y if size.y > 0.0 else custom_minimum_size.y
	var art_min_height: float = 68.0 if compact else ART_MIN_HEIGHT
	var details_min_height: float = 104.0 if compact else DETAILS_MIN_HEIGHT
	var details_target: float = width * (0.62 if compact else 0.56)
	var art_height: float = clampf(width * 0.46, art_min_height, ART_MAX_HEIGHT)
	var details_height: float = clampf(details_target, details_min_height, DETAILS_MAX_HEIGHT)
	var available_body_height: float = maxf(148.0, height - CARD_VERTICAL_CHROME)
	var body_overflow: float = art_height + details_height - available_body_height
	if body_overflow > 0.0:
		var art_reduction: float = minf(body_overflow, art_height - art_min_height)
		art_height -= art_reduction
		body_overflow -= art_reduction
		if body_overflow > 0.0:
			details_height = maxf(details_min_height, details_height - body_overflow)
	art_frame.custom_minimum_size = Vector2(0.0, art_height)
	details_panel.custom_minimum_size = Vector2(0.0, details_height)
	desc_label.custom_minimum_size = Vector2(0.0, details_height)
	footer_label.custom_minimum_size = Vector2.ZERO
	if _summary_icon_box != null:
		_summary_icon_box.custom_minimum_size = Vector2(0.0, details_height)
	pivot_offset = size * 0.5

func _apply_base_style(_background: Color, _border: Color, _usable: bool, _previewed: bool, _printed_playable: bool, _art_background: Color, rarity: String, element_id: String) -> void:
	var normal: StyleBoxTexture = _card_frame_style(0.0, rarity, element_id)
	var hover: StyleBoxTexture = _card_frame_style(2.0, rarity, element_id)
	var pressed: StyleBoxTexture = _card_frame_style(0.0, rarity, element_id)
	var disabled_style: StyleBoxTexture = _card_frame_style(0.0, rarity, element_id)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)
	art_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	details_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _card_frame_style(expand: float = 0.0, rarity: String = "", element_id: String = ElementData.NONE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _card_frame_texture(rarity, element_id)
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

func _card_frame_texture(rarity: String, element_id: String) -> Texture2D:
	var base_path: String = _card_frame_path(rarity)
	var base_texture: Texture2D = AssetLoader.load_texture(base_path)
	if base_texture == null or not ElementData.is_elemental(element_id):
		return base_texture
	var cache_key: String = "%s|%s" % [base_path, element_id]
	if _elemental_frame_cache.has(cache_key):
		return _elemental_frame_cache.get(cache_key, base_texture)
	var image: Image = base_texture.get_image()
	if image == null or image.is_empty():
		_elemental_frame_cache[cache_key] = base_texture
		return base_texture
	var tinted_image: Image = image.duplicate()
	var accent_hsv: Vector3 = _color_to_hsv(_element_frame_tint_color(element_id))
	for y: int in range(tinted_image.get_height()):
		for x: int in range(tinted_image.get_width()):
			var pixel: Color = tinted_image.get_pixel(x, y)
			if not _is_element_frame_metal_pixel(pixel, Vector2i(x, y), Vector2i(tinted_image.get_width(), tinted_image.get_height())):
				continue
			var pixel_hsv: Vector3 = _color_to_hsv(pixel)
			var tinted_pixel: Color = Color.from_hsv(
				accent_hsv.x,
				_element_frame_saturation(element_id, accent_hsv),
				_element_frame_value(element_id, pixel_hsv.z),
				pixel.a
			)
			tinted_image.set_pixel(x, y, pixel.lerp(tinted_pixel, _element_frame_tint_blend(element_id)))
	var tinted_texture: Texture2D = ImageTexture.create_from_image(tinted_image)
	_elemental_frame_cache[cache_key] = tinted_texture
	return tinted_texture

func _element_frame_tint_color(element_id: String) -> Color:
	var accent: Color = ElementData.accent(element_id)
	if element_id == ElementData.FIRE:
		return accent.lerp(Color("e13f35"), 0.38)
	return accent

func _element_frame_saturation(element_id: String, accent_hsv: Vector3) -> float:
	if element_id == ElementData.FIRE:
		return clampf(maxf(FIRE_FRAME_SATURATION_FLOOR, accent_hsv.y * 1.02), 0.0, 0.86)
	return clampf(maxf(ELEMENT_FRAME_SATURATION_FLOOR, accent_hsv.y * 0.74), 0.0, 1.0)

func _element_frame_value(element_id: String, pixel_value: float) -> float:
	if element_id == ElementData.FIRE:
		return clampf(pixel_value * FIRE_FRAME_VALUE_LIFT, 0.0, 1.0)
	return pixel_value

func _element_frame_tint_blend(element_id: String) -> float:
	return FIRE_FRAME_TINT_BLEND if element_id == ElementData.FIRE else ELEMENT_FRAME_TINT_BLEND

func _is_element_frame_metal_pixel(pixel: Color, point: Vector2i, image_size: Vector2i) -> bool:
	if pixel.a < 0.08:
		return false
	var in_frame_band: bool = (
		point.x < ELEMENT_FRAME_BAND
		or point.x >= image_size.x - ELEMENT_FRAME_BAND
		or point.y < ELEMENT_FRAME_BAND
		or point.y >= image_size.y - ELEMENT_FRAME_BAND
	)
	if not in_frame_band:
		return false
	var hsv: Vector3 = _color_to_hsv(pixel)
	if hsv.z > ELEMENT_FRAME_VALUE_MAX:
		return false
	return hsv.y <= ELEMENT_FRAME_SATURATION_MAX

func _color_to_hsv(color: Color) -> Vector3:
	var max_channel: float = maxf(color.r, maxf(color.g, color.b))
	var min_channel: float = minf(color.r, minf(color.g, color.b))
	var chroma: float = max_channel - min_channel
	var hue: float = 0.0
	if chroma > 0.00001:
		if is_equal_approx(max_channel, color.r):
			hue = fmod((color.g - color.b) / chroma, 6.0) / 6.0
		elif is_equal_approx(max_channel, color.g):
			hue = (((color.b - color.r) / chroma) + 2.0) / 6.0
		else:
			hue = (((color.r - color.g) / chroma) + 4.0) / 6.0
		if hue < 0.0:
			hue += 1.0
	var saturation: float = 0.0 if max_channel <= 0.00001 else chroma / max_channel
	return Vector3(hue, saturation, max_channel)

func _card_frame_path(rarity: String) -> String:
	match rarity:
		"starter":
			return CARD_FRAME_STARTER_PATH
		"common":
			return CARD_FRAME_COMMON_PATH
		"uncommon":
			return CARD_FRAME_UNCOMMON_PATH
		"rare":
			return CARD_FRAME_RARE_PATH
		_:
			return CARD_FRAME_PATH

func _ensure_summary_icon_box() -> void:
	if _summary_icon_box != null:
		return
	_summary_icon_box = VBoxContainer.new()
	_summary_icon_box.name = "IconSummary"
	_summary_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_icon_box.add_theme_constant_override("separation", 5)
	details_vbox.add_child(_summary_icon_box)
	details_vbox.move_child(_summary_icon_box, desc_label.get_index() + 1)

func _refresh_summary_display(card: Dictionary) -> void:
	var rows: Array = _summary_rows.duplicate(true)
	if rows.is_empty() and _summary_bbcode.is_empty():
		rows = ActionIcons.rows_for_card(card)
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
	var row_groups: Array = []
	var rendered_rows: Array = []
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var raw_row: Array = row_var as Array
		var segments: Array = []
		for segment: Array in _summary_token_segments(row_var as Array):
			if not segment.is_empty():
				segments.append(segment)
				rendered_rows.append(segment)
		if not segments.is_empty():
			row_groups.append({
				"segments": segments,
				"condition": _row_condition_data(raw_row)
			})
	if rendered_rows.is_empty():
		return
	var metrics: Dictionary = _summary_layout_metrics(rendered_rows)
	var icon_size: float = float(metrics.get("icon_size", _summary_icon_size()))
	var label_size: int = int(metrics.get("label_size", 15))
	var row_gap: int = int(metrics.get("row_gap", 6))
	for group_var: Variant in row_groups:
		if typeof(group_var) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_var
		var condition: Dictionary = group.get("condition", {})
		var condition_element: String = str(condition.get("element", ""))
		var condition_active: bool = bool(condition.get("active", false))
		var segments: Array = group.get("segments", [])
		if condition_element.is_empty():
			for segment_var: Variant in segments:
				if typeof(segment_var) == TYPE_ARRAY:
					_add_summary_segment(_summary_icon_box, segment_var as Array, icon_size, label_size, row_gap)
			continue
		var block := PanelContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		block.add_theme_stylebox_override("panel", _conditional_summary_style(condition_element, condition_active))
		_summary_icon_box.add_child(block)
		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		margin.add_theme_constant_override("margin_left", 1)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_right", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		block.add_child(margin)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", maxi(0, row_gap - 4))
		margin.add_child(inner)
		for segment_var: Variant in segments:
			if typeof(segment_var) == TYPE_ARRAY:
				var segment: Array = segment_var as Array
				var conditional_icon_size: float = icon_size
				var conditional_label_size: int = label_size
				var conditional_row_gap: int = maxi(0, row_gap - 2)
				if _segment_should_compact_conditional(segment):
					conditional_icon_size = maxf(15.0, icon_size - 3.0)
					conditional_label_size = maxi(10, label_size - 2)
					conditional_row_gap = maxi(0, row_gap - 3)
				_add_summary_segment(inner, segment, conditional_icon_size, conditional_label_size, conditional_row_gap, true)

func _add_summary_segment(parent: Node, segment: Array, icon_size: float, label_size: int, row_gap: int, conditional: bool = false) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", row_gap)
	for token_var: Variant in segment:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		_add_token_to_summary_row(row, token_var as Dictionary, icon_size, label_size, conditional)
	if row.get_child_count() > 0:
		parent.add_child(row)

func _segment_should_compact_conditional(segment: Array) -> bool:
	var valued_tokens: int = 0
	for token_var: Variant in segment:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if token.has("value") and str(token.get("kind", "")) != "aoe_pattern":
			valued_tokens += 1
	return valued_tokens >= 3

func _row_condition_data(row: Array) -> Dictionary:
	for token_var: Variant in row:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "intensity_requirement":
			return {
				"element": str(token.get("element", "")),
				"active": bool(token.get("condition_active", false))
			}
	return {}

func _conditional_summary_style(element_id: String, active: bool = false) -> StyleBoxFlat:
	var accent: Color = ElementData.accent(element_id)
	var style := StyleBoxFlat.new()
	var fill: Color = Color(0.09, 0.065, 0.052).lerp(accent.darkened(0.38), 0.58)
	style.bg_color = Color(fill.r, fill.g, fill.b, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.98 if active else 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	if active:
		style.bg_color = Color(fill.r, fill.g, fill.b, 0.97).lightened(0.08)
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.36)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _add_token_to_summary_row(row: HBoxContainer, token: Dictionary, icon_size: float, label_size: int, conditional: bool = false) -> void:
	var tooltip: String = ActionIcons.token_tooltip(token)
	if str(token.get("kind", "")) == "aoe_pattern":
		var pattern_view := AoePatternView.new()
		pattern_view.setup(token.get("pattern", []), bool(token.get("show_origin", false)), tooltip, _aoe_pattern_scale(icon_size))
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
		if ActionIcons.token_is_modified(token):
			_add_token_modifier_marker(row, tooltip, label_size, conditional)
		return
	var label := Label.new()
	label.text = value_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.tooltip_text = tooltip
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, label_size)
	label.add_theme_color_override("font_color", _token_value_color(token, conditional))
	label.add_theme_color_override("font_outline_color", _token_outline_color(conditional))
	label.add_theme_constant_override("outline_size", 2 if conditional else 1)
	row.add_child(label)
	if ActionIcons.token_is_modified(token):
		_add_token_modifier_marker(row, tooltip, label_size, conditional)

func _add_token_modifier_marker(row: HBoxContainer, tooltip: String, label_size: int, conditional: bool = false) -> void:
	var marker := Label.new()
	marker.text = "+"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.tooltip_text = tooltip
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(marker, maxi(10, label_size - 1))
	marker.add_theme_color_override("font_color", Color(DAMAGE_BONUS_COLOR))
	marker.add_theme_color_override("font_outline_color", _token_outline_color(conditional))
	marker.add_theme_constant_override("outline_size", 2 if conditional else 1)
	row.add_child(marker)

func _summary_icon_size() -> float:
	var width: float = _card_visual_width()
	return 22.0 if width <= COMPACT_CARD_WIDTH else 26.0

func _aoe_pattern_scale(icon_size: float) -> float:
	var width: float = _card_visual_width()
	if width <= COMPACT_CARD_WIDTH:
		return clampf(icon_size / 40.0, 0.42, 0.78)
	return clampf(icon_size / 30.0, 0.52, 1.0)

func _summary_layout_metrics(rendered_rows: Array) -> Dictionary:
	var width: float = _card_visual_width()
	var compact: bool = width <= COMPACT_CARD_WIDTH
	var details_height: float = details_panel.custom_minimum_size.y if details_panel.custom_minimum_size.y > 0.0 else desc_label.custom_minimum_size.y
	var available_height: float = maxf(56.0, details_height - SUMMARY_VERTICAL_PADDING)
	var available_width: float = maxf(52.0, width - CARD_FRAME_MARGIN - 12.0)
	var icon_candidates: Array = [28.0, 26.0, 24.0, 22.0, 20.0, 18.0, 16.0] if compact else [30.0, 28.0, 26.0, 24.0, 22.0, 20.0]
	var row_count: int = maxi(1, rendered_rows.size())
	for candidate_var: Variant in icon_candidates:
		var icon_size: float = float(candidate_var)
		var label_size: int = maxi(12, int(round(icon_size * 0.58)))
		var row_gap: int = _summary_row_gap(icon_size, row_count)
		if _summary_height_estimate(row_count, icon_size, label_size, row_gap) <= available_height and _summary_width_estimate(rendered_rows, icon_size, label_size, row_gap) <= available_width:
			return {
				"icon_size": icon_size,
				"label_size": label_size,
				"row_gap": row_gap
			}
	var fallback_icon: float = float(icon_candidates[icon_candidates.size() - 1])
	return {
		"icon_size": fallback_icon,
		"label_size": maxi(12, int(round(fallback_icon * 0.58))),
		"row_gap": _summary_row_gap(fallback_icon, row_count)
	}

func _summary_row_gap(icon_size: float, row_count: int) -> int:
	var gap: int = 4 if icon_size <= 22.0 else 5 if icon_size <= 26.0 else 6
	if row_count >= 3:
		gap -= 1
	if row_count >= 4:
		gap -= 1
	return maxi(2, gap)

func _summary_height_estimate(row_count: int, icon_size: float, label_size: int, row_gap: int) -> float:
	var font: Font = UiTypography.default_font(self)
	var scaled_label_size: int = UiTypography.scaled_size(self, label_size)
	var label_height: float = float(scaled_label_size)
	if font != null:
		label_height = font.get_height(scaled_label_size)
	var row_height: float = maxf(icon_size, label_height)
	return row_height * float(row_count) + float(maxi(0, row_count - 1) * row_gap)

func _summary_width_estimate(rendered_rows: Array, icon_size: float, label_size: int, row_gap: int) -> float:
	var widest: float = 0.0
	for segment_var: Variant in rendered_rows:
		if typeof(segment_var) != TYPE_ARRAY:
			continue
		widest = maxf(widest, _summary_segment_width_estimate(segment_var as Array, icon_size, label_size, row_gap))
	return widest

func _summary_segment_width_estimate(segment: Array, icon_size: float, label_size: int, row_gap: int) -> float:
	var child_width: float = 0.0
	var child_count: int = 0
	for token_var: Variant in segment:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			child_width += maxf(34.0, icon_size * 1.5)
			child_count += 1
			continue
		child_width += icon_size
		child_count += 1
		var value_text: String = ActionIcons.token_value_text(token)
		if not value_text.is_empty():
			child_width += _summary_text_width(value_text, label_size)
			child_count += 1
		if ActionIcons.token_is_modified(token):
			child_width += _summary_text_width("+", maxi(10, label_size - 1))
			child_count += 1
	return child_width + float(maxi(0, child_count - 1) * row_gap)

func _summary_text_width(text: String, label_size: int) -> float:
	var scaled_label_size: int = UiTypography.scaled_size(self, label_size)
	var font: Font = UiTypography.default_font(self)
	if font == null:
		return float(text.length()) * float(scaled_label_size) * 0.62
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, scaled_label_size).x

func _card_visual_width() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	if width <= 0.0:
		width = COMPACT_CARD_WIDTH
	var scale_x: float = absf(scale.x)
	if is_inside_tree():
		scale_x = absf(get_global_transform().get_scale().x)
	if scale_x > 0.0 and scale_x < 0.98:
		return width * scale_x
	return width

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

func _token_value_color(token: Dictionary, conditional: bool = false) -> Color:
	if conditional:
		return Color(CONDITIONAL_TEXT_COLOR)
	match str(token.get("tone", "neutral")):
		"bonus":
			return Color(DAMAGE_BONUS_COLOR)
		"penalty":
			return Color(DAMAGE_PENALTY_COLOR)
		_:
			return Color(DAMAGE_NEUTRAL_COLOR)

func _token_outline_color(conditional: bool) -> Color:
	return Color(CONDITIONAL_OUTLINE_COLOR) if conditional else Color("f8f1dd")

func _display_card_def() -> Dictionary:
	return _card_override.duplicate(true) if not _card_override.is_empty() else GameData.card_def(card_id)

func _base_title_size() -> int:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	if width <= COMPACT_CARD_WIDTH:
		return 17
	if width <= HAND_TITLE_WIDTH_MAX:
		return 18
	return 19

func _queue_title_refit() -> void:
	if is_node_ready():
		call_deferred("_fit_title_label", _base_title_size())

func _fit_title_label(base_size: int) -> void:
	if title_label == null:
		return
	var font: Font = UiTypography.default_font(title_label)
	if font == null:
		UiTypography.set_label_size(title_label, _relieved_title_size(base_size))
		return
	var available_width: float = _title_nameplate_width()
	var available_height: float = maxf(28.0, title_label.custom_minimum_size.y)
	for candidate: int in range(base_size, TITLE_MIN_SIZE - 1, -1):
		var render_size: int = _relieved_title_size(candidate)
		var scaled_size: int = UiTypography.scaled_size(title_label, render_size)
		if _title_fits(font, title_label.text, scaled_size, available_width, available_height):
			UiTypography.set_label_size(title_label, render_size)
			return
	UiTypography.set_label_size(title_label, TITLE_MIN_SIZE)

func _relieved_title_size(candidate: int) -> int:
	return mini(TITLE_MAX_RENDER_SIZE, maxi(TITLE_MIN_SIZE, candidate - TITLE_FIT_RELIEF))

func _title_available_width() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var card_inner_width: float = maxf(80.0, width - 32.0)
	if title_label.size.x > 0.0:
		return minf(title_label.size.x, card_inner_width)
	var top_row: Control = title_label.get_parent() as Control
	if top_row != null and top_row.size.x > 0.0:
		return minf(top_row.size.x, card_inner_width)
	return card_inner_width

func _title_nameplate_width() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var visual_width: float = maxf(72.0, width * TITLE_NAMEPLATE_WIDTH_RATIO)
	return minf(_title_available_width(), visual_width)

func _title_fits(font: Font, title: String, font_size: int, available_width: float, available_height: float) -> bool:
	if title.strip_edges().is_empty():
		return true
	var longest_word_width: float = 0.0
	for word: String in title.split(" ", false):
		longest_word_width = maxf(longest_word_width, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var full_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var line_height: float = font.get_height(font_size)
	if longest_word_width > available_width:
		return false
	return full_width <= available_width and line_height <= available_height + 3.0

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
