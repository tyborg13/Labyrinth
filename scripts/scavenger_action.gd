extends Button
## Native actions with the Scavenger's own leather strap and brass, shaded type.
const Materials = preload("res://scripts/scavenger_materials.gd")
var surface: String = "action"
var reduced_motion: bool = false
var _label: Label
var _lift: float = 0.0
var _held: bool = false
var _keyboard: bool = false
var _last_text: String = ""
var _last_size: Vector2
var _last_font: int = 0
func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color", "font_outline_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	button_down.connect(func() -> void: _held = true)
	button_up.connect(func() -> void: _held = false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey: _keyboard = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton: _keyboard = false

func _active() -> bool:
	var router: Node = get_node_or_null("/root/InputRouter")
	return not disabled and (is_hovered() or (has_focus() and (_keyboard or (router != null and bool(router.call("using_controller"))))))

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var active: bool = _active()
	_lift = 0.0 if reduced_motion else lerpf(_lift, -2.0 if _held else 4.0 if active else 0.0, minf(delta * 24, 1))
	var font_size: int = get_theme_font_size("font_size")
	if _last_text != text or _last_size != size or _last_font != font_size:
		_last_text = text
		_last_size = size
		_last_font = font_size
		var inset: float = 9.0 if size.x < 100 else 38.0 if surface == "action" else 15.0
		_label.position = Vector2(inset, 7)
		_label.size = Vector2(size.x - inset * 2, size.y - 14)
		Materials.shade(_label, font_size, _label.size.y)
		_label.text = text
	_label.size.y = size.y - 14
	_label.position.y = 7 - _lift
	_label.modulate = Color(1.1, 1.05, 0.94) if active else Color(1, 1, 1, 0.44 if disabled else 1.0)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(0, -_lift), size)
	var active: bool = _active()
	var selected: bool = toggle_mode and button_pressed
	if active or selected:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0.8, 0.48, 0.14, 0.04)
		glow.shadow_color = Color(1.0, 0.6, 0.18, 0.20 if active else 0.12)
		glow.shadow_size = 12
		glow.set_corner_radius_all(10)
		draw_style_box(glow, rect.grow(-9))
	Materials.paint(self, "tray" if size.x < 100 else surface, rect, Color(0.70, 0.62, 0.5) if _held else Color(1.25, 1.12, 0.93) if active else Color(1, 1, 1, 0.42 if disabled else 1.0))
	if selected:
		draw_line(Vector2(size.x * 0.28, size.y - 8), Vector2(size.x * 0.72, size.y - 8), Color("f0c774"), 2.0, true)
