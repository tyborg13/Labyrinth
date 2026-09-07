extends RefCounted

## Floor art uses the same textured smoke, shaded fragments and tapered light
## ribbons as live spells. The board owns depth, visibility and redraw cadence.
const Rules = preload("res://scripts/board_surface_rules.gd")
const SpellFx = preload("res://scripts/elemental_spell_fx.gd")
const StaticBatch = preload("res://scripts/board_surface_static_batch.gd")

static var retained_cache_enabled: bool = true
static var retained_electric_enabled: bool = true
static var retained_static_batch_enabled: bool = true
static var _ribbon_templates: Dictionary = {}
static var _mineral_grain: Texture2D
static var _surface_clouds: Array[Texture2D]
static var _flame_templates: Dictionary = {}
# Geometry2D's convex-quad triangle order, matching the original draw_polygon.
static var _quad_indices := PackedInt32Array([3, 0, 1, 1, 2, 3])
static var _quad_uvs := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
static var _quad_bones := PackedInt32Array()
static var _quad_weights := PackedFloat32Array()

static func color_for(kind: String) -> Color:
	match kind:
		"ice": return Color("85d9f2")
		"electrified": return Color("b4a1ff")
		"rubble": return Color("c2a071")
		_: return Color("ff9955")

static func title_for(kind: String) -> String:
	return "Electrified" if kind == "electrified" else kind.capitalize()

static func tooltip(state: Dictionary, tile: Vector2i) -> String:
	var lines := PackedStringArray()
	var kind: String = Rules.element_at(state, tile)
	if not kind.is_empty():
		lines.append(title_for(kind))
		match kind:
			"fire":
				lines.append("Deals 3 damage at turn start and 2 damage when entered.")
				if Rules.is_conductive(state, tile):
					lines.append("Stormcoal: also conducts Lightning. Attacks conducted through it consume it.")
			"ice":
				lines.append("Entering or starting a turn on Ice applies Chilled.")
			"electrified":
				lines.append("Lightning attacks travel through connected Electrified tiles, hitting enemies on them.")
				lines.append("Chain can also jump through individual Electrified tiles.")
	if Rules.has_rubble(state, tile):
		if not lines.is_empty(): lines.append("")
		lines.append("Rubble")
		lines.append("Walking out of Rubble costs 2 movement.")
	return "\n".join(lines)

static func draw_tile(canvas: CanvasItem, state: Dictionary, tile: Vector2i, center: Vector2, width: float, time: float, reduced_motion: bool, draw_rubble: bool = true, draw_elemental: bool = true, draw_electric: bool = true) -> void:
	var ground: Dictionary = Rules.surface_at(state, tile)
	if ground.is_empty(): return
	SpellFx.prepare()
	var seed: int = tile.x * 101 + tile.y * 307
	var phase: float = 0.37 if reduced_motion else time + float(posmod(seed, 127)) * 0.137
	var kind: String = Rules.element_at(state, tile)
	# Use tile-local coordinates in both direct and retained paths. Tiny chips
	# and shallow plate edges otherwise lose triangulation precision far from
	# the canvas origin. Restore identity before the caller paints previews.
	canvas.draw_set_transform(center)
	# Earth remains visible underneath either kind of elemental treatment.
	if draw_rubble and Rules.has_rubble(state, tile):
		_draw_rubble(canvas, Vector2.ZERO, width, seed)
	if draw_elemental:
		match kind:
			"fire": _draw_fire(canvas, Vector2.ZERO, width, phase, seed, reduced_motion)
			"ice": _draw_ice(canvas, Vector2.ZERO, width, phase, seed)
			"electrified":
				if draw_electric: _draw_electric(canvas, Vector2.ZERO, width, phase, seed, 1.0)
	if draw_electric and kind == "fire" and Rules.is_conductive(state, tile):
		_draw_electric(canvas, Vector2.ZERO, width, phase, seed, 0.75)
	canvas.draw_set_transform(Vector2.ZERO)

static func _diamond(p: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0, -h), p + Vector2(w, 0), p + Vector2(0, h), p + Vector2(-w, 0)])

# Persistent materials share the attack renderer's procedural cloud field,
# shaded fragments and feathered light. No illustrated floor sprites are used.
static func _draw_rubble(c: CanvasItem, p: Vector2, w: float, seed: int) -> void:
	var batch: StaticBatch = _material_batch(c)
	_floor_puff(c, p, Vector2(w * 0.86, w * 0.34), 0.0, Color(0.17, 0.13, 0.095, 0.72), seed)
	var chunks: Array[Dictionary]
	for i: int in range(14):
		var angle: float = float(i) * 2.399963 + float(seed % 13) * 0.19
		var radius: float = w * (0.08 + SpellFx._hash(seed + i * 13) * 0.29)
		var at: Vector2 = p + Vector2(cos(angle) * radius, sin(angle) * radius * 0.44)
		var size: float = w * (0.028 + SpellFx._hash(seed + i * 17 + 20) * 0.047)
		if i < 4: size *= 1.25
		chunks.append({"at": at, "size": size, "grain": seed + i * 71})
	chunks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["at"] as Vector2).y < (b["at"] as Vector2).y)
	# Gravel ties the larger blocks into the ground without resembling a wall.
	for i: int in range(22):
		var angle: float = float(i) * 2.399963
		var radius: float = w * (0.13 + SpellFx._hash(seed + i + 511) * 0.26)
		var at: Vector2 = p + Vector2(cos(angle), sin(angle) * 0.43) * radius
		SpellFx._rock_fragment(c, at, w * (0.005 + SpellFx._hash(seed + i + 541) * 0.008), angle, Color("a6947b"), seed + i)
	for chunk: Dictionary in chunks:
		_draw_ground_block(c, chunk["at"], chunk["size"], int(chunk["grain"]), batch)
	if batch != null: batch.flush()

