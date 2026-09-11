extends Node

## One persistent padded canvas per Iskaldra, shared by all retained board layers.
const Rig = preload("res://scripts/iskaldra_cutout/rig.gd")
const Motion = preload("res://scripts/iskaldra_cutout/motion.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const REST_PATH: String = "res://assets/units/iskaldra_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255,255)
const SOURCE_OFFSET := Vector2(128,128)
const CANVAS_SIZE := Vector2i(512,512)
const WALK_CYCLE_SECONDS: float = 0.60
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 2.0

var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var travel_per_cycle: float = 0.0
var reduced_motion: bool = false
var active: bool = true
var _idle_seconds: float = 0.0
var _pose_signature: Array = []

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "IskaldraCanvas"
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for view: String in ["front","rear"]:
		var rig := Rig.new()
		rig.name = view.capitalize()
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig():
			push_error("Iskaldra cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({},"front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	# Duration follows distance; the fitted support cycle may vary its stride,
	# but rounding a cycle must never add a whole extra cycle of travel time.
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func walk_segment_cycles(source_distance: float) -> int:
	# Every resolved segment finishes at the accepted resting stance. Adjust
	# stride to its exact distance instead of dropping an incomplete cycle.
	return maxi(1,roundi(source_distance / walk_cycle_distance()))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	if not active:
		# A death uses the same frozen pose and facing throughout its dissolve.
		_apply_pose()
		return
	var delta: Vector2i = motion.get("direction",Vector2i.ZERO)
	if delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(delta)
		facing = direction["facing"]
		mirrored = bool(direction["mirrored"])
	var previous_clip: String = clip
	var requested: String = str(motion.get("clip","idle"))
	phase = float(motion.get("phase",0.0))
	travel_per_cycle = float(motion.get("travel_per_cycle",0.0))
	if requested == "walk":
		clip = "walk"
		phase = fposmod(phase,1.0)
	elif requested == "attack" and phase < 1.0:
		# The shared facing policy sees an action. The sampler sees the precise
		# dragon family; no humanoid weapon animation is used here.
		clip = str(motion.get("action","idle"))
		if clip not in ["talon","lance","storm","mantle"]:
			clip = "idle"
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
		_idle_seconds = fposmod(_idle_seconds + delta,IDLE_CYCLE_SECONDS)
		_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty():
		return
	var shown_clip: String = "rest" if reduced_motion else clip
	var shown_phase: float = 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase
	var signature: Array = [facing,mirrored,shown_clip,shown_phase,travel_per_cycle]
	if signature == _pose_signature:
		return
	_pose_signature = signature
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if rig.visible:
			rig.position = Vector2(383,128) if mirrored else SOURCE_OFFSET
			rig.scale = Vector2(-1,1) if mirrored else Vector2.ONE
			if shown_clip == "walk":
				rig.call("apply_walk_pose",shown_phase,travel_per_cycle)
			else:
				rig.call("apply_pose",shown_clip,shown_phase)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func source_socket(released: bool = true) -> Vector2:
	# A fixed authored release socket keeps the projectile's flight origin from
	# drifting with recovery. This is geometry only, never a texture readback.
	var rig: Node = rigs[facing]
	var layout: Dictionary = rig.get("layout")
	var pose: Dictionary = Motion.sample_pose("lance" if released else clip,0.45 if released else phase,layout,facing)
	var maw: Array = layout["landmarks"]["maw"]
	var point: Vector2 = Motion.world(pose,layout,"head") * (Vector2(float(maw[0]),float(maw[1])) - Motion.point(layout,"head"))
	return Vector2(SOURCE_SIZE.x-point.x,point.y) if mirrored else point

func texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null

func snapshot() -> Dictionary:
	return {"art":"iskaldra_cutout_v01","facing":facing,"mirrored":mirrored,
		"clip":"rest" if reduced_motion else clip,
		"phase":0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"travel_per_cycle":travel_per_cycle,
		"active":active,"rig_count":rigs.size(),"texture_id":texture().get_instance_id() if texture() != null else 0}
