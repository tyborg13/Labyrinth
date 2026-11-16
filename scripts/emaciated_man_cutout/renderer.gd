extends Node
const Rig = preload("rig.gd")
const Motion = preload("motion.gd")
const REST_PATH: String = "res://assets/units/emaciated_man_cutout/front/rest.png"
const SOURCE_SIZE := Vector2(255, 255)
const SOURCE_OFFSET := Vector2(128, 128)
const CANVAS_SIZE := Vector2i(512, 512)
var viewport: SubViewport
var rig: Node2D
var rigs: Dictionary = {}
var clip: String = "idle"
var facing: String = "front"
var mirrored: bool = false
var reduced_motion: bool = false
var seconds: float = 0.0
var _idle_seconds: float:
	get: return seconds
	set(value): seconds = value
var _signature: Array = []

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "EmaciatedManCanvas"
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	rig = Rig.new()
	rigs["front"] = rig
	rig.position = SOURCE_OFFSET
	viewport.add_child(rig)
	if not rig.load_rig(): push_error("Emaciated Man cutout: " + str(rig.load_errors))
	present(0.0, false)

func present(elapsed: float, reduce: bool) -> void:
	seconds = fposmod(elapsed, Motion.IDLE_SECONDS)
	reduced_motion = reduce
	clip = "rest" if reduce else "idle"
	var signature: Array = [0.0 if reduce else seconds, reduce]
	if signature == _signature: return
	_signature = signature
	if not is_instance_valid(rig): return
	rig.apply_pose("rest" if reduce else "idle", 0.0 if reduce else seconds / Motion.IDLE_SECONDS)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture() if is_instance_valid(viewport) else null

func _apply_pose() -> void:
	# Shared renderer probes freeze every cutout through this existing seam.
	_signature.clear()
	present(seconds, reduced_motion)

func snapshot() -> Dictionary:
	return {"art":"emaciated_man_cutout", "facing":facing, "mirrored":mirrored,
		"clip":"rest" if reduced_motion else "idle", "phase":seconds / Motion.IDLE_SECONDS,
		"seconds":seconds, "reduced_motion":reduced_motion}
