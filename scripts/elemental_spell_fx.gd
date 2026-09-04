extends RefCounted

## Deterministic, spatial spell drawing. No whole-spell sprites, live clocks, nodes,
## per-frame images, or transform changes: the caller owns scene depth and scale.

static var _clouds: Array[Texture2D] = []
static var _light: Texture2D
const TAU_GOLDEN: float = 2.39996323


static func prepare() -> void:
	if _light != null:
		return
	var glow := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		for x: int in range(64):
			var p := (Vector2(x, y) + Vector2.ONE * 0.5 - Vector2.ONE * 32.0) / 32.0
			var a: float = pow(maxf(0.0, 1.0 - p.length_squared()), 3.0)
			glow.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_light = ImageTexture.create_from_image(glow)
	for variant: int in range(4):
		var noise := FastNoiseLite.new()
		noise.seed = 617 + variant * 139
		noise.frequency = 0.09
		noise.fractal_octaves = 3
		var cloud := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		for y: int in range(96):
			for x: int in range(96):
				var p := (Vector2(x, y) + Vector2.ONE * 0.5 - Vector2.ONE * 48.0) / 48.0
				var n: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				var density: float = maxf(0.0, 1.0 - p.length() - n * 0.26)
				var a: float = smoothstep(0.0, 0.42, density) * (0.36 + n * 0.64)
				var shade: float = 0.62 + 0.38 * n
				cloud.set_pixel(x, y, Color(shade, shade, shade, a))
		_clouds.append(ImageTexture.create_from_image(cloud))


static func color_for(element: String) -> Color:
	match element:
		"earth":
			return Color("d8a458")
		"air":
			return Color("9cefdc")
		"lightning":
			return Color("af9aff")
		"ice":
			return Color("70cfff")
		_:
			return Color("ff7429")


static func envelope(t: float) -> float:
	return smoothstep(0.0, 0.045, t) * (1.0 - smoothstep(0.54, 1.0, t))


static func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 127.1 + 311.7) * 43758.5453, 1.0)


static func _tint(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


static func _sprite(
	c: CanvasItem,
	texture: Texture2D,
	p: Vector2,
	size: Vector2,
	angle: float,
	tint: Color
) -> void:
	if tint.a <= 0.001 or size.x <= 0.01 or size.y <= 0.01:
		return
	var x := Vector2(cos(angle), sin(angle)) * size.x * 0.5
	var y := Vector2(-sin(angle), cos(angle)) * size.y * 0.5
	c.draw_polygon(
		PackedVector2Array([p - x - y, p + x - y, p + x + y, p - x + y]),
		PackedColorArray([tint]),
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]),
		texture
	)


static func _glow(c: CanvasItem, p: Vector2, size: Vector2, tint: Color) -> void:
	if _light != null:
		_sprite(c, _light, p, size, 0.0, tint)


static func _puff(
	c: CanvasItem,
	p: Vector2,
	size: Vector2,
	angle: float,
	tint: Color,
	index: int
) -> void:
	if not _clouds.is_empty():
		_sprite(c, _clouds[posmod(index, _clouds.size())], p, size, angle, tint)


## Feathered ribbon strips, tapered at both ends; no stacked hard-edged circles.
static func _ribbon(
	c: CanvasItem,
	points: PackedVector2Array,
	width: float,
	tint: Color,
	hot: bool = true
) -> void:
	if points.size() < 2 or tint.a <= 0.002:
		return
	if points.size() == 2:
		if points[0].distance_squared_to(points[1]) < 0.0001:
			return
		points = PackedVector2Array([points[0], points[0].lerp(points[1], 0.5), points[1]])
	# Shared vertices make a continuous, feathered strip. Explicit triangle indices
	# avoid per-segment triangulation cracks and batch a whole filament in one draw.
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var clear := _tint(tint, 0.0)
	for vertex: int in range(points.size()):
		var tangent: Vector2 = points[mini(vertex + 1, points.size() - 1)] - points[maxi(0, vertex - 1)]
		tangent = tangent.normalized()
		var u: float = float(vertex) / float(points.size() - 1)
		var offset := Vector2(-tangent.y, tangent.x) * width * pow(maxf(0.0, sin(u * PI)), 0.6)
		vertices.append(points[vertex] + offset)
		vertices.append(points[vertex])
		vertices.append(points[vertex] - offset)
		colors.append(clear)
		colors.append(tint)
		colors.append(clear)
		if vertex == points.size() - 1:
			continue
		var a: int = vertex * 3
		var b: int = a + 3
		indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))
		indices.append_array(PackedInt32Array([a + 1, a + 2, b + 2, a + 1, b + 2, b + 1]))
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), indices, vertices, colors)

	if hot:
		c.draw_polyline(points, _tint(tint.lightened(0.72), tint.a * 0.72), maxf(0.7, width * 0.13), true)


