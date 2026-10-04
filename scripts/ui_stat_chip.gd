extends Control

# setup(icon, value_text, caption, value_color = GOLD_BRIGHT). Content determines
# minimum width; the 44px pill reuses a non-interactive 30px socket.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Socket = preload("res://scripts/ui_socket.gd")

var _socket: Button = Socket.new()
var _value := Label.new()
var _caption := Label.new()
var _value_color: Color = Palette.GOLD_BRIGHT

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_socket.name = "Socket"
	_socket.socket_size = 30.0
	_socket.interactive = false
	_value.name = "Value"
	_caption.name = "Caption"
	add_child(_socket)
	add_child(_value)
	add_child(_caption)
	resized.connect(_layout)
	setup(null, "", "")

func _ready() -> void:
	_layout()
	update_minimum_size()

func setup(icon: Texture2D, value_text: String, caption: String, value_color: Color = Palette.GOLD_BRIGHT) -> void:
	_socket.setup(icon)
	_value.text = value_text
	_caption.text = caption
	_value_color = value_color
	_layout()
	update_minimum_size()

func _get_minimum_size() -> Vector2:
	return Vector2(Typography.scaled_value(self, 68.0) + _value.get_minimum_size().x + _caption.get_minimum_size().x, Typography.scaled_value(self, 44.0))

func _layout() -> void:
	Surface.label_style(_value, 22, _value_color)
	_value.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	Typography.apply_eyebrow(_caption, 13, Palette.TEXT_2)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var scale_value: float = Typography.ui_scale(self)
	_socket.position = Vector2(7.0 * scale_value, (size.y - 30.0 * scale_value) * 0.5)
	_socket.size = Vector2.ONE * 30.0 * scale_value
	_value.size = _value.get_minimum_size()
	_value.position = Vector2(45.0 * scale_value, floorf((size.y - _value.size.y) * 0.5))
	var value_ascent: float = _value.get_theme_font("font").get_ascent(_value.get_theme_font_size("font_size"))
	var caption_ascent: float = _caption.get_theme_font("font").get_ascent(_caption.get_theme_font_size("font_size"))
	_caption.size = _caption.get_minimum_size()
	_caption.position = Vector2(_value.position.x + _value.size.x + 8.0 * scale_value, _value.position.y + value_ascent - caption_ascent)
	queue_redraw()

func _draw() -> void:
	Surface.draw_plate(self, Rect2(Vector2.ZERO, size), Palette.INK_2, Palette.INK_1, size.y * 0.5, Color(Palette.GOLD, 0.35))
