extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const REST_PATH: String = "res://assets/units/frostglass_lancer_cutout/humanoid_v2/front/rest.png"
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const WALK_CYCLE_SECONDS: float = 0.85 # Protected director move duration.

func _init() -> void:
	character_id = "frostglass_lancer"

static func walk_segment_frames(_source_distance: float) -> int:
	return roundi(WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS)

func _new_rig() -> Node2D:
	return Rig.new()

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": "res://assets/units/frostglass_lancer_cutout/humanoid_v2/compiled_motion.json"})

static func direction_for_delta(delta: Vector2i) -> Dictionary:
	return preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(delta)

func strike_samples(actor: Dictionary, effect: Dictionary, delta: Vector2i, settings: Dictionary, contact: float) -> Array[Dictionary]:
	return preload("res://scripts/maquette_cutout_runtime/strike_points.gd").samples(self, actor, effect, delta, settings, contact, "spear")

## Non-player buffer capacity: the released full-length spear needs more padding.
func canvas_geometry() -> Dictionary:
	return {"offset": Vector2(192, 192), "size": Vector2i(640, 640)}
