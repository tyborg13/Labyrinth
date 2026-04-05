extends Control
class_name SegmentedHealthBar

const HP_PER_SEGMENT: int = 20

@export var segment_count: int = 1
@export var value: float = 0.0
@export var max_value: float = 1.0
@export var background_color: Color = Color("493021")
@export var fill_color: Color = Color("5ba246")
@export var fill_highlight_color: Color = Color("88cf61")
@export var border_color: Color = Color("ecd7a3")
@export var separator_color: Color = Color(0.0, 0.0, 0.0, 0.35)
@export var separator_width: float = 2.0
@export var border_width: float = 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_health(next_value: float, next_max_value: float) -> void:
	value = next_value
	max_value = maxf(next_max_value, 1.0)
	queue_redraw()

func set_fill(next_fill_color: Color, next_highlight_color: Color) -> void:
	fill_color = next_fill_color
	fill_highlight_color = next_highlight_color
	queue_redraw()

func set_appearance(next_background: Color, next_border: Color, next_separator: Color) -> void:
	background_color = next_background
	border_color = next_border
	separator_color = next_separator
	queue_redraw()

func set_segment_count(next_segment_count: int) -> void:
	segment_count = maxi(1, next_segment_count)
	queue_redraw()

static func segment_count_for_max_hp(bar_max_value: float, hp_per_segment: int = HP_PER_SEGMENT) -> int:
	if hp_per_segment <= 0:
		return 1
	return maxi(1, int(ceili(bar_max_value / float(hp_per_segment))))

func _draw() -> void:
	draw_bar(
		self,
		Rect2(Vector2.ZERO, size),
		value,
		max_value,
		segment_count,
		background_color,
		fill_color,
		fill_highlight_color,
		border_color,
		separator_color,
		separator_width,
		border_width
	)

static func draw_bar(
	canvas: CanvasItem,
	rect: Rect2,
	bar_value: float,
	bar_max_value: float,
	bar_segment_count: int,
	bar_background_color: Color,
	bar_fill_color: Color,
	bar_fill_highlight_color: Color,
	bar_border_color: Color,
	bar_separator_color: Color,
	bar_separator_width: float = 2.0,
	bar_border_width: float = 1.0
) -> void:
	if canvas == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var ratio: float = clamp(bar_value / maxf(bar_max_value, 1.0), 0.0, 1.0)
	canvas.draw_rect(rect, bar_background_color, true)
	if ratio > 0.0:
		var fill_rect: Rect2 = Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		canvas.draw_rect(fill_rect, bar_fill_color, true)
		canvas.draw_rect(
			Rect2(fill_rect.position, Vector2(fill_rect.size.x, minf(fill_rect.size.y, 2.0))),
			bar_fill_highlight_color,
			true
		)
	var safe_segments: int = maxi(1, bar_segment_count)
	for idx: int in range(1, safe_segments):
		var separator_x: float = rect.position.x + rect.size.x * float(idx) / float(safe_segments)
		canvas.draw_rect(
			Rect2(
				Vector2(separator_x - bar_separator_width * 0.5, rect.position.y),
				Vector2(bar_separator_width, rect.size.y)
			),
			bar_separator_color,
			true
		)
	canvas.draw_rect(rect, bar_border_color, false, bar_border_width)