static func _draw_ground_block(c: CanvasItem, p: Vector2, size: float, seed: int, batch: StaticBatch = null) -> void:
	var wide: float = size * (1.0 + SpellFx._hash(seed + 1) * 0.40)
	var depth: float = size * (0.43 + SpellFx._hash(seed + 2) * 0.20)
	var lift: float = size * (0.55 + SpellFx._hash(seed + 3) * 0.45)
	var top := PackedVector2Array([
		p + Vector2(-wide * 0.85, -depth * 0.28 - lift),
		p + Vector2(-wide * 0.18, -depth - lift),
		p + Vector2(wide * 0.80, -depth * 0.30 - lift * 0.95),
		p + Vector2(wide, depth * 0.34 - lift * 0.84),
		p + Vector2(wide * 0.12, depth - lift * 0.88),
		p + Vector2(-wide, depth * 0.38 - lift * 0.91)])
	if batch != null: batch.flush()
	_floor_glow(c, p + Vector2(size * 0.12, size * 0.18), Vector2(wide * 3.5, depth * 3.2), Color(0.065, 0.050, 0.040, 0.82))
	var stone := Color("a19179").lerp(Color("746f64"), SpellFx._hash(seed + 8))
	for edge: int in range(2, 6):
		var next: int = (edge + 1) % 6
		var foot_a: Vector2 = top[edge] + Vector2(0, lift)
		var foot_b: Vector2 = top[next] + Vector2(0, lift)
		var face := PackedVector2Array([top[edge], top[next], foot_b, foot_a])
		var shade: float = 0.43 if edge < 4 else 0.66
		_material_polygon(c, batch, face, PackedColorArray([stone.darkened(1.0 - shade), stone.darkened(0.37), stone.darkened(0.56), stone.darkened(0.68)]))
		_draw_mineral_grain(c, face, Color(stone.lightened(0.38), 0.44), seed + edge * 13, batch)
	var colors := PackedColorArray()
	for vertex: int in range(top.size()):
		colors.append(stone.lightened(0.04 + SpellFx._hash(seed + vertex * 11) * 0.20))
	_material_polygon(c, batch, top, colors)
	_draw_mineral_grain(c, top, Color(stone.lightened(0.44), 0.49), seed, batch)
	var hub: Vector2 = (top[0] + top[3]) * 0.5
	_draw_material_clusters(c, batch, top, hub, size * 0.13, seed, Color(stone.lightened(0.32), 0.72), Color(stone.darkened(0.56), 0.62), 15)
	# Chipped secondary planes and mineral flecks follow each block's lighting.
	for flake: int in range(5):
		var at: Vector2 = hub.lerp(top[flake], 0.28 + SpellFx._hash(seed + flake * 19) * 0.45)
		var r: float = size * (0.05 + SpellFx._hash(seed + flake * 31) * 0.06)
		_material_polygon(c, batch, PackedVector2Array([at + Vector2(-r, 0), at + Vector2(r * 0.3, -r * 0.45), at + Vector2(r, r * 0.3)]), PackedColorArray([stone.darkened(0.16), stone.lightened(0.26), stone]))
	if batch != null: batch.flush()
	c.draw_line(top[0].lerp(top[1], 0.18), top[0].lerp(top[1], 0.87), Color(stone.lightened(0.30), 0.75), maxf(0.65, size * 0.055), true)
	var fracture := PackedVector2Array([hub.lerp(top[1], 0.75), hub + Vector2(size * 0.09, 0), hub.lerp(top[4], 0.78)])
	c.draw_polyline(fracture, Color(0.17, 0.14, 0.12, 0.68), maxf(0.6, size * 0.045), true)

static func _prepare_mineral_grain() -> void:
	if _mineral_grain == null:
		# Like the spell renderer's clouds, this is a deterministic procedural
		# field generated once, not an imported image or a flattened floor stamp.
		var noise := FastNoiseLite.new()
		noise.seed = 7419
		noise.frequency = 0.24
		noise.fractal_octaves = 4
		var texture := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y: int in range(64):
			for x: int in range(64):
				var n: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				# A small stepped value range forms stable mineral clusters. At
				# native scale each texel covers roughly one screen pixel; it
				# must not be squeezed into imperceptible subpixel noise.
				var shade: float = floorf(n * 5.0) / 4.0
				texture.set_pixel(x, y, Color(shade, shade, shade, 0.82))
		_mineral_grain = ImageTexture.create_from_image(texture)
