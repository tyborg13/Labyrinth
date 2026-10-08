extends RefCounted
## Contact claw marks have their own profile; the approved sweep-edge ribbon
## and dragon per-tile area rakes keep their existing geometry.
const LENGTH: float = 46.0
const WIDTH: float = 3.6
const SPACING: float = 8.0
const REVEAL := Vector2(0.36, 0.44)

static func geometry(anchor: Vector2, direction: Vector2, palette: Array,
		alpha: float, scale: float, glow: bool, progress: float) -> Dictionary:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var reveal: float = clampf(inverse_lerp(REVEAL.x, REVEAL.y, progress), 0.0, 1.0)
	if reveal <= 0.0:
		return {"vertices":vertices, "colors":colors, "indices":indices}
	var axis: Vector2 = direction.normalized()
	var normal := Vector2(-axis.y, axis.x)
	var rows: int = 3 if glow else 2
	for lane: int in range(-1, 2):
		var start: int = vertices.size()
		var length: float = LENGTH * (1.15 if lane == 0 else 1.0) * scale
		var center: Vector2 = anchor + normal * float(lane) * SPACING * scale
		var count: int = ceili(reveal * 24.0)
		for index: int in range(count + 1):
			# Clip a fixed tapered slash, rather than stretching the whole taper
			# into the currently revealed part. The middle stays 3.6 source px.
			var u: float = minf(float(index) / 24.0, reveal)
			var point: Vector2 = center + axis * (u - 0.5) * length
			var half_width: float = WIDTH * 0.5 * (1.0 - absf(2.0 * u - 1.0)) * scale * (3.0 if glow else 1.0)
			var color: Color = (palette[1] as Color).lerp(palette[0], u)
			color.a = alpha * (0.35 if glow else 1.0)
			vertices.append(point + normal * half_width)
			if glow:
				vertices.append(point)
				colors.append_array(PackedColorArray([Color(color,0.0),color,Color(color,0.0)]))
			else:
				colors.append_array(PackedColorArray([color,color]))
			vertices.append(point - normal * half_width)
		for index: int in range(count):
			for row: int in range(rows - 1):
				var a: int = start + index * rows + row
				var b: int = a + rows
				indices.append_array(PackedInt32Array([a,a+1,b+1,a,b+1,b]))
	return {"vertices":vertices, "colors":colors, "indices":indices}
