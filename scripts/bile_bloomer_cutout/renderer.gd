extends Node

## Persistent directional mineral bloom. Combat outcomes remain resolver-owned.
const Rig = preload("res://scripts/bile_bloomer_cutout/rig.gd")
const Motion = preload("res://scripts/bile_bloomer_cutout/motion.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const REST_PATH: String = "res://assets/units/bile_bloomer_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const IDLE_CYCLE_SECONDS: float = 1.8
const WALK_CYCLE_SECONDS: float = 0.9
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const BURST_FRAMES: int = 60
const BURST_FRAME_SECONDS: float = 1.0 / 60.0
const MARK_PREPARE_FRAMES: int = 14
const MARK_PREPARE_FRAME_SECONDS: float = Motion.MARK_PREPARE_SECONDS / MARK_PREPARE_FRAMES

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
	viewport.name = "BileBloomerCanvas"
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
			push_error("Shale Bloomer cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	if str(actor.get("type", "")) != "bile_bloomer":
		return false
	var kind: String = str(effect.get("kind", ""))
	return kind == "ranged" or (kind == "aoe" and int(effect.get("range", 0)) <= 0)

static func motion_for_effect(effect: Dictionary, progress: float, player_tile: Vector2i) -> Dictionary:
	var action: String = "mark" if str(effect.get("kind", "")) == "ranged" else "burst"
	var phase_value: float = progress
	if action == "mark":
		phase_value = (Motion.MARK_PREPARE_SECONDS + Motion.MARK_EFFECT_SECONDS * progress) / Motion.MARK_DURATION
	var origin: Vector2i = effect.get("from", Vector2i.ZERO)
	var target: Vector2i = effect.get("to", origin)
	return {"clip": "attack", "action": action, "phase": phase_value,
		"direction": (player_tile if target == origin else target) - origin}

static func preparation_motion(effect: Dictionary, progress: float) -> Dictionary:
	return {"clip": "attack", "action": "mark", "phase": progress * Motion.MARK_PREPARE_SECONDS / Motion.MARK_DURATION,
		"direction": (effect.get("to", Vector2i.ZERO) as Vector2i) - (effect.get("from", Vector2i.ZERO) as Vector2i)}

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
	if delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(delta)
		facing = direction["facing"]
		mirrored = bool(direction["mirrored"])
	if not active:
		_apply_pose()
		return
	var previous_clip: String = clip
	var requested: String = str(motion.get("clip", "idle"))
	phase = float(motion.get("phase", 0.0))
	if requested == "walk":
		clip = "walk"
		phase = fposmod(phase, 1.0)
	elif requested == "attack" and phase < 1.0:
		clip = "mark" if str(motion.get("action", "burst")) == "mark" else "burst"
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

func source_socket() -> Vector2:
	var rig: Node2D = rigs.get(facing, null) as Node2D
	if rig == null:
		return Vector2(124, 48)
	return (rig.bones["core"] as Node2D).global_position - SOURCE_OFFSET

func snapshot() -> Dictionary:
	return {"art": "bile_bloomer_cutout_v01", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(), "source_socket": source_socket(),
		"texture_id": texture().get_instance_id() if texture() != null else 0}