static func _draw_mineral_grain(c: CanvasItem, polygon: PackedVector2Array, tint: Color, seed: int, batch: StaticBatch = null) -> void:
	_prepare_mineral_grain()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon: bounds = bounds.expand(point)
	var uv := PackedVector2Array()
	var offset := Vector2(SpellFx._hash(seed), SpellFx._hash(seed + 4)) * 0.25
	for point: Vector2 in polygon:
		uv.append((point - bounds.position) / maxf(90.0, maxf(bounds.size.x, bounds.size.y) / 0.69) + offset)
	if batch != null:
		batch.polygon(polygon, PackedColorArray([tint]), uv)
	else:
		c.draw_polygon(polygon, PackedColorArray([tint]), uv, _mineral_grain)

static func _draw_material_clusters(c: CanvasItem, batch: StaticBatch, polygon: PackedVector2Array, hub: Vector2, pixel: float, seed: int, light: Color, dark: Color, count: int) -> void:
	# Sparse, directional clusters sit on the actual material face. They are
	# geometry, so no floor stamp, UV scroll or random sparkle can detach them.
	var step: float = maxf(0.65, pixel)
	for index: int in range(count):
		var edge: int = posmod(seed + index * 7, polygon.size())
		var outer: Vector2 = polygon[edge].lerp(polygon[(edge + 1) % polygon.size()], SpellFx._hash(seed + index * 31))
		var at: Vector2 = hub.lerp(outer, 0.25 + SpellFx._hash(seed + index * 73) * 0.63)
		at = (at / step).floor() * step
		var width: float = step * (2.0 if index % 4 == 0 else 1.0)
		var cluster := PackedVector2Array([at, at + Vector2(width, 0), at + Vector2(width, step), at + Vector2(0, step)])
		# Keeping all corners inside prevents chips crossing a fracture or edge.
		var inside: bool = true
		for point: Vector2 in cluster:
			if not Geometry2D.is_point_in_polygon(point, polygon):
				inside = false
				break
		if inside: _material_polygon(c, batch, cluster, PackedColorArray([light if index % 3 != 0 else dark]))

static func surface_cloud(index: int) -> Texture2D:
	if _surface_clouds.is_empty():
		# The spell cloud's same seeded field, sampled into authored-size value
		# clusters. Enlarged texel groups keep a crisp core and a fine soft rim.
		# These are reusable procedural primitives, never illustrated tile art.
		for variant: int in range(4):
			var noise := FastNoiseLite.new()
			noise.seed = 617 + variant * 139
			noise.frequency = 0.09
			noise.fractal_octaves = 3
			var cloud := Image.create(96, 96, false, Image.FORMAT_RGBA8)
			for y: int in range(24):
				for x: int in range(24):
					var sample_at := Vector2(x * 4 + 2, y * 4 + 2)
					var unit: Vector2 = (sample_at - Vector2.ONE * 48.0) / 48.0
					var n: float = noise.get_noise_2d(sample_at.x, sample_at.y) * 0.5 + 0.5
					var density: float = maxf(0.0, 1.0 - unit.length() - n * 0.26)
					var opacity: float = smoothstep(0.0, 0.42, density) * (0.36 + n * 0.64)
					opacity = floorf(opacity * 7.0 + 0.35) / 7.0
					var shade: float = 0.48 + floorf(n * 5.0) * 0.105
					cloud.fill_rect(Rect2i(x * 4, y * 4, 4, 4), Color(shade, shade, shade, opacity))
			_surface_clouds.append(ImageTexture.create_from_image(cloud))
	return _surface_clouds[posmod(index, _surface_clouds.size())]

static func _material_batch(c: CanvasItem) -> StaticBatch:
	if not retained_cache_enabled or not retained_static_batch_enabled: return null
	_prepare_mineral_grain()
	return StaticBatch.new(c, _mineral_grain)

static func _material_polygon(c: CanvasItem, batch: StaticBatch, points: PackedVector2Array, colors: PackedColorArray) -> void:
	if batch != null: batch.polygon(points, colors)
	else: c.draw_polygon(points, colors)

static func fire_pockets(w: float, seed: int) -> Array[Dictionary]:
	var pockets: Array[Dictionary]
	for i: int in range(9):
		var angle: float = float(i) * 2.399963 + float(seed) * 0.01
		var radius: float = w * (0.065 + SpellFx._hash(seed + i) * 0.27)
		pockets.append({"at": Vector2(cos(angle) * radius, sin(angle) * radius * 0.45), "index": i, "height": w * (0.14 + SpellFx._hash(seed + i + 57) * 0.075)})
	pockets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["at"] as Vector2).y < (b["at"] as Vector2).y)
	return pockets

static func fire_pose(w: float, phase: float, i: int, reduced: bool) -> Dictionary:
	var age: float = 0.43 if reduced else fposmod(phase * 0.64 + float(i) * 0.137, 1.0)
	var life: float = sin(age * PI)
	var heat: float = 1.0 - smoothstep(0.45, 1.0, age)
	return {"age": age, "lift": w * (0.018 + age * 0.085), "size": Vector2(w * (0.18 + age * 0.055), w * (0.15 + age * 0.14)), "outer": Color(0.73 + heat * 0.27, 0.17 + heat * 0.20, 0.022, 0.37 + life * 0.48), "inner": Color(1.0, 0.65 + heat * 0.20, 0.17 + heat * 0.12, (0.28 + life * 0.47) * heat)}

