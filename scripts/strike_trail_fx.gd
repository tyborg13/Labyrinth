extends RefCounted
## Pixel trail cores, sampled in effect progress. No clocks or mutable RNG.
## Board-space samples become screen-cell profiles in the pixel painter.
const TAIL: float = 0.14
const FADE: float = 0.08
const SPARK_LIFETIME: float = 0.10
const CONTACT: float = 0.42
const SAMPLE_STEP: float = 1.0 / 240.0
const ARC_RADIUS: float = 44.0
const ARC_BODY_HEIGHT: float = 80.0
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
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

static func visible_samples(samples: Array[Dictionary], progress: float, window: Vector2, exposure_start: float = -1.0) -> Array[Dictionary]:
	var visible: Array[Dictionary]
	var start: float = maxf(window.x, minf(progress - TAIL, exposure_start) if exposure_start >= 0.0 else progress - TAIL)
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
		if age < 0.0 or age >= SPARK_LIFETIME or _noise(seed, index, 0) > 0.55:
			continue
		var drift := Vector2(_noise(seed, index, 1) * 2.0 - 1.0, 0.6) * age * 90.0
		var jitter := Vector2(_noise(seed, index, 2), _noise(seed, index, 3)) * 8.0 - Vector2(4, 4)
		result.append({"point": (sample["tip"] as Vector2) + (drift + jitter) * scale,
			"radius": lerpf(0.7, 1.3, _noise(seed, index, 4)) * scale,
			"alpha": (1.0 - age / SPARK_LIFETIME) * envelope(progress, window)})
	return result

static func _noise(seed: int, index: int, lane: int) -> float:
	var value: int = (seed ^ (index * 374761393) ^ (lane * 668265263)) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value & 65535) / 65535.0

## Source geometry for rig registration. The on-board painter uses
## pixel_geometry and never submits the unsnapped hilt-to-tip envelope.
static func geometry(samples: Array[Dictionary], kind: String, progress: float,
		contact: float, window: Vector2, element: String, scale: float, seed: int,
		streak_length: float = 48.0, previous_progress: float = -1.0, glint_anchor: Variant = null, contact_tail: float = -1.0) -> Array[Dictionary]:
	var batches: Array[Dictionary] = pixel_geometry(samples, kind, progress, contact, window, element, scale, seed,
		streak_length, previous_progress, glint_anchor, contact_tail)
	if batches.is_empty() or batches[0]["shape"] != "crescent": return batches
	var tips: PackedVector2Array = batches[0]["points"]
	var hilt: PackedVector2Array = batches[0]["hilt"]
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	for i: int in tips.size():
		vertices.append(tips[i])
		vertices.append(tips[i] + hilt[i])
		if i > 0:
			var a: int = 2 * (i - 1)
			indices.append_array(PackedInt32Array([a, a + 1, a + 3, a, a + 3, a + 2]))
	batches.insert(1, {"shape": "source_envelope", "vertices": vertices, "indices": indices})
	return batches

static func pixel_geometry(samples: Array[Dictionary], kind: String, progress: float,
		contact: float, window: Vector2, element: String, scale: float, seed: int,
		streak_length: float = 48.0, previous_progress: float = -1.0, glint_anchor: Variant = null, contact_tail: float = -1.0) -> Array[Dictionary]:
	var batches: Array[Dictionary]
	var alpha: float = envelope(progress, window, contact)
	if contact_tail > 0.0 and progress >= contact:
		alpha = 0.0 if progress >= contact+contact_tail-0.000001 else maxf(0.0,1.0-(progress-contact)/contact_tail)
	if alpha <= 0.0 or scale <= 0.0:
		return batches
	# A coarse body step can jump over contact and over most of the rolling
	# tail. Retain that crossed exposure at its peak, including the contact
	# glint, and bridge to the actual current tip. No body/feedback retiming.
	var crossed_contact: bool = previous_progress >= 0.0 and progress - previous_progress > TAIL and previous_progress < contact and progress >= contact
	var exposure_start: float = minf(previous_progress, contact - TAIL) if crossed_contact else -1.0
	var visible: Array[Dictionary] = visible_samples(samples, progress, window, window.x if contact_tail>0.0 else exposure_start)
	if contact_tail>0.0: visible = _distance_samples(visible)
	if crossed_contact:
		alpha = maxf(alpha, envelope(contact, window, contact))
		visible = _distance_samples(visible)
	if visible.size() < 2:
		return batches
	var ramp: PackedColorArray = Pixel.ramp_for(Pixel.trail_ramp_id(element))
	match kind:
		"sweep", "arc":
			var points := PackedVector2Array()
			var hilt := PackedVector2Array()
			for sample: Dictionary in visible:
				var tip: Vector2 = sample["tip"]
				points.append(tip)
				hilt.append((sample["inner"] as Vector2) - tip)
			batches.append({"shape": "crescent", "points": points, "hilt": hilt, "alpha": alpha})
		"streak":
			var tip: Vector2 = visible[-1]["tip"]
			var axis: Vector2 = (tip - (visible[-1]["inner"] as Vector2)).normalized()
			var coverage: float = alpha if contact_tail > 0.0 else _streak_envelope(progress, window, contact)
			batches.append({"shape": "streak", "points": PackedVector2Array([tip - axis * streak_length * scale, tip]),
				"alpha": coverage})
		"rake":
			for lane: int in range(-1, 2):
				var points := PackedVector2Array()
				for sample: Dictionary in visible:
					var axis: Vector2 = ((sample["tip"] as Vector2) - (sample["inner"] as Vector2)).normalized()
					points.append((sample["tip"] as Vector2) + Vector2(-axis.y, axis.x) * float(lane) * 4.0 * scale)
				batches.append(_stroke(points, ramp, alpha, 1.6 * scale))
		"claw_marks":
			var point: Dictionary = sample_at(samples, contact)
			var marks: Dictionary = ClawMarks.geometry(point["tip"], (point["tip"] as Vector2) - (point["inner"] as Vector2), ramp, alpha, scale, progress)
			if not marks.is_empty(): batches.append(marks)
	for spark: Dictionary in sparks(samples, progress, window, scale, seed):
		batches.append({"shape": "spark", "point": spark["point"], "radius": spark["radius"],
			"ink": Color(ramp[-2], float(spark["alpha"]) * 0.8)})
	if progress >= contact and (progress < contact + 0.10 or crossed_contact):
		var point: Vector2 = sample_at(samples, contact)["tip"] if glint_anchor == null else glint_anchor
		var age: float = 0.0 if crossed_contact else (progress - contact) / 0.10
		batches.append({"shape": "glint", "point": point, "age": age})
	return batches

