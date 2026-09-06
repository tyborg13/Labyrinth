extends RefCounted

## Floor art uses the same textured smoke, shaded fragments and tapered light
## ribbons as live spells. The board owns depth, visibility and redraw cadence.
const Rules = preload("res://scripts/board_surface_rules.gd")
const SpellFx = preload("res://scripts/elemental_spell_fx.gd")

static var retained_cache_enabled: bool = true
static var _ribbon_templates: Dictionary = {}
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
				lines.append("Entry: 1 damage. Turn start: 2 damage.
Creation deals no immediate damage.")
				lines.append("Detonate consumes it. Harms any unit.")
				if Rules.is_conductive(state, tile):
					lines.append("Stormcoal: also conducts Lightning and relays Chain. Electrical use consumes it.")
			"ice":
				lines.append("Entry or turn start: Chilled (+1 direct damage).
Creation alone does not Chill.")
				lines.append("An Ice hit Freezes a Chilled unit and consumes its supporting Ice.")
			"electrified":
				lines.append("Lightning discharges the connected cardinal patch, striking its opponents and consuming the ground.")
				lines.append("Chain may also use these tiles as relay nodes. Ready immediately; no entry effect.")
	if Rules.has_rubble(state, tile):
		if not lines.is_empty(): lines.append("")
		lines.append("Rubble")
		lines.append("Entry costs 2 movement. If a fresh movement allowance is only 1, you can enter one adjacent Rubble tile. Push, Pull and Blink ignore the cost. Does not block sight or attacks.")
	if not lines.is_empty():
		lines.append("Persists until removed, consumed or the encounter ends.")
	return "\n".join(lines)

static func draw_tile(canvas: CanvasItem, state: Dictionary, tile: Vector2i, center: Vector2, width: float, time: float, reduced_motion: bool, draw_rubble: bool = true, draw_elemental: bool = true) -> void:
	var ground: Dictionary = Rules.surface_at(state, tile)
	if ground.is_empty(): return
	SpellFx.prepare()
	var seed: int = tile.x * 101 + tile.y * 307
	var phase: float = 0.37 if reduced_motion else time + float(posmod(seed, 127)) * 0.137
	var kind: String = Rules.element_at(state, tile)
	# Earth remains visible underneath either kind of elemental treatment.
	if draw_rubble and Rules.has_rubble(state, tile):
		_draw_rubble(canvas, center, width, seed)
	if draw_elemental:
		match kind:
			"fire": _draw_fire(canvas, center, width, phase, seed, reduced_motion)
			"ice": _draw_ice(canvas, center, width, phase, seed)
			"electrified": _draw_electric(canvas, center, width, phase, seed, 1.0)
	if kind == "fire" and Rules.is_conductive(state, tile):
		_draw_electric(canvas, center, width, phase, seed, 0.75)

static func _diamond(p: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0, -h), p + Vector2(w, 0), p + Vector2(0, h), p + Vector2(-w, 0)])

static func _draw_rubble(c: CanvasItem, p: Vector2, w: float, seed: int) -> void:
	_floor_puff(c, p, Vector2(w * 0.76, w * 0.26), 0.0, Color(0.20, 0.16, 0.12, 0.54), seed)
	for i: int in range(9):
		var a: float = float(i) * 2.399963
		var radius: float = w * (0.11 + SpellFx._hash(seed + i) * 0.25)
		var at: Vector2 = p + Vector2(cos(a) * radius, sin(a) * radius * 0.45)
		var size: float = w * (0.029 + SpellFx._hash(seed + i + 20) * 0.028)
		_floor_glow(c, at + Vector2(1, size * 0.5), Vector2(size * 3.0, size * 1.2), Color(0.08, 0.055, 0.035, 0.82))
		SpellFx._rock_fragment(c, at, size, a, Color("b8a085"), seed + i * 17)

