extends Control
class_name ControllerAnalogCursor

const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")

const CURSOR_DIAMETER: float = 20.0
const CURSOR_RADIUS: float = CURSOR_DIAMETER * 0.5
const DETAIL_GAP: float = 17.0

var _pointer_position: Vector2 = Vector2.ZERO
var _snapped_position: Vector2 = Vector2.ZERO
var _snap_strength: float = 0.0
var _candidate_kind: String = "tile"
var detail_builder: Callable
var _detail_key: String = ""
var _detail_panel: Control
var _detail_text: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 640
	z_as_relative = false
	visible = false
	set_process(false)

func show_cursor(
	pointer_position: Vector2,
	snapped_position: Vector2,
	snap_strength: float,
	candidate_kind: String,
	detail_text: String = "",
	detail_key: String = ""
) -> void:
	var normalized_strength: float = clampf(snap_strength, 0.0, 1.0)
	var normalized_detail: String = detail_text.strip_edges()
	var changed: bool = (
		not visible
		or not _pointer_position.is_equal_approx(pointer_position)
		or not _snapped_position.is_equal_approx(snapped_position)
		or not is_equal_approx(_snap_strength, normalized_strength)
		or _candidate_kind != candidate_kind
		or _detail_text != normalized_detail
		or _detail_key != detail_key
	)
	_pointer_position = pointer_position
	_snapped_position = snapped_position
	_snap_strength = normalized_strength
	_candidate_kind = candidate_kind
	visible = true
	_set_detail(normalized_detail, detail_key)
	if changed:
		queue_redraw()

func hide_cursor() -> void:
	visible = false
	# A later inspection may have different hand/slot availability.
	_set_detail("")

func display_position() -> Vector2:
	return _pointer_position.lerp(_snapped_position, _snap_strength)

func cursor_snapshot() -> Dictionary:
	return {
		"pointer_position": _pointer_position,
		"snapped_position": _snapped_position,
		"display_position": display_position(),
		"snap_strength": _snap_strength,
		"candidate_kind": _candidate_kind,
		"detail_text": _detail_text,
		"detail_key": _detail_key,
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

func _set_detail(text: String, key: String = "") -> void:
	var normalized: String = text.strip_edges()
	if normalized != _detail_text or key != _detail_key:
		_detail_text = normalized
		_detail_key = key
		if _detail_panel != null and is_instance_valid(_detail_panel):
			remove_child(_detail_panel)
			_detail_panel.queue_free()
		_detail_panel = null
		if not normalized.is_empty():
			# Reuse the game-wide tooltip surface instead of styling a one-off
			# controller bubble. This keeps typography and ornamentation native.
			if not key.is_empty() and detail_builder.is_valid():
				_detail_panel = detail_builder.call(key) as Control
			if _detail_panel == null:
				_detail_panel = UiTooltipPanel.make_text(normalized)
			_detail_panel.name = "ControllerCursorDetail"
			_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_detail_panel.z_index = 1
			add_child(_detail_panel)
	if _detail_panel != null:
		_detail_panel.visible = visible and not _detail_text.is_empty()
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
