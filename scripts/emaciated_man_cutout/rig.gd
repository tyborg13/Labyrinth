extends "res://scripts/protagonist_cutout/rig.gd"
const EmaciatedMotion = preload("motion.gd")
const EmberOverlay = preload("glow.gd")
const IDLE_SECONDS: float = EmaciatedMotion.IDLE_SECONDS
const EMACIATED_BASE: String = "res://assets/units/emaciated_man_cutout"
var _ember_overlay: RefCounted

func _layout_path(_which: String) -> String:
	return EMACIATED_BASE.path_join("front.json")

func has_facing(which: String) -> bool:
	return which == "front" and FileAccess.file_exists(_layout_path(which))

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else EMACIATED_BASE.path_join(path)

func load_rig() -> bool:
	var loaded: bool = super.load_rig()
	if loaded and _ember_overlay == null:
		_ember_overlay = EmberOverlay.new()
		_ember_overlay.setup(self)
		apply_pose("idle", 0.0)
	return loaded

func set_glow_enabled(enabled: bool) -> void:
	if _ember_overlay != null:
		_ember_overlay.enabled = enabled
		if not enabled: _ember_overlay.present({})

func apply_pose(clip_name: String, phase: float) -> void:
	var pose: Dictionary = EmaciatedMotion.sample_pose(clip_name, phase, layout, "front")
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position", bone.position)
		bone.rotation = float(override.get("rotation", 0.0))
		bone.scale = override.get("scale", Vector2.ONE)
		bone.skew = float(override.get("skew", 0.0))
	if _ember_overlay != null: _ember_overlay.present(EmaciatedMotion.sample_glow(clip_name, phase))
