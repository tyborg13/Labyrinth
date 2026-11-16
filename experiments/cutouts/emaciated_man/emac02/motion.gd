extends RefCounted
## Director round 2/3: two rigid groups, protagonist keys, rr-05 holds.
const PixelPresentation = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const IDLE_SECONDS: float = 3.36
const BOB_SECONDS: float = 1.68
const GLOW_SECONDS: float = 3.36
const SACK_LAG_SECONDS: float = 0.84
const GLOW_PEAK_ALPHA: float = 0.35
const REDUCED_GLOW_ALPHA: float = 0.15
const UPPER: Array = ["robe_torso", "head_hood", "near_upper_arm", "near_forearm", "near_hand", "far_upper_arm", "far_forearm_hand", "far_hand_support"]

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var previous: Vector2 = keys[index - 1]
			var next: Vector2 = keys[index]
			var u: float = clampf((t - previous.x) / (next.x - previous.x), 0.0, 1.0)
			return lerpf(previous.y, next.y, u * u * (3.0 - 2.0 * u))
	return keys[keys.size() - 1].y

static func bob_offset(phase: float) -> float:
	var held: float = PixelPresentation.phase_for({"clips":{"idle":{"loop":true,"seconds":IDLE_SECONDS}}}, "idle", phase)
	var t: float = fposmod(held * IDLE_SECONDS, BOB_SECONDS) / BOB_SECONDS
	return roundf(_curve(t, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.18, 2.0), Vector2(0.55, 2.0),
		Vector2(0.91, 0.0), Vector2(1.0, 0.0)])))

static func _point(layout: Dictionary, name: String) -> Vector2:
	var p: Array = layout["joints"][name]["position"]
	return Vector2(p[0], p[1])

static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	var pose: Dictionary = {}
	var bob: float = bob_offset(phase) if clip == "idle" else 0.0
	for name: String in layout["joints"]:
		var parent: String = str(layout["joints"][name]["parent"]) if layout["joints"][name]["parent"] != null else ""
		var point: Vector2 = _point(layout, name)
		if not parent.is_empty(): point -= _point(layout, parent)
		# Child and parent in the upper group translate together. In particular,
		# both influences of the far forearm mesh have identical global offsets.
		point.y += bob * (float(name in UPPER) - float(parent in UPPER))
		pose[name] = {"position": point}
	return pose

static func glow_alpha(seconds: float, sack: bool, reduced: bool = false) -> float:
	return REDUCED_GLOW_ALPHA if reduced else GLOW_PEAK_ALPHA * (1.0 - cos(TAU * (seconds - (SACK_LAG_SECONDS if sack else 0.0)) / GLOW_SECONDS)) * 0.5

static func sample_glow(clip: String, phase: float) -> Dictionary:
	var seconds: float = fposmod(phase, 1.0) * IDLE_SECONDS
	return {"eyes":glow_alpha(seconds, false, clip == "rest"), "sack":glow_alpha(seconds, true, clip == "rest")}
