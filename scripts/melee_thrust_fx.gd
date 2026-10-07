extends RefCounted

## Contact streaks for the harrier and the protagonist's knife.
static func draw_streak(canvas: CanvasItem, from: Vector2, to: Vector2, phase: float,
		steel: Color) -> void:
	var contact: Vector2 = to + Vector2(0, -24)
	var direction: Vector2 = (to - from).normalized()
	steel.a = sin(phase * PI) * 0.6
	canvas.draw_line(contact - direction * 22, contact + direction * 8, steel, 2.0, true)


static func draw_protagonist_stab(canvas: CanvasItem, from: Vector2, to: Vector2,
		trail_phase: float, progress: float) -> void:
	var contact: Vector2 = to + Vector2(0, -24)
	var direction: Vector2 = (to - from).normalized()
	var envelope: float = sin(trail_phase * PI)
	var start: Vector2 = contact - direction * 52.0
	var end: Vector2 = contact + direction * 16.0
	canvas.draw_line(start, end, Color(0.95, 0.85, 0.70, 0.28 * envelope), 7.0, true)
	canvas.draw_line(start, end, Color(1.0, 0.97, 0.90, 0.85 * envelope), 3.0, true)
	if progress >= 0.42 and progress <= 0.55:
		var centre: Vector2 = contact + direction * 4.0
		var spark := Color(1.0, 0.92, 0.75, 0.9 * (1.0 - inverse_lerp(0.42, 0.55, progress)))
		for angle: float in [-PI / 4.0, PI / 4.0]:
			var half_line: Vector2 = direction.rotated(angle) * 6.0
			canvas.draw_line(centre - half_line, centre + half_line, spark, 2.0, true)
