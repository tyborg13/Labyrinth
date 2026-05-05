extends Control
class_name DeathEngulfOverlay

const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const HEADER_FONT = preload("res://fonts/LabyrinthCrumble-Header.tres")
const REGULAR_FONT = preload("res://fonts/LabyrinthCrumble-Regular.tres")

signal continue_pressed

const TITLE_TEXT: String = "DARKNESS FALLS"
const ENGULF_SECONDS: float = 1.85
const TITLE_REVEAL_SECONDS: float = 1.05
const BUTTON_FADE_SECONDS: float = 0.30
const BUTTON_DELAY_SECONDS: float = 0.14
const CONTINUE_BUTTON_HEIGHT: float = 54.0
const BLACK: Color = Color(0.0, 0.0, 0.0, 1.0)
const BLOOD_RED: Color = Color("9a0712")

const TENDRILS := [
	{"edge": "left", "lane": 0.13, "delay": 0.00, "reach": 1.03, "width": 36.0, "wobble": 0.18, "drift": 0.20, "phase": 0.20},
	{"edge": "left", "lane": 0.38, "delay": 0.07, "reach": 0.86, "width": 48.0, "wobble": 0.12, "drift": -0.12, "phase": 1.90},
	{"edge": "left", "lane": 0.74, "delay": 0.15, "reach": 0.98, "width": 32.0, "wobble": 0.16, "drift": -0.18, "phase": 3.10},
	{"edge": "right", "lane": 0.22, "delay": 0.05, "reach": 0.78, "width": 44.0, "wobble": 0.14, "drift": 0.18, "phase": 0.95},
	{"edge": "right", "lane": 0.55, "delay": 0.00, "reach": 1.08, "width": 34.0, "wobble": 0.18, "drift": 0.08, "phase": 2.45},
	{"edge": "right", "lane": 0.86, "delay": 0.12, "reach": 0.88, "width": 40.0, "wobble": 0.13, "drift": -0.16, "phase": 4.35},
	{"edge": "top", "lane": 0.18, "delay": 0.03, "reach": 0.90, "width": 42.0, "wobble": 0.14, "drift": 0.10, "phase": 1.35},
	{"edge": "top", "lane": 0.62, "delay": 0.11, "reach": 0.74, "width": 56.0, "wobble": 0.11, "drift": -0.14, "phase": 3.70},
	{"edge": "bottom", "lane": 0.31, "delay": 0.08, "reach": 1.04, "width": 38.0, "wobble": 0.17, "drift": 0.16, "phase": 2.75},
	{"edge": "bottom", "lane": 0.78, "delay": 0.02, "reach": 0.82, "width": 50.0, "wobble": 0.12, "drift": -0.10, "phase": 5.15}
]

var _ui_skin: UiSkin = UiSkin.new()
var _elapsed: float = 0.0
var _playing: bool = false
var _title_label: Label
var _continue_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	_build_children()

func play(_board: Control = null) -> void:
	_elapsed = 0.0
	_playing = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.visible = false
	_title_label.visible_characters = 0
	_continue_button.visible = false
	_continue_button.disabled = true
	_continue_button.modulate = Color(1.0, 1.0, 1.0, 0.0)
	set_process(true)
	_update_child_layout()
	queue_redraw()

func reset() -> void:
	_playing = false
	_elapsed = 0.0
	visible = false
	_title_label.visible = false
	_title_label.visible_characters = 0
	_continue_button.visible = false
	_continue_button.disabled = true
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += minf(delta, 1.0 / 30.0)
	_update_child_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		if _title_label == null or _continue_button == null:
			return
		_update_child_layout()
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var engulf_rect := Rect2(Vector2.ZERO, size)
	var engulf_t: float = clampf(_elapsed / ENGULF_SECONDS, 0.0, 1.0)
	if engulf_t >= 0.995:
		draw_rect(Rect2(Vector2.ZERO, size), BLACK, true)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.08 * engulf_t), true)
	_draw_edge_flood(engulf_rect, "left", engulf_t, 0.20, 0.76)
	_draw_edge_flood(engulf_rect, "right", engulf_t, 1.70, 0.70)
	_draw_edge_flood(engulf_rect, "top", engulf_t, 3.30, 0.62)
	_draw_edge_flood(engulf_rect, "bottom", engulf_t, 4.60, 0.68)
	for spec: Dictionary in TENDRILS:
		_draw_tendril(engulf_rect, spec, engulf_t)
	var final_cover: float = _smoothstep(0.84, 1.0, engulf_t)
	if final_cover > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, final_cover), true)

