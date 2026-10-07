extends RefCounted

## Legacy harrier contact streak; enemy migration belongs to unit 2.
static func draw_streak(canvas: CanvasItem, from: Vector2, to: Vector2, phase: float,
		steel: Color) -> void:
	var contact: Vector2 = to + Vector2(0, -24)
	var direction: Vector2 = (to - from).normalized()
	steel.a = sin(phase * PI) * 0.6
	canvas.draw_line(contact - direction * 22, contact + direction * 8, steel, 2.0, true)
