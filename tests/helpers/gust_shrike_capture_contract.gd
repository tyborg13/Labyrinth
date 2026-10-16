extends RefCounted

const Motion = preload("res://scripts/gust_shrike_cutout/motion.gd")
const Data = preload("res://scripts/gust_shrike_cutout/motion_data.gd")
const ACTIONS := ["move", "dive", "talon_rake", "hover", "hit", "death"]
const MIN_FRAMES: int = 6
const PHASE_EPSILON: float = 0.000001

static func required_phases(clip: String) -> Array:
	var result: Array = [0.0, 1.0]
	if clip == "dive": result.append(Data.CONTACT_PHASES["dive"])
	elif clip == "talon_rake": result.append(Data.CONTACT_PHASES["talon_rake"])
	elif clip in ["move", "hover", "hit"]:
		var channel: String = "body_y" if clip == "move" else "recoil" if clip == "hit" else "wing_near_angle"
		var peak: Dictionary = {"value": 0.0, "at": 0.0}
		for track: Dictionary in Motion.tracks_for(clip, "front"):
			if track["channel"] != channel: continue
			for key: Dictionary in track["keys"]:
				if absf(float(key["value"])) > absf(float(peak["value"])): peak = key
		result.append(float(peak["at"]))
	return result

static func errors(frames: Array) -> Array[String]:
	var result: Array[String]
	for clip: String in ACTIONS:
		var selected: Array = frames.filter(func(frame: Dictionary) -> bool: return frame.get("stage", "") == clip and frame.get("snapshot", {}).get("clip", "") == clip)
		if selected.size() < MIN_FRAMES: result.append(clip + ": fewer than six action frames")
		for required: float in required_phases(clip):
			if not selected.any(func(frame: Dictionary) -> bool: return absf(float(frame["snapshot"]["phase"]) - required) <= PHASE_EPSILON): result.append(clip + ": missing preparation/contact/apex/terminal phase " + str(required))
		var boundary: float = float(Data.CONTACT_PHASES.get(clip, 0.5))
		if not selected.any(func(frame: Dictionary) -> bool: return float(frame["snapshot"]["phase"]) > boundary and float(frame["snapshot"]["phase"]) < 1.0): result.append(clip + ": missing recovery")
		for index: int in range(selected.size()):
			var phase: float = float(selected[index]["snapshot"]["phase"])
			if not is_finite(phase) or phase < 0.0 or phase > 1.0: result.append(clip + ": invalid phase")
			if str(selected[index].get("pose_sha256", "")).is_empty(): result.append(clip + ": missing visible pose evidence")
			if index == 0: continue
			if float(selected[index]["snapshot"]["phase"]) <= float(selected[index - 1]["snapshot"]["phase"]): result.append(clip + ": phase did not advance")
			if selected[index].get("pose_sha256", "") == selected[index - 1].get("pose_sha256", ""): result.append(clip + ": consecutive visible poses are identical")
	return result