func _build_children() -> void:
	_title_label = Label.new()
	_title_label.text = TITLE_TEXT
	_title_label.visible = false
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_override("font", HEADER_FONT)
	_title_label.add_theme_color_override("font_color", BLOOD_RED)
	_title_label.add_theme_color_override("font_outline_color", Color("100204"))
	_title_label.add_theme_constant_override("outline_size", 6)
	add_child(_title_label)

	_continue_button = Button.new()
	_continue_button.text = "Begin again"
	_continue_button.visible = false
	_continue_button.disabled = true
	_continue_button.add_theme_font_override("font", REGULAR_FONT)
	_ui_skin.apply_button_stylebox_overrides(_continue_button)
	_ui_skin.apply_button_text_overrides(_continue_button, Color("f4d8d8"), Color("170304"), 2)
	UiTypography.set_button_size(_continue_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(_continue_button, CONTINUE_BUTTON_HEIGHT)
	_continue_button.pressed.connect(func() -> void:
		if not _continue_button.disabled:
			continue_pressed.emit()
	)
	add_child(_continue_button)

func _update_child_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var title_font_size: int = _fitted_title_font_size()
	_title_label.add_theme_font_size_override("font_size", title_font_size)
	var title_font: Font = HEADER_FONT
	var title_size: Vector2 = title_font.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size)
	title_size.y = maxf(title_size.y, title_font.get_height(title_font_size))
	title_size += Vector2(28.0, 18.0)
	_title_label.size = title_size
	var title_y: float = maxf(24.0, (size.y - title_size.y) * 0.50)
	var text_t: float = clampf((_elapsed - ENGULF_SECONDS) / TITLE_REVEAL_SECONDS, 0.0, 1.0)
	var center_x: float = (size.x - title_size.x) * 0.5
	_title_label.position = Vector2(center_x, title_y)
	_title_label.visible = text_t > 0.0
	_title_label.visible_characters = int(round(float(TITLE_TEXT.length()) * _ease_out_cubic(text_t)))
	_title_label.modulate = Color.WHITE

	var button_alpha: float = clampf(
		(_elapsed - ENGULF_SECONDS - TITLE_REVEAL_SECONDS - BUTTON_DELAY_SECONDS) / BUTTON_FADE_SECONDS,
		0.0,
		1.0
	)
	_continue_button.size = _ui_skin.button_native_size(CONTINUE_BUTTON_HEIGHT)
	_continue_button.position = Vector2((size.x - _continue_button.size.x) * 0.5, title_y + title_size.y + 18.0)
	_continue_button.visible = button_alpha > 0.0
	_continue_button.disabled = button_alpha < 0.98
	_continue_button.modulate = Color(1.0, 1.0, 1.0, _ease_out_cubic(button_alpha))

func _fitted_title_font_size() -> int:
	var font: Font = HEADER_FONT
	var font_size: int = 92
	var min_size: int = 38
	var max_width: float = maxf(240.0, size.x - 56.0)
	while font_size > min_size:
		var text_width: float = font.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if text_width <= max_width:
			return font_size
		font_size -= 2
	return min_size

func _draw_edge_flood(rect: Rect2, edge: String, progress: float, phase: float, reach_scale: float) -> void:
	var t: float = _ease_in_out_cubic(clampf((progress - 0.02) / 0.94, 0.0, 1.0))
	if t <= 0.0:
		return
	var segments: int = 22
	for index: int in range(segments):
		var lane_a: float = float(index) / float(segments)
		var lane_b: float = float(index + 1) / float(segments)
		var points: Array[Vector2] = []
		match edge:
			"left":
				points = [
					Vector2(rect.position.x, rect.position.y + rect.size.y * lane_a),
					Vector2(rect.position.x, rect.position.y + rect.size.y * lane_b),
					Vector2(rect.position.x + _edge_reach(rect.size.x, lane_b, t, phase, reach_scale), rect.position.y + rect.size.y * lane_b),
					Vector2(rect.position.x + _edge_reach(rect.size.x, lane_a, t, phase, reach_scale), rect.position.y + rect.size.y * lane_a)
				]
			"right":
				points = [
					Vector2(rect.end.x, rect.position.y + rect.size.y * lane_a),
					Vector2(rect.end.x, rect.position.y + rect.size.y * lane_b),
					Vector2(rect.end.x - _edge_reach(rect.size.x, lane_b, t, phase, reach_scale), rect.position.y + rect.size.y * lane_b),
					Vector2(rect.end.x - _edge_reach(rect.size.x, lane_a, t, phase, reach_scale), rect.position.y + rect.size.y * lane_a)
				]
			"top":
				points = [
					Vector2(rect.position.x + rect.size.x * lane_a, rect.position.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.position.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.position.y + _edge_reach(rect.size.y, lane_b, t, phase, reach_scale)),
					Vector2(rect.position.x + rect.size.x * lane_a, rect.position.y + _edge_reach(rect.size.y, lane_a, t, phase, reach_scale))
				]
			"bottom":
				points = [
					Vector2(rect.position.x + rect.size.x * lane_a, rect.end.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.end.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.end.y - _edge_reach(rect.size.y, lane_b, t, phase, reach_scale)),
					Vector2(rect.position.x + rect.size.x * lane_a, rect.end.y - _edge_reach(rect.size.y, lane_a, t, phase, reach_scale))
				]
		if points.size() >= 3:
			draw_colored_polygon(PackedVector2Array(points), BLACK)

