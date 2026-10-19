extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const REST_PATH: String = "res://assets/units/storm_capacitor_cutout/front/rest.png"
var _forward_reflection: float = 1.0
var _idle_seed_seconds: float = 0.0

func _init() -> void:
	character_id = "storm_capacitor"

func seed_idle_phase(value: float) -> void:
	super.seed_idle_phase(value)
	_idle_seed_seconds = _idle_seconds

func _process(delta: float) -> void:
	var recovering: bool = clip == "hit"
	super._process(delta)
	if recovering and clip == "idle":
		_idle_seconds = _idle_seed_seconds
		_apply_pose()

func present(motion: Dictionary, reduce: bool, enabled: bool = true) -> void:
	# Direction changes the signed motion axes, never the rotationally symmetric
	# painting. Hit/death retain the preceding action/idle direction.
	if str(motion.get("clip", "idle")) not in ["hit", "death"] and motion.get("direction", Vector2i.ZERO) != Vector2i.ZERO:
		var reflection: float = -1.0 if Facing.direction_for_delta(motion["direction"])["mirrored"] else 1.0
		if reflection != _forward_reflection: _render_signature.clear()
		_forward_reflection = reflection
	super.present(motion, reduce, enabled)

func _apply_pose() -> void:
	mirrored = false
	for view: String in rigs:
		var axis: Vector2 = Motion.point(motion_data()["projection"][view]["forward"])
		axis.x *= _forward_reflection
		rigs[view].layout["forward_axis"] = axis
		rigs[view].layout["forward_reflection"] = _forward_reflection
	super._apply_pose()
