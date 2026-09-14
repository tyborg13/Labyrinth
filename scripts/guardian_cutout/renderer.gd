extends Node

## One persistent canvas per guardian or helper, shared by retained board layers.
const Rig = preload("res://scripts/guardian_cutout/rig.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const Motion = preload("res://scripts/guardian_cutout/motion.gd")
const ACTOR_IDS = ["ash_hound", "ashen_reaver", "bell_tender", "craghide", "gallows_roc", "last_lamplighter", "rime_spitter", "rime_whelp", "rimejaw", "roc_fledgling", "stoneback_mite", "storm_cantor", "wick_shade"]
var character_id: String = ""
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
# Movement timing uses each creature’s authored support cycle.
const WALK_CYCLE_SECONDS: float = 0.32
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 1.6
const ATTACK_FRAMES: int = 18
const ATTACK_FRAME_SECONDS: float = 0.03

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
	viewport.name = "GuardianCanvas"
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.character_id = character_id
		rig.name = view.capitalize()
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig():
			push_error(character_id + " cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance(actor_type: String = "") -> float:
	return float(Motion.gait(actor_type)[0])

static func walk_cycle_seconds(actor_type: String = "") -> float:
	return float(Motion.gait(actor_type)[2])

static func walk_segment_frames(source_distance: float, actor_type: String = "") -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance(actor_type) * walk_cycle_seconds(actor_type) / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func handles(actor_type: String) -> bool:
	return ACTOR_IDS.has(actor_type)

static func rest_path(actor_type: String) -> String:
	return "res://assets/units/guardians/%s/front/rest.png" % actor_type

static func action_clip(effect: Dictionary, actor: Dictionary = {}) -> String:
	if not actor.is_empty() and not handles(str(actor.get("type", ""))): return ""
	match str(effect.get("action_type", effect.get("kind", ""))):
		"block", "stoneskin", "raise_terrain": return "brace"
		"ranged", "surface", "summon", "summon_minions": return "cast"
		"melee", "aoe", "terrain_burst", "push", "pull", "lightning_strikes": return "strike"
	return ""

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return handles(str(actor.get("type", ""))) and not action_clip(effect, actor).is_empty()

static func action_motion(effect: Dictionary, actor: Dictionary, progress: float, contact: float) -> Dictionary:
	# Match the authored impact pose to the actual damage/FX boundary.
	var boundary: float = clampf(contact, 0.01, 0.99)
	var phase_value: float = progress / boundary * 0.46 if progress <= boundary else 0.46 + (progress-boundary)/(1.0-boundary)*0.54
	return {"clip":"attack", "action":action_clip(effect, actor), "phase":phase_value,
		"direction":(effect.get("to", actor.get("pos", Vector2i.ZERO)) as Vector2i)-(effect.get("from", actor.get("pos", Vector2i.ZERO)) as Vector2i)}

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
	elif clip == "attack":
		if phase >= 1.0:
			clip = "idle"
		else:
			clip = str(motion.get("action", "strike"))
			if clip not in ["strike", "cast", "brace"]:
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
	return {"art": character_id + "_cutout_v01", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(),
		"texture_id": texture().get_instance_id() if texture() != null else 0}