static func floor_light(
	c: CanvasItem,
	element: String,
	p: Vector2,
	size: float,
	alpha: float
) -> void:
	var col := color_for(element)
	_glow(c, p, Vector2(size * 1.8, size * 0.64), _tint(col, alpha * 0.34))
	_glow(c, p, Vector2(size * 0.9, size * 0.30), _tint(col.lightened(0.45), alpha * 0.42))


static func ground(
	c: CanvasItem,
	element: String,
	p: Vector2,
	size: float,
	t: float,
	alpha: float
) -> void:
	var e: float = envelope(t) * alpha
	var col := color_for(element)
	floor_light(c, element, p, size, e)
	# Broken pressure fronts skim the isometric floor; gaps prevent a target reticle.
	for arc: int in range(3):
		var radius: float = size * (0.08 + pow(t, 0.56) * 0.75)
		var points := PackedVector2Array()
		for k: int in range(13):
			var angle: float = float(arc) * TAU / 3.0 + float(k) / 12.0 * 1.18 + 0.22
			points.append(p + Vector2(cos(angle), sin(angle) * 0.34) * radius)
		_ribbon(c, points, size * 0.020, _tint(col, e * (1.0 - t) * 0.56), false)


static func impact(
	c: CanvasItem,
	element: String,
	p: Vector2,
	size: float,
	progress: float,
	alpha: float,
	reduced: bool,
	front: bool
) -> void:
	var t: float = 0.38 if reduced else clampf(progress, 0.0, 1.0)
	if alpha <= 0.0 or envelope(t) <= 0.0:
		return
	match element:
		"fire":
			_fire(c, p, size, t, alpha, front, reduced)
		"earth":
			_shatter(c, p, size, t, alpha, front, false, reduced)
		"ice":
			_shatter(c, p, size, t, alpha, front, true, reduced)
		"air":
			_vortex(c, p, size, t, alpha, front, reduced)
		"lightning":
			_storm(c, p, size, t, alpha, front, reduced)


static func _fire(
	c: CanvasItem,
	p: Vector2,
	s: float,
	t: float,
	alpha: float,
	front: bool,
	reduced: bool
) -> void:
	var e: float = envelope(t) * alpha
	if not front:
		_glow(c, p - Vector2(0, s * 0.27), Vector2(s * 1.50, s * 1.18), Color(1.0, 0.18, 0.025, e * 0.30))
	# Separate lobes expand, roll, cool and rise, leaving holes between hot material.
	for i: int in range(18 if not reduced else 10):
		var angle: float = float(i) * TAU_GOLDEN
		if (sin(angle) > 0.25) != front:
			continue
		var age: float = clampf((t - _hash(i + 41) * 0.12) / 0.88, 0.0, 1.0)
		var spread: float = s * (0.06 + 0.37 * pow(age, 0.62)) * (0.55 + _hash(i + 97) * 0.45)
		var lift: float = s * (0.10 + 0.51 * age) * (0.6 + _hash(i + 37) * 0.65)
		var point := p + Vector2(cos(angle) * spread, sin(angle) * spread * 0.34 - lift)
		var radius: float = s * (0.13 + age * 0.22) * (0.72 + _hash(i + 13) * 0.38)
		var heat: float = 1.0 - smoothstep(0.48, 0.96, age)
		var col := Color("623d36").lerp(Color("ff6d12"), heat)
		var density: float = e * (0.82 if front else 1.0)
		_puff(c, point, Vector2(radius * 1.8, radius * 2.0), angle + age * 1.7, _tint(col, density), i)
		_puff(
			c,
			point + Vector2(-radius * 0.10, radius * 0.16),
			Vector2(radius * 1.12, radius * 1.5),
			angle - age,
			Color(1.0, 0.84, 0.27, density * heat),
			i + 1
		)
		_glow(
			c,
			point + Vector2(0, radius * 0.12),
			Vector2.ONE * radius * 0.64,
			Color(1.0, 0.98, 0.76, density * heat * 0.9)
		)
	# Hot tongues stretch independently through the cooler rolling volume.
	for tongue: int in range(8 if not reduced else 4):
		var side: float = lerpf(-1.0, 1.0, _hash(tongue + 801))
		if (tongue % 3 == 0) != front:
			continue
		var points := PackedVector2Array()
		var pocket := Vector2(side * (0.10 + t * 0.19), -0.09 - t * 0.22 - _hash(tongue + 90) * 0.13)
		for k: int in range(16):
			var u: float = float(k) / 15.0
			var x: float = side * u * 0.09 + sin(u * 5.0 - t * 7.0 + float(tongue)) * u * 0.065
			var y: float = -u * (0.14 + _hash(tongue + 90) * 0.12)
			points.append(p + (pocket + Vector2(x, y)) * s)
		_ribbon(c, points, s * 0.054, Color(1.0, 0.38, 0.025, e * (1.0 - smoothstep(0.54, 0.92, t)) * 0.8), false)
		_ribbon(c, points, s * 0.036, Color(1.0, 0.86, 0.36, e * (1.0 - smoothstep(0.45, 0.90, t)) * 0.95), false)
	_sparks(c, "fire", p, s, t, alpha, front, reduced)


