extends Control

var origin := Vector2(580, 640)
var destination := Vector2(1300, 640)
var reduced_motion: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	if not reduced_motion: queue_redraw()

func _point(t: float, strand: int) -> Vector2:
	return origin.lerp(destination, t) + Vector2(sin(t * PI * 3.0 + float(strand)) * 8.0, -sin(t * PI) * (140.0 + strand * 13.0) + sin(t * TAU * 2.0 + elapsed * 6.0 + strand) * 12.0)

func _draw() -> void:
	if reduced_motion: return
	var gather: float = smoothstep(0.0, 0.35, elapsed)
	var travel: float = smoothstep(0.32, 1.35, elapsed)
	var fade: float = 1.0 - smoothstep(1.45, 1.9, elapsed)
	for strand: int in range(6):
		var points := PackedVector2Array()
		for step: int in range(65):
			var t: float = float(step) / 64.0
			if t > travel: break
			points.append(_point(t, strand))
		if points.size() > 1:
			draw_polyline(points, Color(0.52, 0.15, 0.85, 0.15 * gather * fade), 11.0, true)
			draw_polyline(points, Color(0.77, 0.44, 1.0, 0.6 * gather * fade), 2.1, true)
			draw_polyline(points, Color(0.96, 0.82, 1.0, 0.75 * gather * fade), 0.8, true)
		for bead: int in range(5):
			var t: float = fposmod(travel - float(bead) * 0.047 - strand * 0.019, 1.0)
			if t > travel: continue
			draw_circle(_point(t, strand), 2.0 + sin(t * PI), Color(0.95, 0.78, 1.0, fade * 0.8))
	var stitch: float = smoothstep(1.0, 1.65, elapsed)
	for i: int in range(10):
		if float(i) / 10.0 > stitch: continue
		var y: float = destination.y - 95.0 + i * 19.0
		draw_line(Vector2(destination.x - 16, y - 6), Vector2(destination.x + 16, y + 6), Color(0.87, 0.62, 1.0, fade), 2.5, true)
	if stitch > 0:
		draw_arc(destination, 36.0 + stitch * 108.0, 0, TAU, 64, Color(0.72, 0.36, 1.0, sin(stitch * PI) * fade * 0.55), 2.0, true)