func _edge_reach(axis_size: float, lane: float, progress: float, phase: float, reach_scale: float) -> float:
	var wave: float = sin(lane * TAU * 2.15 + phase) * 0.040
	wave += sin(lane * TAU * 5.30 + phase * 0.63) * 0.022
	var bite: float = sin(progress * TAU * 0.72 + lane * TAU + phase) * 0.035
	return clampf(axis_size * (progress * reach_scale + wave + bite), 0.0, axis_size * 1.08)

func _draw_tendril(rect: Rect2, spec: Dictionary, progress: float) -> void:
	var local_t: float = _smoothstep(float(spec.get("delay", 0.0)), 1.0, progress)
	if local_t <= 0.0:
		return
	var path: Array[Vector2] = []
	var sample_count: int = 9
	for index: int in range(sample_count):
		var s: float = float(index) / float(sample_count - 1)
		path.append(_tendril_point(rect, spec, s * local_t))
	for index: int in range(path.size() - 1):
		var segment_t: float = float(index) / float(path.size() - 1)
		var next_segment_t: float = float(index + 1) / float(path.size() - 1)
		var stroke_width: float = maxf(
			_tendril_stroke_width(spec, segment_t, local_t),
			_tendril_stroke_width(spec, next_segment_t, local_t)
		)
		draw_line(path[index], path[index + 1], BLACK, stroke_width, true)
		draw_circle(path[index], stroke_width * 0.48, BLACK)
	var tip_radius: float = float(spec.get("width", 36.0)) * (0.24 + local_t * 0.16)
	draw_circle(path[path.size() - 1], tip_radius, BLACK)

func _tendril_stroke_width(spec: Dictionary, segment_t: float, local_t: float) -> float:
	var taper: float = 1.0 - segment_t * 0.78
	return float(spec.get("width", 36.0)) * taper * (1.05 + local_t * 0.62)

func _tendril_point(rect: Rect2, spec: Dictionary, s: float) -> Vector2:
	var edge: String = str(spec.get("edge", "left"))
	var lane: float = float(spec.get("lane", 0.5))
	var reach: float = float(spec.get("reach", 1.0))
	var wobble: float = float(spec.get("wobble", 0.14))
	var drift: float = float(spec.get("drift", 0.0))
	var phase: float = float(spec.get("phase", 0.0))
	var curve: float = sin(s * PI * 1.55 + phase) * wobble * s
	var curl: float = sin(s * PI * 3.20 + phase * 0.5) * wobble * 0.42 * s
	match edge:
		"left":
			return Vector2(
				rect.position.x - 12.0 + rect.size.x * reach * s,
				rect.position.y + rect.size.y * (lane + curve + curl + drift * s * 0.32)
			)
		"right":
			return Vector2(
				rect.end.x + 12.0 - rect.size.x * reach * s,
				rect.position.y + rect.size.y * (lane + curve - curl + drift * s * 0.32)
			)
		"top":
			return Vector2(
				rect.position.x + rect.size.x * (lane + curve + curl + drift * s * 0.28),
				rect.position.y - 12.0 + rect.size.y * reach * s
			)
		"bottom":
			return Vector2(
				rect.position.x + rect.size.x * (lane + curve - curl + drift * s * 0.28),
				rect.end.y + 12.0 - rect.size.y * reach * s
			)
	return rect.get_center()

func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 1.0 if value >= edge1 else 0.0
	var x: float = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _ease_out_cubic(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

func _ease_in_out_cubic(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	if x < 0.5:
		return 4.0 * x * x * x
	return 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5
