extends RefCounted

## Resample the actual production rig with its live tile travel and board scale.
## Restore its current phase before returning to the production capture.
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const FPS: float = 60.0

static func capture(rig: Node2D, restore_clip: String, restore_phase: float) -> Dictionary:
	var data: Dictionary = Motion.data_for(rig.layout)
	var count: int = roundi(float(data["clips"]["move"]["seconds"]) * FPS)
	var rows: Array[Dictionary]
	for index: int in range(count):
		var phase: float = float(index) / float(count - 1)
		for kind: String in ["authored", "presented"]:
			if kind == "authored": rig.apply_authored_pose("move", phase)
			else: rig.apply_pose("move", phase)
			rows.append(record(rig, phase, index, kind))
	rig.apply_pose(restore_clip, restore_phase)
	return {"samples": rows, "step_distance_px": rig.layout["step_distance_px"], "screen_pixel_scale": rig.layout["screen_pixel_scale"]}

static func record(rig: Node2D, phase: float, frame: int, kind: String) -> Dictionary:
	var source: Transform2D = rig.global_transform.affine_inverse()
	var bones: Dictionary = {}
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		bones[name] = {"local": matrix(bone.transform), "global": matrix(source * bone.global_transform)}
	var parts: Dictionary = {}
	for part: Dictionary in rig.layout["parts"]:
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node_or_null(NodePath(part["name"])) as Sprite2D
		if sprite != null: parts[part["name"]] = {"transform": matrix(source * sprite.global_transform)}
	return {"view": rig.facing, "clip": "move", "phase": phase, "frame": frame, "kind": kind, "bones": bones, "parts": parts}

static func matrix(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]
