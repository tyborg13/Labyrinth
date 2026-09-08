extends Node

## A stable texture RID lets the retained board draw live bones without rebuilding
## its tiles for every breath. Both painted facings stay loaded between turns.
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const REST_PATH: String = "res://assets/units/protagonist_cutout/front/front_assembled_rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const WALK_CYCLE_SECONDS: float = 0.24
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const MELEE_FRAMES: int = 30
const MELEE_FRAME_SECONDS: float = 1.0 / 60.0

var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var reduced_motion: bool = false
var reduced_motion_source: Callable
var active: bool = true
var _idle_seconds: float = 0.0
var _pose_signature: Array = []

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "CutoutCanvas"
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
			push_error("Protagonist cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	# Board projection: +x southeast, +y southwest, -x northwest, -y northeast.
	# Diagonal targets resolve to the dominant grid axis, with x breaking ties.
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return {"facing": "front" if delta.x > 0 else "rear", "mirrored": true}
	return {"facing": "front" if delta.y >= 0 else "rear", "mirrored": false}

static func attack_pose_phase(progress: float) -> float:
	# 180ms lift/hold, a 30ms cut through contact at 210ms, then follow-through
	# and recovery. The accepted painted poses are unchanged; only time changes.
	var keys := PackedVector2Array([Vector2(0, 0), Vector2(0.34, 0.27),
		Vector2(0.36, 0.31), Vector2(0.42, 0.44), Vector2(0.60, 0.60), Vector2(1, 1)])
	for index: int in range(1, keys.size()):
		if progress <= keys[index].x:
			return lerpf(keys[index - 1].y, keys[index].y,
				inverse_lerp(keys[index - 1].x, keys[index].x, clampf(progress, 0, 1)))
	return 1.0

static func attack_trail_phase(progress: float) -> float:
	# Hide the old full-arc effect during preparation. Its bright cut now reaches
	# the target at the same time as the blade and damage, then dissipates.
	if progress < 0.36 or progress >= 0.74:
		return -1.0
	if progress <= 0.42:
		return remap(progress, 0.36, 0.42, 0.0, 0.45)
	return remap(progress, 0.42, 0.74, 0.45, 1.0)

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	reduced_motion = reduce
	active = enabled
	var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
	if delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(delta)
		facing = direction["facing"]
		mirrored = bool(direction["mirrored"])
	var previous_clip: String = clip
	clip = str(motion.get("clip", "idle"))
	phase = float(motion.get("phase", 0.0))
	if clip == "attack":
		if phase >= 1.0:
			clip = "idle"
		else:
			phase = attack_pose_phase(phase)
	if clip == "idle" and previous_clip != "idle":
		_idle_seconds = 0.0
	_apply_pose()

func _process(delta: float) -> void:
	if not active or not is_instance_valid(viewport):
		return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree():
		return
	if reduced_motion_source.is_valid():
		var next_reduced: bool = bool(reduced_motion_source.call())
		if next_reduced != reduced_motion:
			reduced_motion = next_reduced
			_apply_pose()
	if clip == "idle" and not reduced_motion:
		_idle_seconds = fposmod(_idle_seconds + delta, 3.0)
		_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty():
		return
	var shown_clip: String = "rest" if reduced_motion else clip
	var shown_phase: float = 0.0 if reduced_motion else (_idle_seconds / 3.0 if clip == "idle" else phase)
	var signature: Array = [facing, mirrored, shown_clip, shown_phase]
	if signature == _pose_signature:
		return
	_pose_signature = signature
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if not rig.visible:
			continue
		rig.position = Vector2(383, 128) if mirrored else SOURCE_OFFSET
		rig.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
		rig.call("apply_pose", shown_clip, shown_phase)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null

func snapshot() -> Dictionary:
	return {"art": "protagonist_cutout_pass7", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip, "phase": 0.0 if reduced_motion else (_idle_seconds / 3.0 if clip == "idle" else phase),
		"rig_count": rigs.size(), "texture_id": texture().get_instance_id() if texture() != null else 0}