static func _shatter(
	c: CanvasItem,
	p: Vector2,
	s: float,
	t: float,
	alpha: float,
	front: bool,
	ice: bool,
	reduced: bool
) -> void:
	var e: float = envelope(t) * alpha
	var col: Color = Color("a1e8ff") if ice else Color("c3a072")
	# Low, rolling particulate volume establishes the burst's floor plane.
	for i: int in range(9):
		var angle: float = float(i) * TAU_GOLDEN
		if (sin(angle) > 0.2) != front:
			continue
		var r: float = s * (0.06 + 0.40 * pow(t, 0.65))
		var point := p + Vector2(cos(angle) * r, sin(angle) * r * 0.28 - s * 0.13 * t)
		_puff(c, point, Vector2(s * 0.50, s * 0.26) * (0.7 + t), angle + t, _tint(col, e * (0.42 if ice else 0.63)), i)
	var count: int = 32 if ice else 21
	if reduced:
		count = 10
	for i: int in range(count):
		var angle: float = float(i) * TAU_GOLDEN + 0.4
		if (sin(angle) > 0.18) != front:
			continue
		var age: float = clampf((t - _hash(i + 67) * 0.12) / 0.88, 0.0, 1.0)
		var radial: float = s * (0.02 + age * (0.36 + _hash(i + 2) * 0.28))
		var height: float = s * (0.22 + _hash(i + 8) * 0.56) * sin(age * PI)
		var point := p + Vector2(cos(angle) * radial, sin(angle) * radial * 0.34 - height)
		var radius: float = s * ((0.030 if ice else 0.038) + _hash(i + 3) * (0.030 if ice else 0.045)) * (1.0 - age * 0.48)
		if ice:
			_glow(c, point, Vector2.ONE * radius * 6.5, _tint(col, e * 0.23))
		var spin: float = angle + age * (2.0 + _hash(i + 18) * 4.0)
		if ice:
			_fragment(c, point, radius, spin, _tint(col, e * (0.78 if front else 0.96)), true)
		else:
			_rock_fragment(c, point, radius, spin, _tint(col, e * (0.78 if front else 0.96)), i)
		if ice and i % 3 == 0:
			var tail := PackedVector2Array([point + Vector2(-cos(angle) * s * 0.10, s * 0.10), point])
			_ribbon(c, tail, s * 0.014, _tint(col, e * 0.35), false)
	_sparks(c, "ice" if ice else "earth", p, s, t, alpha * 0.85, front, reduced)


