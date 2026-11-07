extends Control
## Input-transparent attachment; the native button keeps its size and focus stop.
const Glyph = preload("res://scripts/input_glyph.gd")
const Router = preload("res://scripts/input_router.gd")
const BUTTON_HEIGHT: float = 26.0
const CORNER_HEIGHT: float = 30.0
const CORNER_INSET: float = 6.0
const CORNER_GAP: float = 6.0
const VIEWPORT_MARGIN: float = 4.0
const LABEL_GAP: float = 8.0
const TEXT_COLORS: Array[String] = Array([
	"font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
	"font_disabled_color", "font_hover_pressed_color", "font_outline_color",
], TYPE_STRING, "", null)

var action_name: StringName
var target: Control
var mode: String = "button"
var pulse_source: Control
var corner_anchor: Control
var _glyph: Control
var _source_label: Label
var _label: Label
var _colors: Dictionary = {}
var _label_offset: float = 0.0
var _last_label_x: float = INF
var _symbol_modulate: Variant
var _local_ui_unit := Vector2.ONE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_glyph = Glyph.new()
	_glyph.name = "InputGlyph"
	add_child(_glyph)
	if mode.begins_with("corner"):
		# Card lift/tuck tweens settle after _process. Follow their final geometry
		# for the frame that will actually be drawn, including viewport clamping.
		RenderingServer.frame_pre_draw.connect(_sync)
	_sync()

func configure(control: Control, action: StringName, placement: String, label: Label = null) -> void:
	target = control
	action_name = action
	mode = placement
	_source_label = label
	name = "GlyphBadge_%s" % action

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree(): return
	var router: Node = get_node_or_null("/root/InputRouter")
	var active: bool = router != null and router.using_controller() and target.is_visible_in_tree()
	visible = active
	if not active:
		_restore_content()
		return
	var family: String = str(router.controller_family())
	if _glyph.action_name != action_name or _glyph.family != family:
		_glyph.configure(action_name, family)
	# The viewport/UI transform supplies scale. Do not add Typography's separate
	# small-viewport type boost to the director's exact 26/30 layout-pixel art.
	var preferred: Vector2 = Glyph.preferred_size(action_name)
	var height: float = CORNER_HEIGHT if mode.begins_with("corner") else BUTTON_HEIGHT
	var inherited_scale: Vector2 = get_global_transform().get_scale().abs()
	if is_zero_approx(inherited_scale.x) or is_zero_approx(inherited_scale.y):
		visible = false
		return
	_local_ui_unit = Vector2.ONE / inherited_scale
	_glyph.custom_minimum_size = preferred
	_glyph.size = preferred
	_glyph.scale = _local_ui_unit * height / preferred.y
	var extent: Vector2 = preferred * _glyph.scale
	size = extent
	if mode == "button":
		_layout_button(extent)
	elif mode == "symbol":
		if is_instance_valid(_source_label):
			if _symbol_modulate == null: _symbol_modulate = _source_label.self_modulate
			_source_label.self_modulate = Color.TRANSPARENT
			position = (_source_label.size - extent) * 0.5
		else:
			_layout_button(extent)
			if _label != null: _label.text = ""
			position = (target.size - extent) * 0.5
	elif mode == "corner_bottom_right_inset":
		position = target.size - CORNER_INSET * _local_ui_unit - extent * 0.5
	elif mode == "corner_bottom_center":
		# Header icon buttons sit edge to edge: centre on the bottom edge so the
		# badge never reaches a neighbouring button.
		position = Vector2((target.size.x - extent.x) * 0.5, target.size.y - extent.y * 0.5)
	elif mode == "corner_top_right_inset":
		position = Vector2(target.size.x, 0.0) + Vector2(-CORNER_INSET, CORNER_INSET) * _local_ui_unit - extent * 0.5
	elif mode == "corner_anchor_before" or mode == "corner_anchor_below":
		var anchor: Control = corner_anchor if is_instance_valid(corner_anchor) else target
		var rect: Rect2 = anchor.get_global_transform() * Rect2(Vector2.ZERO, anchor.size)
		var global_extent: Vector2 = extent / _local_ui_unit
		if mode == "corner_anchor_before":
			global_position = Vector2(rect.position.x - CORNER_GAP - global_extent.x, rect.get_center().y - global_extent.y * 0.5)
		else:
			# Right-align the wider bumper with X: both remain left of the watch.
			global_position = Vector2(rect.end.x - global_extent.x, rect.end.y + CORNER_GAP)
			# A collapsed hand leaves no room below X: sit left of X on its row
			# instead of letting the viewport clamp push the bumper onto it.
			if global_position.y + global_extent.y > get_viewport_rect().end.y - VIEWPORT_MARGIN:
				global_position = Vector2(rect.position.x - CORNER_GAP - global_extent.x, rect.get_center().y - global_extent.y * 0.5)
	elif mode == "seal":
		# Reuse the seal's existing shortcut seat, retaining the state artwork.
		var seat: Control = target.get_node("Badge")
		position = seat.position + (seat.size - extent) * 0.5
	elif mode == "corner_before":
		position = Vector2(-extent.x, 0.0)
	elif mode == "corner_after":
		position = Vector2(target.size.x, 0.0)
	elif mode == "corner_right":
		position = Vector2(target.size.x - extent.x, 0.0)
	else:
		position = Vector2.ZERO
	if mode.begins_with("corner"):
		_clamp_corner_to_viewport()
	if is_instance_valid(pulse_source) and pulse_source.visible and bool(pulse_source.get_meta("attention_pulse", false)):
		var alpha: float = 1.0 if bool(pulse_source.get("_reduced_motion")) else 0.78 + 0.22 * sin(float(pulse_source.call("_pulse_msec")) * float(pulse_source.PULSE_RADIANS_PER_SECOND) / 1000.0)
		_glyph.modulate = Color(1, 1, 1, alpha)
	else:
		_glyph.modulate = Color.WHITE

