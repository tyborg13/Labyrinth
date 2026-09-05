extends RefCounted

# Compact actor-to-actor electricity, deliberately distinct from the initial
# elemental cast. Deterministic geometry; no camera displacement or rapid flash.
static func draw_hop(canvas: CanvasItem, from_floor: Vector2, to_floor: Vector2, tile_width: float, progress: float, reduced_motion: bool) -> void:
	var start: Vector2 = from_floor + Vector2(0.0, -tile_width * 0.26)
	var end: Vector2 = to_floor + Vector2(0.0, -tile_width * 0.26)
	var t: float = clampf(progress, 0.0, 1.0)
	var reach: float = 1.0 if reduced_motion else clampf(t / 0.42, 0.0, 1.0)
	var fade: float = 0.58 if reduced_motion else 1.0 - smoothstep(0.50, 1.0, t)
	if reach <= 0.0 or fade <= 0.001:
		return
	var vector: Vector2 = end - start
	var normal: Vector2 = vector.orthogonal().normalized()
	var width: float = clampf(tile_width * 0.025, 2.0, 4.5)
	var points := PackedVector2Array()
	for index: int in range(13):
		var u: float = minf(float(index) / 12.0, reach)
		var jag: float = sin(float(index) * 2.39 + from_floor.x * 0.013) * tile_width * 0.045 * sin(u * PI)
		points.append(start.lerp(end, u) + normal * jag + Vector2(0.0, -sin(u * PI) * tile_width * 0.07))
		if u >= reach:
			break
	if points.size() < 2:
		return
	canvas.draw_polyline(points, Color(0.39, 0.27, 1.0, fade * 0.15), width * 5.0, true)
	canvas.draw_polyline(points, Color(0.65, 0.58, 1.0, fade * 0.62), width * 2.4, true)
	canvas.draw_polyline(points, Color(0.91, 0.94, 1.0, fade), width, true)
	var tip: Vector2 = points[points.size() - 1]
	canvas.draw_circle(tip, width * 1.6, Color(0.97, 0.98, 1.0, fade))
	if reach >= 1.0:
		var radius: float = tile_width * (0.055 if reduced_motion else lerpf(0.035, 0.11, clampf((t - 0.42) / 0.58, 0.0, 1.0)))
		canvas.draw_arc(end, radius, 0.0, TAU, 16, Color(0.76, 0.69, 1.0, fade * 0.72), width * 0.75, true)