static func _draw_fire_bed(c: CanvasItem, p: Vector2, w: float, seed: int) -> void:
	_floor_puff(c, p, Vector2(w * 0.86, w * 0.34), 0.0, Color(0.26, 0.065, 0.018, 0.72), seed)
	for i: int in range(10):
		var a: float = float(i) * 2.399963
		var r: float = w * (0.05 + SpellFx._hash(seed + i + 77) * 0.30)
		var at: Vector2 = p + Vector2(cos(a), sin(a) * 0.43) * r
		_floor_puff(c, at, Vector2(w * 0.17, w * 0.055), a * 0.1, Color(0.95, 0.16, 0.018, 0.68), seed + i)
		_floor_glow(c, at, Vector2(w * 0.09, w * 0.035), Color(1.0, 0.59, 0.10, 0.72))
	# Dark crust and short hot seams anchor the moving tongues to the floor.
	# Cluster size follows tile scale, like the mineral detail on nearby props.
	var batch: StaticBatch = _material_batch(c)
	for index: int in range(23):
		var angle: float = float(index) * 2.399963 + float(seed % 11) * 0.21
		var radius: float = w * (0.06 + SpellFx._hash(seed + index * 53) * 0.28)
		var at: Vector2 = p + Vector2(cos(angle), sin(angle) * 0.43) * radius
		var step: float = maxf(0.65, w * 0.007)
		at = (at / step).floor() * step
		var crust := PackedVector2Array([at, at + Vector2(step * 3.0, 0), at + Vector2(step * 3.0, step), at + Vector2(step, step), at + Vector2(step, step * 2.0), at + Vector2(0, step * 2.0)])
		_material_polygon(c, batch, crust, PackedColorArray([Color(0.24, 0.075, 0.031, 0.88)]))
		var hot: Color = Color(1.0, 0.60, 0.12, 0.83) if index % 3 == 0 else Color(0.90, 0.24, 0.036, 0.76)
		_material_polygon(c, batch, PackedVector2Array([at, at + Vector2(step * 2.0, 0), at + Vector2(step * 2.0, step), at + Vector2(0, step)]), PackedColorArray([hot]))
	if batch != null: batch.flush()

static func _draw_fire_tongue(c: CanvasItem, at: Vector2, w: float, height_base: float, i: int, phase: float) -> void:
	# Authored combustion beats: gather, climb, curl over, then shed the tip.
	# Neighboring pockets are offset so the whole field never breathes in unison.
	var age: float = fposmod(phase * 0.46 + float(i) * 0.137, 1.0)
	var gather: float = smoothstep(0.0, 0.27, age)
	var curl: float = smoothstep(0.28, 0.70, age)
	var shed: float = smoothstep(0.73, 1.0, age)
	var alpha: float = smoothstep(0.0, 0.075, age) * (1.0 - shed)
	var side: float = -1.0 if i % 2 == 0 else 1.0
	var height: float = height_base * (0.55 + gather * 0.45)
	var base: Vector2 = at - Vector2(0, shed * w * 0.055)
	var control_a: Vector2 = base + Vector2(-side * w * 0.020, -height * 0.36)
	var control_b: Vector2 = base + Vector2(side * w * (0.020 + curl * 0.065), -height * (0.84 + curl * 0.11))
	var tip: Vector2 = base + Vector2(side * w * (0.018 + curl * 0.037), -height * (1.0 - curl * 0.13))
	var points := PackedVector2Array()
	for k: int in range(16):
		var u: float = float(k) / 15.0
		points.append(base.bezier_interpolate(control_a, control_b, tip, u))
	var thickness: float = w * (0.070 + gather * 0.030) * (1.0 - shed * 0.36)
	_draw_flame_volume(c, points, thickness, alpha, curl, i)
	if curl > 0.35:
		var fold := PackedVector2Array()
		for k: int in range(9):
			var u: float = float(k) / 8.0
			fold.append(base.bezier_interpolate(control_a + Vector2(side * w * 0.037, 0), control_b + Vector2(-side * w * 0.014, height * 0.20), tip + Vector2(-side * w * 0.025, height * 0.17), u))
		_floor_ribbon(c, fold, thickness * 0.28, Color(1.0, 0.56, 0.075, alpha * curl * 0.49), false)

static func _flame_template(count: int) -> Dictionary:
	if not _flame_templates.has(count):
		var indices := PackedInt32Array()
		var unit := PackedFloat64Array()
		var taper := PackedFloat64Array()
		var tip_alpha := PackedFloat64Array()
		unit.resize(count)
		taper.resize(count)
		tip_alpha.resize(count)
		for row: int in range(count):
			var u: float = float(row) / float(count - 1)
			unit[row] = u
			taper[row] = pow(1.0 - u, 0.78)
			tip_alpha[row] = 1.0 - smoothstep(0.84, 1.0, u)
			if row == count - 1: continue
			for band: int in range(4):
				var a: int = row * 5 + band
				var b: int = a + 5
				indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))
		_flame_templates[count] = {"indices": indices, "unit": unit, "taper": taper, "tip_alpha": tip_alpha}
	return _flame_templates[count]

