extends Node

## One persistent canvas per Noctyrax, shared by retained board layers and echoes.
const Rig = preload("res://scripts/noctyrax_cutout/rig.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const Motion = preload("res://scripts/noctyrax_cutout/motion.gd")
const REST_PATH: String = "res://assets/units/noctyrax_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
# A deliberate quadruped crawl; phase follows projected distance at the
# unchanged 1.86 boss art scale.
const WALK_CYCLE_SECONDS: float = 0.68
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 2.4
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
	viewport.name = "NoctyraxCanvas"
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
			push_error("Noctyrax cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func clip_for_effect(effect: Dictionary) -> String:
	if str(effect.get("action_type", "")) == "umbra_eclipse":
		return "eclipse"
	match str(effect.get("kind", "")):
		"melee": return "claw"
		"ranged": return "breath"
		"aoe": return "coil"
	return "idle"

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == "noctyrax" and clip_for_effect(effect) != "idle"

static func action_frames(effect: Dictionary, reduce: bool) -> int:
	if reduce:
		return 1
	return int({"claw": 66, "breath": 72, "coil": 72, "eclipse": 96}.get(clip_for_effect(effect), 66))

static func attack_pose_phase(progress: float, contact: float) -> float:
	# Each dragon action releases at authored phase 0.5. The existing result
	# boundary still owns damage, statuses, pull, terrain and eclipse changes.
	var boundary: float = clampf(contact, 0.01, 0.99)
	return 0.5 * progress / boundary if progress <= boundary else 0.5 + 0.5 * (progress - boundary) / (1.0 - boundary)

static func breath_pose_phase(progress: float) -> float:
	# Shadow projectiles leave at 18% and hit at 66%. Aim the maw at launch,
	# hold through travel, and recover only after the existing impact boundary.
	var keys := PackedVector2Array([Vector2(0,0),Vector2(0.12,0.30),Vector2(0.18,0.50),Vector2(0.66,0.63),Vector2(1,1)])
	for index: int in range(1,keys.size()):
		if progress <= keys[index].x:
			return lerpf(keys[index-1].y,keys[index].y,inverse_lerp(keys[index-1].x,keys[index].x,progress))
	return 1.0

static func claw_trail_phase(progress: float) -> float:
	var start: float = 0.42*0.80
	if progress < start or progress >= 0.72:
		return -1.0
	return remap(progress,start,0.42,0.0,0.45) if progress <= 0.42 else remap(progress,0.42,0.72,0.45,1.0)

func maw_canvas_position() -> Vector2:
	var rig: Node2D = rigs.get(facing) as Node2D
	if rig == null: return SOURCE_OFFSET+Vector2(127,100)
	var head: Node2D = rig.get("bones")["head"]
	var muzzle: Vector2 = Vector2(11,17) if facing == "rear" else Vector2(-23,20)
	return head.global_transform*muzzle

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
		phase = fposmod(phase, 1.0)
	elif clip in ["claw", "breath", "coil", "eclipse"]:
		if phase >= 1.0:
			clip = "idle"
		else:
			phase = breath_pose_phase(phase) if clip == "breath" else attack_pose_phase(phase, float(motion.get("contact", 0.42)))
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
	return {"art": "noctyrax_cutout_v01", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(),
		"texture_id": texture().get_instance_id() if texture() != null else 0}
