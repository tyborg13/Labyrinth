extends RefCounted

static func trail_phase(progress: float) -> float:
	if progress < 0.36 or progress >= 0.62:
		return -1.0
	if progress <= 0.42:
		return remap(progress, 0.36, 0.42, 0.0, 0.45)
	return remap(progress, 0.42, 0.62, 0.45, 1.0)

static func crack_points(hand: Vector2, contact: Vector2) -> PackedVector2Array:
	# A quadratic's midpoint receives half its control-point displacement.
	# Moving the control 36px upward gives the requested 18px bow.
	var control: Vector2 = (hand + contact) * 0.5 + Vector2(0, -36)
	var points := PackedVector2Array()
	for sample: int in range(25):
		var t: float = float(sample) / 24.0
		points.append(hand * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + contact * t * t)
	return points

static func draw(canvas: CanvasItem, hand: Vector2, to: Vector2, progress: float) -> void:
	var phase: float = trail_phase(progress)
	if phase < 0.0:
		return
	var envelope: float = sin(phase * PI)
	var contact: Vector2 = to + Vector2(0, -24)
	var points: PackedVector2Array = crack_points(hand, contact)
	canvas.draw_polyline(points, Color(0.55, 0.85, 0.80, 0.28 * envelope), 6.0, true)
	canvas.draw_polyline(points, Color(1.0, 0.97, 0.90, 0.85 * envelope), 3.0, true)
	if progress >= 0.42 and progress < 0.55:
		var burst := Color(1.0, 0.97, 0.90, 0.9 * (1.0 - inverse_lerp(0.42, 0.55, progress)))
		for angle: float in [0.0, PI / 3.0, -PI / 3.0]:
			var ray: Vector2 = Vector2.from_angle(angle) * 5.0
			canvas.draw_line(contact - ray, contact + ray, burst, 2.0, true)
