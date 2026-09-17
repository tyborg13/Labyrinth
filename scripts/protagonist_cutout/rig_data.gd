extends RefCounted
## Immutable source data shared only while rigs using it are alive. Weak entries
## avoid retaining every creature's large JSON/mesh arrays after leaving a room.
class Data extends RefCounted:
	var layout: Dictionary = {}
	var meshes: Dictionary = {}
	var modified: int = 0
	var error: String = ""

	func prepare_mesh(source: Dictionary, mesh_name: String, source_key: String) -> Dictionary:
		if meshes.has(source_key):
			return meshes[source_key]
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point: Variant in source["vertices"]:
			vertices.append(Vector2(float(point[0]), float(point[1])))
		for point: Variant in source["uvs"]:
			uvs.append(Vector2(float(point[0]), float(point[1])))
		if vertices.size() != uvs.size():
			return {"error": mesh_name + ": vertex/UV count differs"}
		var triangles: Array = []
		for triangle: Variant in source["triangles"]:
			if triangle.size() != 3:
				return {"error": mesh_name + ": a mesh face must contain three indices"}
			for index: int in triangle:
				if index < 0 or index >= vertices.size():
					return {"error": mesh_name + ": triangle index outside vertex array"}
			triangles.append(PackedInt32Array(triangle))
		var weights: Dictionary = {}
		var totals := PackedFloat32Array()
		totals.resize(vertices.size())
		for bone_name: String in source["weights"]:
			var influence := PackedFloat32Array(source["weights"][bone_name])
			if influence.size() != vertices.size() or not (layout["joints"] as Dictionary).has(bone_name):
				return {"error": mesh_name + ": invalid skin weights for " + bone_name}
			for index: int in range(influence.size()):
				if not is_finite(influence[index]) or influence[index] < 0.0:
					return {"error": mesh_name + ": invalid influence for " + bone_name}
				totals[index] += influence[index]
			weights[bone_name] = influence
		for total: float in totals:
			if absf(total - 1.0) > 0.001:
				return {"error": mesh_name + ": vertex weights do not sum to one"}
		var prepared: Dictionary = {"vertices": vertices, "uvs": uvs, "triangles": triangles, "weights": weights}
		meshes[source_key] = prepared
		return prepared

static var _sources: Dictionary = {}

static func load_source(path: String) -> Data:
	var modified: int = FileAccess.get_modified_time(path)
	var cached: Data = (_sources[path] as WeakRef).get_ref() as Data if _sources.has(path) else null
	if cached != null and cached.modified == modified:
		return cached
	var result := Data.new()
	result.modified = modified
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		result.error = "Invalid cutout layout: " + path
		return result
	result.layout = parsed as Dictionary
	_sources[path] = weakref(result)
	return result
