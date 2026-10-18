extends RefCounted

## Preserve authored float64 angle ties until the final pixel presentation.
## Bone2D still receives the continuous pose. Reconstructing its angle from a
## float32 matrix can move an exact half step to the other side of the tie.
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const MIN_PIXEL_SCALE: float = 0.000001 # Same zero-scale guard as SemanticMotion.

static func angles(data: Dictionary, layout: Dictionary, view: String, clip: String, phase: float) -> Dictionary:
	var channels: Dictionary = Motion.channels_at(data, clip, phase, view, float(layout.get("step_distance_px", 0.0)))
	var matrices: Dictionary = {}
	var result: Dictionary = {}
	for bone: String in layout["joints"]:
		basis(bone, layout, channels, matrices)
		var matrix: Array = matrices[bone]
		result[bone] = atan2(float(matrix[1]), float(matrix[0]))
	return result

static func apply_bones(rig: Node2D, data: Dictionary, clip: String, phase: float) -> void:
	# Compensate float32 parent accumulation with a float64 relative solve.
	# Both the local and global Bone2D contracts remain independently tested.
	var values: Dictionary = Motion.channels_at(data, clip, phase, rig.facing, float(rig.layout.get("step_distance_px", 0.0)))
	var matrices: Dictionary = {}
	var done: Dictionary = {}
	for bone: String in rig.bones:
		world(bone, rig.layout, values, data["projection"][rig.facing]["forward"], matrices)
	for bone: String in rig.bones:
		install(bone, rig, matrices, done)

static func world(bone: String, layout: Dictionary, channels: Dictionary, forward: Array, matrices: Dictionary) -> void:
	if matrices.has(bone): return
	var bases: Dictionary = {}
	basis(bone, layout, channels, bases)
	var joint: Dictionary = layout["joints"][bone]
	var parent: Variant = joint["parent"]
	var values: Dictionary = channels.get(bone, {})
	var pixel_scale: float = maxf(float(layout.get("screen_pixel_scale", 1.0)), MIN_PIXEL_SCALE)
	var x: float = float(joint["position"][0])
	var y: float = float(joint["position"][1])
	if parent != null:
		x -= float(layout["joints"][parent]["position"][0])
		y -= float(layout["joints"][parent]["position"][1])
	x += float(forward[0]) * float(values.get("forward_px", 0.0)) / pixel_scale
	y += (float(forward[1]) * float(values.get("forward_px", 0.0)) - float(values.get("lift_px", 0.0))) / pixel_scale
	if parent != null:
		world(str(parent), layout, channels, forward, matrices)
		var p: Array = matrices[parent]
		var next_x: float = float(p[0]) * x + float(p[2]) * y + float(p[4])
		y = float(p[1]) * x + float(p[3]) * y + float(p[5])
		x = next_x
	var b: Array = bases[bone]
	matrices[bone] = [b[0], b[1], b[2], b[3], x, y]

static func install(bone: String, rig: Node2D, matrices: Dictionary, done: Dictionary) -> void:
	if done.has(bone): return
	var parent: Variant = rig.layout["joints"][bone]["parent"]
	var target: Array = matrices[bone].duplicate()
	if parent != null:
		install(str(parent), rig, matrices, done)
		var p: Transform2D = rig.global_transform.affine_inverse() * rig.bones[parent].global_transform
		var determinant: float = float(p.x.x) * float(p.y.y) - float(p.x.y) * float(p.y.x)
		var a: float = float(p.y.y) / determinant
		var b: float = -float(p.x.y) / determinant
		var c: float = -float(p.y.x) / determinant
		var d: float = float(p.x.x) / determinant
		var x: float = float(target[4]) - float(p.origin.x)
		var y: float = float(target[5]) - float(p.origin.y)
		target = [a * float(target[0]) + c * float(target[1]), b * float(target[0]) + d * float(target[1]),
			a * float(target[2]) + c * float(target[3]), b * float(target[2]) + d * float(target[3]),
			a * x + c * y, b * x + d * y]
	rig.bones[bone].transform = Transform2D(Vector2(target[0], target[1]), Vector2(target[2], target[3]), Vector2(target[4], target[5]))
	done[bone] = true

static func basis(bone: String, layout: Dictionary, channels: Dictionary, matrices: Dictionary) -> void:
	if matrices.has(bone): return
	var values: Dictionary = channels.get(bone, {})
	var angle: float = deg_to_rad(float(values.get("raise_deg", 0.0)) + float(values.get("lean_deg", 0.0)))
	var squash: float = float(values.get("squash", 1.0))
	var scale: float = float(values.get("scale", 1.0))
	var c: float = cos(angle)
	var s: float = sin(angle)
	var local: Array = [c * scale / squash, s * scale / squash, -s * scale * squash, c * scale * squash]
	var parent: Variant = layout["joints"][bone]["parent"]
	if parent == null:
		matrices[bone] = local
		return
	basis(str(parent), layout, channels, matrices)
	var p: Array = matrices[parent]
	matrices[bone] = [float(p[0]) * float(local[0]) + float(p[2]) * float(local[1]),
		float(p[1]) * float(local[0]) + float(p[3]) * float(local[1]),
		float(p[0]) * float(local[2]) + float(p[2]) * float(local[3]),
		float(p[1]) * float(local[2]) + float(p[3]) * float(local[3])]