static func _draw_flame_volume(c: CanvasItem, points: PackedVector2Array, width: float, alpha: float, curl: float, seed: int) -> void:
	# A flame is a broad rooted volume, not a rounded strip with two fading
	# ends. Five shaded cross-sections give it cool ragged edges and a hot fold.
	# Topology/taper stay immutable; only authored geometry and heat advance.
	var template: Dictionary = _flame_template(points.size())
	var unit: PackedFloat64Array = template["unit"]
	var taper: PackedFloat64Array = template["taper"]
	var tip_alpha: PackedFloat64Array = template["tip_alpha"]
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	vertices.resize(points.size() * 5)
	colors.resize(points.size() * 5)
	for row: int in range(points.size()):
		var u: float = unit[row]
		var tangent: Vector2 = (points[mini(row + 1, points.size() - 1)] - points[maxi(0, row - 1)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var breadth: float = taper[row] * (0.74 + sin(u * 6.0 + curl * 2.1 + seed) * 0.12)
		var left: float = width * breadth * (0.83 + sin(u * 9.0 + seed * 2.3 - curl * 3.0) * 0.20)
		var right: float = width * breadth * (0.70 + sin(u * 7.0 + seed * 1.7 + curl * 2.0) * 0.16)
		var hot: float = floorf((1.0 - u * 0.52) * (0.84 + sin(u * 11.0 + curl * 4.0 + seed) * 0.16) * 5.0) / 5.0
		var life: float = alpha * tip_alpha[row]
		var at: int = row * 5
		vertices[at] = points[row] + normal * left
		vertices[at + 1] = points[row] + normal * left * 0.64
		vertices[at + 2] = points[row] + normal * width * sin(u * 5.2 + seed + curl) * 0.12
		vertices[at + 3] = points[row] - normal * right * 0.66
		vertices[at + 4] = points[row] - normal * right
		colors[at] = Color(0.67, 0.08, 0.008, life * 0.10)
		colors[at + 1] = Color(0.98, 0.25 + hot * 0.20, 0.025, life * 0.78)
		colors[at + 2] = Color(1.0, 0.63 + hot * 0.28, 0.15 + hot * 0.19, life * 0.94)
		colors[at + 3] = Color(0.96, 0.18 + hot * 0.18, 0.020, life * 0.72)
		colors[at + 4] = Color(0.68, 0.07, 0.006, life * 0.08)
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), template["indices"], vertices, colors)

static func _draw_fire(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int, reduced: bool) -> void:
	_draw_fire_bed(c, p, w, seed)
	_floor_glow(c, p, Vector2(w * 0.95, w * 0.39), Color(1.0, 0.25, 0.025, 0.30 + sin(phase * 2.7) * 0.045))
	for pocket: Dictionary in fire_pockets(w, seed):
		var i: int = int(pocket["index"])
		var at: Vector2 = p + (pocket["at"] as Vector2)
		var pose: Dictionary = fire_pose(w, phase, i, reduced)
		var lift: float = float(pose["lift"])
		var size: Vector2 = pose["size"]
		_floor_puff(c, at - Vector2(0, lift), size, sin(phase * 0.9 + i) * 0.22, pose["outer"], seed + i)
		_floor_puff(c, at - Vector2(w * 0.009, lift * 0.72), size * Vector2(0.59, 0.69), -sin(phase * 1.2 + i) * 0.18, pose["inner"], seed + i + 1)
		_draw_fire_tongue(c, at, w, float(pocket["height"]), i, phase)
		if i % 2 == 0:
			var age: float = 0.5 if reduced else fposmod(phase * 0.42 + i * 0.23, 1.0)
			var ember: Vector2 = at + Vector2(sin(phase + i) * w * 0.037, -w * (0.14 + age * 0.16))
			_floor_glow(c, ember, Vector2(w * 0.025, w * 0.018), Color(1.0, 0.73, 0.22, sin(age * PI) * 0.78))

static func _ice_plates(seed: int) -> Array[PackedVector2Array]:
	# A fractured sheet follows irregular neighboring plates, never a radial
	# icon or a second grid painted on top of the tactical board.
	var sites: Array[Vector2]
	for y: int in range(3):
		for x: int in range(4):
			sites.append(Vector2((float(x) + 0.5) / 4.0 - 0.5 + (SpellFx._hash(seed + x * 41 + y * 13) - 0.5) * 0.17, (float(y) + 0.5) / 3.0 - 0.5 + (SpellFx._hash(seed + x * 31 + y * 71) - 0.5) * 0.21))
	var plates: Array[PackedVector2Array]
	for site: Vector2 in sites:
		var poly := PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
		for neighbor: Vector2 in sites:
			if neighbor == site: continue
			var normal: Vector2 = neighbor - site
			var midpoint: Vector2 = (neighbor + site) * 0.5
			var clipped := PackedVector2Array()
			for edge: int in range(poly.size()):
				var from: Vector2 = poly[edge]
				var to: Vector2 = poly[(edge + 1) % poly.size()]
				var a: float = (from - midpoint).dot(normal)
				var b: float = (to - midpoint).dot(normal)
				if a <= 0.0: clipped.append(from)
				if (a <= 0.0) != (b <= 0.0): clipped.append(from.lerp(to, a / (a - b)))
			poly = clipped
		var projected := PackedVector2Array()
		for point: Vector2 in poly:
			var edge_chip: float = 0.020
			if absf(point.x) > 0.499 or absf(point.y) > 0.499:
				edge_chip = 0.065 + SpellFx._hash(seed + int((point.x + point.y) * 150.0)) * 0.07
			var inset: Vector2 = point.lerp(site, edge_chip)
			projected.append(Vector2((inset.x - inset.y) * 0.43, (inset.x + inset.y) * 0.205))
		plates.append(projected)
	plates.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool:
		var ay: float = 0.0
		var by: float = 0.0
		for point: Vector2 in a: ay += point.y
		for point: Vector2 in b: by += point.y
		return ay / float(a.size()) < by / float(b.size()))
	return plates