static func _rock_fragment(
	c: CanvasItem,
	p: Vector2,
	r: float,
	angle: float,
	col: Color,
	seed: int
) -> void:
	if r <= 0.05 or col.a <= 0.001:
		return
	# A chipped, asymmetric outline; mild radial variation keeps every face convex.
	var vertex_count: int = 5 + posmod(seed, 3)
	var stretch := Vector2(0.82 + _hash(seed + 41) * 0.28, 0.76 + _hash(seed + 73) * 0.30)
	var shear: float = (_hash(seed + 113) - 0.5) * 0.24
	var outline := PackedVector2Array()
	for vertex: int in range(vertex_count):
		var theta: float = float(vertex) * TAU / float(vertex_count)
		theta += (_hash(seed + 97 + vertex * 17) - 0.5) * 0.24
		var radial: float = r * (0.90 + _hash(seed + 211 + vertex * 31) * 0.20)
		var local_point := Vector2(cos(theta) * stretch.x, sin(theta) * stretch.y) * radial
		local_point.x += local_point.y * shear
		outline.append(p + local_point.rotated(angle))
	var hub_offset := Vector2(_hash(seed + 307) - 0.5, _hash(seed + 389) - 0.5) * r * 0.16
	var hub: Vector2 = p + hub_offset.rotated(angle)
	var stone := Color(0.24, 0.21, 0.18, col.a).lerp(col, 0.50 + _hash(seed + 457) * 0.12)
	var light_direction := Vector2(-0.52, -0.85).normalized()
	# Three broad matte faces tumble through a fixed upper-left light.
	for face: int in range(3):
		var first_vertex: int = face * 2
		var last_vertex: int = vertex_count if face == 2 else first_vertex + 2
		var face_points := PackedVector2Array()
		var face_center := Vector2.ZERO
		for vertex: int in range(first_vertex, last_vertex + 1):
			var point: Vector2 = outline[posmod(vertex, vertex_count)]
			face_points.append(point)
			face_center += point
		face_center /= float(face_points.size())
		face_points.append(hub)
		var facing: Vector2 = (face_center - hub).normalized()
		var light_amount: float = clampf(0.5 + facing.dot(light_direction) * 0.5, 0.0, 1.0)
		var shade: float = lerpf(0.62, 1.18, light_amount)
		var face_color := Color(stone.r * shade, stone.g * shade, stone.b * shade, col.a)
		c.draw_polygon(face_points, PackedColorArray([face_color]))
	# One interrupted sunlit edge and a short fracture, never a glowing outline.
	var lit_edge: int = 0
	var highest_edge_y: float = INF
	for vertex: int in range(vertex_count):
		var next: int = posmod(vertex + 1, vertex_count)
		var edge_y: float = (outline[vertex].y + outline[next].y) * 0.5
		if edge_y < highest_edge_y:
			highest_edge_y = edge_y
			lit_edge = vertex
	var edge_start: Vector2 = outline[lit_edge]
	var edge_end: Vector2 = outline[posmod(lit_edge + 1, vertex_count)]
	var rim_start: Vector2 = edge_start.lerp(edge_end, 0.16)
	var rim_end: Vector2 = edge_start.lerp(edge_end, 0.72)
	var rim_color := Color(0.82, 0.65, 0.40, col.a * 0.46)
	c.draw_line(rim_start, rim_end, rim_color, maxf(0.55, r * 0.045), true)
	if r > 2.5:
		var fracture := PackedVector2Array([
			hub.lerp(rim_start, 0.13),
			hub.lerp(edge_start, 0.35),
			hub.lerp(rim_end, 0.57)
		])
		c.draw_polyline(fracture, Color(0.73, 0.47, 0.22, col.a * 0.24), maxf(0.45, r * 0.027), true)


static func _fragment(
	c: CanvasItem,
	p: Vector2,
	r: float,
	angle: float,
	col: Color,
	ice: bool
) -> void:
	var axis := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-axis.y, axis.x)
	var tip: Vector2 = p + axis * r * (2.5 if ice else 1.0)
	var tail: Vector2 = p - axis * r
	var left: Vector2 = p + normal * r * (0.38 if ice else 0.8)
	var right: Vector2 = p - normal * r * (0.38 if ice else 0.65)
	c.draw_polygon(
		PackedVector2Array([tip, left, tail]),
		PackedColorArray([col.lightened(0.65), col, col.darkened(0.2)])
	)
	c.draw_polygon(
		PackedVector2Array([tip, tail, right]),
		PackedColorArray([col, col.darkened(0.48), col.darkened(0.4)])
	)
	c.draw_line(tip, left, _tint(col.lightened(0.8), col.a * 0.75), 0.8, true)


