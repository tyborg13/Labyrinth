extends RefCounted

## Independent rigid pieces. No mesh weights, ripple, or whole-body idle bob.
const Data = preload("motion_data.gd")
const CHANNELS := ["body_y", "body_forward", "body_pitch", "body_roll", "body_scale_y", "head_angle", "head_x", "head_y", "head_forward",
	"wing_near_angle", "wing_far_angle", "wing_near_span", "wing_far_span",
	"tail_angle", "legs_angle", "legs_x", "legs_y", "recoil"]

static func design_errors() -> Array[String]:
	var result: Array[String]
	for key: String in Data.TODO_DESIGN:
		if not str(Data.TODO_DESIGN[key]).is_empty(): result.append(key)
	for view: String in ["front", "rear"]:
		for clip: String in Data.TRACKS:
			var tracks: Array = tracks_for(clip, view)
			if tracks.is_empty(): result.append("Missing tracks: " + view + "/" + clip)
			result.append_array(track_errors(tracks))
	if Data.DIVE_RECOVERY_FRAME_SECONDS <= 0:
		result.append("Invalid recovery clock")
	for clip: String in Data.CONTACT_PHASES:
		if float(Data.CONTACT_PHASES[clip]) <= 0 or float(Data.CONTACT_PHASES[clip]) >= 1:
			result.append("Invalid contact phase/" + clip)
	return result

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	return sample_tracks(clip, phase, layout, facing, tracks_for(clip, facing))

static func tracks_for(clip: String, facing: String) -> Array:
	var tracks: Array = (Data.TRACKS.get(clip, []) as Array).duplicate()
	tracks.append_array(Data.VIEW_TRACKS.get(facing, {}).get(clip, []))
	return tracks

static func pixel_scale(layout: Dictionary) -> float:
	return float(layout.get("screen_pixel_scale", Data.PROOF_PIXEL_SCALE))

static func track_errors(tracks: Array) -> Array[String]:
	var result: Array[String]
	for track: Dictionary in tracks:
		var channel: String = str(track.get("channel", ""))
		if channel not in CHANNELS: result.append("Unknown channel: " + channel)
		var keys: Array = track.get("keys", [])
		if keys.is_empty(): result.append("Missing keys: " + channel)
		var previous: float = -1.0
		for index: int in range(keys.size()):
			var key: Dictionary = keys[index]
			if typeof(key.get("at")) not in [TYPE_INT, TYPE_FLOAT] or typeof(key.get("value")) not in [TYPE_INT, TYPE_FLOAT]:
				result.append("Unresolved key: " + channel)
				continue
			var at: float = float(key["at"])
			var value: float = float(key["value"])
			if not is_finite(at) or not is_finite(value) or at < 0 or at > 1 or at <= previous:
				result.append("Invalid key: " + channel)
			if (channel.ends_with("span") or channel == "body_scale_y") and value <= 0:
				result.append("Nonpositive part scale: " + channel)
			if index > 0 and str(key.get("interpolation", "")) not in ["hold", "linear", "smoothstep"]:
				result.append("Unresolved interpolation: " + channel)
			previous = at
	return result

static func channel_values(tracks: Array, phase: float) -> Dictionary:
	var values: Dictionary = {}
	for track: Dictionary in tracks:
		var channel: String = str(track.get("channel", ""))
		if channel in CHANNELS:
			values[channel] = track_value(track.get("keys", []), clampf(phase, 0.0, 1.0))
	return values

static func sample_tracks(clip: String, phase: float, layout: Dictionary, facing: String, tracks: Array) -> Dictionary:
	if clip == "rest" or tracks.is_empty() or not track_errors(tracks).is_empty(): return {}
	var values: Dictionary = channel_values(tracks, phase)
	var joints: Dictionary = layout.get("joints", {})
	if not joints.has("body") or not joints.has("root"): return {}
	var root_position: Vector2 = _point(joints["root"]["position"])
	var pivot: Vector2 = _point(joints["body"]["position"])
	var body_angle: float = deg_to_rad(float(values.get("body_pitch", 0.0)) + float(values.get("body_roll", 0.0)))
	var body_scale: float = float(values.get("body_scale_y", 1.0))
	var pixels_per_source: float = pixel_scale(layout)
	if pixels_per_source <= 0: return {}
	var forward: Vector2 = _point(Data.PROJECTION[facing]["forward"])
	# Recoil direction is already expressed in the unreflected source view.
	# A case study places its diagnostic attacker in front; combat supplies the
	# actual resolved attacker vector, including an explicit zero when unknown.
	var recoil: Vector2 = layout.get("recoil_direction", -forward)
	var translation: Vector2 = (Vector2(0, float(values.get("body_y", 0.0))) + forward * float(values.get("body_forward", 0.0)) + recoil * float(values.get("recoil", 0.0))) / pixels_per_source
	var body := Transform2D(body_angle, Vector2(1, body_scale), 0, pivot + translation)
	var result: Dictionary = {"body": {"position": pivot - root_position + translation,
		"rotation": body_angle, "scale": Vector2(1, body_scale)}}
	for name: String in ["head", "wing_near", "wing_far", "tail", "legs"]:
		if not joints.has(name): continue
		var bind: Vector2 = _point(joints[name]["position"])
		# Sibling bones avoid transmitting breathing scale into rigid feathers,
		# the beak or the feet. The idle head holds its world-space look pose.
		# Death's authored lift, side roll and drop carry the whole bird. The
		# director's planted-foot rule applies to idle/hit and grounded crouches.
		var planted: bool = name == "legs" and (clip in ["idle", "hit"] or (clip == "move" and float(values.get("body_y", 0.0)) >= 0.0))
		var held_head: bool = name == "head" and clip == "idle"
		var origin: Vector2 = bind if planted or held_head else body * (bind - pivot)
		var angle: float = 0.0 if planted or held_head else body_angle
		angle += deg_to_rad(float(values.get(name + "_angle", 0.0)))
		if planted:
			# Grounded rotations pivot at the exported foot/root contact, so a
			# crouch cannot rotate the talons off it.
			origin = root_position + (bind - root_position).rotated(angle)
		origin += (Vector2(float(values.get(name + "_x", 0.0)), float(values.get(name + "_y", 0.0))) + forward * float(values.get(name + "_forward", 0.0))) / pixels_per_source
		result[name] = {"position": origin - root_position, "rotation": angle}
		if name.begins_with("wing_"):
			result[name]["scale"] = Vector2(float(values.get(name + "_span", 1.0)), 1.0)
	return result

static func track_value(keys: Array, phase: float) -> float:
	if keys.is_empty(): return 0.0
	if phase <= float(keys[0]["at"]): return float(keys[0]["value"])
	for index: int in range(1, keys.size()):
		var previous: Dictionary = keys[index - 1]
		var current: Dictionary = keys[index]
		if phase <= float(current["at"]):
			var weight: float = inverse_lerp(float(previous["at"]), float(current["at"]), phase)
			match str(current.get("interpolation", "")):
				"hold": weight = 1.0 if phase == float(current["at"]) else 0.0
				"smoothstep": weight = smoothstep(0.0, 1.0, weight)
				"linear": pass
				_: return float(previous["value"])
			return lerpf(float(previous["value"]), float(current["value"]), weight)
	return float(keys[-1]["value"])

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
