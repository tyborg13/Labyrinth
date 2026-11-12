extends Control
class_name SegmentedHealthBar

const HP_PER_SEGMENT: int = 2
const WidgetBatch = preload("res://scripts/widget_triangle_batch.gd")
const HealthGhostTracker = preload("res://scripts/health_ghost_tracker.gd")

var _triangle_batch := WidgetBatch.new()
var _separator_batch := WidgetBatch.new()
var _draw_inputs: Array = []
var _redraw_inputs: Array = []

var ghost_tracker: RefCounted
var ghost_key: String = ""
var ghost_color: Color = Color.TRANSPARENT

func bind_ghost(tracker: RefCounted, key: String, enemy: bool) -> void:
	var next_color: Color = HealthGhostTracker.ENEMY_GHOST_COLOR if enemy else HealthGhostTracker.ALLY_GHOST_COLOR
	if ghost_tracker == tracker and ghost_key == key and ghost_color == next_color:
		_request_redraw()
		return
	if ghost_tracker != tracker:
		if ghost_tracker != null and ghost_tracker.changed.is_connected(_ghost_changed):
			ghost_tracker.changed.disconnect(_ghost_changed)
		ghost_tracker = tracker
		if ghost_tracker != null:
			ghost_tracker.changed.connect(_ghost_changed)
	ghost_key = key
	ghost_color = next_color
	_request_redraw()

func _ghost_changed() -> void:
	# The shared tracker notifies every bar, including while another actor
	# animates or this actor's damage ghost is holding at the same position.
	_request_redraw()

func _draw_key(ghost: Dictionary) -> Array:
	return [size, value, max_value, segment_count, background_color, fill_color,
		fill_highlight_color, border_color, separator_color, separator_width,
		border_width, ghost_color, ghost]

func _request_redraw() -> void:
	# Compare every input, not just setter arguments: observe() can change max
	# HP without emitting changed, and reduced motion changes the ghost sample.
	var inputs: Array = _draw_key(ghost_sample())
	if inputs == _redraw_inputs: return
	_redraw_inputs = inputs
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
		_request_redraw()

func set_health(next_value: float, next_max_value: float) -> void:
	next_max_value = maxf(next_max_value, 1.0)
	value = next_value
	max_value = next_max_value
	_request_redraw()

func set_fill(next_fill_color: Color, next_highlight_color: Color) -> void:
	fill_color = next_fill_color
	fill_highlight_color = next_highlight_color
	_request_redraw()

func set_appearance(next_background: Color, next_border: Color, next_separator: Color) -> void:
	background_color = next_background
	border_color = next_border
	separator_color = next_separator
	_request_redraw()

func set_segment_count(next_segment_count: int) -> void:
	next_segment_count = maxi(1, next_segment_count)
	segment_count = next_segment_count
	_request_redraw()

static func segment_count_for_max_hp(bar_max_value: float, hp_per_segment: int = HP_PER_SEGMENT) -> int:
	if hp_per_segment <= 0:
		return 1
	return maxi(1, int(ceili(bar_max_value / float(hp_per_segment))))

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	var ghost: Dictionary = ghost_sample()
	_redraw_inputs = _draw_key(ghost)
	var ghost_range: Vector2 = ghost.get("ghost_range", Vector2.ZERO)
	var batch_faces: bool = ghost_range.y <= ghost_range.x and float(ghost.get("heal_flash", 0.0)) <= 0.0
	# Animated ghost/heal faces stay native: rebuilding their triangles each
	# sample costs more CPU than the original commands. Stable bars retain the
	# complete faces and separators without per-segment work or vertex hashing.
	if batch_faces:
		var inputs: Array = _redraw_inputs
		if inputs == _draw_inputs:
			_triangle_batch.replay(self)
			_separator_batch.replay(self)
			_draw_border(self, Rect2(Vector2.ZERO, size), border_color, border_width)
			return
		_draw_inputs = inputs.duplicate(true)
		_triangle_batch.health_faces(Rect2(Vector2.ZERO, size), float(ghost.get("hp", value)), float(ghost.get("max_hp", max_value)), background_color, fill_color, fill_highlight_color)
		_triangle_batch.flush(self)
		_separator_batch.draw_separators(self, Rect2(Vector2.ZERO, size), maxi(1, segment_count), separator_width, separator_color)
		_draw_border(self, Rect2(Vector2.ZERO, size), border_color, border_width)
		return
	else:
		_draw_inputs.clear()
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
	heal_flash: float = 0.0,
	triangle_batch: RefCounted = null
) -> void:
	if canvas == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var ratio: float = clamp(bar_value / maxf(bar_max_value, 1.0), 0.0, 1.0)
	# The well and fill share the authored bounds: depth must never suggest
	# extra health or change where a projected-damage band starts.
	_draw_vertical_shade(canvas, rect, bar_background_color.darkened(0.24), bar_background_color, triangle_batch)
	var ghost_rect: Rect2 = range_rect(rect, ghost_range, bar_max_value)
	if ghost_rect.size.x > 0.0:
		if triangle_batch != null: triangle_batch.flush(canvas)
		canvas.draw_rect(ghost_rect, bar_ghost_color, true)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		var shoulder: float = fill_rect.size.y * 0.35
		var lit_color: Color = bar_fill_color.lerp(bar_fill_highlight_color, 0.56)
		_draw_vertical_shade(canvas, Rect2(fill_rect.position, Vector2(fill_rect.size.x, shoulder)), bar_fill_color, lit_color, triangle_batch)
		_draw_vertical_shade(canvas, Rect2(fill_rect.position + Vector2(0.0, shoulder), Vector2(fill_rect.size.x, fill_rect.size.y - shoulder)), lit_color, bar_fill_color.darkened(0.32), triangle_batch)
		if triangle_batch != null: triangle_batch.flush(canvas)
		canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, minf(fill_rect.size.y, 1.0))), bar_fill_highlight_color, true)
		if ratio < 1.0:
			var cap_width: float = minf(1.0, fill_rect.size.x)
			canvas.draw_rect(Rect2(Vector2(fill_rect.end.x - cap_width, fill_rect.position.y), Vector2(cap_width, fill_rect.size.y)), bar_fill_highlight_color.lerp(bar_fill_color, 0.38), true)
	if triangle_batch != null: triangle_batch.flush(canvas)
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
	_draw_border(canvas, rect, bar_border_color, bar_border_width)

static func range_rect(rect: Rect2, hp_range: Vector2, bar_max_value: float) -> Rect2:
	var start: float = clampf(hp_range.x / maxf(bar_max_value, 1.0), 0.0, 1.0)
	var end: float = clampf(hp_range.y / maxf(bar_max_value, 1.0), start, 1.0)
	return Rect2(rect.position + Vector2(rect.size.x * start, 0.0), Vector2(rect.size.x * (end - start), rect.size.y))

# A pair of vertically shaded faces gives the small meter an inset, enamel
# finish without textures, animation, extra nodes or new layout.
static func _draw_vertical_shade(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, triangle_batch: RefCounted = null) -> void:
	if triangle_batch != null:
		triangle_batch.polygon(
			PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([top, top, bottom, bottom])
		)
		return
	canvas.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom])
	)

static func _draw_border(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	canvas.draw_rect(rect, color, false, width)
