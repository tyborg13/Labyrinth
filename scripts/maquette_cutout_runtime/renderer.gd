extends Node

const CommonRig = preload("rig.gd")
const Motion = preload("motion.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const NATIVE_FPS: float = 60.0
var character_id: String = "shale_bloomer"
var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var active: bool = true
var reduced_motion: bool = false
var screen_pixel_scale: float = 1.0
var step_distance_px: float = 0.0
var _idle_seconds: float = 0.0
var _recovering_hit: bool = false
var _pose_signature: Array = []

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "MaquetteCanvas"
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	for view: String in ["front", "rear"]:
		var rig := CommonRig.new()
		rig.character_id = character_id
		rig.name = view.capitalize()
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig(): push_error("Maquette cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": "res://assets/units/" + character_id + "_cutout/compiled_motion.json"})

## LiveActor seeds before tree entry; use the protected compiled clock rather
## than a second UI duration. _ready applies this phase to both loaded rigs.
func seed_idle_phase(value: float) -> void:
	_idle_seconds = fposmod(value, 1.0) * float(motion_data()["clips"]["idle"]["seconds"])
	_apply_pose()

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	var requested: String = str(motion.get("clip", "idle"))
	if clip == "death" and requested != "death": return
	if clip == "hit" and requested == "idle" and phase < 1.0:
		_recovering_hit = true
		_apply_pose()
		return
	_recovering_hit = false
	clip = requested if motion_data()["clips"].has(requested) else "idle"
	phase = clampf(float(motion.get("phase", 0.0)), 0.0, 1.0)
	screen_pixel_scale = float(motion.get("screen_pixel_scale", screen_pixel_scale))
	step_distance_px = float(motion.get("step_distance_px", 0.0))
	if clip not in ["hit", "death"]:
		var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
		if delta != Vector2i.ZERO:
			var direction: Dictionary = Facing.direction_for_delta(delta)
			facing = str(direction["facing"])
			mirrored = bool(direction["mirrored"])
	_apply_pose()

func _process(delta: float) -> void:
	if clip == "hit" and _recovering_hit and not reduced_motion:
		phase = minf(1.0, phase + delta / float(motion_data()["clips"]["hit"]["seconds"]))
		if phase >= 1.0:
			clip = "idle"
			_idle_seconds = 0.0
		_apply_pose()
		return
	if not active or reduced_motion or clip != "idle": return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree(): return
	_idle_seconds = fposmod(_idle_seconds + delta, float(motion_data()["clips"]["idle"]["seconds"]))
	_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty(): return
	var shown: String = _shown_clip()
	var progress: float = _shown_phase()
	var signature: Array = [facing, mirrored, shown, progress, screen_pixel_scale, step_distance_px]
	if signature == _pose_signature: return
	_pose_signature = signature
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if not rig.visible: continue
		rig.position = Vector2(SOURCE_OFFSET.x + SOURCE_SIZE.x, SOURCE_OFFSET.y) if mirrored else SOURCE_OFFSET
		rig.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
		rig.layout["screen_pixel_scale"] = screen_pixel_scale
		rig.layout["step_distance_px"] = step_distance_px
		rig.apply_pose(shown, progress)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if is_instance_valid(viewport) else null

func source_socket() -> Vector2:
	var rig: Node2D = rigs.get(facing)
	var bone: Bone2D = rig.bones.get("core")
	return bone.global_position - SOURCE_OFFSET if bone != null else SOURCE_SIZE / 2.0

func snapshot() -> Dictionary:
	return {"art": character_id + "_maquette", "clip": clip, "shown_clip": _shown_clip(), "phase": _shown_phase(),
		"facing": facing, "mirrored": mirrored, "active": active, "rig_count": rigs.size(),
		"reduced_motion": reduced_motion,
		"screen_pixel_scale": screen_pixel_scale, "step_distance_px": step_distance_px,
		"texture_id": texture().get_instance_id() if texture() != null else 0}

func _shown_clip() -> String:
	return "death" if clip == "death" else "rest" if reduced_motion else clip

func _shown_phase() -> float:
	return 1.0 if reduced_motion and clip == "death" else 0.0 if reduced_motion else _idle_seconds / float(motion_data()["clips"]["idle"]["seconds"]) if clip == "idle" else phase
