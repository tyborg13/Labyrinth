extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const REST_PATH: String = "res://assets/units/ashen_reaver_cutout/humanoid_v2/front/rest.png"
const WALK_FRAME_SECONDS: float = 1.0 / Action.FPS
# The authored action clock is loaded data, so this contract is a static value
# rather than a second, hard-coded duration. Movement uses the same frame query.
static var WALK_CYCLE_SECONDS: float = float(Action.frames_for("ashen_reaver", "move")) * WALK_FRAME_SECONDS

func _init() -> void:
	character_id = "ashen_reaver"

static func walk_segment_frames(_source_distance: float) -> int:
	return Action.frames_for("ashen_reaver", "move")

func _new_rig() -> Node2D:
	return Rig.new()

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": "res://assets/units/ashen_reaver_cutout/humanoid_v2/compiled_motion.json"})

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(delta)

func strike_samples(actor: Dictionary, effect: Dictionary, delta: Vector2i, settings: Dictionary, contact: float) -> Array[Dictionary]:
	return preload("res://scripts/maquette_cutout_runtime/strike_points.gd").samples(self, actor, effect, delta, settings, contact, "falchion")

## Non-player buffer capacity: the released falchion needs more padding.
func canvas_geometry() -> Dictionary:
	return {"offset": Vector2(192, 192), "size": Vector2i(640, 640)}
