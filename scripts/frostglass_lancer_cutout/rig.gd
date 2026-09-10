extends "res://scripts/protagonist_cutout/rig.gd"

## Frostglass topology and paint reuse the production skeleton loader.
const FrostglassMotion = preload("res://scripts/frostglass_lancer_cutout/motion.gd")
const FROSTGLASS_BASE: String = "res://assets/units/frostglass_lancer_cutout"
var _paint_facing: String = ""
var _paint: Dictionary = {}
var _default_layers: Dictionary = {}

func _layout_path(which: String) -> String:
	return FROSTGLASS_BASE.path_join(which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else FROSTGLASS_BASE.path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = FrostglassMotion.sample_pose(clip_name, phase_value, layout, facing)
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position", bone.position)
		bone.rotation = float(override.get("rotation", 0.0))
		bone.scale = override.get("scale", Vector2.ONE)
		bone.skew = float(override.get("skew", 0.0))
	if _paint_facing != facing:
		_paint_facing = facing
		_paint.clear()
		_default_layers.clear()
		for part_name: String in FrostglassMotion.sample_draw_order("walk", 0.0, layout, facing):
			# A rigid boot's Bone2D has the same name; only the painted node
			# owns its absolute layer and can keep it behind the nearer shin.
			var matches: Array[Node] = find_children(part_name, "Sprite2D", true, false)
			matches.append_array(find_children(part_name, "Polygon2D", true, false))
			if matches.size() != 1:
				load_errors.append("Missing or ambiguous Frostglass paint: " + part_name)
				continue
			_paint[part_name] = matches[0]
			_default_layers[part_name] = (matches[0] as CanvasItem).z_index
	var layers: Dictionary = FrostglassMotion.sample_draw_order(clip_name, phase_value, layout, facing)
	for part_name: String in _paint:
		(_paint[part_name] as CanvasItem).z_index = int(layers.get(part_name, _default_layers[part_name]))