static func _draw_fire(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int, reduced: bool) -> void:
	var pulse: float = 0.88 + sin(phase * 2.7) * 0.12
	_floor_glow(c, p, Vector2(w * 0.92, w * 0.36), Color(1.0, 0.24, 0.025, 0.32 * pulse))
	for i: int in range(6):
		var a: float = float(i) * 2.399963 + float(seed) * 0.01
		var radius: float = w * (0.10 + SpellFx._hash(seed + i) * 0.22)
		var at: Vector2 = p + Vector2(cos(a) * radius, sin(a) * radius * 0.46)
		var age: float = 0.4 if reduced else fposmod(phase * 0.55 + float(i) * 0.173, 1.0)
		var opacity: float = sin(age * PI) * 0.32 + 0.10
		var lift: float = w * (0.025 + age * 0.12)
		var size: Vector2 = Vector2(w * 0.12, w * (0.10 + age * 0.13))
		_floor_puff(c, at - Vector2(0, lift), size, sin(phase + i) * 0.12, Color(1.0, 0.30, 0.025, opacity), seed + i)
		_floor_puff(c, at - Vector2(0, lift * 0.65), size * Vector2(0.53, 0.58), 0.0, Color(1.0, 0.83, 0.31, opacity * 0.94), seed + i + 1)
		_floor_glow(c, at, Vector2(w * 0.10, w * 0.035), Color(1.0, 0.48, 0.08, 0.62))
		# Thin, feathered tongues give the low rolling heat a flame silhouette.
		# Their tips stay below the actor's waist and never leave the tile's depth.
		var tongue := PackedVector2Array()
		var height: float = w * (0.12 + SpellFx._hash(seed + i + 57) * 0.065) * (0.9 + 0.1 * sin(phase * 3.4 + i))
		for k: int in range(9):
			var u: float = float(k) / 8.0
			var sway: float = sin(phase * 3.0 + i * 1.7 - u * 3.2) * u * w * 0.026
			tongue.append(at + Vector2(sway, -u * height))
		_floor_ribbon_pair(c, tongue, w * 0.037, Color(1.0, 0.23, 0.018, 0.88), w * 0.019, Color(1.0, 0.77, 0.18, 0.91))
		if i % 2 == 0:
			var ember_age: float = 0.5 if reduced else fposmod(phase * 0.45 + i * 0.23, 1.0)
			var ember: Vector2 = at + Vector2(sin(phase + i) * w * 0.035, -w * (0.10 + ember_age * 0.12))
			_floor_glow(c, ember, Vector2(w * 0.024, w * 0.018), Color(1.0, 0.68, 0.16, sin(ember_age * PI) * 0.72))

static func _draw_ice(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int) -> void:
	var outline: PackedVector2Array = _diamond(p, w * 0.43, w * 0.205)
	c.draw_polygon(outline, PackedColorArray([Color(0.18, 0.53, 0.67, 0.25)]))
	_floor_glow(c, p, Vector2(w * 0.81, w * 0.30), Color(0.45, 0.83, 1.0, 0.24))
	# Frost grows in small, irregular clusters along the slab's perspective edges.
	# Facets share the Ice spell's shaded shards instead of a uniform UI border.
	for edge: int in range(4):
		var a: Vector2 = outline[edge]
		var b: Vector2 = outline[(edge + 1) % 4]
		for cluster: int in range(3):
			var grain: int = seed + edge * 29 + cluster * 71
			var u: float = (float(cluster) + 0.3 + SpellFx._hash(grain) * 0.4) / 3.0
			var at: Vector2 = a.lerp(b, u).lerp(p, 0.035 + SpellFx._hash(grain + 1) * 0.05)
			_floor_puff(c, at, Vector2(w * 0.14, w * 0.035), (b - a).angle(), Color(0.67, 0.89, 0.98, 0.28), grain)
			var glimmer: float = 0.42 + 0.14 * sin(phase * 0.65 + cluster + edge)
			SpellFx._fragment(c, at, w * (0.010 + SpellFx._hash(grain + 2) * 0.008), -PI * 0.5 + (SpellFx._hash(grain + 3) - 0.5) * 0.9, Color(0.52, 0.82, 0.94, glimmer), true)
	for i: int in range(5):
		var a: float = float(i) * 1.2566 + float(seed % 9) * 0.11
		var end: Vector2 = p + Vector2(cos(a) * w * 0.32, sin(a) * w * 0.15)
		var joint: Vector2 = p.lerp(end, 0.54) + Vector2(w * 0.025 * sin(a * 3.0), 0)
		var crack := PackedVector2Array([p, joint, end])
		c.draw_polyline(crack, Color(0.24, 0.57, 0.69, 0.65), maxf(0.7, w * 0.009), true)
		c.draw_polyline(crack, Color(0.79, 0.96, 1.0, 0.48 + sin(phase * 0.6 + i) * 0.10), maxf(0.5, w * 0.0035), true)
	# Restrained glints replace a pulsing targeting-square outline.
	var glint: Vector2 = p + Vector2(-w * 0.18, -w * 0.04)
	_floor_glow(c, glint, Vector2(w * 0.20, w * 0.035), Color(0.79, 0.96, 1.0, 0.28 + sin(phase * 0.7) * 0.10))

