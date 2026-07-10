extends Control
class_name DeathEngulfOverlay

const ENGULF_SECONDS: float = 1.55
const FINAL_SHROUD_ALPHA: float = 0.43
const SHROUD_COLOR: Color = Color(0.018, 0.020, 0.028, 1.0)
const EDGE_FLOOD_ALPHA: float = 0.30

var _elapsed: float = 0.0
var _motion_enabled: bool = true
var _playing: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func play(_board: Control = null) -> void:
	_elapsed = 0.0 if _motion_enabled else ENGULF_SECONDS
	_playing = true
	visible = true
	set_process(_motion_enabled)
	queue_redraw()

func reset() -> void:
	_elapsed = 0.0
	_playing = false
	visible = false
	set_process(false)
	queue_redraw()

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	if _playing and not _motion_enabled:
		_elapsed = ENGULF_SECONDS
		set_process(false)
		queue_redraw()

func motion_enabled() -> bool:
	return _motion_enabled

func seek_seconds(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, ENGULF_SECONDS)
	_playing = true
	visible = true
	set_process(_motion_enabled and _elapsed < ENGULF_SECONDS)
	queue_redraw()

func engulf_progress() -> float:
	return clampf(_elapsed / ENGULF_SECONDS, 0.0, 1.0)

func final_shroud_alpha() -> float:
	return FINAL_SHROUD_ALPHA

func has_decorative_edge_strokes() -> bool:
	return false

func sample_alpha(normalized_position: Vector2, progress_override: float = -1.0) -> float:
	var progress: float = engulf_progress() if progress_override < 0.0 else clampf(progress_override, 0.0, 1.0)
	if progress >= 0.999:
		return FINAL_SHROUD_ALPHA
	var edge_distance: float = minf(
		minf(normalized_position.x, 1.0 - normalized_position.x),
		minf(normalized_position.y, 1.0 - normalized_position.y)
	)
	var eased: float = _ease_in_out_cubic(progress)
	var front_depth: float = minf(0.48, 0.02 + eased * 0.50)
	var edge_coverage: float = 1.0 - _smoothstep(front_depth - 0.075, front_depth + 0.075, edge_distance)
	var base_alpha: float = FINAL_SHROUD_ALPHA * _smoothstep(0.58, 1.0, progress)
	var edge_alpha: float = EDGE_FLOOD_ALPHA * (0.55 + 0.45 * eased)
	return clampf(base_alpha + (1.0 - base_alpha) * edge_alpha * edge_coverage, 0.0, 0.58)

func _process(delta: float) -> void:
	if not _playing or not _motion_enabled:
		return
	_elapsed = minf(ENGULF_SECONDS, _elapsed + minf(delta, 1.0 / 30.0))
	if _elapsed >= ENGULF_SECONDS:
		set_process(false)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		queue_redraw()

func _draw() -> void:
	if not visible or size.x <= 0.0 or size.y <= 0.0:
		return
	var progress: float = engulf_progress()
	if progress >= 0.999:
		draw_rect(Rect2(Vector2.ZERO, size), Color(SHROUD_COLOR.r, SHROUD_COLOR.g, SHROUD_COLOR.b, FINAL_SHROUD_ALPHA), true)
		return
	var eased: float = _ease_in_out_cubic(progress)
	var base_alpha: float = FINAL_SHROUD_ALPHA * _smoothstep(0.58, 1.0, progress)
	if base_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(SHROUD_COLOR.r, SHROUD_COLOR.g, SHROUD_COLOR.b, base_alpha), true)
	var edge_alpha: float = EDGE_FLOOD_ALPHA * (0.55 + 0.45 * eased)
	var rect := Rect2(Vector2.ZERO, size)
	_draw_edge_flood(rect, "left", eased, 0.20, 0.96, edge_alpha)
	_draw_edge_flood(rect, "right", eased, 1.70, 0.92, edge_alpha)
	_draw_edge_flood(rect, "top", eased, 3.30, 0.78, edge_alpha * 0.92)
	_draw_edge_flood(rect, "bottom", eased, 4.60, 0.82, edge_alpha * 0.94)

func _draw_edge_flood(rect: Rect2, edge: String, progress: float, phase: float, reach_scale: float, alpha: float) -> void:
	if progress <= 0.0 or alpha <= 0.0:
		return
	var segments: int = 28
	var color := Color(SHROUD_COLOR.r, SHROUD_COLOR.g, SHROUD_COLOR.b, alpha)
	for index: int in range(segments):
		var lane_a: float = float(index) / float(segments)
		var lane_b: float = float(index + 1) / float(segments)
		var reach_a: float
		var reach_b: float
		if edge in ["left", "right"]:
			reach_a = _edge_reach(rect.size.x, lane_a, progress, phase, reach_scale)
			reach_b = _edge_reach(rect.size.x, lane_b, progress, phase, reach_scale)
		else:
			reach_a = _edge_reach(rect.size.y, lane_a, progress, phase, reach_scale)
			reach_b = _edge_reach(rect.size.y, lane_b, progress, phase, reach_scale)
		if reach_a <= 0.5 or reach_b <= 0.5:
			continue
		var points: Array[Vector2] = []
		match edge:
			"left":
				points = _vector2_array([
					Vector2(rect.position.x, rect.position.y + rect.size.y * lane_a),
					Vector2(rect.position.x, rect.position.y + rect.size.y * lane_b),
					Vector2(rect.position.x + reach_b, rect.position.y + rect.size.y * lane_b),
					Vector2(rect.position.x + reach_a, rect.position.y + rect.size.y * lane_a)
				])
			"right":
				points = _vector2_array([
					Vector2(rect.end.x, rect.position.y + rect.size.y * lane_a),
					Vector2(rect.end.x, rect.position.y + rect.size.y * lane_b),
					Vector2(rect.end.x - reach_b, rect.position.y + rect.size.y * lane_b),
					Vector2(rect.end.x - reach_a, rect.position.y + rect.size.y * lane_a)
				])
			"top":
				points = _vector2_array([
					Vector2(rect.position.x + rect.size.x * lane_a, rect.position.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.position.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.position.y + reach_b),
					Vector2(rect.position.x + rect.size.x * lane_a, rect.position.y + reach_a)
				])
			"bottom":
				points = _vector2_array([
					Vector2(rect.position.x + rect.size.x * lane_a, rect.end.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.end.y),
					Vector2(rect.position.x + rect.size.x * lane_b, rect.end.y - reach_b),
					Vector2(rect.position.x + rect.size.x * lane_a, rect.end.y - reach_a)
				])
		if points.size() >= 3:
			draw_colored_polygon(PackedVector2Array(points), color)

func _edge_reach(axis_size: float, lane: float, progress: float, phase: float, reach_scale: float) -> float:
	var wave: float = sin(lane * TAU * 2.15 + phase) * 0.030
	wave += sin(lane * TAU * 5.30 + phase * 0.63) * 0.014
	var breathing: float = sin(progress * PI + lane * TAU + phase) * 0.018
	var normalized_reach: float = minf(0.48, progress * 0.52 * reach_scale + wave * progress + breathing * progress)
	return clampf(axis_size * normalized_reach, 0.0, axis_size * 0.48)

func _vector2_array(values: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for value: Variant in values:
		if value is Vector2:
			result.append(value as Vector2)
	return result

func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 1.0 if value >= edge1 else 0.0
	var x: float = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _ease_in_out_cubic(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	if x < 0.5:
		return 4.0 * x * x * x
	return 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5