static func _distance_samples(samples: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if samples.size() < 2: return samples
	var lengths := PackedFloat32Array([0.0])
	for index: int in range(1, samples.size()):
		lengths.append(lengths[-1] + (samples[index]["tip"] as Vector2).distance_to(samples[index-1]["tip"]))
	if is_zero_approx(lengths[-1]): return samples
	var segment: int = 1
	for index: int in range(samples.size()):
		var distance: float = lengths[-1] * float(index) / float(samples.size()-1)
		while segment < samples.size()-1 and lengths[segment] < distance: segment += 1
		var t: float = inverse_lerp(lengths[segment-1], lengths[segment], distance) if lengths[segment] > lengths[segment-1] else 0.0
		var a: Dictionary = samples[segment-1]
		var b: Dictionary = samples[segment]
		result.append({"progress":lerpf(a["progress"],b["progress"],t), "tip":(a["tip"] as Vector2).lerp(b["tip"],t),
			"inner":(a["inner"] as Vector2).lerp(b["inner"],t)})
	return result

static func bounds(batches: Array[Dictionary]) -> Rect2:
	var result := Rect2()
	for batch: Dictionary in batches:
		for point: Vector2 in batch.get("vertices", batch.get("points", PackedVector2Array())):
			result = result.expand(point) if result.has_area() else Rect2(point, Vector2.ONE)
		if batch.has("point"):
			var point: Vector2 = batch["point"]
			var radius: float = float(batch.get("radius", 0.0))
			# The trail viewport's cell padding covers the glint's fixed arms.
			var box := Rect2(point - Vector2.ONE * radius, Vector2.ONE * maxf(1.0, 2.0 * radius))
			result = result.merge(box) if result.has_area() else box
	return result

static func draw(canvas: Node2D, batches: Array[Dictionary]) -> void:
	canvas.begin_trail()
	for batch: Dictionary in batches:
		match batch["shape"]:
			"crescent", "streak":
				canvas.trail_profile(batch)
			"stroke":
				RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), batch["indices"], batch["vertices"], batch["colors"])
				canvas.trail_stroke(batch)
			"claws":
				canvas.trail_claws(batch)
			"spark":
				canvas.trail_spark(batch["point"], batch["radius"], batch["ink"])
			"glint":
				canvas.trail_glint(batch["point"], batch["age"])

static func _stroke(points: PackedVector2Array, ramp: PackedColorArray, alpha: float, width: float) -> Dictionary:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var ink := PackedColorArray()
	for index: int in range(points.size()):
		var u: float = float(index) / float(points.size() - 1)
		var tangent: Vector2 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width: float = width * 0.5 * (0.4 + 0.6 * u)
		var color: Color = ramp[2].lerp(ramp[3], u).lerp(ramp[4], u * u)
		color.a = alpha * pow(u, 1.8) * 0.95
		var edge := Color(color, 0.0)
		vertices.append_array(PackedVector2Array([points[index] + normal * half_width, points[index], points[index] - normal * half_width]))
		colors.append_array(PackedColorArray([edge, color, edge]))
		ink.append(color)
	var indices := PackedInt32Array()
	for index: int in range(points.size() - 1):
		for row: int in range(2):
			var a: int = index * 3 + row
			var b: int = a + 3
			indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))
	return {"shape": "stroke", "points": points, "ink": ink, "vertices": vertices, "colors": colors, "indices": indices}

static func _streak_envelope(progress: float, window: Vector2, contact: float = CONTACT) -> float:
	# The thrust must already read at full strength during the drive, before
	# the .42 contact glint. Follow-through keeps the shared fade.
	if progress <= contact:
		return smoothstep(window.x, minf(0.40, contact), progress)
	return envelope(progress, window, contact)
