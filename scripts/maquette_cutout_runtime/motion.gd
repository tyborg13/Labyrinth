extends RefCounted

## Semantic tracks retain the director's clock; all positions are local to
## exported joints. Translations convert board pixels exactly once.
static var _cache: Dictionary = {}

static func data_for(layout: Dictionary) -> Dictionary:
	var path: String = str(layout.get("motion_data", ""))
	if not _cache.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_cache[path] = parsed if parsed is Dictionary else {}
	return _cache[path]

static func value_at(keys: Array, phase: float) -> float:
	if phase <= float(keys[0]["at"]): return float(keys[0]["value"])
	for index: int in range(1, keys.size()):
		var a: Dictionary = keys[index - 1]
		var b: Dictionary = keys[index]
		if phase <= float(b["at"]):
			var weight: float = inverse_lerp(float(a["at"]), float(b["at"]), phase)
			match str(b["interpolation"]):
				"smoothstep": weight = smoothstep(0.0, 1.0, weight)
				"hold": weight = 1.0 if phase == float(b["at"]) else 0.0
			return lerpf(float(a["value"]), float(b["value"]), weight)
	return float(keys[-1]["value"])

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var data: Dictionary = data_for(layout)
	if clip == "rest" or not data.get("clips", {}).has(clip): return {}
	var values: Dictionary = {}
	for track: Dictionary in data["view_tracks"][facing][clip]:
		var bone: String = str(track["bone"])
		if not values.has(bone): values[bone] = {}
		var value: float = value_at(track["keys"], clampf(phase, 0.0, 1.0))
		if track["channel"] == "forward_px" and track["forward_mode"] == "fraction_of_step": value *= float(layout.get("step_distance_px", 0.0))
		values[bone][track["channel"]] = value
	var result: Dictionary = {}
	var joints: Dictionary = layout["joints"]
	var forward := point(data["projection"][facing]["forward"])
	var pixel_scale: float = float(layout.get("screen_pixel_scale", 1.0))
	for bone: String in joints:
		var joint: Dictionary = joints[bone]
		var parent: String = "" if joint.get("parent") == null else str(joint["parent"])
		var origin: Vector2 = point(joint["position"]) - (Vector2.ZERO if parent.is_empty() else point(joints[parent]["position"]))
		var channels: Dictionary = values.get(bone, {})
		var squash: float = float(channels.get("squash", 1.0))
		var uniform: float = float(channels.get("scale", 1.0))
		result[bone] = {"position": origin + (forward * float(channels.get("forward_px", 0.0)) + Vector2(0, -float(channels.get("lift_px", 0.0)))) / maxf(pixel_scale, 0.000001),
			"rotation": deg_to_rad(float(channels.get("raise_deg", 0.0)) + float(channels.get("lean_deg", 0.0))),
			"scale": Vector2(uniform / squash, uniform * squash), "alpha": float(channels.get("alpha", 1.0))}
	return result

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
