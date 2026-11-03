extends RefCounted

## Immutable, floor-relative meshes. Mirrors and root travel are submission
## transforms, so neither movement nor animation phase builds new geometry.
const Actor = preload("res://scripts/actor_presentation.gd")
# Numerical approximation of a semicircle (subpixel error on the rest canvas).
const CAP_SEGMENTS: int = 32
var meshes: Dictionary = {}

func mesh_for(unit_type: String, facing: String, draw_size: Vector2) -> ArrayMesh:
	if not Actor.GROUND_CONTACT.has(unit_type): return null
	var views: Dictionary = Actor.GROUND_CONTACT[unit_type]
	if not views.has(facing): return null
	if not meshes.has(unit_type): meshes[unit_type] = {}
	var by_facing: Dictionary = meshes[unit_type]
	if not by_facing.has(facing): by_facing[facing] = {}
	var by_size: Dictionary = by_facing[facing]
	if not by_size.has(draw_size):
		by_size[draw_size] = _build(views[facing], Actor.floor_anchor(unit_type, facing), draw_size / Actor.SOURCE_SIZE)
	return by_size[draw_size] as ArrayMesh

static func root_transform(center: Vector2, mirrored: bool) -> Transform2D:
	return Transform2D(Vector2.LEFT if mirrored else Vector2.RIGHT, Vector2.DOWN, center)

static func _build(contact: Dictionary, anchor: Vector2, pixel_scale: Vector2) -> ArrayMesh:
	var start: Vector2 = contact["from"]
	var finish: Vector2 = contact["to"]
	var radius: float = float(contact["half_width"])
	var axis: Vector2 = (finish - start).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var points := PackedVector2Array([start, finish, start + normal * radius,
		finish + normal * radius, start - normal * radius, finish - normal * radius])
	var colors := PackedColorArray([Color(0, 0, 0, contact["alpha"]), Color(0, 0, 0, contact["alpha"]),
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
	var indices := PackedInt32Array([0, 2, 1, 2, 3, 1, 0, 1, 4, 1, 5, 4])
	# Full alpha along the segment; linear interpolation feathers to the zero
	# alpha boundary, including both rounded ends. No overlapping alpha layers.
	for end_index: int in range(2):
		var center: Vector2 = start if end_index == 0 else finish
		var first: int = points.size()
		var angle: float = axis.angle() + (PI * 0.5 if end_index == 0 else -PI * 0.5)
		for step: int in range(CAP_SEGMENTS + 1):
			points.append(center + Vector2.from_angle(angle + PI * float(step) / CAP_SEGMENTS) * radius)
			colors.append(Color(0, 0, 0, 0))
			if step > 0:
				indices.append(end_index)
				indices.append(first + step - 1)
				indices.append(first + step)
	var vertices := PackedVector3Array()
	for point: Vector2 in points:
		var local: Vector2 = (point - anchor) * pixel_scale
		vertices.append(Vector3(local.x, local.y, 0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
