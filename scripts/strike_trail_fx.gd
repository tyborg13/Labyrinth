extends RefCounted
## Warm additive light, sampled in effect progress. No clocks or mutable RNG.
## Board-space points; every width, reach and drift uses attacker source pixels.
const TAIL: float = 0.10
const FADE: float = 0.06
const CONTACT: float = 0.42
const SAMPLE_STEP: float = 1.0 / 240.0
const ARC_RADIUS: float = 44.0
const ARC_BODY_HEIGHT: float = 80.0
const ClawMarks = preload("res://scripts/enemy_claw_marks.gd")
const PALETTES: Dictionary = {
	"none": [Color8(255, 244, 220), Color8(255, 178, 92), Color8(150, 60, 20)],
	"fire": [Color8(255, 236, 200), Color8(255, 128, 48), Color8(170, 40, 10)],
	"ice": [Color8(236, 250, 255), Color8(140, 210, 255), Color8(40, 90, 150)],
	"lightning": [Color8(248, 240, 255), Color8(186, 150, 255), Color8(80, 50, 170)],
	"air": [Color8(240, 255, 246), Color8(150, 230, 200), Color8(40, 110, 90)],
	"earth": [Color8(255, 240, 214), Color8(214, 160, 96), Color8(110, 70, 30)]}

static func motion_settings(motion: String) -> Dictionary:
	match motion:
		"heavy": return {"window": Vector2(0.25, 0.56), "kind": "sweep", "reach": 0.50, "length": 0.0}
		"stab": return {"window": Vector2(0.33, 0.54), "kind": "streak", "reach": 1.0, "length": 48.0}
		"thrust": return {"window": Vector2(0.30, 0.54), "kind": "streak", "reach": 1.0, "length": 74.0}
		"lash": return {"window": Vector2(0.30, 0.54), "kind": "sweep", "reach": 0.09, "length": 0.0}
		# A bow/repeater limb needs a short smear, clear of the hero's head.
		"bow", "repeater": return {"window": Vector2(0.33, 0.56), "kind": "sweep", "reach": 0.25, "length": 0.0}
		_: return {"window": Vector2(0.33, 0.56), "kind": "sweep", "reach": 0.55, "length": 0.0}

static func palette(element: String) -> Array:
	return PALETTES.get(element, PALETTES["none"])

static func envelope(progress: float, window: Vector2, contact: float = CONTACT) -> float:
	if progress <= window.x or progress >= window.y + FADE - 0.000001:
		return 0.0
	if progress <= contact:
		return smoothstep(window.x, contact, progress)
	var brightness: float = lerpf(1.0, 0.65, clampf(inverse_lerp(contact, window.y, progress), 0.0, 1.0))
	return brightness * (1.0 - clampf((progress - window.y) / FADE, 0.0, 1.0))

static func sample_at(samples: Array[Dictionary], progress: float) -> Dictionary:
	if samples.is_empty():
		return {}
	for index: int in range(1, samples.size()):
		var b: Dictionary = samples[index]
		if float(b["progress"]) >= progress:
			var a: Dictionary = samples[index - 1]
			var t: float = clampf(inverse_lerp(a["progress"], b["progress"], progress), 0.0, 1.0)
			return {"progress": progress, "tip": (a["tip"] as Vector2).lerp(b["tip"], t),
				"inner": (a["inner"] as Vector2).lerp(b["inner"], t)}
	return samples[-1]

static func visible_samples(samples: Array[Dictionary], progress: float, window: Vector2) -> Array[Dictionary]:
	var visible: Array[Dictionary]
	var start: float = maxf(window.x, progress - TAIL)
	var end: float = minf(progress, window.y)
	if samples.is_empty() or end <= start:
		return visible
	visible.append(sample_at(samples, start))
	for sample: Dictionary in samples:
		if float(sample["progress"]) > start and float(sample["progress"]) < end:
			visible.append(sample)
	visible.append(sample_at(samples, end))
	return visible

static func arc_samples(from: Vector2, to: Vector2, scale: float, window: Vector2) -> Array[Dictionary]:
	var samples: Array[Dictionary]
	var direction: Vector2 = (to - from).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	# Tiles are floor anchors. The old 30px lift put the contact near the
	# target's feet; use body height and complete the cut by contact instead
	# of spreading its angle uniformly across the entire strike window.
	var center: Vector2 = to - Vector2(0, ARC_BODY_HEIGHT * scale)
	var count: int = ceili((window.y - window.x) / SAMPLE_STEP)
	for index: int in range(count + 1):
		var progress: float = minf(window.x + float(index) * SAMPLE_STEP, window.y)
		var angle: float = lerpf(-2.2, 0.3, smoothstep(window.x, CONTACT, progress)) if progress <= CONTACT else lerpf(0.3, 0.9, clampf(inverse_lerp(CONTACT, window.y, progress), 0.0, 1.0))
		var tip: Vector2 = center + direction.rotated(angle) * ARC_RADIUS * scale
		samples.append({"progress": progress, "tip": tip, "inner": tip.lerp(center, 0.55)})
	return samples

