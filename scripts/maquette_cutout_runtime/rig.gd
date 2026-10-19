extends "res://scripts/protagonist_cutout/rig.gd"

const SemanticMotion = preload("motion.gd")
const Pixels = preload("pixel_presentation.gd")
var character_id: String = "shale_bloomer"
var case_directory: String = ""
var precise_angles: Dictionary = {}
var _glow_textures: Dictionary = {}

func base_path() -> String:
	return case_directory if not case_directory.is_empty() else "res://assets/units/" + character_id + "_cutout"

func _layout_path(which: String) -> String:
	return base_path().path_join("layouts/" + which + ".json" if not case_directory.is_empty() else which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path() else base_path().path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	layout["motion_data"] = base_path().path_join("compiled_motion.json")
	var data: Dictionary = SemanticMotion.data_for(layout)
	apply_authored_pose(clip_name, Pixels.phase_for(data, clip_name, phase_value))
	if str(data.get("rig", "")) == "humanoid_v2":
		preload("humanoid_presentation.gd").apply(self, clip_name)
		return
	Pixels.apply(self)

## Diagnostic oracle entry point; never used by production playback. Retain the
## raw Bone2D contract separately from the deliberately stepped presentation.
func apply_authored_pose(clip_name: String, phase_value: float) -> void:
	layout["motion_data"] = base_path().path_join("compiled_motion.json")
	var pose: Dictionary = SemanticMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose, true)
	precise_angles.clear()
	if bool(layout.get("native_angle_ties", false)) and clip_name != "rest":
		preload("res://assets/units/hoarfrost_seer_cutout/precision.gd").apply_bones(
			self, SemanticMotion.data_for(layout), clip_name, phase_value)
		precise_angles = preload("res://assets/units/hoarfrost_seer_cutout/precision.gd").angles(
			SemanticMotion.data_for(layout), layout, facing, clip_name, phase_value)
	for bone: String in bones:
		(bones[bone] as Bone2D).modulate.a = float(pose.get(bone, {}).get("alpha", 1.0))
	if layout.has("glow_textures"):
		# rr-17: swap pre-baked integer light levels; no shader or resampling.
		var data: Dictionary = SemanticMotion.data_for(layout)
		var channels: Dictionary = {} if clip_name == "rest" else SemanticMotion.channels_at(data, clip_name, phase_value, facing, 0.0)
		var level: int = int(channels.get("column", {}).get("glow", 0))
		for part: Dictionary in layout["parts"]:
			if part["name"] != "column": continue
			var path: String = str(layout["glow_textures"][str(level)])
			if not _glow_textures.has(path): _glow_textures[path] = _texture(path)
			(bones["column"].get_node("column") as Sprite2D).texture = _glow_textures[path]
		# Keep the authored float64 half-step decision out of Bone2D's float32
		# matrix decomposition, as in the rr-05 native agreement path.
		precise_angles["cap"] = deg_to_rad(float(channels.get("cap", {}).get("lean_deg", 0.0)) * float(layout.get("forward_reflection", 1.0)))
