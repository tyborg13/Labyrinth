extends Node

const Rig = preload("rig.gd")
const Motion = preload("motion.gd")
const Data = preload("motion_data.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const REST_PATH: String = "res://assets/units/gust_shrike_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
const INTEGRATION_PATH: String = "res://assets/units/gust_shrike_cutout/integration.json"
static var _availability_checked: bool = false
static var _available: bool = false

var viewport: SubViewport
var rigs: Dictionary = {}
var facing: String = "front"
var mirrored: bool = false
var clip: String = "idle"
var phase: float = 0.0
var active: bool = true
var reduced_motion: bool = false
var recoil_direction := Vector2.ZERO
var screen_pixel_scale: float = Data.PROOF_PIXEL_SCALE
var _idle_seconds: float = 0.0
var _pose_signature: Array = []

static func available() -> bool:
	# No blank rig, magenta hidden requests, or invented motion reaches combat.
	# Promotion happens between engine runs; file IO never belongs in draw loops.
	if _availability_checked: return _available
	_availability_checked = true
	if not Motion.design_errors().is_empty() or not FileAccess.file_exists(INTEGRATION_PATH): return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(INTEGRATION_PATH))
	_available = manifest is Dictionary and bool(manifest.get("ready", false)) and FileAccess.file_exists("res://assets/units/gust_shrike_cutout/front.json") and FileAccess.file_exists("res://assets/units/gust_shrike_cutout/rear.json")
	return _available

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "GustShrikeCanvas"
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
		if not rig.load_rig(): push_error("Gust Shrike cutout could not load: " + str(rig.load_errors))
		rigs[view] = rig
	_apply_pose()

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	active = enabled
	reduced_motion = reduce
	screen_pixel_scale = float(motion.get("screen_pixel_scale", screen_pixel_scale))
	var requested: String = str(motion.get("clip", "idle"))
	# Freeze terminal orientation/pose throughout the existing dissolve.
	if clip == "death" and requested != "death":
		_apply_pose()
		return
	if not active and requested != "death": return
	var previous: String = clip
	clip = requested if requested in Data.TRACKS else "idle"
	phase = clampf(float(motion.get("phase", 0.0)), 0.0, 1.0)
	if clip not in ["hit", "death"]:
		var delta: Vector2i = motion.get("direction", Vector2i.ZERO)
		if delta != Vector2i.ZERO:
			var direction: Dictionary = Facing.direction_for_delta(delta)
			facing = str(direction["facing"])
			mirrored = bool(direction["mirrored"])
	if motion.has("recoil_direction"):
		recoil_direction = motion["recoil_direction"]
	if previous != "idle" and clip == "idle": _idle_seconds = 0.0
	_apply_pose()

func _process(delta: float) -> void:
	if not active or reduced_motion or clip != "idle": return
	if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree(): return
	_idle_seconds = fposmod(_idle_seconds + delta, Data.IDLE_SECONDS)
	_apply_pose()

func _apply_pose() -> void:
	if rigs.is_empty(): return
	var shown: String = "death" if clip == "death" else "rest" if reduced_motion else clip
	var progress: float = 1.0 if reduced_motion and clip == "death" else 0.0 if reduced_motion else _idle_seconds / Data.IDLE_SECONDS if clip == "idle" else phase
	var signature: Array = [facing, mirrored, shown, progress, recoil_direction, screen_pixel_scale]
	if signature == _pose_signature: return
	_pose_signature = signature
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		rig.visible = view == facing
		if not rig.visible: continue
		rig.position = Vector2(SOURCE_OFFSET.x + SOURCE_SIZE.x, SOURCE_OFFSET.y) if mirrored else SOURCE_OFFSET
		rig.scale = Vector2(-1, 1) if mirrored else Vector2.ONE
		rig.layout["recoil_direction"] = recoil_direction * Vector2(-1 if mirrored else 1, 1)
		rig.layout["screen_pixel_scale"] = screen_pixel_scale
		rig.apply_pose(shown, progress)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if is_instance_valid(viewport) else null

func snapshot() -> Dictionary:
	return {"art": "gust_shrike_cutout_mq2", "clip": clip, "phase": phase,
		"shown_clip": "death" if clip == "death" else "rest" if reduced_motion else clip,
		"facing": facing, "mirrored": mirrored, "active": active,
		"screen_pixel_scale": screen_pixel_scale,
		"rig_count": rigs.size(), "texture_id": texture().get_instance_id() if texture() != null else 0}
