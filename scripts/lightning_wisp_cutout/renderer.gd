extends Node

## One persistent canvas per LightningWisp, shared by all retained board layers.
const Rig = preload("res://scripts/lightning_wisp_cutout/rig.gd")
const EnemyFacing = preload("res://scripts/enemy_cutout_facing.gd")
const Motion = preload("res://scripts/lightning_wisp_cutout/motion.gd")
const REST_PATH: String = "res://assets/units/lightning_wisp_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
# Flight follows actual projected distance at the existing 0.68 body scale.
const WALK_CYCLE_SECONDS: float = 0.39
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const IDLE_CYCLE_SECONDS: float = 1.6
const ATTACK_FRAMES: int = 36
const ATTACK_FRAME_SECONDS: float = 1.0 / 60.0

var viewport: SubViewport
var output_viewport: SubViewport
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
	viewport.name = "LightningWispCanvas"
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
			push_error("Lightning Wisp cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	# Preserve the accepted front's extensive partial alpha when its canvas
	# is later submitted through the board's ordinary texture blending.
	output_viewport = SubViewport.new()
	output_viewport.name = "StraightAlphaCanvas"
	output_viewport.size = CANVAS_SIZE
	output_viewport.transparent_bg = true
	output_viewport.disable_3d = true
	output_viewport.world_2d = World2D.new()
	output_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(output_viewport)
	var output := Sprite2D.new()
	output.centered = false
	output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	output.texture = viewport.get_texture()
	var conversion := ShaderMaterial.new()
	conversion.shader = preload("res://scripts/lightning_wisp_cutout/straight_alpha.gdshader")
	output.material = conversion
	output_viewport.add_child(output)
	_apply_pose()

static func walk_cycle_distance() -> float:
	return (Motion.walk_cycle_info({}, "front")["travel_per_cycle"] as Vector2).length()

static func walk_segment_frames(source_distance: float) -> int:
	return maxi(1, roundi(source_distance / walk_cycle_distance() * WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS))

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return EnemyFacing.direction_for_delta(delta)

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == "lightning_wisp" and str(effect.get("kind", "")) in ["melee", "ranged"]

static func cast_pose_phase(progress: float) -> float:
	# Gathering is authored before the unchanged lightning effect. Release
	# aligns with its existing anticipation/travel boundary (4/30).
	var release: float = 4.0 / 30.0
	return lerpf(.36, .5, progress / release) if progress <= release else lerpf(.5, 1.0, (progress - release) / (1.0 - release))

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
			if str(motion.get("action", "")) == "cast":
				clip = "cast"
				phase = float(motion["authored_phase"]) if motion.has("authored_phase") else cast_pose_phase(phase)
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
	output_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return output_viewport.get_texture() if output_viewport != null else null

func snapshot() -> Dictionary:
	return {"art": "lightning_wisp_cutout_v01", "facing": facing, "mirrored": mirrored,
		"clip": "rest" if reduced_motion else clip,
		"phase": 0.0 if reduced_motion else _idle_seconds / IDLE_CYCLE_SECONDS if clip == "idle" else phase,
		"active": active, "rig_count": rigs.size(),
		"texture_id": texture().get_instance_id() if texture() != null else 0}