func visual_rect() -> Rect2:
	return get_global_transform() * Rect2(Vector2.ZERO, size)

func _clamp_corner_to_viewport() -> void:
	var safe: Rect2 = get_viewport_rect().grow(-VIEWPORT_MARGIN)
	var rect: Rect2 = visual_rect()
	# Preserve the authored anchor on every axis that already clears the edge.
	global_position += Vector2(
		clampf(rect.position.x, safe.position.x, safe.end.x - rect.size.x) - rect.position.x,
		clampf(rect.position.y, safe.position.y, safe.end.y - rect.size.y) - rect.position.y
	)

func _layout_button(extent: Vector2) -> void:
	var gap: float = LABEL_GAP * _local_ui_unit.x
	if is_instance_valid(_source_label):
		if get_parent() is BoxContainer:
			# An existing internal caption row (Undo) centres its own children.
			# The row is inside a Button, so its minimum cannot resize the button.
			var row: BoxContainer = get_parent()
			custom_minimum_size = Vector2(extent.x + gap - row.get_theme_constant("separation"), extent.y)
			size_flags_vertical = Control.SIZE_SHRINK_CENTER
			return
		# Keep the real label (including its authored material, motion and ink).
		# Its caption moves half the glyph+gap reservation so the pair is centred.
		if is_equal_approx(_source_label.position.x, _last_label_x):
			_source_label.position.x -= _label_offset
		_label_offset = extent.x + gap
		_label_offset *= 0.5
		_source_label.position.x += _label_offset
		_last_label_x = _source_label.position.x
		var font: Font = _source_label.get_theme_font("font")
		var width: float = font.get_string_size(_source_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _source_label.get_theme_font_size("font_size")).x
		position = Vector2((_source_label.size.x - width) * 0.5 - gap - extent.x, (_source_label.size.y - extent.y) * 0.5)
		return
	var button := target as Button
	if button == null: return
	if _label == null:
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
	for key: String in TEXT_COLORS:
		var color: Color = button.get_theme_color(key)
		if color != Color.TRANSPARENT: _colors[key] = [button.has_theme_color_override(key), color]
		if color != Color.TRANSPARENT: button.add_theme_color_override(key, Color.TRANSPARENT)
	_label.text = button.text
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size)
	var color_key: String = "font_disabled_color" if button.disabled else "font_pressed_color" if button.is_pressed() else "font_hover_color" if button.is_hovered() else "font_focus_color" if button.has_focus() else "font_color"
	_label.add_theme_color_override("font_color", _saved_color(color_key))
	_label.add_theme_color_override("font_outline_color", _saved_color("font_outline_color"))
	_label.add_theme_constant_override("outline_size", button.get_theme_constant("outline_size"))
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	position = Vector2((button.size.x - text_width - gap - extent.x) * 0.5, (button.size.y - extent.y) * 0.5)
	_label.position = Vector2(extent.x + gap, (extent.y - button.size.y) * 0.5)
	_label.size = Vector2(text_width, button.size.y)

func _saved_color(key: String) -> Color:
	return _colors.get(key, _colors.get("font_color", [false, Color.WHITE]))[1]

func _restore_content() -> void:
	if is_instance_valid(_source_label) and _symbol_modulate != null:
		_source_label.self_modulate = _symbol_modulate
	_symbol_modulate = null
	if is_instance_valid(_source_label) and is_equal_approx(_source_label.position.x, _last_label_x):
		_source_label.position.x -= _label_offset
	_last_label_x = INF
	if is_instance_valid(target) and target is Button:
		for key: String in _colors:
			if _colors[key][0]: target.add_theme_color_override(key, _colors[key][1])
			else: target.remove_theme_color_override(key)
	_colors.clear()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)
	_restore_content()