static func sparks(samples: Array[Dictionary], progress: float, window: Vector2,
		scale: float, seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	# Emission belongs to fixed samples, never to the current visible-list index.
	for index: int in range(0, samples.size(), 4):
		var sample: Dictionary = samples[index]
		var age: float = progress - float(sample["progress"])
		if age < 0.0 or age >= TAIL or _noise(seed, index, 0) > 0.55:
			continue
		var drift := Vector2(_noise(seed, index, 1) * 2.0 - 1.0, 0.6) * age * 90.0
		var jitter := Vector2(_noise(seed, index, 2), _noise(seed, index, 3)) * 8.0 - Vector2(4, 4)
		result.append({"point": (sample["tip"] as Vector2) + (drift + jitter) * scale,
			"radius": lerpf(0.7, 1.3, _noise(seed, index, 4)) * scale,
			"alpha": (1.0 - age / TAIL) * envelope(progress, window)})
	return result

static func _noise(seed: int, index: int, lane: int) -> float:
	var value: int = (seed ^ (index * 374761393) ^ (lane * 668265263)) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value & 65535) / 65535.0

static func geometry(samples: Array[Dictionary], kind: String, progress: float,
		contact: float, window: Vector2, element: String, scale: float, seed: int,
		streak_length: float = 48.0) -> Array[Dictionary]:
	var batches: Array[Dictionary]
	var alpha: float = envelope(progress, window, contact)
	if alpha <= 0.0 or scale <= 0.0:
		return batches
	var visible: Array[Dictionary] = visible_samples(samples, progress, window)
	if visible.size() < 2:
		return batches
	var colors: Array = palette(element)
	# All glow geometry precedes the sharp core, with interpolated clear edges.
	for glow: bool in [true, false]:
		var pass_batches: Array[Dictionary]
		match kind:
			"sweep", "arc":
				pass_batches.append(_sweep(visible, colors, alpha, scale, glow))
			"streak":
				var tip: Vector2 = visible[-1]["tip"]
				var axis: Vector2 = (tip - (visible[-1]["inner"] as Vector2)).normalized()
				var normal := Vector2(-axis.y, axis.x)
				for lane: int in range(3):
					var points := PackedVector2Array()
					var offset: float = 0.0 if lane == 0 else 4.0 if lane == 1 else -4.0
					for index: int in range(19):
						points.append(tip - axis * streak_length * scale * float(index) / 18.0 * (1.0 if lane == 0 else 0.7) + normal * offset * scale)
					points.reverse()
					pass_batches.append(_streak(points, colors, _streak_envelope(progress, window, contact) * (1.0 if lane == 0 else 0.6), (4.4 if lane == 0 else 1.6) * scale, glow))
			"rake":
				for lane: int in range(-1, 2):
					var points := PackedVector2Array()
					for sample: Dictionary in visible:
						var axis: Vector2 = ((sample["tip"] as Vector2) - (sample["inner"] as Vector2)).normalized()
						points.append((sample["tip"] as Vector2) + Vector2(-axis.y, axis.x) * float(lane) * 4.0 * scale)
					pass_batches.append(_ribbon(points, colors, alpha, 1.6 * scale, glow))
			"claw_marks":
				var point: Dictionary = sample_at(samples, contact)
				pass_batches.append(ClawMarks.geometry(point["tip"], (point["tip"] as Vector2) - (point["inner"] as Vector2), colors, alpha, scale, glow, progress))
		if kind not in ["rake", "claw_marks"]:
			var edge := PackedVector2Array()
			for sample: Dictionary in visible:
				edge.append(sample["tip"])
			pass_batches.append(_ribbon(edge, colors, alpha, 1.6 * scale, glow))
		for spark: Dictionary in sparks(samples, progress, window, scale, seed):
			pass_batches.append(_diamond(spark["point"], spark["radius"] * (2.8 if glow else 1.0), colors[1], spark["alpha"] * (0.16 if glow else 0.8)))
		if progress >= contact and progress < contact + 0.10:
			var point: Vector2 = sample_at(samples, contact)["tip"]
			var life: float = 1.0 - (progress - contact) / 0.10
			# One four-point contact glint; vertices feather to clear at the tips.
			pass_batches.append(_diamond(point, 11.0 * scale * (0.6 + 0.6 * life) * (1.45 if glow else 1.0), colors[0], life * (0.18 if glow else 1.0), 1.2 * scale))
		batches.append(_combine(pass_batches))
	return batches

static func _combine(batches: Array[Dictionary]) -> Dictionary:
	# One submission per light pass even when sparks and streak lanes add
	# geometry. Preserve primitive order and per-vertex color interpolation.
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for batch: Dictionary in batches:
		var offset: int = vertices.size()
		vertices.append_array(batch["vertices"])
		colors.append_array(batch["colors"])
		for index: int in batch["indices"]:
			indices.append(index + offset)
	return {"indices": indices, "vertices": vertices, "colors": colors}

