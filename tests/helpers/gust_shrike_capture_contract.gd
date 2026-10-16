extends RefCounted

const Motion = preload("res://scripts/gust_shrike_cutout/motion.gd")
const Data = preload("res://scripts/gust_shrike_cutout/motion_data.gd")
const Action = preload("res://scripts/gust_shrike_cutout/action.gd")
const Context = preload("res://scripts/cutout_context.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const ACTIONS := ["move", "dive", "talon_rake", "hover", "hit", "death"]
const MIN_FRAMES: int = 6
const PHASE_EPSILON: float = 0.000001

static func required_phases(clip: String) -> Array:
	# Production move/melee callbacks begin at frame 1, not zero. Dive's
	# sixth recovery frame already holds rest. Hit retires to idle at phase 1.
	var result: Array
	if clip in ["dive", "hover", "death"]: result.append(0.0)
	if clip in ["move", "talon_rake", "hover", "death"]: result.append(1.0)
	if clip == "dive": result.append(Action.dive_recovery_phase(Data.DIVE_RECOVERY_FRAMES, Data.CONTACT_PHASES["dive"]))
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

static func phase_tolerance(clip: String) -> float:
	# The real attack callback samples hit at the existing popup frame clock;
	# the apex can fall between those samples. No pose is sought to fill it in.
	return FloatingText.TARGET_FRAME_SECONDS / Context.HIT_SECONDS if clip == "hit" else PHASE_EPSILON

static func preparation_limit(clip: String) -> float:
	var first: float = 1.0
	for track: Dictionary in Motion.tracks_for(clip, "front"):
		for key: Dictionary in track["keys"]:
			if float(key["at"]) > 0.0: first = minf(first, float(key["at"]))
	return first

static func errors(frames: Array, completions: Dictionary = {}) -> Array[String]:
	var result: Array[String]
	for clip: String in ACTIONS:
		var selected: Array = frames.filter(func(frame: Dictionary) -> bool: return frame.get("stage", "") == clip and frame.get("snapshot", {}).get("clip", "") == clip)
		if selected.size() < MIN_FRAMES: result.append(clip + ": fewer than six action frames")
		for required: float in required_phases(clip):
			if not selected.any(func(frame: Dictionary) -> bool: return absf(float(frame["snapshot"]["phase"]) - required) <= phase_tolerance(clip)): result.append(clip + ": missing preparation/contact/apex/terminal phase " + str(required))
		if not selected.any(func(frame: Dictionary) -> bool: return float(frame["snapshot"]["phase"]) < preparation_limit(clip)): result.append(clip + ": missing preparation")
		if clip == "hit" and str(completions.get(clip, {}).get("clip", "")) != "idle": result.append(clip + ": missing production return to idle")
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
