extends Node

## Persistent canvas and loaded views for one Bone Harrier. Shared by retained board layers.
const Rig = preload("res://scripts/harrier_cutout/rig.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const Motion = preload("res://scripts/harrier_cutout/motion.gd")
const REST_PATH: String = "res://assets/units/harrier_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
# Harrier stride follows actual traveled source distance in the 2:1 board plane.
const WALK_CYCLE_SECONDS: float = 0.48
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 1.45
const ATTACK_FRAMES: int = 39
const ATTACK_FRAME_SECONDS: float = 1.0 / 60.0

var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var reduced_motion: bool = false
var active: bool = true
var _idle_seconds: float = 0.0
var _pose_signature: Array = []

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "HarrierCanvas"
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.name = view.capitalize()
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig():
			push_error("Bone Harrier cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == "harrier" and str(effect.get("kind", "")) in ["melee", "ranged"]

static func attack_pose_phase(progress: float, contact: float) -> float:
	var boundary: float = clampf(contact, 0.01, 0.99)
	var keys := PackedVector2Array([Vector2(0,0),Vector2(boundary*0.68,0.30),Vector2(boundary*0.82,0.40),Vector2(boundary,0.55),Vector2(lerpf(boundary,1.0,0.25),0.66),Vector2(1,1)])
	for index: int in range(1,keys.size()):
		if progress <= keys[index].x:
			return lerpf(keys[index-1].y,keys[index].y,inverse_lerp(keys[index-1].x,keys[index].x,clampf(progress,0,1)))
	return 1.0

static func attack_trail_phase(progress: float) -> float:
	return -1.0 if progress < 0.34 or progress > 0.60 else inverse_lerp(0.34,0.60,progress)

func source_release_socket(delta: Vector2i) -> Vector2:
	var orientation: Dictionary = direction_for_delta(delta)
	var rig: Node = rigs[orientation["facing"]]
	var pose: Dictionary = Motion.sample_pose("cast",0.55,rig.layout,str(orientation["facing"]))
	# Cast launches from the rigid spear tip at the fixed release pose, even during recovery.
	var local_tip: Array = rig.layout["landmarks"]["weapon_tip"]
	var grip: Array = rig.layout["joints"]["weapon_r"]["position"]
	var point: Vector2 = Motion._world(pose,rig.layout,"weapon_r") * (Vector2(local_tip[0],local_tip[1])-Vector2(grip[0],grip[1]))
	if bool(orientation["mirrored"]):point.x = SOURCE_SIZE.x-point.x
	return point

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
	if delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(delta)
		facing = direction["facing"]
		mirrored = bool(direction["mirrored"])
	if not active:
		# Hidden actors retain their facing but pause animation; death
		# dissolves the same frozen art without resetting its current pose.
		_apply_pose()
		return
	var previous_clip: String = clip
	clip = str(motion.get("clip", "idle"))
	phase = float(motion.get("phase", 0.0))
	if clip == "walk":
		clip = "retreat" if str(motion.get("travel_variant", "walk")) == "retreat" else "walk"
		phase = fposmod(phase, 1.0)
	elif clip == "attack":
		if phase >= 1.0:
			clip = "idle"
		else:
			clip = "cast" if str(motion.get("family", "melee")) == "ranged" else "attack"
			phase = phase if bool(motion.get("authored_phase", false)) else attack_pose_phase(phase, float(motion.get("contact", 0.42)))
	else:
		clip = "idle"
	if clip == "idle" and previous_clip != "idle":
		_idle_seconds = 0.0
	_apply_pose()

func _process(delta: float) -> void:
	if not active or not is_instance_valid(viewport):
		return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree():
		return
	if clip == "idle" and not reduced_motion:
		_idle_seconds = fposmod(_idle_seconds + delta, IDLE_CYCLE_SECONDS)
		_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty():
		return
	var shown_clip: String = "rest" if reduced_motion else clip
	var shown_phase: float = 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase
	var signature: Array = [facing, mirrored, shown_clip, shown_phase]
	if signature == _pose_signature:
		return
	_pose_signature = signature
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if rig.visible:
			rig.position = Vector2(383, 128) if mirrored else SOURCE_OFFSET
			rig.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
			rig.call("apply_pose", shown_clip, shown_phase)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null

func snapshot() -> Dictionary:
	return {"art": "harrier_cutout_v02", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(),
		"texture_id": texture().get_instance_id() if texture() != null else 0}
