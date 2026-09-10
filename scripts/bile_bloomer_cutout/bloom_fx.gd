extends RefCounted

## Small shale fragments explain the bloom's release. Existing earth impacts,
## rubble, target tiles and all outcomes remain on their original effect paths.
static func draw_fragments(canvas: CanvasItem, source: Vector2, target: Vector2, progress: float, burst: bool, scale: float) -> void:
	var release: float = 0.38 if burst else 4.0 / 44.0
	var end: float = 0.72 if burst else 16.0 / 44.0
	if progress < release or progress >= end:
		return
	var t: float = inverse_lerp(release, end, progress)
	var count: int = 9 if burst else 3
	for index: int in range(count):
		var angle: float = float(index) * TAU / 9.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle) * 0.5) if burst else (target - source).normalized()
		var point: Vector2 = source + direction * (9.0 + 92.0 * t) * scale if burst else source.lerp(target, clampf(t + float(index) * 0.035, 0.0, 1.0))
		if not burst:
			point += direction.orthogonal() * float(index - 1) * 3.5 * scale * sin(PI * t)
		var axis: Vector2 = direction.normalized()
		var width: float = (3.4 if index % 2 == 0 else 2.4) * scale
		var length: float = (9.0 if burst else 11.0) * scale
		var normal: Vector2 = axis.orthogonal() * width
		var alpha: float = (1.0 - smoothstep(0.6, 1.0, t)) if burst else 1.0
		var shape := PackedVector2Array([point + axis * length, point + normal, point - axis * length * 0.45, point - normal])
		canvas.draw_colored_polygon(shape, Color(0.50, 0.43, 0.28, alpha))
		canvas.draw_colored_polygon(PackedVector2Array([point + axis * length, point + normal, point]), Color(0.92, 0.65, 0.27, alpha))
		canvas.draw_line(point - axis * length * 0.2, point + axis * length * 0.75, Color(1.0, 0.82, 0.42, alpha), maxf(1.0, scale))
