extends Control
class_name SegmentedHealthBar

const HP_PER_SEGMENT: int = 2
const HealthGhostTracker = preload("res://scripts/health_ghost_tracker.gd")

var ghost_tracker: RefCounted
var ghost_key: String = ""
var ghost_color: Color = Color.TRANSPARENT

func bind_ghost(tracker: RefCounted, key: String, enemy: bool) -> void:
	if ghost_tracker != tracker:
		if ghost_tracker != null and ghost_tracker.changed.is_connected(queue_redraw):
			ghost_tracker.changed.disconnect(queue_redraw)
		ghost_tracker = tracker
		if ghost_tracker != null:
			ghost_tracker.changed.connect(queue_redraw)
	ghost_key = key
	ghost_color = HealthGhostTracker.ENEMY_GHOST_COLOR if enemy else HealthGhostTracker.ALLY_GHOST_COLOR
	queue_redraw()

func ghost_sample() -> Dictionary:
	return ghost_tracker.sample(ghost_key) if ghost_tracker != null else {}

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
	var ghost: Dictionary = ghost_sample()
	draw_bar(
		self,
		Rect2(Vector2.ZERO, size),
		float(ghost.get("hp", value)),
		float(ghost.get("max_hp", max_value)),
		segment_count,
		background_color,
		fill_color,
		fill_highlight_color,
		border_color,
		separator_color,
		separator_width,
		border_width,
		ghost.get("ghost_range", Vector2.ZERO),
		ghost_color,
		ghost.get("heal_range", Vector2.ZERO),
		float(ghost.get("heal_flash", 0.0))
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
	bar_border_width: float = 1.0,
	ghost_range: Vector2 = Vector2.ZERO,
	bar_ghost_color: Color = Color.TRANSPARENT,
	heal_range: Vector2 = Vector2.ZERO,
	heal_flash: float = 0.0
) -> void:
	if canvas == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var ratio: float = clamp(bar_value / maxf(bar_max_value, 1.0), 0.0, 1.0)
	# The well and fill share the authored bounds: depth must never suggest
	# extra health or change where a projected-damage band starts.
	_draw_vertical_shade(canvas, rect, bar_background_color.darkened(0.24), bar_background_color)
	var ghost_rect: Rect2 = range_rect(rect, ghost_range, bar_max_value)
	if ghost_rect.size.x > 0.0:
		canvas.draw_rect(ghost_rect, bar_ghost_color, true)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		var shoulder: float = fill_rect.size.y * 0.35
		var lit_color: Color = bar_fill_color.lerp(bar_fill_highlight_color, 0.56)
		_draw_vertical_shade(canvas, Rect2(fill_rect.position, Vector2(fill_rect.size.x, shoulder)), bar_fill_color, lit_color)
		_draw_vertical_shade(canvas, Rect2(fill_rect.position + Vector2(0.0, shoulder), Vector2(fill_rect.size.x, fill_rect.size.y - shoulder)), lit_color, bar_fill_color.darkened(0.32))
		canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, minf(fill_rect.size.y, 1.0))), bar_fill_highlight_color, true)
		if ratio < 1.0:
			var cap_width: float = minf(1.0, fill_rect.size.x)
			canvas.draw_rect(Rect2(Vector2(fill_rect.end.x - cap_width, fill_rect.position.y), Vector2(cap_width, fill_rect.size.y)), bar_fill_highlight_color.lerp(bar_fill_color, 0.38), true)
	var heal_rect: Rect2 = range_rect(rect, Vector2(heal_range.x, minf(heal_range.y, bar_value)), bar_max_value)
	if heal_flash > 0.0 and heal_rect.size.x > 0.0:
		var flash_color: Color = bar_fill_color.lightened(HealthGhostTracker.HEAL_LIGHTEN_AMOUNT)
		flash_color.a *= clampf(heal_flash, 0.0, 1.0)
		canvas.draw_rect(heal_rect, flash_color, true)
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

static func range_rect(rect: Rect2, hp_range: Vector2, bar_max_value: float) -> Rect2:
	var start: float = clampf(hp_range.x / maxf(bar_max_value, 1.0), 0.0, 1.0)
	var end: float = clampf(hp_range.y / maxf(bar_max_value, 1.0), start, 1.0)
	return Rect2(rect.position + Vector2(rect.size.x * start, 0.0), Vector2(rect.size.x * (end - start), rect.size.y))

# A pair of vertically shaded faces gives the small meter an inset, enamel
# finish without textures, animation, extra nodes or new layout.
static func _draw_vertical_shade(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	canvas.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom])
	)
