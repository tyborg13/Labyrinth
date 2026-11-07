extends RefCounted
## Contact-playback rigs publish impact FX only at contact. Their trail has a
## separate presentation clock, so the actual pre-contact swing can emit light.
const Points = preload("res://scripts/enemy_strike_points.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const SavedPose = preload("res://scripts/maquette_cutout_runtime/strike_points.gd")
const SWING_SPEED_FRACTION: float = 0.25
const CONTACT_TAIL: float = 0.10
var _profiles: Dictionary = {}

static func decorate(shown: Dictionary, effect: Dictionary, actor: Dictionary,
		phase: float, authored_contact: float) -> void:
	if str(effect.get("kind","")) not in ["melee","aoe"]: return
	if not bool(Points.settings(str(actor["type"]),effect).get("live_weapon",false)): return
	var contact: float = Points.contact(effect)
	shown["strike_trail_effect"] = effect
	shown["strike_trail_progress"] = contact * phase / authored_contact if phase < authored_contact else contact + (1.0-contact) * (phase-authored_contact) / (1.0-authored_contact)

func profile(renderer: Node, actor: Dictionary, effect: Dictionary, settings: Dictionary, boundary: float) -> Dictionary:
	var clip: String = Action.clip_for(effect,actor)
	if clip.is_empty(): return {}
	var key: Array = [renderer.get_instance_id(),renderer.facing,renderer.mirrored,clip,boundary]
	if _profiles.has(key): return _profiles[key]
	var definition: Dictionary = Action.data_for(str(actor["type"]))["clips"][clip]
	var contact: float = float(definition["contact"])
	var intervals: int = Action.frames_for(str(actor["type"]),clip)-1
	var contact_frame: int = ceili(contact*intervals)
	var rig: Node2D = renderer.rigs[renderer.facing]
	var saved: Array[Dictionary] = SavedPose.save_nodes(rig)
	var angles: Dictionary = rig.precise_angles.duplicate(true)
	var speeds: Array[float]
	var phases: Array[float]
	var previous := Vector2.ZERO
	var peak: float = 0.0
	for frame: int in range(contact_frame+1):
		var phase: float = Action.contact_phase(float(frame)/intervals,float(contact_frame)/intervals,contact)
		rig.apply_pose(clip,phase)
		var tip: Vector2 = Points.live_sample(renderer,settings,phase)["tip"]
		var speed: float = 0.0 if frame==0 else tip.distance_to(previous)
		speeds.append(speed)
		phases.append(phase)
		peak = maxf(peak,speed)
		previous = tip
	SavedPose.restore_nodes(saved)
	rig.precise_angles = angles
	var start: int = 0
	for frame: int in range(1,speeds.size()):
		if speeds[frame]>peak*SWING_SPEED_FRACTION and speeds[frame-1]<=peak*SWING_SPEED_FRACTION:
			start = frame-1
	var result: Dictionary = {"window":Vector2(boundary*phases[start]/contact,boundary+CONTACT_TAIL),
		"contact_tail":CONTACT_TAIL,"swing_start_frame":start,"contact_frame":contact_frame,
		"clip_frames":intervals+1,"peak_source_speed":peak,"clock":"contact_playback_swing"}
	_profiles[key] = result
	return result