static func _vortex(
	c: CanvasItem,
	p: Vector2,
	s: float,
	t: float,
	alpha: float,
	front: bool,
	reduced: bool
) -> void:
	var e: float = envelope(t) * alpha
	var col := color_for("air")
	# Sample helical streamlines in 3D, splitting at the target's depth plane.
	for strand: int in range(6 if not reduced else 4):
		var points := PackedVector2Array()
		for k: int in range(41):
			var u: float = float(k) / 40.0
			var angle: float = u * TAU * (0.75 + _hash(strand + 188) * 0.5) + float(strand) * 1.13 - t * (4.3 + _hash(strand + 152))
			var radius: float = s * (0.12 + u * 0.32 + sin(u * 12.0 + float(strand) * 2.3 - t * 3.0) * 0.035) * (0.45 + sin(t * PI) * 0.55)
			var point := p + Vector2(cos(angle) * radius, sin(angle) * radius * 0.34 - s * u * (0.46 + _hash(strand + 148) * 0.18 + t * 0.24))
			if (sin(angle) > 0.0) == front:
				points.append(point)
			else:
				_ribbon(c, points, s * (0.025 if strand % 2 == 0 else 0.012), _tint(col, e * (0.48 if front else 0.70)))
				points = PackedVector2Array()
		_ribbon(c, points, s * 0.023, _tint(col, e * 0.62))
	for i: int in range(7):
		var angle: float = float(i) * TAU_GOLDEN - t * 4.0
		if (sin(angle) > 0.0) != front:
			continue
		var point := p + Vector2(cos(angle) * s * 0.30, sin(angle) * s * 0.09 - s * (0.1 + float(i) * 0.07))
		_puff(c, point, Vector2(s * 0.54, s * 0.15), angle * 0.12, _tint(col, e * 0.29), i)
	_sparks(c, "air", p, s, t, alpha * 0.6, front, reduced)


