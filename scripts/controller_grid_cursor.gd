extends Control
class_name ControllerGridCursor

const UiTypography = preload("res://scripts/ui_typography.gd")

const BOARD_COLOR := Color("f2c66d")
const CONTROL_COLOR := Color("a9ddff")

var _board_mode: bool = true
var _caption: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(92.0, 62.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	visible = false
	z_index = 230

func show_board_cursor(center: Vector2, tile_size: Vector2, caption: String = "") -> void:
	_board_mode = true
	_caption = caption
	size = Vector2(maxf(54.0, tile_size.x * 0.92), maxf(36.0, tile_size.y * 0.92))
	pivot_offset = size * 0.5
	global_position = center - size * 0.5
	visible = true
	queue_redraw()

func show_control_cursor(rect: Rect2, caption: String = "") -> void:
	_board_mode = false
	_caption = caption
	var padding := Vector2(8.0, 6.0)
	global_position = rect.position - padding
	size = rect.size + padding * 2.0
	pivot_offset = size * 0.5
	visible = true
	queue_redraw()

func hide_cursor() -> void:
	visible = false

func _draw() -> void:
	if _board_mode:
		_draw_board_diamond()
	else:
		_draw_control_brackets()
	if not _caption.is_empty():
		_draw_caption()

func _draw_board_diamond() -> void:
	var center: Vector2 = size * 0.5
	var half := Vector2(size.x * 0.49, size.y * 0.45)
	var points := PackedVector2Array([
		center + Vector2(0.0, -half.y),
		center + Vector2(half.x, 0.0),
		center + Vector2(0.0, half.y),
		center + Vector2(-half.x, 0.0),
	])
	draw_colored_polygon(points, Color(BOARD_COLOR, 0.10))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.05, 0.02, 0.01, 0.82), 6.0, true)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), BOARD_COLOR, 3.0, true)

func _draw_control_brackets() -> void:
	var color: Color = CONTROL_COLOR
	var shadow := Color(0.02, 0.03, 0.05, 0.86)
	var length: float = minf(18.0, minf(size.x, size.y) * 0.24)
	var corners := [Vector2(2.0, 2.0), Vector2(size.x - 2.0, 2.0), Vector2(size.x - 2.0, size.y - 2.0), Vector2(2.0, size.y - 2.0)]
	var directions := [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0)]
	for index: int in range(corners.size()):
		var corner: Vector2 = corners[index]
		var direction: Vector2 = directions[index]
		for width: float in [7.0, 3.0]:
			var ink: Color = shadow if width > 3.0 else color
			draw_line(corner, corner + Vector2(direction.x * length, 0.0), ink, width, true)
			draw_line(corner, corner + Vector2(0.0, direction.y * length), ink, width, true)

func _draw_caption() -> void:
	var font: Font = UiTypography.ui_font()
	if font == null:
		font = get_theme_default_font()
	var font_size: int = 13
	var text_size: Vector2 = font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var rect := Rect2(Vector2((size.x - text_size.x) * 0.5 - 6.0, size.y - 4.0), text_size + Vector2(12.0, 6.0))
	draw_style_box(_caption_style(), rect)
	draw_string(font, rect.position + Vector2(6.0, text_size.y), _caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("fff2cb"))

func _caption_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.04, 0.95)
	style.border_color = Color("9c7542")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
