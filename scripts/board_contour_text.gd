extends Control
## Bare board wordmark, sharing the enemy intent title's contour and baseline box.
const Type = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const OUTLINE_SIZE: float = 2.25
const SHADOW_OFFSET := Vector2(3.5, 4.5)
var text: String = "":
	set(value):
		text = value
		fit_text()
var font_size: int = 26:
	set(value):
		font_size = value
		fit_text()
var font: Font = Type.display_font()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func fit_text() -> void:
	if font == null: return
	size = Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, font.get_height(font_size))
	queue_redraw()

func _draw() -> void:
	draw_title(self, font, Vector2(0, font.get_ascent(font_size)), text, size.x, font_size)

static func draw_title(canvas: CanvasItem, display_font: Font, baseline: Vector2, value: String, width: float, pixels: int) -> void:
	canvas.draw_string(display_font, baseline + SHADOW_OFFSET, value, HORIZONTAL_ALIGNMENT_LEFT, width, pixels, Palette.BOARD_TITLE_SHADOW)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2.ONE]:
		canvas.draw_string(display_font, baseline + direction * OUTLINE_SIZE, value, HORIZONTAL_ALIGNMENT_LEFT, width, pixels, Palette.BOARD_TITLE_OUTLINE)
	canvas.draw_string(display_font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, width, pixels, Palette.BOARD_TITLE_FILL)