static func _bolt(
	c: CanvasItem,
	a: Vector2,
	b: Vector2,
	seed: int,
	t: float,
	width: float,
	tint: Color
) -> void:
	if a.distance_squared_to(b) < 0.0001:
		return
	var points := PackedVector2Array()
	var direction: Vector2 = (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	for k: int in range(13):
		var u: float = float(k) / 12.0
		var jag: float = sin(float(k) * 7.3 + float(seed) * 3.1 + t * 17.0) * sin(u * PI)
		points.append(a.lerp(b, u) + normal * jag * a.distance_to(b) * 0.075)
	_ribbon(c, points, width, tint)


static func _storm(
	c: CanvasItem,
	p: Vector2,
	s: float,
	t: float,
	alpha: float,
	front: bool,
	reduced: bool
) -> void:
	var e: float = envelope(t) * alpha
	var col := color_for("lightning")
	var contact := p - Vector2(0, s * 0.16)
	if not front:
		_glow(c, contact, Vector2(s * 0.72, s * 1.18), _tint(col, e * 0.33))
		for bolt: int in range(3):
			var top := p + Vector2(s * (float(bolt) - 1.0) * 0.25, -s * (0.75 + float(bolt) * 0.08))
			_bolt(c, top, contact, bolt, t, s * 0.035, _tint(col, e * (0.95 - float(bolt) * 0.22)))
	for branch: int in range(9 if not reduced else 5):
		var angle: float = float(branch) * TAU_GOLDEN + t * 0.2
		if (sin(angle) > 0.1) != front:
			continue
		var end := p + Vector2(cos(angle) * s * (0.30 + t * 0.24), sin(angle) * s * 0.16 - s * _hash(branch + 99) * 0.26)
		var junction: Vector2 = contact.lerp(end, 0.57) + Vector2(0, -s * 0.08)
		_bolt(c, contact, end, branch + 11, t, s * 0.018, _tint(col, e * 0.85))
		_bolt(c, junction, end + Vector2(s * 0.09, -s * 0.12), branch + 30, t, s * 0.009, _tint(col, e * 0.5))
	_sparks(c, "lightning", p, s, t, alpha, front, reduced)


static func _sparks(
	c: CanvasItem,
	element: String,
	p: Vector2,
	s: float,
	t: float,
	alpha: float,
	front: bool,
	reduced: bool
) -> void:
	var count: int = 12 if reduced else 32
	var col := color_for(element)
	for i: int in range(count):
		var angle: float = float(i) * TAU_GOLDEN
		if (sin(angle) > 0.18) != front:
			continue
		var age: float = clampf((t - _hash(i + 127) * 0.18) / 0.82, 0.0, 1.0)
		if age <= 0.0 or age >= 1.0:
			continue
		var speed: float = s * (0.40 + _hash(i + 74) * 0.40)
		var lift: float = s * (0.16 + _hash(i + 54) * 0.5)
		var dir := Vector2(cos(angle), sin(angle) * 0.36)
		var point := p + dir * speed * age - Vector2(0, lift * sin(age * PI))
		var previous_age: float = maxf(0.0, age - 0.022 - _hash(i + 401) * 0.035)
		var prev := p + dir * speed * previous_age - Vector2(0, lift * sin(previous_age * PI))
		var a: float = alpha * pow(1.0 - age, 0.9) * smoothstep(0.0, 0.045, age)
		var radius: float = s * (0.005 + _hash(i + 27) * 0.007)
		if element == "earth":
			c.draw_circle(point, maxf(0.6, radius * 0.70), _tint(col.darkened(_hash(i + 2) * 0.50), a * 0.8))
			continue
		_glow(c, point, Vector2.ONE * radius * 7.0, _tint(col, a * 0.32))
		c.draw_line(prev, point, _tint(col.lightened(0.75), a), maxf(0.8, radius), true)


static func release(
	c: CanvasItem,
	element: String,
	p: Vector2,
	ground_point: Vector2,
	s: float,
	t: float,
	alpha: float
) -> void:
	var col := color_for(element)
	var e: float = smoothstep(0.0, 0.22, t) * alpha
	_glow(c, ground_point, Vector2(s * 0.9, s * 0.3), _tint(col, e * 0.24))
	for i: int in range(7):
		var points := PackedVector2Array()
		for k: int in range(13):
			var u: float = float(k) / 12.0
			var radius: float = s * (0.08 + (1.0 - t) * 0.3) * (1.0 - u * 0.65)
			var angle: float = float(i) * TAU / 7.0 + u * 1.7 + t * 1.1
			points.append(p + Vector2(cos(angle), sin(angle) * 0.65) * radius)
		_ribbon(c, points, s * 0.014, _tint(col, e * 0.60))
	_glow(c, p, Vector2.ONE * s * (0.20 + t * 0.16), _tint(col.lightened(0.65), e * 0.65))


static func travel(
	c: CanvasItem,
	element: String,
	start: Vector2,
	end: Vector2,
	floor_start: Vector2,
	floor_end: Vector2,
	s: float,
	t: float,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var col := color_for(element)
	var direction: Vector2 = (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var head: Vector2 = start.lerp(end, t)
	_glow(c, floor_start.lerp(floor_end, t), Vector2(s * 0.9, s * 0.30), _tint(col, alpha * 0.23))
	if element == "lightning":
		_bolt(c, start, head, 91, t, s * 0.055, _tint(col, alpha * 0.9))
		_bolt(c, start + normal * s * 0.03, head, 27, t, s * 0.021, _tint(col, alpha * 0.50))
		_glow(c, head, Vector2.ONE * s * 0.35, _tint(col.lightened(0.7), alpha * 0.70))
		return
	for strand: int in range(5):
		var points := PackedVector2Array()
		for k: int in range(19):
			var u: float = float(k) / 18.0
			var phase: float = maxf(0.0, t - (1.0 - u) * 0.36)
			var spread: float = s * (0.045 + (1.0 - u) * 0.16)
			var offset: float = sin(u * 7.0 + float(strand) * 1.27 - t * 8.0) * spread * sin(u * PI)
			points.append(start.lerp(end, phase) + normal * offset)
		_ribbon(
			c,
			points,
			s * (0.048 if element == "fire" else 0.022),
			_tint(col, alpha * (0.45 if element == "fire" else 0.60))
		)
	if element == "fire":
		for i: int in range(9):
			var age: float = float(i) / 9.0
			var point: Vector2 = start.lerp(end, maxf(0.0, t - age * 0.20)) + normal * sin(float(i) * 2.4 + t * 9.0) * s * 0.07
			var radius: float = s * (0.24 - age * 0.12)
			_puff(c, point, Vector2(radius * 1.6, radius), direction.angle(), _tint(col, alpha * (1.0 - age) * 0.72), i)
		_glow(c, head, Vector2.ONE * s * 0.22, Color(1.0, 0.94, 0.64, alpha * 0.94))
	elif element == "ice":
		for i: int in range(7):
			var point: Vector2 = start.lerp(end, maxf(0.0, t - float(i) * 0.024)) + normal * sin(float(i) * 2.4) * s * 0.13
			_fragment(c, point, s * 0.024, direction.angle(), _tint(col, alpha * (1.0 - float(i) * 0.08)), true)
	else:
		_glow(c, head, Vector2.ONE * s * 0.22, _tint(col, alpha * 0.25))
