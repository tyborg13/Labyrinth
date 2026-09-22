extends Button
## Shelf-object material response. Native input and the shop's hover scale remain
## authoritative; this control animates paint and its existing content press only.
const Materials = preload("res://scripts/scavenger_materials.gd")
const RESPONSE_SECONDS: float = 0.12

var chosen: bool = false:
	set(value):
		if chosen == value: return
		chosen = value
		_request_response()
var pack: bool = false:
	set(value):
		pack = value
		queue_redraw()
var reduced_motion: bool = false:
	set(value):
		if reduced_motion == value: return
		reduced_motion = value
		_request_response()

# active, physical press, selected. Never move or resize the Button itself.
var _paint := Vector3.ZERO
var _from := Vector3.ZERO
var _target := Vector3.ZERO
var _elapsed: float = RESPONSE_SECONDS

func _ready() -> void:
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	for state_signal: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]:
		state_signal.connect(_request_response)
	visibility_changed.connect(_visibility_changed)
	resized.connect(queue_redraw)
	_snap_response()

func _state_target() -> Vector3:
	return Vector3(
		1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,
		1.0 if not disabled and is_pressed() else 0.0,
		1.0 if chosen else 0.0
	)

func _request_response() -> void:
	if not is_node_ready(): return
	var next: Vector3 = _state_target()
	if reduced_motion or disabled or not is_visible_in_tree():
		_snap_response()
		return
	if next == _target: return
	_from = _paint
	_target = next
	_elapsed = 0.0
	set_process(true)
	queue_redraw()

func _snap_response() -> void:
	_target = _state_target()
	_paint = _target
	_from = _target
	_elapsed = RESPONSE_SECONDS
	set_process(false)
	_apply_content_response()
	queue_redraw()

func _visibility_changed() -> void:
	# Hiding/rebuilding a shelf never leaves a dormant animation running.
	_snap_response()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or reduced_motion or disabled:
		_snap_response()
		return
	_elapsed = minf(RESPONSE_SECONDS, _elapsed + delta)
	var t: float = _elapsed / RESPONSE_SECONDS
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	_paint = _from.lerp(_target, eased)
	_apply_content_response()
	queue_redraw()
	if _elapsed >= RESPONSE_SECONDS:
		set_process(false)

func _apply_content_response() -> void:
	var content: Control = get_node_or_null("CenteredOfferContent") as Control
	if content != null:
		content.position.y = 0.0 if reduced_motion else _paint.y * 2.0
		content.modulate = Color.WHITE.lerp(Color(0.78, 0.71, 0.60), _paint.y)

func material_snapshot() -> Dictionary:
	return {"active": _paint.x, "press": _paint.y, "chosen": _paint.z, "processing": is_processing()}

func _draw() -> void:
	# BaseButton redraws on disabled changes but exposes no disabled signal.
	# Reset a settled press here as well as during a running response; no idle
	# polling is needed, and enabling again can resume the native hover state.
	if disabled and (_paint.x > 0.0 or _paint.y > 0.0):
		_snap_response()
	elif _state_target() != _target:
		_request_response()
	var active: float = _paint.x if not disabled else 0.0
	var selection: float = _paint.z
	var press: float = _paint.y if not disabled else 0.0
	var accent := Color("edbe72")
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.TRANSPARENT
	frame.set_corner_radius_all(8)
	frame.set_border_width_all(1 if pack or selection > 0.001 or active > 0.001 else 0)
	frame.border_color = Color(accent, maxf(0.24 if pack else 0.0, maxf(0.9 * selection, 0.6 * active)))
	frame.shadow_color = Color(1.0, 0.52, 0.15, maxf(0.17 * active, 0.09 * selection) * (1.0 - 0.35 * press))
	frame.shadow_size = 16
	if pack:
		Materials.paint(self, "tray", Rect2(Vector2(3, 2), size - Vector2(6, 4)), Color(0.80, 0.74, 0.63))
	var rect := Rect2(Vector2(5, 4), size - Vector2(10, 8))
	draw_style_box(frame, rect)
	# Quiet reflected upper lip and dark contact edge use the same brass/light
	# vocabulary as shared inset surfaces; their paint stays inside the ware.
	var light: float = maxf(active * 0.42, selection * 0.28)
	if light > 0.001:
		draw_line(rect.position + Vector2(9, 1), Vector2(rect.end.x - 9, rect.position.y + 1), Color(1.0, 0.88, 0.66, light * (1.0 - 0.45 * press)), 1.0, true)
		draw_line(Vector2(rect.position.x + 9, rect.end.y - 1), rect.end - Vector2(9, 1), Color(0.025, 0.012, 0.008, light + press * 0.16), 2.0, true)
	if chosen:
		draw_line(Vector2(size.x * 0.25, size.y - 2), Vector2(size.x * 0.75, size.y - 2), accent, 3, true)
		var middle := Vector2(size.x * 0.5, size.y - 2)
		draw_colored_polygon(PackedVector2Array([middle + Vector2(-5, 0), middle + Vector2(0, -5), middle + Vector2(5, 0), middle + Vector2(0, 5)]), accent)
