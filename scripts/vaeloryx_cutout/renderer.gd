extends Node

## A persistent 512px canvas per Vaeloryx, with independently loaded painted
## front/rear rigs. Logical 2x2 occupancy remains entirely with the board.
const Rig = preload("res://scripts/vaeloryx_cutout/rig.gd")
const Motion = preload("res://scripts/vaeloryx_cutout/motion.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const REST_PATH: String = "res://assets/units/vaeloryx_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const WALK_CYCLE_SECONDS: float = 0.70
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 2.0
const ATTACK_FRAME_SECONDS: float = 1.0 / 60.0
const DIVE_FRAMES: int = 48
const WIND_FRAMES: int = 60
const GUARD_SECONDS: float = 0.48

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
	viewport.name = "VaeloryxCanvas"
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
			push_error("Vaeloryx cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func action_for_effect(effect: Dictionary, actor: Dictionary) -> String:
	if str(actor.get("type", "")) != "vaeloryx":
		return ""
	if str(effect.get("action_type", "")) == "gale_force":
		return "gale"
	match str(effect.get("kind", "")):
		"melee": return "dive"
		"pull": return "pull"
		"block": return "guard"
	return ""

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return action_for_effect(effect, actor) in ["dive", "gale", "pull"]

static func attack_frame_count(effect: Dictionary, actor: Dictionary) -> int:
	return DIVE_FRAMES if action_for_effect(effect, actor) == "dive" else WIND_FRAMES

static func effect_direction(effect: Dictionary, actor: Dictionary, player_tile: Vector2i) -> Vector2i:
	# A 2x2 actor faces from its occupied center. Doubled tile coordinates keep
	# the shared integer-facing policy exact without rounding the half tile.
	var origin: Vector2i = actor.get("pos", effect.get("from", Vector2i.ZERO))
	var target: Vector2i = effect.get("player_from", effect.get("to", player_tile))
	if str(effect.get("kind", "")) == "block":
		target = player_tile
	return target * 2 - (origin * 2 + Vector2i.ONE)

static func attack_pose_phase(progress: float, contact: float) -> float:
	var t: float = clampf(progress, 0.0, 1.0)
	var boundary: float = clampf(contact, 0.01, 0.99)
	if t <= boundary:
		return Motion.CONTACT * t / boundary
	return lerpf(Motion.CONTACT, 1.0, (t - boundary) / (1.0 - boundary))

static func attack_trail_phase(progress: float) -> float:
	# Existing melee FX begins with the claw thrust, after the lifted windup.
	var start: float = 0.34
	if progress < start or progress >= 0.72:
		return -1.0
	if progress <= 0.42:
		return remap(progress, start, 0.42, 0.0, 0.45)
	return remap(progress, 0.42, 0.72, 0.45, 1.0)

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	# Death receives no idle direction and freezes its current facing and pose.
	var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
	if delta != Vector2i.ZERO:
		var direction: Dictionary = direction_for_delta(delta)
		facing = str(direction["facing"])
		mirrored = bool(direction["mirrored"])
	if not active:
		_apply_pose()
		return
	var previous_clip: String = clip
	clip = str(motion.get("clip", "idle"))
	phase = float(motion.get("phase", 0.0))
	if clip == "walk":
		phase = fposmod(phase, 1.0)
	elif clip == "attack" and phase < 1.0:
		clip = str(motion.get("action", "dive"))
		if clip not in ["dive", "gale", "pull", "guard"]:
			clip = "idle"
		elif clip != "guard":
			phase = attack_pose_phase(phase, float(motion.get("contact", 0.42)))
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
	return {"art": "vaeloryx_cutout_v01", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(), "texture_id": texture().get_instance_id() if texture() != null else 0}
