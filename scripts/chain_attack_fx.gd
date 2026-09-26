extends RefCounted

const SpellFx = preload("res://scripts/elemental_spell_fx.gd")

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
	SpellFx.prepare()
	# The relay keeps a fine white filament inside a feathered violet corona.
	# Match the primary spell's material without making another full-size cast.
	SpellFx._ribbon(canvas, points, width * 3.8, Color(0.43, 0.30, 1.0, fade * 0.22), false)
	SpellFx._ribbon(canvas, points, width * 1.45, Color(0.72, 0.65, 1.0, fade * 0.82), false)
	canvas.draw_polyline(points, Color(0.94, 0.96, 1.0, fade), maxf(0.8, width * 0.43), true)
	# Two short tributaries stay behind the traveling tip. Stable geometry avoids
	# high-frequency noise; reduced motion holds the exact same complete path.
	for branch: int in range(2):
		var anchor_index: int = 3 + branch * 4
		if anchor_index >= points.size() - 1:
			continue
		var anchor: Vector2 = points[anchor_index]
		var side: float = -1.0 if branch == 0 else 1.0
		var direction: Vector2 = vector.normalized()
		var fork := PackedVector2Array([
			anchor,
			anchor - direction * tile_width * 0.035 + normal * tile_width * 0.035 * side,
			anchor + direction * tile_width * 0.018 + normal * tile_width * 0.060 * side,
			anchor + direction * tile_width * 0.045 + normal * tile_width * 0.092 * side
		])
		SpellFx._ribbon(canvas, fork, width * 1.1, Color(0.69, 0.64, 1.0, fade * 0.58))
	var tip: Vector2 = points[points.size() - 1]
	SpellFx._glow(canvas, tip, Vector2.ONE * tile_width * 0.17, Color(0.66, 0.58, 1.0, fade * 0.70))
	SpellFx._glow(canvas, tip, Vector2.ONE * tile_width * 0.055, Color(0.94, 0.97, 1.0, fade * 0.90))
	if reach >= 1.0:
		var contact_t: float = 0.34 if reduced_motion else clampf((t - 0.42) / 0.58, 0.0, 1.0)
		var radius: float = tile_width * lerpf(0.04, 0.13, contact_t)
		# Interrupted, floor-aligned arcs read as dissipating energy, not a target ring.
		for arc: int in range(2):
			var contact := PackedVector2Array()
			for k: int in range(7):
				var angle: float = float(arc) * PI + float(k) * 0.17 + 0.28
				contact.append(to_floor + Vector2(cos(angle), sin(angle) * 0.34) * radius)
			SpellFx._ribbon(canvas, contact, width, Color(0.73, 0.66, 1.0, fade * 0.65), false)
		SpellFx._glow(canvas, to_floor, Vector2(tile_width * 0.35, tile_width * 0.12), Color(0.62, 0.49, 1.0, fade * 0.32))
