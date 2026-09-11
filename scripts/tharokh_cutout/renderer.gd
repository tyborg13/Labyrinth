extends Node

## One persistent canvas per Tharokh, shared by all retained board layers.
const Rig = preload("res://scripts/tharokh_cutout/rig.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const Motion = preload("res://scripts/tharokh_cutout/motion.gd")
const REST_PATH: String = "res://assets/units/tharokh_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
# The 2x2 dragon advances through one deliberate four-foot crawl cycle.
# Source distance drives phase and board traversal together.
const WALK_CYCLE_SECONDS: float = 0.66
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 2.4
const ATTACK_FRAMES: int = 63
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
	viewport.name = "TharokhCanvas"
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
			push_error("Tharokh cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func action_clip(effect: Dictionary, actor: Dictionary) -> String:
	if str(actor.get("type", "")) != "tharokh":
		return ""
	if str(effect.get("action_type", "")) == "terrain_burst":
		return "faultline"
	if str(effect.get("action_type", "")) == "raise_terrain":
		return "brace"
	return "claw" if str(effect.get("kind", "")) == "melee" else ""

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return action_clip(effect, actor) in ["claw", "faultline"]

static func attack_frames(effect: Dictionary) -> int:
	return 66 if str(effect.get("action_type", "")) == "terrain_burst" else ATTACK_FRAMES

static func attack_pose_phase(progress: float, contact: float) -> float:
	# The rake/stamp reaches authored contact at 0.55. Remap it to the
	# existing resolved effect boundary; presentation never applies damage.
	var boundary: float = clampf(contact, 0.01, 0.99)
	var keys := PackedVector2Array([Vector2(0, 0), Vector2(boundary * 0.75, 0.32),
		Vector2(boundary * 0.88, 0.42), Vector2(boundary, 0.55),
		Vector2(lerpf(boundary, 1.0, 0.32), 0.65), Vector2(1, 1)])
	for index: int in range(1, keys.size()):
		if progress <= keys[index].x:
			return lerpf(keys[index - 1].y, keys[index].y,
				inverse_lerp(keys[index - 1].x, keys[index].x, clampf(progress, 0.0, 1.0)))
	return 1.0

static func attack_trail_phase(progress: float) -> float:
	# The existing slash is visible only during the claw rake/contact,
	# so it cannot announce a hit while Tharokh is still preparing the rake.
	var cut_start: float = 0.42 * 0.88
	if progress < cut_start or progress >= 0.72:
		return -1.0
	if progress <= 0.42:
		return remap(progress, cut_start, 0.42, 0.0, 0.45)
	return remap(progress, 0.42, 0.72, 0.45, 1.0)

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
	var requested_clip: String = str(motion.get("clip", "idle"))
	clip = str(motion.get("action", "claw")) if requested_clip == "attack" else requested_clip
	phase = float(motion.get("phase", 0.0))
	if clip == "walk":
		phase = fposmod(phase, 1.0)
	elif clip in ["claw", "faultline"]:
		if phase >= 1.0:
			clip = "idle"
		else:
			phase = attack_pose_phase(phase, float(motion.get("contact", 0.42)))
	elif clip == "brace":
		if phase >= 1.0:
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
	return {"art": "tharokh_cutout_v01", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(),
		"texture_id": texture().get_instance_id() if texture() != null else 0}