static func _draw_ice_material(c: CanvasItem, p: Vector2, w: float, seed: int) -> void:
	var batch: StaticBatch = _material_batch(c)
	_floor_glow(c, p, Vector2(w * 0.88, w * 0.34), Color(0.23, 0.64, 0.82, 0.28))
	var plate_index: int = 0
	for normalized: PackedVector2Array in _ice_plates(seed):
		var grain: int = seed + plate_index * 113
		var poly := PackedVector2Array()
		var hub := Vector2.ZERO
		var rise: float = w * (0.003 + SpellFx._hash(grain + 3) * 0.013)
		for point: Vector2 in normalized:
			poly.append(p + point * w - Vector2(0, rise))
			hub += poly[-1]
		hub /= float(poly.size())
		var lift: float = w * (0.004 + SpellFx._hash(grain) * 0.008)
		for edge: int in range(poly.size()):
			var a: Vector2 = poly[edge]
			var b: Vector2 = poly[(edge + 1) % poly.size()]
			if (a + b).y * 0.5 < hub.y: continue
			var side := PackedVector2Array([a, b, b + Vector2(0, lift), a + Vector2(0, lift)])
			_material_polygon(c, batch, side, PackedColorArray([Color(0.18, 0.45, 0.56, 0.66), Color(0.20, 0.49, 0.60, 0.72), Color(0.12, 0.33, 0.40, 0.72), Color(0.13, 0.34, 0.43, 0.65)]))
		var blue: Color = Color(0.15, 0.34, 0.45, 0.50).lerp(Color(0.60, 0.79, 0.83, 0.66), SpellFx._hash(grain + 8))
		var shades := PackedColorArray()
		for point: Vector2 in poly:
			shades.append(blue.lightened(clampf((hub.y - point.y) / (w * 0.075), -0.2, 0.3)))
		_material_polygon(c, batch, poly, shades)
		# Overlapping internal reflective planes break the flat cyan-paving read.
		for facet: int in range(poly.size()):
			var a: Vector2 = poly[facet]
			var b: Vector2 = poly[(facet + 1) % poly.size()]
			var reflection: float = 0.06 + SpellFx._hash(grain + facet * 31) * 0.18
			_material_polygon(c, batch, PackedVector2Array([a, b, hub]), PackedColorArray([Color(0.72, 0.89, 0.94, reflection), Color(0.39, 0.69, 0.79, reflection * 0.38), Color(0.10, 0.31, 0.42, 0.11)]))
		_draw_mineral_grain(c, poly, Color(0.74, 0.93, 0.99, 0.32), grain, batch)
		_draw_material_clusters(c, batch, poly, hub, w * 0.0065, grain, Color(0.78, 0.95, 0.97, 0.62), Color(0.12, 0.37, 0.47, 0.38), 16)
		var vein: Vector2 = poly[0].lerp(hub, 0.70)
		_material_polygon(c, batch, PackedVector2Array([poly[0], poly[1], vein]), PackedColorArray([Color(0.78, 0.94, 0.98, 0.29), Color(0.67, 0.84, 0.91, 0.08), Color(0.37, 0.71, 0.85, 0.06)]))
		if batch != null: batch.flush()
		for edge: int in range(poly.size()):
			var a: Vector2 = poly[edge]
			var b: Vector2 = poly[(edge + 1) % poly.size()]
			c.draw_line(a.lerp(b, 0.08), a.lerp(b, 0.85), Color(0.74, 0.93, 0.98, 0.51 if (a + b).y * 0.5 < hub.y else 0.24), maxf(0.55, w * 0.0038), true)
		# Delicate feathered frost and a few low fractured shards catch the light.
		if plate_index % 2 == 0:
			_floor_puff(c, hub.lerp(poly[0], 0.48), Vector2(w * 0.13, w * 0.045), 0.1, Color(0.71, 0.90, 0.97, 0.30), grain)
			for shard: int in range(2):
				var at: Vector2 = hub.lerp(poly[shard], 0.70)
				SpellFx._fragment(c, at, w * (0.007 + SpellFx._hash(grain + shard) * 0.006), -PI * 0.5 + (SpellFx._hash(grain + shard + 21) - 0.5) * 1.3, Color(0.58, 0.85, 0.95, 0.51), true)
		plate_index += 1
	if batch != null: batch.flush()

static func _draw_ice_shimmer(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int) -> void:
	for i: int in range(5):
		var u: float = SpellFx._hash(seed + i * 51) - 0.5
		var v: float = SpellFx._hash(seed + i * 73 + 2) - 0.5
		var at: Vector2 = p + Vector2((u - v) * w * 0.36, (u + v) * w * 0.17)
		var gleam: float = pow(0.5 + sin(phase * 0.72 + i * 1.4) * 0.5, 4.0)
		_floor_glow(c, at, Vector2(w * 0.15, w * 0.022), Color(0.79, 0.95, 1.0, gleam * 0.40))