static func _draw_electric(c: CanvasItem, p: Vector2, w: float, phase: float, seed: int, opacity: float) -> void:
	_floor_glow(c, p, Vector2(w * 0.84, w * 0.31), Color(0.39, 0.23, 0.94, opacity * 0.25))
	for i: int in range(3):
		var a: float = float(i) * 2.0944 + float(seed % 7) * 0.21
		var start: Vector2 = p + Vector2(cos(a), sin(a) * 0.44) * w * 0.29
		var end: Vector2 = p + Vector2(cos(a + 2.2), sin(a + 2.2) * 0.44) * w * 0.31
		var alpha: float = (0.38 + pow(0.5 + sin(phase * 2.1 + i) * 0.5, 3.0) * 0.42) * opacity
		_floor_bolt(c, start, end, seed + i, phase * 0.14, w * 0.008, Color(0.68, 0.56, 1.0, alpha))

# Floor particles retain the original textured quad, tint and primitive order.
# Only immutable UV/topology setup and generic polygon triangulation are removed.
static func _floor_glow(c: CanvasItem, p: Vector2, size: Vector2, tint: Color) -> void:
	if not retained_cache_enabled:
		SpellFx._glow(c, p, size, tint)
		return
	if SpellFx._light != null:
		_floor_sprite(c, SpellFx._light, p, size, 0.0, tint)

static func _floor_puff(c: CanvasItem, p: Vector2, size: Vector2, angle: float, tint: Color, index: int) -> void:
	if not retained_cache_enabled:
		SpellFx._puff(c, p, size, angle, tint, index)
		return
	if not SpellFx._clouds.is_empty():
		_floor_sprite(c, SpellFx._clouds[posmod(index, SpellFx._clouds.size())], p, size, angle, tint)

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

# Shared topology is ordered exactly like consecutive outer then inner strips.
# The Fire tints are constant, so paired vertex colors are also retained.
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

static func _floor_ribbon_pair(c: CanvasItem, points: PackedVector2Array, outer_width: float, outer_tint: Color, inner_width: float, inner_tint: Color) -> void:
	if not retained_cache_enabled:
		SpellFx._ribbon(c, points, outer_width, outer_tint, false)
		SpellFx._ribbon(c, points, inner_width, inner_tint, false)
		return
	if points.size() < 2:
		return
	if outer_tint.a <= 0.002 or inner_tint.a <= 0.002:
		_floor_ribbon(c, points, outer_width, outer_tint, false)
		_floor_ribbon(c, points, inner_width, inner_tint, false)
		return
	if points.size() == 2:
		if points[0].distance_squared_to(points[1]) < 0.0001: return
		points = PackedVector2Array([points[0], points[0].lerp(points[1], 0.5), points[1]])
	var count: int = points.size()
	var template: Dictionary = _floor_ribbon_template(count)
	if not template.has("pair_indices"):
		var base_indices: PackedInt32Array = template["indices"]
		var pair_indices: PackedInt32Array = base_indices.duplicate()
		for index: int in base_indices:
			pair_indices.append(index + count * 3)
		template["pair_indices"] = pair_indices
	if template.get("pair_outer_tint") != outer_tint or template.get("pair_inner_tint") != inner_tint:
		var colors := PackedColorArray()
		colors.resize(count * 6)
		var outer_clear := Color(outer_tint.r, outer_tint.g, outer_tint.b, 0.0)
		var inner_clear := Color(inner_tint.r, inner_tint.g, inner_tint.b, 0.0)
		for vertex: int in range(count):
			var outer: int = vertex * 3
			var inner: int = outer + count * 3
			colors[outer] = outer_clear
			colors[outer + 1] = outer_tint
			colors[outer + 2] = outer_clear
			colors[inner] = inner_clear
			colors[inner + 1] = inner_tint
			colors[inner + 2] = inner_clear
		template["pair_colors"] = colors
		template["pair_outer_tint"] = outer_tint
		template["pair_inner_tint"] = inner_tint
	var vertices: PackedVector2Array = _floor_ribbon_pair_vertices(points, outer_width, inner_width, template["taper"])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), template["pair_indices"], vertices, template["pair_colors"])

static func _floor_ribbon_pair_vertices(points: PackedVector2Array, outer_width: float, inner_width: float, taper: PackedFloat64Array) -> PackedVector2Array:
	var count: int = points.size()
	var vertices := PackedVector2Array()
	vertices.resize(count * 6)
	for vertex: int in range(count):
		var tangent: Vector2 = (points[mini(vertex + 1, count - 1)] - points[maxi(0, vertex - 1)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		# Keep the original multiplication order for exact vertex coordinates.
		var outer_offset: Vector2 = normal * outer_width * taper[vertex]
		var inner_offset: Vector2 = normal * inner_width * taper[vertex]
		var outer: int = vertex * 3
		var inner: int = outer + count * 3
		vertices[outer] = points[vertex] + outer_offset
		vertices[outer + 1] = points[vertex]
		vertices[outer + 2] = points[vertex] - outer_offset
		vertices[inner] = points[vertex] + inner_offset
		vertices[inner + 1] = points[vertex]
		vertices[inner + 2] = points[vertex] - inner_offset
	return vertices

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