static func draw(canvas: CanvasItem, batches: Array[Dictionary]) -> void:
	for batch: Dictionary in batches:
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), batch["indices"], batch["vertices"], batch["colors"])

static func _sweep(samples: Array[Dictionary], palette_colors: Array, alpha: float, scale: float, glow: bool) -> Dictionary:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var rows := PackedFloat32Array([-0.08, 0.0, 0.12, 0.55, 1.0])
	for index: int in range(samples.size()):
		var u: float = float(index) / float(samples.size() - 1)
		var tip: Vector2 = samples[index]["tip"]
		var inner: Vector2 = tip.lerp(samples[index]["inner"], pow(u, 0.85))
		var axis: Vector2 = (inner - tip).normalized()
		for row: int in range(rows.size()):
			var f: float = rows[row]
			vertices.append(tip.lerp(inner, f) + axis * (f - 0.5) * (5.0 * scale if glow else 0.0))
			var color: Color = (palette_colors[0] as Color).lerp(palette_colors[1], minf(1.0, maxf(0.0, f) / 0.12)).lerp(palette_colors[2], maxf(0.0, f))
			color = color.lerp(palette_colors[2], (1.0 - u) * 0.65)
			color.a = alpha * pow(u, 1.3) * pow(1.0 - maxf(0.0, f), 1.4) * (0.18 if glow else 0.8)
			if row == 0 or row == rows.size() - 1:
				color.a = 0.0
			colors.append(color)
	return _strip(vertices, colors, rows.size())

static func _ribbon(points: PackedVector2Array, palette_colors: Array, alpha: float, width: float, glow: bool) -> Dictionary:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for index: int in range(points.size()):
		var u: float = float(index) / float(points.size() - 1)
		var tangent: Vector2 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width: float = width * (0.4 + 0.6 * u) * (2.8 if glow else 0.5)
		var color: Color = (palette_colors[2] as Color).lerp(palette_colors[1], u).lerp(palette_colors[0], u * u)
		color.a = alpha * pow(u, 1.8) * (0.18 if glow else 0.95)
		var clear := Color(color, 0.0)
		vertices.append_array(PackedVector2Array([points[index] + normal * half_width, points[index], points[index] - normal * half_width]))
		colors.append_array(PackedColorArray([clear, color, clear]))
	return _strip(vertices, colors, 3)

static func _streak_envelope(progress: float, window: Vector2, contact: float = CONTACT) -> float:
	# The thrust must already read at full strength during the drive, before
	# the .42 contact glint. Follow-through keeps the shared .06 fade.
	if progress <= contact:
		return smoothstep(window.x, minf(0.40, contact), progress)
	return envelope(progress, window, contact)

static func _streak(points: PackedVector2Array, palette_colors: Array, alpha: float, width: float, glow: bool) -> Dictionary:
	# Axial speed lines have their own profile. The tip-path ribbon and the
	# approved sword/heavy sweep keep their existing width and alpha taper.
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for index: int in range(points.size()):
		var u: float = float(index) / float(points.size() - 1)
		var tangent: Vector2 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width: float = width * 0.5 * (3.0 if glow else 1.0)
		var color: Color = (palette_colors[1] as Color).lerp(palette_colors[0], u)
		color.a = alpha * minf(1.0, u / 0.30) * (0.35 if glow else 1.0)
		vertices.append(points[index] + normal * half_width)
		if glow:
			vertices.append(points[index])
			colors.append_array(PackedColorArray([Color(color, 0.0), color, Color(color, 0.0)]))
		else:
			colors.append_array(PackedColorArray([color, color]))
		vertices.append(points[index] - normal * half_width)
	return _strip(vertices, colors, 3 if glow else 2)

static func _strip(vertices: PackedVector2Array, colors: PackedColorArray, rows: int) -> Dictionary:
	var indices := PackedInt32Array()
	for index: int in range(vertices.size() / rows - 1):
		for row: int in range(rows - 1):
			var a: int = index * rows + row
			var b: int = a + rows
			indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))
	return {"indices": indices, "vertices": vertices, "colors": colors}

static func _diamond(point: Vector2, radius: float, color: Color, alpha: float, waist: float = -1.0) -> Dictionary:
	color.a = alpha
	var clear := Color(color, 0.0)
	var vertices := PackedVector2Array([point])
	var colors := PackedColorArray([color])
	var indices := PackedInt32Array()
	for index: int in range(8):
		var length: float = radius if index % 2 == 0 or waist < 0 else waist
		vertices.append(point + Vector2.from_angle(float(index) * PI / 4.0) * length)
		colors.append(clear if index % 2 == 0 else color)
	for index: int in range(8):
		indices.append_array(PackedInt32Array([0, index + 1, (index + 1) % 8 + 1]))
	return {"indices": indices, "vertices": vertices, "colors": colors}