static func _draw_ice(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int) -> void:
	_draw_ice_material(c, p, w, seed)
	_draw_ice_shimmer(c, p, w, phase, seed)

static func electric_cloud_color(phase: float, index: int, opacity: float) -> Color:
	return Color(0.31, 0.32, 0.94, opacity * (0.38 + sin(phase * 1.7 + index) * 0.045))

static func electric_contact_color(alpha: float, opacity: float) -> Color:
	# Hot contacts follow the gathering front, then dim back into the corona.
	var heat: float = clampf((alpha / maxf(opacity, 0.001) - 0.37) * 1.8, 0.0, 0.85)
	return Color(0.87, 0.92, 1.0, opacity * (0.13 + heat))

static func _draw_electric(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int, opacity: float) -> void:
	_floor_glow(c, p, Vector2(w * 0.87, w * 0.34), Color(0.30, 0.24, 0.92, opacity * 0.40))
	for i: int in range(5):
		var angle: float = float(i) * 2.399963 + float(seed % 7) * 0.21
		var at: Vector2 = p + Vector2(cos(angle), sin(angle) * 0.44) * w * 0.23
		_floor_puff(c, at, Vector2(w * 0.28, w * 0.10), angle * 0.1, electric_cloud_color(phase, i, opacity), seed + i)
	var main := PackedVector2Array()
	# Each small discharge gathers, grows its forks, flashes and decays. A
	# moving front lights the network; paths reform during its quiet interval.
	var tick: int = int(floor(phase * 0.91))
	var beat: float = fposmod(phase * 0.91, 1.0)
	var sweep: float = smoothstep(0.09, 0.69, beat)
	var flash: float = smoothstep(0.57, 0.62, beat) * (1.0 - smoothstep(0.66, 0.82, beat))
	for i: int in range(7):
		var u: float = float(i) / 6.0
		var x: float = lerpf(-0.35, 0.35, u)
		var y: float = (SpellFx._hash(seed + i * 71 + tick * 13) - 0.5) * 0.10
		main.append(p + Vector2(x, y) * w)
	for i: int in range(6):
		var alpha: float = opacity * (0.37 + 0.40 * exp(-pow((float(i) / 6.0 - sweep) * 4.0, 2.0)) + flash * 0.12)
		_floor_bolt(c, main[i], main[i + 1], seed + i * 37, phase * 0.24, w * 0.013, Color(0.60, 0.47, 1.0, alpha))
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var end: Vector2 = main[i + 1] + Vector2((SpellFx._hash(seed + i * 11) - 0.5) * w * 0.18, side * w * (0.07 + SpellFx._hash(seed + i * 19) * 0.07))
		var junction: Vector2 = main[i].lerp(main[i + 1], 0.65)
		_floor_bolt(c, junction, end, seed + i + 102, phase * 0.20, w * 0.008, Color(0.67, 0.55, 1.0, alpha * 0.73))
		var tip: Vector2 = end.lerp(junction, 0.30) + Vector2(w * 0.055 * side, -w * 0.025)
		_floor_bolt(c, end.lerp(junction, 0.53), tip, seed + i + 311, phase * 0.19, w * 0.005, Color(0.74, 0.68, 1.0, alpha * 0.52))
		_floor_glow(c, main[i + 1], Vector2(w * 0.15, w * 0.07), Color(0.52, 0.54, 1.0, alpha * 0.77))
		_floor_glow(c, main[i + 1], Vector2(w * 0.028, w * 0.017), electric_contact_color(alpha, opacity))

# Floor particles retain the original textured quad, tint and primitive order.
# Only immutable UV/topology setup and generic polygon triangulation are removed.
static func _floor_glow(c: CanvasItem, p: Vector2, size: Vector2, tint: Color) -> void:
	if not retained_cache_enabled:
		SpellFx._glow(c, p, size, tint)
		return
	if SpellFx._light != null:
		_floor_sprite(c, SpellFx._light, p, size, 0.0, tint)

static func _floor_puff(c: CanvasItem, p: Vector2, size: Vector2, angle: float, tint: Color, index: int) -> void:
	_floor_sprite(c, surface_cloud(index), p, size, angle, tint)

static func _floor_sprite(c: CanvasItem, texture: Texture2D, p: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	if tint.a <= 0.001 or size.x <= 0.01 or size.y <= 0.01:
		return
	# Preserve the original operation order, including orientation and UV corners.
	var x := Vector2(cos(angle), sin(angle)) * size.x * 0.5
	var y := Vector2(-sin(angle), cos(angle)) * size.y * 0.5
	var vertices := PackedVector2Array([p - x - y, p + x - y, p + x + y, p - x + y])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), _quad_indices, vertices, PackedColorArray([tint]), _quad_uvs, _quad_bones, _quad_weights, texture.get_rid())

