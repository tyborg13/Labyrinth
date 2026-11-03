extends "res://scripts/protagonist_cutout/rig.gd"

const SemanticMotion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
var character_id: String = "shale_bloomer"
var case_directory: String = ""
var precise_angles: Dictionary = {}
var _glow_textures: Dictionary = {}
var cap_bones: Dictionary = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_paint.gd").follow_root(self)

func load_rig() -> bool:
	cap_bones.clear()
	return super.load_rig()

func _build_mesh(data: Dictionary, mesh_name: String, source_key: String) -> void:
	if not data.get("rigid_source_alignment", false):
		super._build_mesh(data, mesh_name, source_key)
		preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_paint.gd").register_mesh(self, data, mesh_name)
		return
	preload("res://scripts/maquette_cutout_runtime/humanoid_joint_caps.gd").ensure_bones(self, data)
	super._build_mesh(data, mesh_name, source_key)
	var mesh: Polygon2D = get_node_or_null(NodePath(mesh_name)) as Polygon2D
	if mesh == null: return
	var prepared: Dictionary = _source_data.prepare_mesh(data, mesh_name, source_key)
	mesh.clear_bones()
	for name: String in prepared["weights"]:
		var bone: Bone2D = cap_bones[name] if cap_bones.has(name) else bones[name]
		mesh.add_bone(skeleton.get_path_to(bone), prepared["weights"][name])
	preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_paint.gd").register_mesh(self, data, mesh_name)

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
		preload("res://scripts/maquette_cutout_runtime/humanoid_presentation.gd").apply(self, clip_name, phase_value)
		preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_paint.gd").apply(self, clip_name)
		return
	Pixels.apply(self)

## Diagnostic oracle entry point; never used by production playback. Retain the
## raw Bone2D contract separately from the deliberately stepped presentation.
func apply_authored_pose(clip_name: String, phase_value: float) -> void:
	layout["motion_data"] = base_path().path_join("compiled_motion.json")
	preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_paint.gd").restore(self)
	preload("res://scripts/maquette_cutout_runtime/humanoid_held_follow.gd").reset_authored_sprites(self, SemanticMotion.data_for(layout))
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
	preload("res://scripts/maquette_cutout_runtime/humanoid_joint_caps.gd").apply(self, {}, clip_name, phase_value)
