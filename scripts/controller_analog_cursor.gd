extends Control
class_name ControllerAnalogCursor

const CURSOR_DIAMETER: float = 20.0
const CURSOR_RADIUS: float = CURSOR_DIAMETER * 0.5
const DETAIL_MAX_WIDTH: float = 330.0
const DETAIL_GAP: float = 17.0

var _pointer_position: Vector2 = Vector2.ZERO
var _snapped_position: Vector2 = Vector2.ZERO
var _snap_strength: float = 0.0
var _candidate_kind: String = "tile"
var _detail_panel: PanelContainer
var _detail_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 640
	z_as_relative = false
	visible = false
	_build_detail_panel()
	set_process(true)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func show_cursor(
	pointer_position: Vector2,
	snapped_position: Vector2,
	snap_strength: float,
	candidate_kind: String,
	detail_text: String = ""
) -> void:
	_pointer_position = pointer_position
	_snapped_position = snapped_position
	_snap_strength = clampf(snap_strength, 0.0, 1.0)
	_candidate_kind = candidate_kind
	visible = true
	_set_detail(detail_text)
	queue_redraw()

func hide_cursor() -> void:
	visible = false
	if _detail_panel != null:
		_detail_panel.visible = false

func display_position() -> Vector2:
	return _pointer_position.lerp(_snapped_position, _snap_strength)

func cursor_snapshot() -> Dictionary:
	return {
		"pointer_position": _pointer_position,
		"snapped_position": _snapped_position,
		"display_position": display_position(),
		"snap_strength": _snap_strength,
		"candidate_kind": _candidate_kind,
		"detail_text": _detail_label.text if _detail_label != null else "",
		"visible": visible,
	}

func _draw() -> void:
	var center: Vector2 = display_position() - global_position
	var accent: Color = _accent_color()
	# A plain, weighty puck makes the true analog pointer legible without looking
	# like a debug reticle or competing with the board's authored tile borders.
	draw_circle(center + Vector2(1.5, 2.5), CURSOR_RADIUS + 3.0, Color(0.02, 0.015, 0.01, 0.64))
	draw_circle(center, CURSOR_RADIUS + 1.5, Color("3a2413"))
	draw_circle(center, CURSOR_RADIUS, accent)
	draw_circle(center + Vector2(-2.6, -3.0), 2.2, Color(1.0, 0.96, 0.82, 0.76))
	_layout_detail_panel()

func _accent_color() -> Color:
	match _candidate_kind:
		"door":
			return Color("66e1dc")
		"control", "relic":
			return Color("d5b3ff")
		"enemy":
			return Color("f3b079")
		_:
			return Color("ffd26f")

func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "ControllerCursorDetail"
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.z_index = 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241a22e8")
	style.border_color = Color("c99bd8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 11.0
	style.content_margin_top = 7.0
	style.content_margin_right = 11.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 5
	_detail_panel.add_theme_stylebox_override("panel", style)
	add_child(_detail_panel)
	_detail_label = Label.new()
	_detail_label.name = "ControllerCursorDetailLabel"
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size.x = 180.0
	_detail_label.add_theme_font_size_override("font_size", 17)
	_detail_label.add_theme_color_override("font_color", Color("fff0d0"))
	_detail_label.add_theme_color_override("font_outline_color", Color("1c1116"))
	_detail_label.add_theme_constant_override("outline_size", 2)
	_detail_panel.add_child(_detail_label)
	_detail_panel.visible = false

func _set_detail(text: String) -> void:
	if _detail_panel == null or _detail_label == null:
		return
	var normalized: String = text.strip_edges()
	_detail_label.text = normalized
	_detail_label.custom_minimum_size.x = minf(
		DETAIL_MAX_WIDTH,
		maxf(180.0, _detail_label.get_theme_default_font().get_string_size(normalized).x + 8.0)
	)
	_detail_panel.visible = not normalized.is_empty()
	if _detail_panel.visible:
		_detail_panel.reset_size()
		call_deferred("_layout_detail_panel")

func _layout_detail_panel() -> void:
	if _detail_panel == null or not _detail_panel.visible:
		return
	var cursor: Vector2 = display_position() - global_position
	var panel_size: Vector2 = _detail_panel.get_combined_minimum_size()
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var desired := cursor + Vector2(CURSOR_RADIUS + DETAIL_GAP, -panel_size.y * 0.5)
	if desired.x + panel_size.x > viewport_rect.end.x - 12.0:
		desired.x = cursor.x - CURSOR_RADIUS - DETAIL_GAP - panel_size.x
	desired.x = clampf(desired.x, 12.0, maxf(12.0, viewport_rect.end.x - panel_size.x - 12.0))
	desired.y = clampf(desired.y, 12.0, maxf(12.0, viewport_rect.end.y - panel_size.y - 12.0))
	_detail_panel.position = desired
	_detail_panel.size = panel_size
