extends RefCounted
## Enemy-only projection rules. Rig points retain their registration; light
## sizes have a floor, and tiny/non-forward authored paths get readable FX.
const Trail = preload("res://scripts/strike_trail_fx.gd")
const SHORT_PATH: float = 24.0
const AXIS_LIMIT: float = 50.0

static func samples_for(resolved: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for sample: Dictionary in resolved["samples"]: result.append(sample)
	return result

static func size_scale(board: Control, actor: Dictionary) -> float:
	return board.protagonist_source_pixel_scale() * clampf(float(board.call("_unit_art_scale", actor)), 0.9, 1.6)

static func path_span(samples: Array[Dictionary]) -> float:
	var span: float = 0.0
	for i: int in range(samples.size()):
		for j: int in range(i + 1, samples.size()):
			span = maxf(span, (samples[i]["tip"] as Vector2).distance_squared_to(samples[j]["tip"]))
	return sqrt(span)

static func resolve(samples: Array[Dictionary], kind: String, attacker: Vector2,
		target: Vector2, scale: float, contact: float, window: Vector2, span: float = -1.0) -> Dictionary:
	var result: Array[Dictionary] = samples.duplicate(true)
	if samples.is_empty(): return {"samples":result, "kind":kind, "fallback":false}
	var point: Dictionary = Trail.sample_at(samples, contact)
	var anchor: Vector2 = point["tip"]
	var target_direction: Vector2 = (target - attacker).normalized()
	if target_direction == Vector2.ZERO: target_direction = Vector2.RIGHT
	var to_target: Vector2 = (target - anchor).normalized()
	if to_target == Vector2.ZERO: to_target = target_direction
	var measured: float = path_span(samples) if span < 0.0 else span
	var short_path: bool = measured < SHORT_PATH * scale
	var direction: Vector2 = target_direction
	match kind:
		"sweep":
			if short_path:
				kind = "arc"
				result = _anchored_arc(anchor, target_direction, scale, contact, window)
		"streak":
			for sample: Dictionary in result:
				var axis: Vector2 = ((sample["tip"] as Vector2) - (sample["inner"] as Vector2)).normalized()
				if short_path or axis.dot(target_direction) < cos(deg_to_rad(AXIS_LIMIT)):
					axis = to_target
				sample["inner"] = (sample["tip"] as Vector2) - axis * scale
			direction = ((Trail.sample_at(result,contact)["tip"] as Vector2) - (Trail.sample_at(result,contact)["inner"] as Vector2)).normalized()
		"rake":
			if not short_path:
				direction = (anchor - (Trail.sample_at(samples,contact - 0.02)["tip"] as Vector2)).normalized()
				if direction == Vector2.ZERO: direction = target_direction
			kind = "claw_marks"
			for sample: Dictionary in result:
				sample["inner"] = (sample["tip"] as Vector2) - direction * scale
	return {"samples":result, "kind":kind, "fallback":short_path, "span":measured,
		"anchor":anchor, "direction":direction, "target_direction":to_target}

static func _anchored_arc(anchor: Vector2, direction: Vector2, scale: float,
		contact: float, window: Vector2) -> Array[Dictionary]:
	var canonical := Vector2(window.x / contact * Trail.CONTACT,
		Trail.CONTACT + (window.y - contact) / (1.0 - contact) * (1.0 - Trail.CONTACT))
	var lift := Vector2(0, Trail.ARC_BODY_HEIGHT * scale)
	var samples: Array[Dictionary] = Trail.arc_samples(anchor - direction + lift, anchor + lift, scale, canonical)
	var offset: Vector2 = anchor - (Trail.sample_at(samples,Trail.CONTACT)["tip"] as Vector2)
	for sample: Dictionary in samples:
		var time: float = sample["progress"]
		sample["progress"] = time / Trail.CONTACT * contact if time <= Trail.CONTACT else contact + (time - Trail.CONTACT) / (1.0 - Trail.CONTACT) * (1.0 - contact)
		sample["tip"] += offset
		sample["inner"] += offset
	return samples