# Same feathered strip as ElementalSpellFx: immutable topology/taper are shared,
# while all animated positions and alpha are still evaluated on every draw.
static func _floor_ribbon(c: CanvasItem, points: PackedVector2Array, width: float, tint: Color, hot: bool = true) -> void:
	if not retained_cache_enabled:
		SpellFx._ribbon(c, points, width, tint, hot)
		return
	if points.size() < 2 or tint.a <= 0.002:
		return
	if points.size() == 2:
		if points[0].distance_squared_to(points[1]) < 0.0001: return
		points = PackedVector2Array([points[0], points[0].lerp(points[1], 0.5), points[1]])
	var count: int = points.size()
	var template: Dictionary = _floor_ribbon_template(count)
	var taper: PackedFloat64Array = template["taper"]
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	vertices.resize(count * 3)
	colors.resize(count * 3)
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	for vertex: int in range(count):
		var tangent: Vector2 = (points[mini(vertex + 1, count - 1)] - points[maxi(0, vertex - 1)]).normalized()
		var offset := Vector2(-tangent.y, tangent.x) * width * taper[vertex]
		var index: int = vertex * 3
		vertices[index] = points[vertex] + offset
		vertices[index + 1] = points[vertex]
		vertices[index + 2] = points[vertex] - offset
		colors[index] = clear
		colors[index + 1] = tint
		colors[index + 2] = clear
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), template["indices"], vertices, colors)
	if hot:
		var hot_tint: Color = tint.lightened(0.72)
		hot_tint.a = tint.a * 0.72
		c.draw_polyline(points, hot_tint, maxf(0.7, width * 0.13), true)

# Immutable feathered-strip topology is shared by the animated floor ribbons.
static func _floor_ribbon_template(count: int) -> Dictionary:
	if not _ribbon_templates.has(count):
		var topology := PackedInt32Array()
		var taper := PackedFloat64Array()
		taper.resize(count)
		for vertex: int in range(count):
			var u: float = float(vertex) / float(count - 1)
			taper[vertex] = pow(maxf(0.0, sin(u * PI)), 0.6)
			if vertex == count - 1: continue
			var a: int = vertex * 3
			var b: int = a + 3
			topology.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b, a + 1, a + 2, b + 2, a + 1, b + 2, b + 1]))
		_ribbon_templates[count] = {"indices": topology, "taper": taper}
	return _ribbon_templates[count]

static func _floor_bolt(c: CanvasItem, a: Vector2, b: Vector2, seed: int, t: float, width: float, tint: Color) -> void:
	if a.distance_squared_to(b) < 0.0001: return
	var points := PackedVector2Array()
	points.resize(13)
	var direction: Vector2 = (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var distance: float = a.distance_to(b)
	for k: int in range(13):
		var u: float = float(k) / 12.0
		var jag: float = sin(float(k) * 7.3 + float(seed) * 3.1 + t * 17.0) * sin(u * PI)
		points[k] = a.lerp(b, u) + normal * jag * distance * 0.075
	_floor_ribbon(c, points, width, tint)

static func draw_preview(canvas: CanvasItem, tile: Vector2i, center: Vector2, width: float, events: Array) -> void:
	for event_var: Variant in events:
		if typeof(event_var) != TYPE_DICTIONARY: continue
		var event: Dictionary = event_var as Dictionary
		var affected: Array = event.get("tiles", []) as Array
		if not affected.has(tile) and event.get("tile", Vector2i(-1, -1)) != tile: continue
		var event_kind: String = str(event.get("kind", ""))
		if not event_kind in ["surface_created", "surface_replaced", "surface_placed", "surface_removed", "surface_consumed", "placed", "removed", "consumed", "placement", "consumption"]: continue
		var removing: bool = "consum" in event_kind or "remov" in event_kind
		var tint: Color = Color("f5c998") if removing else color_for(str(event.get("surface", "fire")))
		var polygon: PackedVector2Array = _diamond(center, width * 0.42, width * 0.20)
		canvas.draw_polygon(polygon, PackedColorArray([Color(tint, 0.15)]))
		for edge: int in range(4):
			var a: Vector2 = polygon[edge]
			var b: Vector2 = polygon[(edge + 1) % 4]
			canvas.draw_line(a.lerp(b, 0.15), a.lerp(b, 0.84), Color(tint, 0.7), maxf(1.0, width * 0.012), true)

static func draw_feedback(canvas: CanvasItem, tile: Vector2i, center: Vector2, width: float, events: Array, progress: float) -> void:
	if progress >= 1.0: return
	for event_var: Variant in events:
		if typeof(event_var) != TYPE_DICTIONARY: continue
		var event: Dictionary = event_var as Dictionary
		if event.get("tile", Vector2i(-1, -1)) != tile and not (event.get("tiles", []) as Array).has(tile): continue
		var kind: String = str(event.get("kind", ""))
		if kind not in ["surface_created", "surface_replaced", "surface_removed", "surface_consumed"]: continue
		var tint: Color = color_for(str(event.get("surface", "fire")))
		var alpha: float = sin(clampf(progress, 0.0, 1.0) * PI) * 0.55
		_floor_glow(canvas, center, Vector2(width * (0.5 + progress * 0.8), width * (0.18 + progress * 0.28)), Color(tint, alpha))
		if kind == "surface_removed":
			for i: int in range(4):
				var angle: float = float(i) * 1.5708 + float(tile.x + tile.y) * 0.2
				var at: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.46) * width * progress * 0.34
				_floor_glow(canvas, at - Vector2(0, width * progress * 0.08), Vector2(width * 0.09, width * 0.05), Color(tint, alpha))
